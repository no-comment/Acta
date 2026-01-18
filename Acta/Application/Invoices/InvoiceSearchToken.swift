import Foundation

struct InvoiceSearchToken: Identifiable, Equatable, Hashable {
    let id = UUID()
    let field: Field
    let value: String

    enum Field: String, CaseIterable {
        case all = "All"
        case status = "Status"
        case vendor = "Vendor"
        case filename = "Filename"
        case invoiceNo = "Invoice #"
        case preTax = "Pre Tax"
        case tax = "Tax"
        case total = "Total"
        case date = "Date"

        var iconName: String {
            switch self {
            case .all: return "magnifyingglass"
            case .status: return "circle.badge.checkmark"
            case .vendor: return "building.2"
            case .filename: return "doc"
            case .invoiceNo: return "number"
            case .preTax: return "minus.circle"
            case .tax: return "percent"
            case .total: return "dollarsign"
            case .date: return "calendar"
            }
        }
    }

    func matches(_ invoice: Invoice) -> Bool {
        let lowercasedValue = value.lowercased()
        switch field {
        case .all:
            // Recursively check all other fields
            return Field.allCases.filter { $0 != .all }.contains { otherField in
                InvoiceSearchToken(field: otherField, value: value).matches(invoice)
            }
        case .status:
            return invoice.status.label.lowercased().contains(lowercasedValue)
        case .vendor:
            return invoice.vendorName?.lowercased().contains(lowercasedValue) ?? false
        case .filename:
            return invoice.path?.lowercased().contains(lowercasedValue) ?? false
        case .invoiceNo:
            return invoice.invoiceNo?.lowercased().contains(lowercasedValue) ?? false
        case .preTax:
            guard let preTaxAmount = invoice.preTaxAmount else { return false }
            let amountString = Formatters.amount.string(from: NSNumber(value: abs(preTaxAmount))) ?? ""
            // Check startsWith
            if amountString.hasPrefix(value) || amountString.hasPrefix(value.replacingOccurrences(of: ",", with: ".")) {
                return true
            }
            // Check 5% tolerance
            if let searchAmount = Double(value.replacingOccurrences(of: ",", with: ".")) {
                let tolerance = abs(preTaxAmount) * 0.05
                if abs(searchAmount - abs(preTaxAmount)) <= tolerance {
                    return true
                }
            }
            return false
        case .tax:
            guard let taxPercentage = invoice.taxPercentage else { return false }
            let taxString = Formatters.tax.string(from: NSNumber(value: taxPercentage)) ?? ""
            return taxString.lowercased().contains(lowercasedValue)
        case .total:
            guard let invoiceAmount = invoice.totalAmount else { return false }
            let amountString = Formatters.amount.string(from: NSNumber(value: abs(invoiceAmount))) ?? ""
            // Check startsWith
            if amountString.hasPrefix(value) || amountString.hasPrefix(value.replacingOccurrences(of: ",", with: ".")) {
                return true
            }
            // Check 5% tolerance
            if let searchAmount = Double(value.replacingOccurrences(of: ",", with: ".")) {
                let tolerance = abs(invoiceAmount) * 0.05
                if abs(searchAmount - abs(invoiceAmount)) <= tolerance {
                    return true
                }
            }
            return false
        case .date:
            guard let date = invoice.date else { return false }
            let formatted = Formatters.date.string(from: date).lowercased()
            return formatted.contains(lowercasedValue)
        }
    }
}
