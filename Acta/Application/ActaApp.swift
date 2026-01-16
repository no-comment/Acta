import SwiftUI
import SwiftData

@main
struct ActaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(DataStoreConfig.container)
    }
}
