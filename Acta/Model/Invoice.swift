import Foundation
import SwiftData

@Model
final class Invoice {
    var path: String?
    var tags: [Tag]?
    var isManuallyChecked: Bool = false
    
    var vendorName: String?
    var date: Date?
    var invoiceNo: String?
    
    var totalAmount: Double?
    var preTaxAmount: Double?
    var taxPercentage: Double?
    var currency: String?
    var direction: Direction?
    
    init(path: String? = nil, tags: [Tag], isManuallyChecked: Bool = false, vendorName: String? = nil, date: Date? = nil, invoiceNo: String? = nil, totalAmount: Double? = nil, preTaxAmount: Double? = nil, taxPercentage: Double? = nil, currency: String? = nil, direction: Direction? = nil) {
        self.path = path
        self.tags = tags
        self.isManuallyChecked = isManuallyChecked
        self.vendorName = vendorName
        self.date = date
        self.invoiceNo = invoiceNo
        self.totalAmount = totalAmount
        self.preTaxAmount = preTaxAmount
        self.taxPercentage = taxPercentage
        self.currency = currency
        self.direction = direction
    }
}

extension Invoice {
    func getPreTaxAmountString() -> String {
        guard let preTaxAmount else { return "N/A" }
        guard let currency else { return "N/A" }
        
        return preTaxAmount.formatted() + " " + currency
    }
    
    func getTags(for group: TagGroup) -> [Tag] {
        guard let tags else { return [] }
        let resultTags = tags.filter({ $0.group == group })
        return resultTags
    }
}

extension Invoice {
    enum Direction: String, Identifiable, Codable {
        case incoming = "incoming"
        case outgoing = "outgoing"
        
        var id: String { self.rawValue }
    }
}

// MARK: Mock Data
extension Invoice {
    static func generateMockData(modelContext: ModelContext) {
        let allTags = try? modelContext.fetch(FetchDescriptor<Tag>())
        guard let nocommentTag = allTags?.first(where: { $0.title == "no-comment" }) else { return }
        guard let privateTag = allTags?.first(where: { $0.title == "private" }) else { return }
                
        let invoice1 = Invoice(tags: [nocommentTag], vendorName: "Wilhelm Gymnasium")
        let invoice2 = Invoice(tags: [privateTag], vendorName: "Apple")
                
        modelContext.insert(invoice1)
        modelContext.insert(invoice2)
    }
}
