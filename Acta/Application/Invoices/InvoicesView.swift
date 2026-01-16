import SwiftUI
import SwiftData

struct InvoicesView: View {
    @Query private var invoices: [Invoice]
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(invoices) { invoice in
                    Text(invoice.vendorName ?? "N/A")
                }
            }
            .frame(minWidth: 300, minHeight: 400)
        }
        .navigationTitle("Invoices")
    }
}

#Preview {
    ModelPreview { (_: Invoice) in
        ContentView()
    }
}
