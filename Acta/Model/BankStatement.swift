import Foundation
import SwiftData

@Model
final class BankStatement {
    var bank: String?
    var date: Date?
    var reference: String?
    var amountString: String?
    var notes: String = ""
    
    var matchedInvoice: Invoice?
    
    init(bank: String?, date: Date, reference: String, amountString: String, notes: String = "") {
        self.bank = bank
        self.date = date
        self.reference = reference
        self.amountString = amountString
        self.notes = notes
    }
}

// MARK: Mock Data
extension BankStatement {
    static func generateMockData(modelContext: ModelContext) {
//        let allTags = try? modelContext.fetch(FetchDescriptor<Tag>())
//        guard let nocommentTag = allTags?.first(where: { $0.title == "no-comment" }) else { return }
//        guard let privateTag = allTags?.first(where: { $0.title == "private" }) else { return }
                
        let statement1 = BankStatement(bank: "N26", date: Date.now, reference: "Apple Inc.; APPLE DEVELOPER 1 YEAR; CAMERON SHEMILT", amountString: "341,37 $", notes: "Apple Developer Licence")
                
        modelContext.insert(statement1)
    }
}
