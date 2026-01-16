import Foundation
import SwiftData

@Model
final class TagGroup {
    var title: String = "Untitled Tag Group"
    var tags: [Tag]?
    
    init(title: String) {
        self.title = title
    }
}

// MARK: Mock Data
extension TagGroup {
    static func generateMockData(modelContext: ModelContext) {
        let projectTagGroup = TagGroup(title: "Project")
        modelContext.insert(projectTagGroup)
    }
}
