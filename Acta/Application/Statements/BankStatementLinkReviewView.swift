import SwiftData
import SwiftUI

struct BankStatementLinkReviewView: View {
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Query(sort: \BankStatement.date) private var statements: [BankStatement]
    
    private var unapprovedStatements: [BankStatement] {
        statements.filter { statement in
            guard let invoice = statement.matchedInvoice else { return false }
            return invoice.status != .statementVerified
        }
    }
    
    @State private var currentStatementID: BankStatement.ID?
    
    private var currentStatement: BankStatement? {
        if let currentStatementID {
            return unapprovedStatements.first { $0.id == currentStatementID }
        }
        return unapprovedStatements.first
    }
    
    private var currentInvoice: Invoice? {
        currentStatement?.matchedInvoice
    }
    
    private var currentIndex: Int {
        guard let currentStatementID else { return 0 }
        return unapprovedStatements.firstIndex { $0.id == currentStatementID } ?? 0
    }
    
    private var documentURL: URL? {
        guard let currentInvoice else { return nil }
        return documentManager?.getURL(for: currentInvoice)
    }
    
    private var hasPrevious: Bool {
        currentIndex > 0 && !unapprovedStatements.isEmpty
    }
    
    private var hasNext: Bool {
        currentIndex < unapprovedStatements.count - 1 && !unapprovedStatements.isEmpty
    }
    
    private func goToPrevious() {
        guard hasPrevious else { return }
        currentStatementID = unapprovedStatements[currentIndex - 1].id
    }
    
    private func goToNext() {
        guard hasNext else { return }
        currentStatementID = unapprovedStatements[currentIndex + 1].id
    }
    
    private func approve() {
        guard let currentStatement,
              let currentInvoice
        else { return }
        
        let nextStatementID = hasNext ? unapprovedStatements[currentIndex + 1].id : nil
        currentInvoice.status = .statementVerified
        
        if currentInvoice.matchedBankStatement == nil {
            currentInvoice.matchedBankStatement = currentStatement
        }
        
        currentStatementID = nextStatementID
    }
    
    var body: some View {
        Group {
            if let statement = currentStatement, let invoice = currentInvoice {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        gridContent(statement: statement, invoice: invoice)
                            .frame(minWidth: 550, alignment: .leading)
                        if let warning = amountMismatchWarning(for: invoice) {
                            warningView(message: warning)
                        }
                        if let warning = missingDocumentWarning(for: invoice) {
                            warningView(message: warning)
                        }
                        if let warning = linkedWithoutBankStatementWarning(for: invoice) {
                            warningView(message: warning)
                        }
                        if let warning = directionMismatchWarning(for: invoice, statement: statement) {
                            warningView(message: warning)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView {
                    Label("All Done", systemImage: "checkmark.circle.fill")
                } description: {
                    Text("All linked statements have been approved.")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !unapprovedStatements.isEmpty {
                    Button("Previous", systemImage: "chevron.left", action: goToPrevious)
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                        .disabled(!hasPrevious)
                        .help("Previous")
                    
                    Text("\(currentIndex + 1) of \(unapprovedStatements.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                    
                    Button("Next", systemImage: "chevron.right", action: goToNext)
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                        .disabled(!hasNext)
                        .help("Next")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Approve Link", image: .linkBadgeCheckmark, role: .confirm, action: approve)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Approve Link")
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(currentInvoice == nil)
            }
        }
    }

    private func gridContent(statement: BankStatement, invoice: Invoice) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                Text("Bank Statement")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Invoice")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GridRow {
                gridCell("Status") {
                    Label {
                        Text(statement.status.label)
                    } icon: {
                        statement.status.icon
                    }
                }
                gridCell("Status") {
                    Label {
                        Text(invoice.status.label)
                    } icon: {
                        invoice.status.icon
                    }
                }
            }
            
            GridRow {
                gridCell("Payment Date") {
                    Text(statement.date.map { Formatters.date.string(from: $0) } ?? "N/A")
                        .fontDesign(.monospaced)
                }
                gridCell("Invoice Date") {
                    Text(invoice.date.map { Formatters.date.string(from: $0) } ?? "")
                        .fontDesign(.monospaced)
                }
            }
            
            GridRow {
                gridCell("Amount") {
                    Text(statement.amountDisplay ?? "N/A")
                        .fontDesign(.monospaced)
                }
                gridCell("Total Amount") {
                    Text(invoice.getPostTaxAmountString())
                        .fontDesign(.monospaced)
                }
            }
            
            GridRow {
                gridCell("Currency") {
                    Text(statement.currency ?? "N/A")
                        .fontDesign(.monospaced)
                }
                gridCell("Currency") {
                    Text(invoice.currency ?? "")
                        .fontDesign(.monospaced)
                }
            }
            
            GridRow {
                gridCell("Vendor") {
                    Text(statement.vendor ?? "N/A")
                        .fontDesign(.monospaced)
                }
                gridCell("Vendor Name") {
                    Text(invoice.vendorName ?? "")
                }
            }

            GridRow {
                gridCell("Reference") {
                    Text(statement.reference ?? "N/A")
                        .fontDesign(.monospaced)
                }
                gridCell("Invoice Number") {
                    Text(invoice.invoiceNo ?? "")
                        .fontDesign(.monospaced)
                }
            }
            
            GridRow {
                gridCell("Notes") {
                    Text(statement.notes)
                }
                gridCell("Tags") {
                    Text(invoiceTagsDisplay(for: invoice))
                }
            }
            
            GridRow {
                emptyGridCell()
                gridCell("Pre Tax Amount") {
                    Text(invoice.getPreTaxAmountString())
                        .fontDesign(.monospaced)
                }
            }
            
            GridRow {
                emptyGridCell()
                gridCell("Tax Percentage") {
                    Text(invoice.getTaxPercentage())
                        .fontDesign(.monospaced)
                }
            }
            
            GridRow {
                emptyGridCell()
                gridCell("Type") {
                    Text(invoice.direction == .outgoing ? "Outgoing" : "Incoming")
                }
            }
            
            GridRow {
                emptyGridCell()
                gridCell("File Path") {
                    HStack(spacing: 6) {
                        if let path = invoice.path, !path.isEmpty {
                            Text(path)
                                .lineLimit(1)
                        } else {
                            Text("No document associated with this entry.")
                                .italic()
                        }
                        
                        if let url = documentURL {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Show in Finder")
                        }
                    }
                }
            }
        }
    }
    
