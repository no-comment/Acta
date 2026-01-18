import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage(DefaultKey.isNewUser) private var isNewUser: Bool = true
    @SceneStorage("ActiveMainView") private var mainView: ActaApp.MainView = .invoices
    
    @Environment(\.modelContext) private var modelContext
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @State private var isImportingInvoice = false
    
    var body: some View {
        content
            .navigationTitle("")
            .sheet(isPresented: self.$isNewUser, content: { OnboardingView() })
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Menu(mainView.title) {
                        ForEach(ActaApp.MainView.allCases) { view in
                            Button(view.title, action: { self.mainView = view })
                                .padding(.horizontal)
                        }
                    }
                    .font(.headline)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showInvoices)) { _ in
                mainView = .invoices
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBankStatements)) { _ in
                mainView = .bankStatements
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if self.mainView == .invoices {
            InvoicesView()
                .invoiceImporter(isPresented: $isImportingInvoice, documentManager: documentManager)
                .onReceive(NotificationCenter.default.publisher(for: .importInvoice)) { _ in
                    if documentManager != nil {
                        isImportingInvoice = true
                    }
                }
                .onChange(of: documentManager?.loadingState) { _, newState in
                    if case .loaded = newState {
                        syncInvoicesWithDocuments()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: DocumentManager.documentsDidChangeNotification)) { _ in
                    syncInvoicesWithDocuments()
                }
        } else {
            BankStatementsView()
        }
    }
    
    /// Creates Invoice records for any documents in iCloud Drive that don't have a corresponding database entry
    private func syncInvoicesWithDocuments() {
        guard let documentManager else { return }
        
        // Fetch all existing invoice paths from the database
        let descriptor = FetchDescriptor<Invoice>()
        guard let existingInvoices = try? modelContext.fetch(descriptor) else { return }
        let existingPaths = Set(existingInvoices.compactMap { $0.path })
        
        // Create records for documents that don't have a corresponding invoice
        for document in documentManager.invoices {
            if !existingPaths.contains(document.filename) {
                let invoice = Invoice(path: document.filename, tags: [], status: .new)
                modelContext.insert(invoice)
            }
        }
    }

}

extension Notification.Name {
    static let importInvoice = Notification.Name("importInvoice")
    static let showInvoices = Notification.Name("showInvoices")
    static let showBankStatements = Notification.Name("showBankStatements")
}

#Preview {
    ContentView()
}
