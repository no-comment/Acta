import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BankStatementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Environment(\.openWindow) private var openWindow
    @Query private var statements: [BankStatement]
    
    @SceneStorage("BankStatementColumnCustomization") private var columnCustomization: TableColumnCustomization<BankStatement>
    @State private var sortOrder = [KeyPathComparator(\BankStatement.date), KeyPathComparator(\BankStatement.account)]
    @State private var selection: BankStatement.ID?
    
    @State private var isTargeted = false
    @State private var importURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false

    // Search state
    @State private var searchText = ""
    @State private var searchTokens: [BankStatementSearchToken] = []

    private var suggestedTokens: [BankStatementSearchToken] {
        guard !searchText.isEmpty else { return [] }
        var tokens: [BankStatementSearchToken] = []

        for field in BankStatementSearchToken.Field.allCases {
            if field == .status {
                let matchingStatuses = BankStatement.Status.allCases.filter {
                    $0.label.lowercased().contains(searchText.lowercased())
                }
                for status in matchingStatuses {
                    tokens.append(BankStatementSearchToken(field: .status, value: status.label))
                }
            } else {
                tokens.append(BankStatementSearchToken(field: field, value: searchText))
            }
        }

        return tokens
    }
    
    private var filteredStatements: [BankStatement] {
        var result = statements

        for token in searchTokens {
            result = result.filter { token.matches($0) }
        }

        if !searchText.isEmpty {
            let searchToken = BankStatementSearchToken(field: .all, value: searchText)
            result = result.filter { searchToken.matches($0) }
        }

        return result
    }

    private var sortedStatements: [BankStatement] {
        filteredStatements.sorted(using: sortOrder)
    }

    private var isSearching: Bool {
        !searchText.isEmpty || !searchTokens.isEmpty
    }
    
    private var selectedStatement: BankStatement? {
        guard let selection else { return nil }
        return statements.first { $0.id == selection }
    }
    
    private var showInspector: Binding<Bool> {
        Binding(
            get: { selectedStatement != nil },
            set: { newValue in
                if newValue == false {
                    selection = nil
                }
            }
        )
    }
    
    var body: some View {
        content
            .searchable(text: $searchText, tokens: $searchTokens, prompt: "Search statements") { token in
                if token.field == .all {
                    Text(token.value)
                } else {
                    Text("\(token.field.rawValue): \(token.value)")
                }
            }
            .searchSuggestions {
                if !searchText.isEmpty {
                    ForEach(suggestedTokens) { token in
                        let matchCount = statements.filter { token.matches($0) }.count
                        if matchCount > 0 {
                            HStack {
                                Label("\(token.field.rawValue): \(token.value)", systemImage: token.field.iconName)
                                Spacer()
                                Text("\(matchCount)")
                                    .foregroundStyle(.secondary)
                            }
                            .searchCompletion(token)
                        }
                    }
                }
            }
            .toolbar(content: toolbar)
            .inspector(isPresented: showInspector, content: {
                if let selectedStatement {
                    BankStatementInspectorView(for: selectedStatement, onClose: { self.selection = nil })
                }
            })
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                return handleDrop(url: url)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .overlay {
                if isTargeted {
                    dropOverlay
                }
            }
            .sheet(isPresented: sheetPresented) {
                if let importURL {
                    BankStatementCSVImportView(url: importURL)
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if self.statements.isEmpty {
            ContentUnavailableView("No Bank Statements", systemImage: "tray.and.arrow.down", description: Text("Drop a CSV file to import your first bank statement"))
        } else if self.sortedStatements.isEmpty && isSearching {
            ContentUnavailableView.search(text: searchText)
        } else {
            table
        }
    }
    
    private var table: some View {
        Table(self.sortedStatements, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("", value: \.status) { statement in
                statement.status.icon
                    .help(statement.status.label)
            }
            .width(14)
            .disabledCustomizationBehavior(.all)
            .customizationID("status")
            
            TableColumn("Account", value: \.account) { statement in
                Text(statement.account ?? "")
            }
            .customizationID("accountName")
            
            TableColumn("Date", value: \.date) { statement in
                Text(statement.date.map { Formatters.date.string(from: $0) } ?? "N/A")
            }
            .customizationID("date")
            
            TableColumn("Amount", value: \.amountDisplay) { statement in
                Text(statement.amountDisplay ?? "")
                    .monospacedDigit()
                    .valueColor(for: statement.amount)
            }
            .alignment(.trailing)
            .customizationID("amount")
            
            TableColumn("Reference", value: \.reference) { statement in
                Text(statement.reference ?? "")
            }
            .customizationID("reference")
            
            TableColumn("Notes", value: \.notes)
                .customizationID("notes")
            
            TableColumn("Linked Invoice", value: \.matchedInvoice?.path) { statement in
                Text(statement.linkedFilePath ?? "")
            }
            .defaultVisibility(.hidden)
            .customizationID("linkedFileName")
        }
        .contextMenu(forSelectionType: BankStatement.ID.self) { items in
            Button("Delete Statement", systemImage: "trash", role: .destructive, action: { deleteStatements(items) })
                .tint(.red)
        } primaryAction: { items in
            guard let statementID = items.first else { return }
            openWindow(value: ActaApp.WindowType.statementMatching(id: statementID))
        }
    }
    
    @ToolbarContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Auto Link", systemImage: "wand.and.stars") {
                BankStatementMatcher.autoLink(modelContext: modelContext)
            }
            .help("Auto Link")
        }
        
        ToolbarItemGroup(placement: .principal) {
            Button("Generate Sample Data", systemImage: "plus") {
                BankStatement.generateMockData(modelContext: modelContext)
            }
            
            Button("Delete All", systemImage: "trash", role: .destructive) {
                for statement in statements {
                    modelContext.delete(statement)
                }
            }
        }
    }
    
    private var dropOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Drop to Import")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var sheetPresented: Binding<Bool> {
        Binding(
            get: { importURL != nil },
            set: { newValue in
                if !newValue {
                    importURL = nil
                }
            }
        )
    }
    
    private func handleDrop(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            errorMessage = "Unsupported file type"
            showError = true
            return false
        }
        
        if type.conforms(to: .commaSeparatedText) || type.conforms(to: .plainText) {
            importURL = url
            return true
        }
        
        errorMessage = "Only CSV files can be imported"
        showError = true
        return false
    }
    
    private func deleteStatements(_ statementIDs: Set<BankStatement.ID>) {
        for statementID in statementIDs {
            guard let statement = self.statements.first(where: { $0.id == statementID }) else { continue }
            modelContext.delete(statement)
        }
    }
}

#Preview {
    BankStatementsView()
}
