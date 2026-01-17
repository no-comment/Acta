import SwiftUI

struct InvoiceFormView: View {
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Bindable var invoice: Invoice
    
    private var documentURL: URL? {
        documentManager?.getURL(for: invoice)
    }
    
    private var directionBinding: Binding<Invoice.Direction> {
        Binding(
            get: { invoice.direction ?? .incoming },
            set: { invoice.direction = $0 }
        )
    }
    
    var body: some View {
        VStack(spacing: 14) {
            generalSection
            Divider()
            moneySection
            Divider()
            statusSection
        }
    }
    
    private var generalSection: some View {
        VStack(spacing: 10) {
            Labeled("File Path") {
                HStack(spacing: 6) {
                    if let path = invoice.path, !path.isEmpty {
                        Text(path)
                            .lineLimit(1)
                    } else {
                        Text("No document associated with this entry.")
                            .italic()
                    }
                    
                    if let url = documentURL {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
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
        }
    }
    
    private var moneySection: some View {
        VStack(spacing: 10) {
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
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 10) {
            Labeled("Status") {
                Picker("Invoice Status", selection: $invoice.status) {
                    ForEach(Invoice.Status.allCases) { status in
                        Label(status.label, systemImage: status.iconName)
                            .tag(status)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
