import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BankStatementCSVExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BankStatement.date) private var statements: [BankStatement]

    @AppStorage(DefaultKey.bankStatementCSVExportDateColumn) private var dateColumnRawValue = DateFilterColumn.statementDate.rawValue
    @State private var dateColumn: DateFilterColumn = .statementDate
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var didSetInitialRange = false

    @State private var exportDocument = CSVExportDocument(text: "")
    @State private var showExporter = false
    @State private var exportErrorMessage: String?
    @State private var showExportError = false

    var body: some View {
        HSplitView {
            previewPane
            optionsPane
        }
        .frame(minWidth: 1000, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Export Linked Statements")
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Export CSV") {
                    print("Export CSV tapped. Rows: \(filteredRows.count)")
                    exportDocument = CSVExportDocument(text: buildCSV())
                    print("Export CSV document prepared. Presenting exporter.")
                    showExporter = true
                }
                .disabled(filteredRows.isEmpty)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Acta-Linked-Export"
        ) { result in
            print("Export CSV result: \(result)")
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
        .onAppear {
            dateColumn = DateFilterColumn(rawValue: dateColumnRawValue) ?? .statementDate
            setInitialDateRange()
        }
        .onChange(of: dateColumn) { _, _ in
            dateColumnRawValue = dateColumn.rawValue
            updateDateRangeForColumn()
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Unknown error")
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Export")
                .font(.headline)
                .padding(.top)
                .padding(.leading)

            if filteredRows.isEmpty {
                ContentUnavailableView("No Linked Statements", systemImage: "link")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredRows) {
                    TableColumnForEach(previewColumns, id: \.self) { column in
                        switch column {
                        case .statementDate:
                            TableColumn(column.title) { row in
                                Text(formatDate(row.statement.date))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .statementVendor:
                            TableColumn(column.title) { row in
                                Text(row.statement.vendor ?? "")
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .statementReference:
                            TableColumn(column.title) { row in
                                Text(row.statement.reference ?? "")
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .statementAmount:
                            TableColumn(column.title) { row in
                                Text(formatAmount(row.statement.amount, currency: row.statement.currency))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .statementAccount:
                            TableColumn(column.title) { row in
                                Text(row.statement.account ?? "")
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .statementNotes:
                            TableColumn(column.title) { row in
                                Text(row.statement.notes)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceDate:
                            TableColumn(column.title) { row in
                                Text(formatDate(row.invoice.date))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceVendor:
                            TableColumn(column.title) { row in
                                Text(row.invoice.vendorName ?? "")
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceNumber:
                            TableColumn(column.title) { row in
                                Text(row.invoice.invoiceNo ?? "")
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceAmount:
                            TableColumn(column.title) { row in
                                Text(formatAmount(signedInvoiceAmount(row.invoice.totalAmount, invoice: row.invoice), currency: row.invoice.currency))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoicePreTaxAmount:
                            TableColumn(column.title) { row in
                                Text(formatAmount(signedInvoiceAmount(row.invoice.preTaxAmount, invoice: row.invoice), currency: row.invoice.currency))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceTaxPercentage:
                            TableColumn(column.title) { row in
                                Text(formatNumber(row.invoice.taxPercentage))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceTaxAmount:
                            TableColumn(column.title) { row in
                                Text(formatAmount(signedInvoiceAmount(invoiceTaxAmount(row.invoice), invoice: row.invoice), currency: row.invoice.currency))
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceStatus:
                            TableColumn(column.title) { row in
                                Text(row.invoice.status.label)
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceFilePath:
                            TableColumn(column.title) { row in
                                Text(row.invoice.path ?? "")
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        case .invoiceTags:
                            TableColumn(column.title) { row in
                                Text(invoiceTagsDisplay(row.invoice))
                                    .lineLimit(1)
                            }
                            .width(min: column.minWidth, ideal: column.idealWidth, max: column.maxWidth)
                        }
                    }
                }
            }
        }
    }

    private var optionsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Date Filter") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Use date from")
                            Spacer()
                            Picker("", selection: $dateColumn) {
                                ForEach(DateFilterColumn.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 320, maxWidth: 380)
    }

    private var linkedRows: [ExportRow] {
        statements.compactMap { statement in
            guard let invoice = statement.matchedInvoice else { return nil }
            return ExportRow(id: statement.id, statement: statement, invoice: invoice)
        }
    }

    private var filteredRows: [ExportRow] {
        guard !linkedRows.isEmpty else { return [] }
        let range = normalizedDateRange
        return linkedRows.filter { row in
            guard let date = dateForRow(row) else { return false }
            let start = startOfDay(for: range.lowerBound)
            let end = endOfDay(for: range.upperBound)
            return date >= start && date <= end
        }
    }

    private var normalizedDateRange: ClosedRange<Date> {
        if startDate <= endDate {
            return startDate...endDate
        }
        return endDate...startDate
    }

    private func dateForRow(_ row: ExportRow) -> Date? {
        switch dateColumn {
        case .statementDate:
            return row.statement.date
        case .invoiceDate:
            return row.invoice.date
        }
    }

    private func setInitialDateRange() {
        guard !didSetInitialRange else { return }
        didSetInitialRange = true
        updateDateRangeForColumn()
    }

    private func updateDateRangeForColumn() {
        let dates = linkedRows.compactMap { dateForRow($0) }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            startDate = Date()
            endDate = Date()
            return
        }
        startDate = minDate
        endDate = maxDate
    }

    private func buildCSV() -> String {
        let header = [
            "Statement Date",
            "Statement Vendor",
            "Statement Reference",
            "Statement Amount",
            "Statement Account",
            "Statement Notes",
            "Invoice Date",
            "Invoice Vendor",
            "Invoice Number",
            "Invoice Amount",
            "Invoice Pre-Tax Amount",
            "Invoice Tax Percentage",
            "Invoice Tax Amount",
            "Invoice Status",
            "Invoice File Path",
            "Invoice Tags"
        ]

        var lines: [String] = []
        lines.append(csvLine(header))

        for row in filteredRows {
            let invoice = row.invoice
            let statement = row.statement
            let values = [
                formatDate(statement.date),
                statement.vendor ?? "",
                statement.reference ?? "",
                formatAmount(statement.amount, currency: statement.currency),
                statement.account ?? "",
                statement.notes,
                formatDate(invoice.date),
                invoice.vendorName ?? "",
                invoice.invoiceNo ?? "",
                formatAmount(signedInvoiceAmount(invoice.totalAmount, invoice: invoice), currency: invoice.currency),
                formatAmount(signedInvoiceAmount(invoice.preTaxAmount, invoice: invoice), currency: invoice.currency),
                formatNumber(invoice.taxPercentage),
                formatAmount(signedInvoiceAmount(invoiceTaxAmount(invoice), invoice: invoice), currency: invoice.currency),
                invoice.status.label,
                invoice.path ?? "",
                invoiceTagsDisplay(invoice)
            ]
            lines.append(csvLine(values))
        }

        return lines.joined(separator: "\n")
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map(csvEscape).joined(separator: ",")
    }

    private func csvEscape(_ value: String) -> String {
        let needsEscaping = value.contains(",") || value.contains("\"") || value.contains("\n")
        guard needsEscaping else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Formatters.date.string(from: date)
    }

    private func formatAmount(_ amount: Double?, currency: String?) -> String {
        guard let amount else { return "" }
        let formatted = ExportFormatters.amount.string(from: NSNumber(value: amount)) ?? ""
        guard let currency, !currency.isEmpty else { return formatted }
        return "\(formatted) \(currency)"
    }

    private func signedInvoiceAmount(_ amount: Double?, invoice: Invoice) -> Double? {
        guard var amount else { return nil }
        if invoice.direction == .incoming {
            amount.negate()
        }
        return amount
    }

    private func formatNumber(_ number: Double?) -> String {
        guard let number else { return "" }
        return ExportFormatters.number.string(from: NSNumber(value: number)) ?? ""
    }

    private func invoiceTaxAmount(_ invoice: Invoice) -> Double? {
        guard let total = invoice.totalAmount,
              let preTax = invoice.preTaxAmount
        else { return nil }
        return total - preTax
    }

    private func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? date
    }

    private func invoiceTagsDisplay(_ invoice: Invoice) -> String {
        let titles = (invoice.tags ?? []).map(\.title).sorted()
        return titles.joined(separator: ", ")
    }

    private var previewColumns: [ExportPreviewColumn] {
        ExportPreviewColumn.allCases
    }
}

private struct ExportRow: Identifiable {
    let id: BankStatement.ID
    let statement: BankStatement
    let invoice: Invoice
}

private struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

private enum ExportPreviewColumn: String, CaseIterable, Hashable {
    case statementDate
    case statementVendor
    case statementReference
    case statementAmount
    case statementAccount
    case statementNotes
    case invoiceDate
    case invoiceVendor
    case invoiceNumber
    case invoiceAmount
    case invoicePreTaxAmount
    case invoiceTaxPercentage
    case invoiceTaxAmount
    case invoiceStatus
    case invoiceFilePath
    case invoiceTags

    var title: String {
        switch self {
        case .statementDate: return "Statement Date"
        case .statementVendor: return "Statement Vendor"
        case .statementReference: return "Reference"
        case .statementAmount: return "Statement Amount"
        case .statementAccount: return "Statement Account"
        case .statementNotes: return "Statement Notes"
        case .invoiceDate: return "Invoice Date"
        case .invoiceVendor: return "Invoice Vendor"
        case .invoiceNumber: return "Invoice No"
        case .invoiceAmount: return "Invoice Amount"
        case .invoicePreTaxAmount: return "Invoice Pre-Tax Amount"
        case .invoiceTaxPercentage: return "Invoice Tax Percentage"
        case .invoiceTaxAmount: return "Invoice Tax Amount"
        case .invoiceStatus: return "Invoice Status"
        case .invoiceFilePath: return "Invoice File Path"
        case .invoiceTags: return "Invoice Tags"
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .statementDate: return 110
        case .statementVendor: return 120
        case .statementReference: return 140
        case .statementAmount: return 90
        case .statementAccount: return 120
        case .statementNotes: return 120
        case .invoiceDate: return 110
        case .invoiceVendor: return 120
        case .invoiceNumber: return 90
        case .invoiceAmount: return 100
        case .invoicePreTaxAmount: return 130
        case .invoiceTaxPercentage: return 130
        case .invoiceTaxAmount: return 130
        case .invoiceStatus: return 140
        case .invoiceFilePath: return 160
        case .invoiceTags: return 140
        }
    }

    var idealWidth: CGFloat {
        switch self {
        case .statementDate: return 140
        case .statementVendor: return 180
        case .statementReference: return 220
        case .statementAmount: return 120
        case .statementAccount: return 160
        case .statementNotes: return 200
        case .invoiceDate: return 140
        case .invoiceVendor: return 180
        case .invoiceNumber: return 120
        case .invoiceAmount: return 140
        case .invoicePreTaxAmount: return 160
        case .invoiceTaxPercentage: return 160
        case .invoiceTaxAmount: return 160
        case .invoiceStatus: return 180
        case .invoiceFilePath: return 240
        case .invoiceTags: return 200
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .statementDate: return 180
        case .statementVendor: return 260
        case .statementReference: return 320
        case .statementAmount: return 140
        case .statementAccount: return 220
        case .statementNotes: return 280
        case .invoiceDate: return 180
        case .invoiceVendor: return 260
        case .invoiceNumber: return 160
        case .invoiceAmount: return 180
        case .invoicePreTaxAmount: return 200
        case .invoiceTaxPercentage: return 200
        case .invoiceTaxAmount: return 200
        case .invoiceStatus: return 220
        case .invoiceFilePath: return 320
        case .invoiceTags: return 280
        }
    }
}

private enum DateFilterColumn: String, CaseIterable, Identifiable {
    case invoiceDate
    case statementDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .invoiceDate:
            return "Invoice Date"
        case .statementDate:
            return "Bank Statement Date"
        }
    }
}

private enum ExportFormatters {
    static let amount: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    static let number: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

#Preview {
    ModelPreview { (_: BankStatement) in
        BankStatementCSVExportView()
    }
}
