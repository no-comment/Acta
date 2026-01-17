import SwiftUI
import SwiftData

struct InvoicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Query private var invoices: [Invoice]
    @Query private var tagGroups: [TagGroup]
    @Query private var tags: [Tag]
    
    @SceneStorage("BugReportTableConfig") private var columnCustomization: TableColumnCustomization<Invoice>
    
    @State private var isProcessingOCR = false
    @State private var ocrManager = OCRManager.shared
    @State private var ocrProgressTotal = 0
    @State private var ocrProgressCompleted = 0
    @State private var ocrTask: Task<Void, Never>?
    
    @State private var sortOrder = [KeyPathComparator(\Invoice.status), KeyPathComparator(\Invoice.vendorName)]
    @State private var selection: Invoice.ID?
    
    private var selectedInvoice: Invoice? {
        guard let selection else { return nil }
        return invoices.first { $0.id == selection }
    }
    
    private var showInspector: Binding<Bool> {
        Binding(
            get: { selectedInvoice != nil },
            set: { newValue in
                if newValue == false {
                    selection = nil
                }
            }
        )
    }
    
    private var sortedInvoices: [Invoice] {
        invoices.sorted(using: sortOrder)
    }
    
    private var newInvoices: [Invoice] {
        invoices.filter { $0.status == .new }
    }

    private var unreviewedInvoices: [Invoice] {
        invoices.filter { $0.status != .verified }
    }

    
    var body: some View {
        table
            .frame(minWidth: 300, minHeight: 300)
            .toolbar(content: { self.toolbar })
            .inspector(isPresented: showInspector, content: {
                if let selectedInvoice {
                    InvoiceInspectorView(invoice: selectedInvoice, onClose: { selection = nil })
                }
            })
            .invoiceDropImporter(documentManager: documentManager)
    }
    
    private var table: some View {
        Table(sortedInvoices, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("", value: \.status.rawValue) { invoice in
                Image(systemName: invoice.status.iconName)
                    .help(invoice.status.label)
            }
            .width(16)
            .customizationID("status")

            TableColumn("Vendor", value: \.vendorName)
                .customizationID("vendorName")
            
            TableColumn("Date") { invoice in
                Text(invoice.date?.formatted(date: .numeric, time: .omitted) ?? "N/A")
            }
            .customizationID("invoiceDate")
            
            TableColumn("Invoice #", value: \.invoiceNo)
                .customizationID("invoiceNumber")

            TableColumn("Filename") { invoice in
                Text(invoice.path ?? "N/A")
            }
            .customizationID("filename")

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
            }
            .customizationID("totalAmount")
            
            TableColumnForEach(tagGroups) { group in
                TableColumn(group.title) { invoice in
                    HStack(spacing: 6) {
                        ForEach(invoice.getTags(for: group)) { tag in
                            Text(tag.title)
                        }
                    }
                }
                .customizationID("groupColumn-\(group.title)")
            }
        }
        .contextMenu(forSelectionType: Invoice.ID.self) { items in
            Button("Rescan Invoice", systemImage: "text.viewfinder", action: {})
            Button("Delete Invoice", systemImage: "trash", role: .destructive, action: {})
                .tint(.red)
        } primaryAction: { items in
            guard let invoiceID = items.first else { return }
            openWindow(value: invoiceID)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Import", systemImage: "square.and.arrow.down") {
                NotificationCenter.default.post(name: .importInvoice, object: nil)
            }
            .disabled(documentManager == nil)

            if isProcessingOCR {
                HStack(spacing: 8) {
                    ProgressView(value: Double(ocrProgressCompleted), total: Double(max(ocrProgressTotal, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 160)
                        .help("OCR \(ocrProgressCompleted) of \(ocrProgressTotal)")

                    Button("Cancel", systemImage: "xmark.circle") {
                        ocrTask?.cancel()
                        OCRManager.shared.cancelAllProcessing()
                    }
                }
            } else {
                Button("OCR All New", systemImage: "doc.text.viewfinder", action: processAllNewInvoices)
                    .disabled(newInvoices.isEmpty || documentManager == nil || !APIKeyStore.hasOpenRouterKey())
            }

            Button("Review", systemImage: "checkmark.circle") {
                openWindow(id: "invoice-review")
            }
            .disabled(unreviewedInvoices.isEmpty)
            .help("Open Invoice Review")
        }

        ToolbarItemGroup(placement: .principal) {
            Button("Show Counts", systemImage: "number") {
                print("Invoices: \(invoices.count), TagGroups: \(tagGroups.count), Tags: \(tags.count)")
            }

            Button("Generate Sample Data", systemImage: "plus") {
                TagGroup.generateMockData(modelContext: modelContext)
                Tag.generateMockData(modelContext: modelContext)
                Invoice.generateMockData(modelContext: modelContext)
            }

            Button("Delete All", systemImage: "trash", role: .destructive) {
                for invoice in invoices {
                    modelContext.delete(invoice)
                }

                for group in tagGroups {
                    modelContext.delete(group)
                }

                for tag in tags {
                    modelContext.delete(tag)
                }
            }
        }
    }
    
    private func processAllNewInvoices() {
        guard let documentManager else { return }
        
        isProcessingOCR = true
        ocrProgressTotal = newInvoices.count
        ocrProgressCompleted = 0
        
        ocrTask?.cancel()
        ocrTask = Task {
            for invoice in newInvoices {
                if Task.isCancelled {
                    break
                }

                guard let path = invoice.path else { continue }
                
                // Find the DocumentFile matching this invoice's path
                guard let documentFile = documentManager.invoices.first(where: { $0.filename == path }) else {
                    continue
                }
                
                do {
                    try await OCRManager.shared.processInvoice(
                        document: documentFile,
                        invoice: invoice,
                        documentManager: documentManager
                    )
                } catch is CancellationError {
                    break
                } catch {
                    print("OCR failed for \(path): \(error.localizedDescription)")
                }

                ocrProgressCompleted += 1
            }
            
            isProcessingOCR = false
            ocrTask = nil
        }
    }
}

#Preview {
    ModelPreview { (_: Invoice) in
        ContentView()
    }
}
