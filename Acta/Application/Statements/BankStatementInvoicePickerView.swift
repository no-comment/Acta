import SwiftUI
import SwiftData

struct BankStatementInvoicePickerView: View {
    private var statementID: BankStatement.ID
    
    @Query private var invoices: [Invoice]
    @Query private var statements: [BankStatement]
    
    private var sortedInvoices: [Invoice] {
        self.invoices.sorted(using: sortOrder)
    }
    
    private var statement: BankStatement? {
        statements.first { $0.id == statementID }
    }
    
    @SceneStorage("InvoiceMatchingColumnCustomization") private var columnCustomization: TableColumnCustomization<Invoice>
    @State private var sortOrder = [KeyPathComparator(\Invoice.status), KeyPathComparator(\Invoice.vendorName)]
    @State private var selection: Invoice.ID?
    
    private var selectedInvoice: Invoice? {
        invoices.first { $0.id == selection }
    }
    
    init(for statementID: BankStatement.ID) {
        self.statementID = statementID
    }
    
    var body: some View {
        if let statement {
            HSplitView {
                statementSection(for: statement)
                invoiceSection
            }
            .navigationTitle("Bank Statement & Invoice Matching")
            .toolbar(content: toolbar)
            .onAppear(perform: { self.selection = statement.matchedInvoice?.id})
        } else {
            ContentUnavailableView("Bank Statement Not Found", systemImage: "doc.questionmark")
                .navigationTitle("Bank Statement & Invoice Matching")
        }
    }
    
    private func statementSection(for statement: BankStatement) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Labeled("Status") {
                    Label {
                        Text(statement.status.label)
                    } icon: {
                        statement.status.icon
                    }
                }
                .onTapGesture(perform: {
                    if statement.status > .unlinked {
                        self.selection = statement.matchedInvoice?.id
                    }
                })
                
                Labeled("Account Name") {
                    Text(statement.account ?? "N/A")
                        .fontDesign(.monospaced)
                }
                
                Labeled("Payment Date") {
                    Text(statement.date.map { Formatters.date.string(from: $0) } ?? "N/A")
                        .fontDesign(.monospaced)
                }
                
                Labeled("Amount") {
                    Text(statement.amountDisplay ?? "N/A")
                        .fontDesign(.monospaced)
                        .valueColor(for: statement.amount)
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
            TableColumn("", value: \.status) { invoice in
                invoice.status.icon
                    .help(invoice.status.label)
            }
            .width(14)
            .disabledCustomizationBehavior(.all)
            .customizationID("status")
            
            TableColumn("Date", value: \.date) { invoice in
                Text(invoice.date.map { Formatters.date.string(from: $0) } ?? "")
            }
            .customizationID("invoiceDate")
            
            TableColumn("Pre Tax", value: \.preTaxAmount) { invoice in
                Text(invoice.getPreTaxAmountString())
                    .monospacedDigit()
                    .valueColor(isNegative: invoice.direction == .incoming)
            }
            .alignment(.trailing)
            .customizationID("preTaxAmount")
            .defaultVisibility(.hidden)
            
            TableColumn("Tax", value: \.taxPercentage) { invoice in
                Text(invoice.getTaxPercentage())
                    .monospacedDigit()
            }
            .alignment(.trailing)
            .customizationID("taxPercentage")
            .defaultVisibility(.hidden)
            
            TableColumn("Total", value: \.totalAmount) { invoice in
                Text(invoice.getPostTaxAmountString())
                    .monospacedDigit()
                    .valueColor(isNegative: invoice.direction == .incoming)
            }
            .alignment(.trailing)
            .customizationID("totalAmount")
            
            TableColumn("Vendor", value: \.vendorName) { invoice in
                Text(invoice.vendorName ?? "")
            }
            .customizationID("vendorName")
            
            TableColumn("Invoice #", value: \.invoiceNo) { invoice in
                Text(invoice.invoiceNo ?? "")
            }
            .customizationID("invoiceNumber")
            
            TableColumn("Filename", value: \.path) { invoice in
                Text(invoice.path ?? "")
            }
            .customizationID("filename")
            .defaultVisibility(.hidden)
        }
    }
    
    @ToolbarContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Link & Verify", image: .linkBadgeCheckmark, action: confirmLink)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Link & Verify")
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(self.selectedInvoice == nil || self.statement == nil)
        }
    }
    
    private func confirmLink() {
        guard let selectedInvoice, let statement else { return }
        
        statement.matchedInvoice = selectedInvoice
        selectedInvoice.status = .statementVerified
    }
}

#Preview {
    ModelPreview { (statement: BankStatement) in
        BankStatementInvoicePickerView(for: statement.id)
    }
}
