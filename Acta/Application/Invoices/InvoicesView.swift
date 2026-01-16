import SwiftUI
import SwiftData

struct InvoicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var invoices: [Invoice]
    @Query private var tagGroups: [TagGroup]
    
    @SceneStorage("BugReportTableConfig") private var columnCustomization: TableColumnCustomization<Invoice>
    
    @State private var sortOrder = [KeyPathComparator(\Invoice.vendorName)]
    @State private var selection: Invoice.ID?
    
    private var sortedInvoices: [Invoice] {
        invoices.sorted(using: sortOrder)
    }
    
    var body: some View {
        Table(sortedInvoices, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("Checked") { invoice in
                Text(invoice.isManuallyChecked ? "✅" : "❌")
            }
            .customizationID("isManuallyChecked")
            
            TableColumn("Vendor", value: \.vendorName)
                .customizationID("vendorName")
            
            TableColumn("Date") { invoice in
                Text(invoice.date?.formatted() ?? "N/A")
            }
            .customizationID("invoiceDate")
            
            TableColumn("Amount") { invoice in
                Text(invoice.getPreTaxAmountString())
            }
            .customizationID("preTaxAmount")
            
            TableColumnForEach(tagGroups) { group in
                TableColumn(group.title) { invoice in
                    HStack(spacing: 6) {
                        ForEach(invoice.getTags(for: group)) { tag in
                            Text(tag.title)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
        .toolbar(content: { self.toolbar })
        .navigationTitle("Invoices")
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button("Delete All", systemImage: "trash", role: .destructive, action: {
                for invoice in invoices {
                    modelContext.delete(invoice)
                }
                
                for group in tagGroups {
                    modelContext.delete(group)
                }
            })
        }
        
        ToolbarItem {
            Button("Generate Mock", systemImage: "plus", role: .none, action: {
                TagGroup.generateMockData(modelContext: modelContext)
                Tag.generateMockData(modelContext: modelContext)
                Invoice.generateMockData(modelContext: modelContext)
            })
        }
    }
}

#Preview {
    ModelPreview { (_: Invoice) in
        ContentView()
    }
}
