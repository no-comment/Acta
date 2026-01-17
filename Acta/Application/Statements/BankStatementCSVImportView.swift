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
    @State private var dateFormat = "yyyy-MM-dd"
    @State private var accountName = ""

    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didSetInitialRanges = false
    @State private var columnVersion = 0
    @State private var didAutoDetectDelimiter = false

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
                .disabled(croppedRows.isEmpty)
            }
        }
        .onAppear(perform: loadFile)
        .onChange(of: delimiter) { _, _ in
            parse()
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
                    TableColumnForEach(visibleColumns, id: \.self) { column in
                        TableColumn(columnLabel(for: column)) { row in
                            Text(cellValue(row: row.cells, column: column))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .width(min: 100, ideal: 180, max: 360)
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
                                Text(columnLabel(for: column)).tag(column)
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
                                Text(columnLabel(for: column)).tag(column)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maxColumns == 0)

                        Picker("Amount column", selection: $amountColumn) {
                            ForEach(columnIndices, id: \.self) { column in
                                Text(columnLabel(for: column)).tag(column)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maxColumns == 0)
                    }
                }

                GroupBox("Account") {
                    TextField("Account name", text: $accountName)
                        .textFieldStyle(.roundedBorder)
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

    private var croppedRows: [[String]] {
        guard !parsedRows.isEmpty else { return [] }
        let start = min(rowStart, maxRowIndex)
        let end = min(rowEnd, maxRowIndex)
        if start > end { return [] }
        return (start...end).map { index in
            parsedRows[index]
        }
    }

    private var previewRows: [PreviewRow] {
        croppedRows.enumerated().map { offset, row in
            PreviewRow(id: rowStart + offset, cells: row)
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

        let values: [String] = croppedRows.compactMap { row in
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

    private func columnLabel(for index: Int) -> String {
        "\(index + 1). Column"
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
            amountColumn = min(2, maxColumnIndex)
            didSetInitialRanges = true
        }
        columnVersion += 1
        normalizeRanges()
    }

    private func saveStatements() {
        guard !croppedRows.isEmpty else { return }

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
                amount: statement.amountString
            )
        })

        for row in croppedRows {
            let dateString = cellValue(row: row, column: dateColumn)
            let reference = cellValue(row: row, column: referenceColumn)
            let amount = cellValue(row: row, column: amountColumn)

            guard let date = formatter.date(from: dateString) else {
                continue
            }

            if amount.isEmpty {
                continue
            }

            let key = statementKey(
                account: accountValue,
                date: date,
                reference: reference,
                amount: amount
            )
            if existingKeys.contains(key) {
                continue
            }

            let statement = BankStatement(
                account: accountValue,
                date: date,
                reference: reference,
                amountString: amount
            )
            modelContext.insert(statement)
            existingKeys.insert(key)
        }

        dismiss()
    }

    private func statementKey(account: String?, date: Date, reference: String?, amount: String?) -> String {
        let accountValue = account ?? ""
        let referenceValue = reference ?? ""
        let amountValue = amount ?? ""
        return "\(accountValue)|\(date.timeIntervalSinceReferenceDate)|\(referenceValue)|\(amountValue)"
    }

    private func normalizeRanges() {
        guard !parsedRows.isEmpty else {
            rowStart = 0
            rowEnd = 0
            dateColumn = 0
            referenceColumn = 0
            amountColumn = 0
            return
        }

        rowStart = min(max(rowStart, 0), maxRowIndex)
        rowEnd = min(max(rowEnd, 0), maxRowIndex)
        if rowStart > rowEnd { rowStart = rowEnd }

        dateColumn = min(max(dateColumn, 0), maxColumnIndex)
        referenceColumn = min(max(referenceColumn, 0), maxColumnIndex)
        amountColumn = min(max(amountColumn, 0), maxColumnIndex)
    }

}

private struct PreviewRow: Identifiable {
    let id: Int
    let cells: [String]
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
