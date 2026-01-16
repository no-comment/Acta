import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @State private var isImportingInvoice = false
    
    var body: some View {
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
}

#Preview {
    ContentView()
}
