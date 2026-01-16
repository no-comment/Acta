import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var title: String = "Untitled Tag"
    var group: TagGroup?
    var invoices: [Invoice]?
    
    init(title: String, group: TagGroup, color: Color = Color.accentColor) {
        self.title = title
        self.group = group
    }
}

// MARK: Mock Data
extension Tag {
    static func generateMockData(modelContext: ModelContext) {
        let allTagGroups = try? modelContext.fetch(FetchDescriptor<TagGroup>())
        guard let projectGroup = allTagGroups?.first(where: { $0.title == "Project" }) else { return }
        
        let tag1 = Tag(title: "no-comment", group: projectGroup)
        let tag2 = Tag(title: "private", group: projectGroup)
        
        modelContext.insert(tag1)
        modelContext.insert(tag2)
    }
}
