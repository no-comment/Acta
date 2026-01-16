import SwiftUI
import SwiftData

struct ContentView: View {
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
    }
}

extension Notification.Name {
    static let importInvoice = Notification.Name("importInvoice")
}

#Preview {
    ContentView()
}