    private func gridCell<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Labeled(title) {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
    
    private func emptyGridCell() -> some View {
        Color.clear
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private func invoiceTagsDisplay(for invoice: Invoice) -> String {
        let titles = (invoice.tags ?? []).map(\.title).sorted()
        return titles.isEmpty ? "No tags" : titles.joined(separator: ", ")
    }
    
    private func warningView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
        }
        .font(.caption)
        .foregroundStyle(.red)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func amountMismatchWarning(for invoice: Invoice) -> String? {
        guard let preTax = invoice.preTaxAmount,
              let tax = invoice.taxPercentage,
              let total = invoice.totalAmount
        else { return nil }
        
        let expectedTotal = preTax * (1 + tax)
        let delta = abs(expectedTotal - total)
        let tolerance = max(0.01, expectedTotal * 0.005)
        guard delta > tolerance else { return nil }
        
        let currency = invoice.currency?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyPrefix = currency?.isEmpty == false ? "\(currency!) " : ""
        let expectedStr = Formatters.amount.string(from: NSNumber(value: expectedTotal)) ?? "\(expectedTotal)"
        let totalStr = Formatters.amount.string(from: NSNumber(value: total)) ?? "\(total)"
        return "Pre-tax + tax does not match total. Expected \(currencyPrefix)\(expectedStr), got \(currencyPrefix)\(totalStr)."
    }
    
    private func missingDocumentWarning(for invoice: Invoice) -> String? {
        guard let documentManager,
              let path = invoice.path
        else { return nil }
        
        let existsInListing = documentManager.invoices.contains { $0.filename == path }
        guard !existsInListing else { return nil }
        
        return "The document file could not be found. The invoice may need re-import."
    }
    
    private func linkedWithoutBankStatementWarning(for invoice: Invoice) -> String? {
        guard invoice.status == .statementVerified, invoice.matchedBankStatement == nil else { return nil }
        return "This invoice is marked as linked, but no bank statement is attached."
    }

    private func directionMismatchWarning(for invoice: Invoice, statement: BankStatement) -> String? {
        guard let direction = invoice.direction,
              let amount = statement.amount,
              amount != 0
        else { return nil }

        let signMismatch: Bool
        switch direction {
        case .incoming:
            signMismatch = amount < 0
        case .outgoing:
            signMismatch = amount > 0
        }

        guard signMismatch else { return nil }
        return "Invoice direction does not match the bank statement amount sign."
    }
}

#Preview {
    ModelPreview { (_: BankStatement) in
        BankStatementLinkReviewView()
    }
}
