import SwiftUI
import SwiftData
import SwiftCloudDrive
import os

private let logger = Logger(subsystem: "xyz.no-comment.Acta", category: "iCloud")

@main
struct ActaApp: App {
    @State private var documentManager: DocumentManager?
    @State private var initError: InitializationError?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let documentManager {
                    ContentView()
                        .environment(documentManager)
                } else if let initError {
                    ContentUnavailableView {
                        Label("iCloud Unavailable", systemImage: "icloud.slash")
                    } description: {
                        Text(initError.localizedDescription)
                    } actions: {
                        Button("Retry") {
                            self.initError = nil
                            Task { await initializeiCloud() }
                        }
                    }
                }
            }
            .task {
                await initializeiCloud()
            }
        }
        .modelContainer(DataStoreConfig.container)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Invoice...") {
                    NotificationCenter.default.post(name: .importInvoice, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(documentManager == nil)
            }
        }
    }
    
    private func initializeiCloud() async {
        guard documentManager == nil && initError == nil else { return }
        
        do {
            let drive = try await CloudDrive(
                ubiquityContainerIdentifier: "iCloud.xyz.no-comment.Acta",
                relativePathToRootInContainer: "Documents"
            )
            
            logger.info("✅ CloudDrive initialized: \(drive.rootDirectory.path)")
            documentManager = DocumentManager(drive: drive)
            
        } catch SwiftCloudDrive.Error.notSignedIntoCloud {
            logger.error("❌ User not signed into iCloud")
            initError = .notSignedIntoiCloud
        } catch {
            logger.error("❌ iCloud Drive error: \(error.localizedDescription)")
            initError = .unknown(error.localizedDescription)
        }
    }
}
