import Foundation

struct BankStatementSearchToken: Identifiable, Equatable, Hashable {
    let id = UUID()
    let field: Field
    let value: String

    enum Field: String, CaseIterable {
        case all = "All"
        case status = "Status"
        case account = "Account"
        case reference = "Reference"
        case amount = "Amount"
        case currency = "Currency"
        case notes = "Notes"
        case linkedInvoice = "Linked Invoice"
        case date = "Date"

        var iconName: String {
            switch self {
            case .all: return "magnifyingglass"
            case .status: return "link.badge.plus"
            case .account: return "banknote"
            case .reference: return "text.alignleft"
            case .amount: return "dollarsign"
            case .currency: return "coloncurrencysign"
            case .notes: return "note.text"
            case .linkedInvoice: return "doc.text"
            case .date: return "calendar"
            }
        }
    }

    func matches(_ statement: BankStatement) -> Bool {
        let lowercasedValue = value.lowercased()
        switch field {
        case .all:
            return Field.allCases.filter { $0 != .all }.contains { otherField in
                BankStatementSearchToken(field: otherField, value: value).matches(statement)
            }
        case .status:
            return statement.status.label.lowercased().contains(lowercasedValue)
        case .account:
            return statement.account?.lowercased().contains(lowercasedValue) ?? false
        case .reference:
            return statement.reference?.lowercased().contains(lowercasedValue) ?? false
        case .amount:
            guard let amount = statement.amount else { return false }
            let amountString = Formatters.amount.string(from: NSNumber(value: abs(amount))) ?? ""
            if amountString.hasPrefix(value) || amountString.hasPrefix(value.replacingOccurrences(of: ",", with: ".")) {
                return true
            }
            if let searchAmount = Double(value.replacingOccurrences(of: ",", with: ".")) {
                let tolerance = abs(amount) * 0.05
                if abs(searchAmount - abs(amount)) <= tolerance {
                    return true
                }
            }
            return false
        case .currency:
            return statement.currency?.lowercased().contains(lowercasedValue) ?? false
        case .notes:
            return statement.notes.lowercased().contains(lowercasedValue)
        case .linkedInvoice:
            return statement.linkedFilePath?.lowercased().contains(lowercasedValue) ?? false
        case .date:
            guard let date = statement.date else { return false }
            let formatted = Formatters.date.string(from: date).lowercased()
            return formatted.contains(lowercasedValue)
        }
    }
}
