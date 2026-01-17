import Foundation
import SwiftData
import SwiftUI

@Model
final class BankStatement {
    var account: String?
    var date: Date?
    var reference: String?
    var amountString: String?
    var notes: String = ""
    
    var matchedInvoice: Invoice?
    
    init(account: String?, date: Date, reference: String, amountString: String, notes: String = "") {
        self.account = account
        self.date = date
        self.reference = reference
        self.amountString = amountString
        self.notes = notes
    }
}

extension BankStatement {
    var amount: Double {
        // TODO: Calculate Amount
        return 0
    }
    
    var linkedFilePath: String? {
        guard let matchedInvoice, let path = matchedInvoice.path else { return nil }
        return path
    }
    
    var status: Status {
        // TODO: check invoice status
        if let matchedInvoice, false {
            return .linked
        }
        
        if self.matchedInvoice != nil {
            return .linked
        }
        
        return .unlinked
    }
}

extension BankStatement {
    enum Status: String, Identifiable, Codable, Comparable, CaseIterable {
        case unlinked = "unlinked"
        case linked = "linked"
        case verified = "verified"

        var id: String { self.rawValue }

        var icon: Image {
            switch self {
            case .unlinked: Image(systemName: "questionmark.circle.dashed")
            case .linked: Image(systemName: "link")
            case .verified: Image(systemName: "checkmark.circle.fill")
            }
        }

        var label: String {
            switch self {
            case .unlinked: return "Unlinked"
            case .linked: return "Linked to Invoice"
            case .verified: return "Linked & Verified"
            }
        }

        static func < (lhs: Status, rhs: Status) -> Bool {
            let order: [Status] = [.unlinked, .linked, .verified]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
}

// MARK: Mock Data
extension BankStatement {
    static func generateMockData(modelContext: ModelContext) {
//        let allTags = try? modelContext.fetch(FetchDescriptor<Tag>())
//        guard let nocommentTag = allTags?.first(where: { $0.title == "no-comment" }) else { return }
//        guard let privateTag = allTags?.first(where: { $0.title == "private" }) else { return }
                
        let statement1 = BankStatement(account: "N26", date: Date.now, reference: "Apple Inc.; APPLE DEVELOPER 1 YEAR; CAMERON SHEMILT", amountString: "341,37 $", notes: "Apple Developer Licence")
                
        modelContext.insert(statement1)
    }
}
