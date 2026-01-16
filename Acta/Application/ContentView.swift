import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isImportingInvoice = false
    
    var body: some View {
        InvoicesView()
            .invoiceImporter(isPresented: $isImportingInvoice)
            .onReceive(NotificationCenter.default.publisher(for: .importInvoice)) { _ in
                isImportingInvoice = true
            }
    }
}

extension Notification.Name {
    static let importInvoice = Notification.Name("importInvoice")
}

#Preview {
    ContentView()
}
