import SwiftUI
import SwiftData

struct InvoiceInspectorView: View {
    @Query private var invoices: [Invoice]
    @Binding private var id: Invoice.ID?
    
    @State private var isManuallyChecked: Bool = false
    
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
            Button("Save", action: self.saveChanges)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
        }
    }
    
    private var form: some View {
        VStack(spacing: 10) {
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
            }
        }
    }
    
    private func saveChanges() {
        
    }
    
    private func onIDChange(oldValue: Invoice.ID?, newValue: Invoice.ID?) {
        if newValue != oldValue, let selectedID = newValue, let invoice = invoices.first(where: { $0.id == selectedID }) {
            self.isManuallyChecked = invoice.isManuallyChecked
            self.vendorName = invoice.vendorName ?? "N/A"
            self.date = invoice.date ?? Date.distantPast
            self.invoiceNo = invoice.invoiceNo ?? "N/A"
            self.totalAmount = invoice.totalAmount ?? 0
            self.preTaxAmount = invoice.preTaxAmount ?? 0
            self.taxPercentage = invoice.taxPercentage ?? 0
            self.currency = invoice.currency ?? "N/A"
            self.direction = invoice.direction ?? .incoming
        }
    }
}

#Preview {
    ModelPreview { (invoice: Invoice) in
        InvoiceInspectorView(for: .constant(invoice.id))
    }
}
