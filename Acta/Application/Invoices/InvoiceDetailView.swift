import SwiftUI
import SwiftData

struct InvoiceDetailView: View {
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Query private var invoices: [Invoice]

    let invoiceID: Invoice.ID

    private var invoice: Invoice? {
        invoices.first { $0.id == invoiceID }
    }

    private var documentURL: URL? {
        guard let invoice else { return nil }
        return documentManager?.getURL(for: invoice)
    }

    var body: some View {
        Group {
            if let invoice {
                HSplitView {
                    documentPreview
                        .frame(minWidth: 300)

                    formPanel(for: invoice)
                        .frame(minWidth: 280, idealWidth: 320)
                }
            } else {
                ContentUnavailableView {
                    Label("Invoice Not Found", systemImage: "doc.questionmark")
                } description: {
                    Text("The invoice could not be found.")
                }
            }
        }
        .navigationTitle(invoice?.path ?? "Invoice")
    }

    private var documentPreview: some View {
        DocumentPreviewView(url: documentURL)
            .id(documentURL)
    }

    private func formPanel(for invoice: Invoice) -> some View {
        ScrollView {
            InvoiceFormView(invoice: invoice, documentURL: documentURL)
                .padding()
        }
    }
}
