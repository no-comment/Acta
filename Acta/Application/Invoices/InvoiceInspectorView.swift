import SwiftUI
import SwiftData

struct InvoiceInspectorView: View {
    @Query private var invoices: [Invoice]
    @Binding private var id: Invoice.ID?
    
    @State private var status: Invoice.Status = .new
    @State private var filePath: String = ""
    
    @State private var vendorName: String = ""
    @State private var date: Date = Date.distantPast
    @State private var invoiceNo: String = ""
    
    @State private var totalAmount: Double = 0
    @State private var preTaxAmount: Double = 0
    @State private var taxPercentage: Double = 0
    @State private var currency: String = ""
    @State private var direction: Invoice.Direction = .incoming
    
    init(for invoiceId: Binding<Invoice.ID?>) {
        self._id = invoiceId
    }
    
    var body: some View {
        ScrollView {
            form
                .padding()
        }
        .onChange(of: self.id, onIDChange)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button("Close", action: { self.id = nil })
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                    Button("Save", action: self.saveChanges)
                        .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 10)
            }
            .background(.regularMaterial)
        }
    }
    
    private var form: some View {
        VStack(spacing: 10) {
            Labeled("File Path") {
                HStack(spacing: 2) {
                    Text(filePath)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Labeled("Vendor Name") {
                TextField("Vendor Name", text: $vendorName)
            }
            
            Labeled("Invoice Date") {
                DatePicker("Invoice Date", selection: $date, displayedComponents: .date)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .labelsHidden()
            }
            
            Labeled("Invoice Number") {
                TextField("Invoice Number", text: $invoiceNo)
            }
            
            Divider()
            
            Labeled("Pre Tax Amount") {
                TextField("Pre Tax Amount", value: $preTaxAmount, format: .number)
            }
            
            Labeled("Tax Percentage") {
                TextField("Tax Percentage", value: $taxPercentage, format: .percent)
            }
            
            Labeled("Total Amount") {
                TextField("Total Amount", value: $totalAmount, format: .number)
            }
            
            Labeled("Currency") {
                TextField("Currency", text: $currency)
            }
            
            Labeled("Type") {
                Picker("Invoice Direction", selection: $direction) {
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
                Picker("Invoice Status", selection: $status) {
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
    
    private func saveChanges() {
        guard let selectedID = self.id, let invoice = invoices.first(where: { $0.id == selectedID }) else {
            assertionFailure("No invoice found for ID when attempting save")
            return
        }
        invoice.vendorName = vendorName
        invoice.date = date
        invoice.invoiceNo = invoiceNo
        invoice.totalAmount = totalAmount
        invoice.preTaxAmount = preTaxAmount
        invoice.taxPercentage = taxPercentage
        invoice.currency = currency
        invoice.direction = direction
        invoice.status = status
    }
    
    private func onIDChange(oldValue: Invoice.ID?, newValue: Invoice.ID?) {
        if newValue != oldValue, let selectedID = newValue, let invoice = invoices.first(where: { $0.id == selectedID }) {
            self.status = invoice.status
            self.vendorName = invoice.vendorName ?? "N/A"
            self.date = invoice.date ?? Date.distantPast
            self.invoiceNo = invoice.invoiceNo ?? "N/A"
            self.totalAmount = invoice.totalAmount ?? 0
            self.preTaxAmount = invoice.preTaxAmount ?? 0
            self.taxPercentage = invoice.taxPercentage ?? 0
            self.currency = invoice.currency ?? "N/A"
            self.direction = invoice.direction ?? .incoming
            self.filePath = invoice.path ?? "N/A"
        }
    }
}

#Preview {
    ModelPreview { (invoice: Invoice) in
        InvoiceInspectorView(for: .constant(invoice.id))
    }
}
