import SwiftUI
import SwiftData

struct BankStatementInvoicePickerView: View {
    private var statementID: BankStatement.ID
    
    @Query private var invoices: [Invoice]
    @Query private var statements: [BankStatement]
    
    private var sortedInvoices: [Invoice] {
        self.invoices
    }
    
    private var statement: BankStatement? {
        statements.first { $0.id == statementID }
    }
    
    @SceneStorage("InvoiceMatchingColumnCustomization") private var columnCustomization: TableColumnCustomization<Invoice>
    @State private var sortOrder = [KeyPathComparator(\Invoice.status), KeyPathComparator(\Invoice.vendorName)]
    @State private var selection: Invoice.ID?
    
    init(for statementID: BankStatement.ID) {
        self.statementID = statementID
    }
    
    var body: some View {
        if let statement {
            HSplitView {
                statementSection(for: statement)
                invoiceSection
            }
            .navigationTitle("Statement Invoice Matching")
        } else {
            ContentUnavailableView("Bank Statement Not Found", systemImage: "doc.questionmark")
                .navigationTitle("Statement Invoice Matching")
        }
    }
    
    private func statementSection(for statement: BankStatement) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Labeled("Account Name") {
                    Text(statement.account ?? "N/A")
                        .fontDesign(.monospaced)
                }
                .frame(minWidth: 100, idealWidth: 200, alignment: .leading)
                
                Labeled("Payment Date") {
                    Text(statement.date?.formatted(date: .numeric, time: .omitted) ?? "N/A")
                        .fontDesign(.monospaced)
                }
                
                Labeled("Amount") {
                    Text(statement.amountString ?? "N/A")
                        .fontDesign(.monospaced)
                }
                
                Labeled("Reference") {
                    Text(statement.reference ?? "N/A")
                        .fontDesign(.monospaced)
                }
                
                Labeled("Notes") {
                    Text(statement.notes)
                        .fontDesign(.monospaced)
                }
            }
            .padding()
            .multilineTextAlignment(.leading)
        }
        .frame(minWidth: 100, idealWidth: 200, maxWidth: .infinity, alignment: .leading)
    }
    
    private var invoiceSection: some View {
        Table(sortedInvoices, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("", value: \.status.rawValue) { invoice in
                invoice.status.icon
                    .help(invoice.status.label)
            }
            .width(16)
            .disabledCustomizationBehavior(.all)
            .customizationID("status")
            
            TableColumn("Date") { invoice in
                Text(invoice.date?.formatted(date: .numeric, time: .omitted) ?? "N/A")
            }
            .customizationID("invoiceDate")
            
            TableColumn("Pre Tax") { invoice in
                Text(invoice.getPreTaxAmountString())
            }
            .customizationID("preTaxAmount")
            .defaultVisibility(.hidden)
            
            TableColumn("Tax") { invoice in
                Text(invoice.getTaxPercentage())
            }
            .customizationID("taxPercentage")
            .defaultVisibility(.hidden)
            
            TableColumn("Total") { invoice in
                Text(invoice.getPostTaxAmountString())
                    .monospacedDigit()
            }
            .alignment(.trailing)
            .customizationID("totalAmount")
            
            TableColumn("Vendor", value: \.vendorName)
                .customizationID("vendorName")
            
            TableColumn("Invoice #", value: \.invoiceNo)
                .customizationID("invoiceNumber")
            
            TableColumn("Filename") { invoice in
                Text(invoice.path ?? "N/A")
            }
            .customizationID("filename")
            .defaultVisibility(.hidden)
        }
    }
}

#Preview {
    ModelPreview { (statement: BankStatement) in
        BankStatementInvoicePickerView(for: statement.id)
    }
}
