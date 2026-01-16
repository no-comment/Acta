import SwiftUI

struct InvoiceInspectorView: View {
    private var invoice: Invoice
    
    @State private var vendorName: String
    
    init(for invoice: Invoice) {
        self.invoice = invoice
        self._vendorName = .init(initialValue: invoice.vendorName ?? "N/A")
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                TextField("Vendor Name", text: $vendorName)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save", action: self.saveChanges)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
        }
    }
    
    private func saveChanges() {
        
    }
}

#Preview {
    ModelPreview { (invoice: Invoice) in
        InvoiceInspectorView(for: invoice)
    }
}
