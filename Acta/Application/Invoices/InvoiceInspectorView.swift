import SwiftUI
import SwiftData

struct InvoiceInspectorView: View {
    var invoice: Invoice
    var onClose: () -> Void

    var body: some View {
        ScrollView {
            InvoiceFormView(invoice: invoice)
                .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button("Close", action: onClose)
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 10)
            }
            .background(.regularMaterial)
        }
    }
}

#Preview {
    ModelPreview { (invoice: Invoice) in
        InvoiceInspectorView(invoice: invoice, onClose: {})
    }
}
