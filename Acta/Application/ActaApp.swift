import os
import SwiftCloudDrive
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "xyz.no-comment.Acta", category: "iCloud")

@main
struct ActaApp: App {
    @State private var documentManager: DocumentManager?
    @State private var initError: InitializationError?
    
    var body: some Scene {
        WindowGroup {
            if let initError {
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
            } else {
                ContentView()
                    .environment(documentManager)
                    .task {
                        await initializeiCloud()
                    }
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
                
                Divider()
                
                Button("Open Invoices Folder in Finder") {
                    if let documentManager {
                        let folderURL = documentManager.getFolderURL(for: .invoice)
                        NSWorkspace.shared.open(folderURL)
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(documentManager == nil)
            }

            CommandGroup(after: .sidebar) {
                Divider()

                Button {
                    NotificationCenter.default.post(name: .showInvoices, object: nil)
                } label: {
                    Label("Show Invoices", systemImage: "doc.text")
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button {
                    NotificationCenter.default.post(name: .showBankStatements, object: nil)
                } label: {
                    Label("Show Bank Statements", systemImage: "list.bullet.rectangle")
                }
                .keyboardShortcut("2", modifiers: [.command])

                Divider()
            }
        }
        
        WindowGroup("Details", for: ActaApp.WindowType.self) { $window in
            switch window {
            case .invoiceDetail(id: let id): InvoiceDetailView(invoiceID: id).environment(documentManager)
            case .statementMatching(id: let id):BankStatementInvoicePickerView(for: id).environment(documentManager)
            case .none: Text("Error")
            }
        }
        .modelContainer(DataStoreConfig.container)

        Window("Review Invoices", id: "invoice-review") {
            InvoiceReviewView()
                .environment(documentManager)
        }
        .modelContainer(DataStoreConfig.container)

        Window("Review Links", id: "link-review") {
            BankStatementLinkReviewView()
                .environment(documentManager)
        }
        .modelContainer(DataStoreConfig.container)

        Settings {
            SettingsView()
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

    
    enum MainView: String, Identifiable, CaseIterable {
        case invoices
        case bankStatements = "bank-statements"
        
        var id: String { self.rawValue }
        
        var title: String {
            switch self {
            case .invoices: "Invoices"
            case .bankStatements: "Bank Statements"
            }
        }
    }
    
    enum WindowType: Codable, Hashable {
        case invoiceDetail(id: Invoice.ID)
        case statementMatching(id: BankStatement.ID)
    }
}
