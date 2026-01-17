import SwiftData
import SwiftUI

struct InvoiceReviewView: View {
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Query(sort: \Invoice.vendorName)
    private var allInvoices: [Invoice]

    private var unreviewedInvoices: [Invoice] {
        allInvoices.filter { $0.status != .verified }
    }

    @State private var currentInvoiceID: Invoice.ID?

    private var currentInvoice: Invoice? {
        if let currentInvoiceID {
            return unreviewedInvoices.first { $0.id == currentInvoiceID }
        }
        return unreviewedInvoices.first
    }

    private var currentIndex: Int {
        guard let currentInvoiceID else { return 0 }
        return unreviewedInvoices.firstIndex { $0.id == currentInvoiceID } ?? 0
    }

    private var documentURL: URL? {
        guard let currentInvoice else { return nil }
        return documentManager?.getURL(for: currentInvoice)
    }

    private var hasPrevious: Bool {
        currentIndex > 0 && !unreviewedInvoices.isEmpty
    }

    private var hasNext: Bool {
        currentIndex < unreviewedInvoices.count - 1 && !unreviewedInvoices.isEmpty
    }

    private func goToPrevious() {
        guard hasPrevious else { return }
        currentInvoiceID = unreviewedInvoices[currentIndex - 1].id
    }

    private func goToNext() {
        guard hasNext else { return }
        currentInvoiceID = unreviewedInvoices[currentIndex + 1].id
    }

    private func approve() {
        guard let currentInvoice else { return }
        let nextInvoiceID = hasNext ? unreviewedInvoices[currentIndex + 1].id : nil
        currentInvoice.status = .verified
        currentInvoiceID = nextInvoiceID
    }

    var body: some View {
        Group {
            if let invoice = currentInvoice {
                HSplitView {
                    documentPreview
                        .frame(minWidth: 300)

                    formPanel(for: invoice)
                        .frame(minWidth: 280, idealWidth: 320)
                }
            } else {
                ContentUnavailableView {
                    Label("All Done", systemImage: "checkmark.circle.fill")
                } description: {
                    Text("All invoices have been reviewed.")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !unreviewedInvoices.isEmpty {
                    Button {
                        goToPrevious()
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .disabled(!hasPrevious)

                    Text("\(currentIndex + 1) of \(unreviewedInvoices.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)

                    Button {
                        goToNext()
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(!hasNext)

                    Spacer()

                    Button {
                        approve()
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
    }

    @ViewBuilder
    private var documentPreview: some View {
        if let documentURL {
            DocumentPreviewView(url: documentURL)
                .id(documentURL)
        } else if currentInvoice?.path == nil {
            ContentUnavailableView {
                Label("No Document", systemImage: "doc")
            } description: {
                Text("This invoice has no associated document.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formPanel(for invoice: Invoice) -> some View {
        ScrollView {
            InvoiceFormView(invoice: invoice)
                .padding()
        }
    }
}
