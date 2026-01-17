import SwiftUI
import SwiftData

struct InvoiceInspectorView: View {
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Query private var invoices: [Invoice]
    @Binding private var id: Invoice.ID?

    init(for invoiceId: Binding<Invoice.ID?>) {
        self._id = invoiceId
    }

    private var invoice: Invoice? {
        guard let id else { return nil }
        return invoices.first { $0.id == id }
    }

    private var documentURL: URL? {
        guard let invoice else { return nil }
        return documentManager?.getURL(for: invoice)
    }

    var body: some View {
        Group {
            if let invoice {
                ScrollView {
                    InvoiceFormView(invoice: invoice, documentURL: documentURL)
                        .padding()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button("Close", action: { self.id = nil })
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
        InvoiceInspectorView(for: .constant(invoice.id))
    }
}
