import SwiftUI

struct InvoiceFormView: View {
    @Bindable var invoice: Invoice
    var documentURL: URL?

    private var directionBinding: Binding<Invoice.Direction> {
        Binding(
            get: { invoice.direction ?? .incoming },
            set: { invoice.direction = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            Labeled("File Path") {
                HStack(spacing: 2) {
                    Text(invoice.path ?? "")
                    Spacer(minLength: 0)
                    Button {
                        if let url = documentURL {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(documentURL == nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Labeled("Vendor Name") {
                TextField("Vendor Name", text: $invoice.vendorName.orEmpty)
            }

            Labeled("Invoice Date") {
                DatePicker("Invoice Date", selection: $invoice.date.orDistantPast, displayedComponents: .date)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .labelsHidden()
            }

            Labeled("Invoice Number") {
                TextField("Invoice Number", text: $invoice.invoiceNo.orEmpty)
            }

            Divider()

            Labeled("Pre Tax Amount") {
                TextField("Pre Tax Amount", value: $invoice.preTaxAmount.orZero, format: .number)
            }

            Labeled("Tax Percentage") {
                TextField("Tax Percentage", value: $invoice.taxPercentage.orZero, format: .percent)
            }

            Labeled("Total Amount") {
                TextField("Total Amount", value: $invoice.totalAmount.orZero, format: .number)
            }

            Labeled("Currency") {
                TextField("Currency", text: $invoice.currency.orEmpty)
            }

            Labeled("Type") {
                Picker("Invoice Direction", selection: directionBinding) {
                    Text("Incoming")
                        .tag(Invoice.Direction.incoming)
                    Text("Outgoing")
                        .tag(Invoice.Direction.outgoing)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Labeled("Status") {
                Picker("Invoice Status", selection: $invoice.status) {
                    ForEach(Invoice.Status.allCases) { status in
                        HStack {
                            Image(systemName: status.iconName)
                            Text(status.label)
                        }
                        .tag(status)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
