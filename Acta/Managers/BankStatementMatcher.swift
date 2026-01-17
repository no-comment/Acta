import Foundation
import SwiftData

@MainActor
enum BankStatementMatcher {
    static func autoLink(modelContext: ModelContext) {
        let statementDescriptor = FetchDescriptor<BankStatement>(
            predicate: #Predicate { $0.matchedInvoice == nil }
        )
        let statements = (try? modelContext.fetch(statementDescriptor)) ?? []
        let invoiceDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.matchedBankStatement == nil }
        )
        let invoices = (try? modelContext.fetch(invoiceDescriptor)) ?? []

        var availableInvoices = invoices.filter { $0.status != .statementVerified }

        for statement in statements {
            autoLink(statement: statement, availableInvoices: &availableInvoices)
        }
    }

    static func autoLink(statement: BankStatement, availableInvoices: inout [Invoice]) {
        guard statement.matchedInvoice == nil,
              let statementAmount = statement.amount,
              let statementDate = statement.date else { return }

        let matches = availableInvoices.filter { invoice in
            guard let invoiceDate = invoice.date,
                  let invoiceAmount = signedTotalAmount(for: invoice) else { return false }
            guard let invoiceCurrency = normalizedCurrency(invoice.currency),
                  let statementCurrency = normalizedCurrency(statement.currency),
                  invoiceCurrency == statementCurrency else { return false }
            guard invoiceAmount == statementAmount else { return false }
            return isWithinWeek(statementDate: statementDate, invoiceDate: invoiceDate)
        }

        guard matches.count == 1, let match = matches.first else { return }

        statement.matchedInvoice = match
        match.matchedBankStatement = statement
        availableInvoices.removeAll { $0.id == match.id }
    }

    private static func signedTotalAmount(for invoice: Invoice) -> Double? {
        guard let amount = invoice.totalAmount else { return nil }
        guard let direction = invoice.direction else { return amount }

        switch direction {
        case .incoming:
            return abs(amount)
        case .outgoing:
            return -abs(amount)
        }
    }

    private static func isWithinWeek(statementDate: Date, invoiceDate: Date) -> Bool {
        let calendar = Calendar.current
        let statementDay = calendar.startOfDay(for: statementDate)
        let invoiceDay = calendar.startOfDay(for: invoiceDate)
        let dayDelta = calendar.dateComponents([.day], from: invoiceDay, to: statementDay).day ?? .max
        return abs(dayDelta) <= 7
    }

    private static func normalizedCurrency(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed.uppercased()
    }
}
