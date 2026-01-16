import Foundation
import SwiftData

@Model
final class Invoice {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

// MARK: Mock Data
extension Invoice {
    static func generateMockData(modelContext: ModelContext) {
        
    }
}
