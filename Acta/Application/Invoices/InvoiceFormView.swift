import SwiftData
import SwiftUI

struct InvoiceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DocumentManager.self) private var documentManager: DocumentManager?
    @Bindable var invoice: Invoice
    @State private var ocrManager = OCRManager.shared
    @State private var isShowingDeleteConfirm = false
    
    private var currentDocumentFile: DocumentFile? {
        guard let documentManager,
              let path = invoice.path
        else { return nil }
        return documentManager.invoices.first(where: { $0.filename == path })
    }
    
    private var isOCRProcessing: Bool {
        guard let document = currentDocumentFile else { return false }
        return ocrManager.isProcessing(document: document)
    }
    
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
            if let warning = amountMismatchWarning {
                warningView(message: warning)
            }
            if let warning = missingDocumentWarning {
                warningView(message: warning)
            }
            if let warning = linkedWithoutBankStatementWarning {
                warningView(message: warning)
            }
            statusSection
        }
        .confirmationDialog(
            "Delete this invoice?",
            isPresented: $isShowingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Invoice", role: .destructive, action: deleteInvoice)
            Button("Cancel", role: .cancel, action: {})
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
        VStack(alignment: .leading, spacing: 10) {
            Labeled("Status") {
                Picker("Invoice Status", selection: $invoice.status) {
                    ForEach(Invoice.Status.allCases) { status in
                        Label(title: {
                            Text(status.label)
                        }, icon: {
                            status.icon
                        })
                        .tag(status)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button(action: processInvoiceOCR) {
                Label {
                    Text(self.isOCRProcessing ? "Rescanning" : "Rescan Invoice")
                } icon: {
                    if self.isOCRProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "doc.text.viewfinder")
                    }
                }
            }
            .disabled(isOCRProcessing || currentDocumentFile == nil || !APIKeyStore.hasOpenRouterKey())
            
            Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                isShowingDeleteConfirm = true
            }
            .tint(.red)
        }
    }

    @State var foo: Bool = false
    
    private func processInvoiceOCR() {
        guard let documentManager, let documentFile = currentDocumentFile else { return }
        
        Task {
            do {
                try await ocrManager.processInvoice(
                    document: documentFile,
                    invoice: invoice,
                    documentManager: documentManager
                )
                await MainActor.run {
                    try? modelContext.save()
                }
            } catch is CancellationError {
                return
            } catch {
                let filename = documentFile.filename
                print("OCR failed for \(filename): \(error.localizedDescription)")
            }
        }
    }
    
    private var amountMismatchWarning: String? {
        guard let preTax = invoice.preTaxAmount,
              let tax = invoice.taxPercentage,
              let total = invoice.totalAmount
        else { return nil }
        
        let expectedTotal = preTax * (1 + tax)
        let delta = abs(expectedTotal - total)
        let tolerance = max(0.01, expectedTotal * 0.005)
        guard delta > tolerance else { return nil }
        
        let currency = invoice.currency?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyPrefix = currency?.isEmpty == false ? "\(currency!) " : ""
        return "Pre-tax + tax does not match total. Expected \(currencyPrefix)\(expectedTotal.formatted(.number)), got \(currencyPrefix)\(total.formatted(.number))."
    }
    
    private func warningView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
        }
        .font(.caption)
        .foregroundStyle(.red)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var missingDocumentWarning: String? {
        guard let documentManager,
              let path = invoice.path
        else { return nil }
        
        let existsInListing = documentManager.invoices.contains { $0.filename == path }
        guard !existsInListing else { return nil }
        
        return "The document file could not be found. The invoice may need re-import."
    }

    private var linkedWithoutBankStatementWarning: String? {
        guard invoice.status == .statementVerified, invoice.matchedBankStatement == nil else { return nil }
        return "This invoice is marked as linked, but no bank statement is attached."
    }
    
    private func deleteInvoice() {
        if let documentManager,
           let path = invoice.path,
           let documentFile = documentManager.invoices.first(where: { $0.filename == path }) {
            Task {
                try? await documentManager.deleteDocument(documentFile, type: .invoice)
                await MainActor.run {
                    modelContext.delete(invoice)
                }
            }
        } else {
            modelContext.delete(invoice)
        }
    }
}
