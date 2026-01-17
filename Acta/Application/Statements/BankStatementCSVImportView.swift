import SwiftUI
import SwiftData

struct BankStatementCSVImportView: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var delimiter: CSVDelimiter = .comma
    @State private var rawText = ""
    @State private var parsedRows: [[String]] = []

    @State private var rowStart = 0
    @State private var rowEnd = 0

    @State private var dateColumn = 0
    @State private var referenceColumn = 0
    @State private var amountColumn = 0
    @State private var currencyColumn = -1
    @State private var dateFormat = "yyyy-MM-dd"
    @State private var accountName = ""
    @State private var decimalSeparator: DecimalSeparator = .comma

    @AppStorage("BankStatementImportBlacklist") private var blacklistDefaultsString = ""
    @State private var blacklistTokens: [String] = []

    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didSetInitialRanges = false
    @State private var columnVersion = 0
    @State private var didAutoDetectDelimiter = false

    private enum DecimalSeparator: String, Identifiable, CaseIterable {
        case dot = "."
        case comma = ","

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dot: return "Dot (.)"
            case .comma: return "Comma (,)"
            }
        }
    }
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
                Text(url.lastPathComponent)
                    .lineLimit(1)
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    saveStatements()
                }
                .disabled(filteredRows.isEmpty)
            }
        }
        .onAppear {
            loadFile()
            blacklistTokens = sanitizeBlacklist(tokens(from: blacklistDefaultsString))
        }
        .onChange(of: delimiter) { _, _ in
            parse()
        }
        .onChange(of: blacklistTokens) { _, newValue in
            let sanitized = sanitizeBlacklist(newValue)
            if sanitized != newValue {
                blacklistTokens = sanitized
                return
            }
            blacklistDefaultsString = sanitized.joined(separator: ",")
        }
        .alert("CSV Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .padding(.top)
                .padding(.leading)

            if previewRows.isEmpty {
                ContentUnavailableView("No CSV Data", systemImage: "tablecells")
            } else {
                Table(previewRows) {
                    TableColumnForEach(previewColumns, id: \.self) { column in
                        switch column {
                        case .data(let index):
                            TableColumn(columnLabel(for: index)) { row in
                                Text(cellValue(row: row.cells, column: index))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .strikethrough(row.isBlacklisted, color: .secondary)
                                    .opacity(row.isBlacklisted ? 0.5 : 1.0)
                            }
                            .width(min: 100, ideal: 180, max: 360)
                        case .parsedAmount:
                            TableColumn("Parsed Amount") { row in
                                amountParseCell(for: row)
                            }
                            .width(min: 120, ideal: 160, max: 220)
                        }
                    }
                }
                .id(tableIdentity)
//                .frame(maxWidth: 300)
            }
        }
    }

    private var optionsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Delimiter") {
                    Picker("Delimiter", selection: $delimiter) {
                        ForEach(CSVDelimiter.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                GroupBox("Crop") {
                    VStack(alignment: .leading, spacing: 12) {
                        rangeControl(title: "Rows", start: $rowStart, end: $rowEnd, maxValue: maxRowIndex)
                    }
                }

                GroupBox("Column Mapping") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Date column", selection: $dateColumn) {
                            ForEach(columnIndices, id: \.self) { column in
                                Text(columnPickerLabel(for: column)).tag(column)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maxColumns == 0)

                        HStack(spacing: 8) {
                            TextField("Date format", text: $dateFormat)
                                .textFieldStyle(.roundedBorder)

                            if dateFormatHasMismatch {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .help("Some dates in the selected column don't match this format.")
                            }
                        }

                        Picker("Reference column", selection: $referenceColumn) {
                            ForEach(columnIndices, id: \.self) { column in
                                Text(columnPickerLabel(for: column)).tag(column)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maxColumns == 0)

                        Picker("Amount column", selection: $amountColumn) {
                            ForEach(columnIndices, id: \.self) { column in
                                Text(columnPickerLabel(for: column)).tag(column)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maxColumns == 0)

                        Picker("Currency column", selection: $currencyColumn) {
                            Text("Same as Amount").tag(-1)
                            ForEach(columnIndices, id: \.self) { column in
                                Text(columnPickerLabel(for: column)).tag(column)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maxColumns == 0)
                    }
                }

                GroupBox("Amount") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Decimal separator", selection: $decimalSeparator) {
                            ForEach(DecimalSeparator.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                GroupBox("Account") {
                    TextField("Account name", text: $accountName)
                        .textFieldStyle(.roundedBorder)
                }

                GroupBox("Blacklist") {
                    VStack(alignment: .leading, spacing: 8) {
                        TokenField(tokens: $blacklistTokens, placeholder: "Reference contains...")
                            .frame(minHeight: 24)

                        Text("Ignore rows whose reference contains any of these tokens.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 320, maxWidth: 380)
        .onChange(of: rowStart) { _, _ in normalizeRanges() }
        .onChange(of: rowEnd) { _, _ in normalizeRanges() }
    }

    private var maxRowIndex: Int {
        max(parsedRows.count - 1, 0)
    }

    private var maxColumnIndex: Int {
        max(maxColumns - 1, 0)
    }

    private var maxColumns: Int {
        parsedRows.map(\.count).max() ?? 0
    }

    private var columnIndices: [Int] {
        guard maxColumns > 0 else { return [] }
        return Array(0..<maxColumns)
    }

    private var visibleColumns: [Int] {
        guard maxColumns > 0 else { return [] }
        return Array(0..<maxColumns)
    }

    private var previewColumns: [PreviewColumn] {
        guard !visibleColumns.isEmpty else { return [] }
        var columns = visibleColumns.map { PreviewColumn.data($0) }
        if let amountIndex = columns.firstIndex(where: { column in
            if case .data(let index) = column { return index == amountColumn }
            return false
        }) {
            columns.insert(.parsedAmount, at: amountIndex + 1)
        } else {
            columns.append(.parsedAmount)
        }
        return columns
    }

    private var croppedRows: [[String]] {
        guard !parsedRows.isEmpty else { return [] }
        let start = min(rowStart, maxRowIndex)
        let end = min(rowEnd, maxRowIndex)
        if start > end { return [] }
        return (start...end).map { index in
            parsedRows[index]
        }
    }

    private var filteredRows: [[String]] {
        let blacklist = normalizedBlacklist
        guard !blacklist.isEmpty else { return croppedRows }
        return croppedRows.filter { row in
            !rowIsBlacklisted(row, blacklist: blacklist)
        }
    }

    private var previewRows: [PreviewRow] {
        let blacklist = normalizedBlacklist
        return croppedRows.enumerated().map { offset, row in
            PreviewRow(
                id: rowStart + offset,
                cells: row,
                isBlacklisted: rowIsBlacklisted(row, blacklist: blacklist)
            )
        }
    }

    private var tableIdentity: String {
        "\(delimiter.rawValue)-\(maxColumns)-\(parsedRows.count)-\(rawText.count)-\(columnVersion)"
    }

    private var dateFormatHasMismatch: Bool {
        guard !dateFormat.isEmpty, !parsedRows.isEmpty else { return false }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat

        let values: [String] = filteredRows.compactMap { row in
            let value = cellValue(row: row, column: dateColumn)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        guard !values.isEmpty else { return false }

        return values.contains { formatter.date(from: $0) == nil }
    }

    private func cellValue(row: [String], column: Int) -> String {
        guard row.indices.contains(column) else { return "" }
        return row[column]
    }

    private func amountParseCell(for row: PreviewRow) -> some View {
        let raw = cellValue(row: row.cells, column: amountColumn)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return AnyView(Text("Missing").foregroundStyle(.secondary))
        }

        let parsed = parseAmountAndCurrency(from: raw, decimalSeparator: decimalSeparator)
        guard let amount = parsed.amount else {
            return AnyView(
                Label("Invalid", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.orange)
            )
        }

        let currency = resolveCurrency(from: currencyColumn, row: row.cells, fallback: parsed.currency)
        let display = formatAmount(amount, currency: currency)
        return AnyView(Text(display))
    }

    private func columnLabel(for index: Int) -> String {
        let mapping = selectedMappingLabel(for: index)
        if mapping.isEmpty {
            return "\(index + 1). Column"
        }
        return "\(index + 1). Column (\(mapping))"
    }

    private func columnPickerLabel(for index: Int) -> String {
        "\(index + 1). Column"
    }

    private func selectedMappingLabel(for index: Int) -> String {
        var labels: [String] = []
        if index == dateColumn { labels.append("Date") }
        if index == referenceColumn { labels.append("Reference") }
        if index == amountColumn { labels.append("Amount") }
        if currencyColumn >= 0, index == currencyColumn { labels.append("Currency") }
        return labels.joined(separator: ", ")
    }

    private func rangeControl(title: String, start: Binding<Int>, end: Binding<Int>, maxValue: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Stepper(value: start, in: 0...maxValue) {
                    Text("Start \(start.wrappedValue + 1)")
                }
            }

            HStack {
                Stepper(value: end, in: 0...maxValue) {
                    Text("End \(end.wrappedValue + 1)")
                }
            }
        }
    }

    private func loadFile() {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            rawText = try String(contentsOf: url, encoding: .utf8)
            if !didAutoDetectDelimiter, let detected = CSVParser.detectDelimiter(text: rawText) {
                didAutoDetectDelimiter = true
                if detected != delimiter {
                    delimiter = detected
                    return
                }
            }
            parse()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func parse() {
        parsedRows = CSVParser.parse(text: rawText, delimiter: delimiter.character)
        if !didSetInitialRanges, !parsedRows.isEmpty {
            rowStart = 0
            rowEnd = maxRowIndex
            dateColumn = 0
            referenceColumn = min(1, maxColumnIndex)
            dateFormat = guessDateFormat(in: parsedRows) ?? dateFormat
            amountColumn = guessAmountColumn(in: parsedRows) ?? min(2, maxColumnIndex)
            currencyColumn = -1
            didSetInitialRanges = true
        }
        columnVersion += 1
        normalizeRanges()
    }

    private func saveStatements() {
        guard !filteredRows.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat

        let account = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountValue = account.isEmpty ? nil : account

        let existingStatements = (try? modelContext.fetch(FetchDescriptor<BankStatement>())) ?? []
        var existingKeys: Set<String> = Set(existingStatements.compactMap { statement in
            guard let date = statement.date else { return nil }
            return statementKey(
                account: statement.account,
                date: date,
                reference: statement.reference,
                amount: statement.amount,
                currency: statement.currency
            )
        })

        for row in filteredRows {
            let dateString = cellValue(row: row, column: dateColumn)
            let reference = cellValue(row: row, column: referenceColumn)
            let amount = cellValue(row: row, column: amountColumn)

            guard let date = formatter.date(from: dateString) else {
                continue
            }

            if amount.isEmpty {
                continue
            }

            let parsed = parseAmountAndCurrency(from: amount, decimalSeparator: decimalSeparator)
            guard let amountValue = parsed.amount else {
                continue
            }

            let currencyValue = resolveCurrency(from: currencyColumn, row: row, fallback: parsed.currency)

            let key = statementKey(
                account: accountValue,
                date: date,
                reference: reference,
                amount: amountValue,
                currency: currencyValue
            )
            if existingKeys.contains(key) {
                continue
            }

            let statement = BankStatement(
                account: accountValue,
                date: date,
                reference: reference,
                amount: amountValue,
                currency: currencyValue
            )
            modelContext.insert(statement)
            existingKeys.insert(key)
        }

        BankStatementMatcher.autoLink(modelContext: modelContext)
        dismiss()
    }

    private func statementKey(account: String?, date: Date, reference: String?, amount: Double?, currency: String?) -> String {
        let accountValue = account ?? ""
        let referenceValue = reference ?? ""
        let amountValue = amount.map { String(format: "%.6f", $0) } ?? ""
        let currencyValue = currency ?? ""
        return "\(accountValue)|\(date.timeIntervalSinceReferenceDate)|\(referenceValue)|\(amountValue)|\(currencyValue)"
    }

    private func parseAmountAndCurrency(from raw: String, decimalSeparator: DecimalSeparator) -> (amount: Double?, currency: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }

        let currency = normalizeCurrency(extractCurrency(from: trimmed))
        let normalized = normalizeAmountString(from: trimmed, decimalSeparator: decimalSeparator)
        guard !normalized.isEmpty else { return (nil, currency) }
        guard let value = Double(normalized) else { return (nil, currency) }

        let negative = trimmed.contains("-")
        let amount = negative ? -abs(value) : value
        return (amount, currency)
    }

    private func extractCurrency(from raw: String) -> String? {
        let symbols = raw.unicodeScalars.filter { "$€£¥".unicodeScalars.contains($0) }
        let symbolText = String(String.UnicodeScalarView(symbols))
        if !symbolText.isEmpty {
            return symbolText
        }

        let letters = raw.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let text = String(String.UnicodeScalarView(letters)).uppercased()
        return text.isEmpty ? nil : text
    }

    private func normalizeCurrency(_ currency: String?) -> String? {
        guard let currency else { return nil }
        let trimmed = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch trimmed.uppercased() {
        case "EUR":
            return "€"
        case "USD":
            return "$"
        case "GBP":
            return "£"
        default:
            return trimmed
        }
    }

    private func normalizeAmountString(from raw: String, decimalSeparator: DecimalSeparator) -> String {
        let allowed = CharacterSet(charactersIn: "0123456789" + decimalSeparator.rawValue)
        let scalars = raw.unicodeScalars.filter { allowed.contains($0) }
        var cleaned = String(String.UnicodeScalarView(scalars))
        if decimalSeparator == .comma {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        return cleaned
    }

    private func formatAmount(_ amount: Double, currency: String?) -> String {
        let formatted = amountFormatter.string(from: NSNumber(value: amount)) ?? amount.formatted()
        guard let currency, !currency.isEmpty else { return formatted }
        return "\(formatted) \(currency)"
    }

    private var amountFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private func normalizeRanges() {
        guard !parsedRows.isEmpty else {
            rowStart = 0
            rowEnd = 0
            dateColumn = 0
            referenceColumn = 0
            amountColumn = 0
            currencyColumn = -1
            return
        }

        rowStart = min(max(rowStart, 0), maxRowIndex)
        rowEnd = min(max(rowEnd, 0), maxRowIndex)
        if rowStart > rowEnd { rowStart = rowEnd }

        dateColumn = min(max(dateColumn, 0), maxColumnIndex)
        referenceColumn = min(max(referenceColumn, 0), maxColumnIndex)
        amountColumn = min(max(amountColumn, 0), maxColumnIndex)
        if currencyColumn >= 0 {
            currencyColumn = min(max(currencyColumn, 0), maxColumnIndex)
        }
    }

    private func guessAmountColumn(in rows: [[String]]) -> Int? {
        guard maxColumns > 0 else { return nil }
        let sampleRows = rows.prefix(50)
        var best: (index: Int, parsed: Int, nonEmpty: Int)?

        for index in 0..<maxColumns {
            let cells = sampleRows.map { cellValue(row: $0, column: index).trimmingCharacters(in: .whitespacesAndNewlines) }
            let filtered = cells.filter { !$0.isEmpty && $0.filter({ $0 == "." }).count <= 1 }
            let parsed = filtered.filter { parseAmountAndCurrency(from: $0, decimalSeparator: decimalSeparator).amount != nil }.count
            guard parsed > 0 else { continue }
            let candidate = (index: index, parsed: parsed, nonEmpty: filtered.count)
            if let current = best {
                if candidate.parsed > current.parsed || (candidate.parsed == current.parsed && candidate.nonEmpty > current.nonEmpty) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        return best?.index
    }

    private func guessDateFormat(in rows: [[String]]) -> String? {
        let formats = [
            "yyyy-MM-dd",
            "dd.MM.yyyy",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy/MM/dd",
            "dd-MM-yyyy",
            "MM-dd-yyyy"
        ]
        let sampleRows = rows.prefix(50)
        let values = sampleRows
            .map { cellValue(row: $0, column: dateColumn).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !values.isEmpty else { return nil }

        var best: (format: String, matches: Int)?
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            let matches = values.filter { formatter.date(from: $0) != nil }.count
            guard matches > 0 else { continue }
            if let current = best {
                if matches > current.matches {
                    best = (format, matches)
                }
            } else {
                best = (format, matches)
            }
        }

        return best?.format
    }

    private func tokens(from string: String) -> [String] {
        string
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { String($0) }
    }

    private func sanitizeBlacklist(_ tokens: [String]) -> [String] {
        var seen: Set<String> = []
        var sanitized: [String] = []

        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            sanitized.append(trimmed)
        }

        return sanitized
    }

    private func resolveCurrency(from column: Int, row: [String], fallback: String?) -> String? {
        guard column >= 0 else { return normalizeCurrency(fallback) }
        let raw = cellValue(row: row, column: column)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return fallback }
        return normalizeCurrency(extractCurrency(from: raw) ?? fallback)
    }

    private var normalizedBlacklist: [String] {
        blacklistTokens.map { $0.lowercased() }
    }

    private func rowIsBlacklisted(_ row: [String], blacklist: [String]) -> Bool {
        guard !blacklist.isEmpty else { return false }
        let reference = cellValue(row: row, column: referenceColumn)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !reference.isEmpty else { return false }
        return blacklist.contains { reference.contains($0) }
    }

}

private struct PreviewRow: Identifiable {
    let id: Int
    let cells: [String]
    let isBlacklisted: Bool
}

private enum PreviewColumn: Hashable {
    case data(Int)
    case parsedAmount
}

private enum CSVDelimiter: String, CaseIterable, Identifiable {
    case comma = ","
    case semicolon = ";"
    case tab = "\t"
    case pipe = "|"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .comma:
            return "Comma (,)"
        case .semicolon:
            return "Semicolon (;)"
        case .tab:
            return "Tab"
        case .pipe:
            return "Pipe (|)"
        }
    }

    var character: Character {
        Character(rawValue)
    }
}

private enum CSVParser {
    static func parse(text: String, delimiter: Character) -> [[String]] {
        let lines = sanitizedLines(from: text)
        return lines.map { parseLine(String($0), delimiter: delimiter) }
    }

    static func detectDelimiter(text: String) -> CSVDelimiter? {
        let lines = sanitizedLines(from: text)
        guard !lines.isEmpty else { return nil }

        let sample = lines.prefix(20)
        var best: (delimiter: CSVDelimiter, score: Int)?

        for delimiter in CSVDelimiter.allCases {
            let counts = sample.map { line in
                line.filter { $0 == delimiter.character }.count
            }
            let total = counts.reduce(0, +)
            if total == 0 { continue }

            let score = total
            if best == nil || score > best!.score {
                best = (delimiter, score)
            }
        }

        return best?.delimiter
    }

    private static func sanitizedLines(from text: String) -> [Substring] {
        var sanitized = text
        if sanitized.hasPrefix("\u{feff}") {
            sanitized.removeFirst()
        }
        return sanitized.split(whereSeparator: \.isNewline)
    }

    private static func parseLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var isQuoted = false
        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let char = characters[index]

            if char == "\"" {
                if isQuoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    current.append("\"")
                    index += 2
                    continue
                }

                isQuoted.toggle()
                index += 1
                continue
            }

            if char == delimiter, !isQuoted {
                fields.append(current)
                current = ""
                index += 1
                continue
            }

            current.append(char)
            index += 1
        }

        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

#Preview {
    BankStatementCSVImportView(url: URL(fileURLWithPath: "/tmp/sample.csv"))
}
