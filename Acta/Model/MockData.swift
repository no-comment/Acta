import SwiftData
import SwiftUI

// MARK: - Shared Model Container

enum DataStoreConfig {
    @MainActor
    static let container: ModelContainer = {
        try! ModelContainer(for: Invoice.self, Tag.self, TagGroup.self, BankStatement.self)
    }()
}

// MARK: - Preview Helpers

public struct ModelPreview<Model: PersistentModel, Content: View>: View {
    var content: (Model) -> Content
    
    public init(@ViewBuilder content: @escaping (Model) -> Content) {
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            PreviewContentView(content: content)
        }
        .dataContainer(inMemory: true)
    }
    
    struct PreviewContentView: View {
        var content: (Model) -> Content
        
        @Query private var models: [Model]
        @State private var waitedToShowIssue = false
        
        var body: some View {
            if let model = models.first {
                content(model)
            } else {
                ContentUnavailableView("Could not load model for previews", systemImage: "xmark.circle.fill")
                    .opacity(waitedToShowIssue ? 1 : 0)
                    .task {
                        Task {
                            try await Task.sleep(for: .seconds(1))
                            waitedToShowIssue = true
                        }
                    }
            }
        }
    }
}

public extension View {
    func dataContainer(inMemory: Bool) -> some View {
        modifier(DataContainerViewModifier(inMemory: inMemory))
    }
}

struct DataContainerViewModifier: ViewModifier {
    let inMemory: Bool
    
    func body(content: Content) -> some View {
        content
            .generateData()
            .modelContainer(for: [Invoice.self, Tag.self, TagGroup.self, BankStatement.self], inMemory: inMemory)
    }
}

private extension View {
    func generateData() -> some View {
        modifier(GenerateDataViewModifier())
    }
}

struct GenerateDataViewModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    
    func body(content: Content) -> some View {
        content.onAppear {
            TagGroup.generateMockData(modelContext: modelContext)
            Tag.generateMockData(modelContext: modelContext)
            Invoice.generateMockData(modelContext: modelContext)
            BankStatement.generateMockData(modelContext: modelContext)
        }
    }
}
