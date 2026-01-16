import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(DocumentManager.self) private var documentManager
    @State private var isImportingInvoice = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var importTask: Task<Void, Never>?
    
    var body: some View {
        InvoicesView()
            .fileImporter(
                isPresented: $isImportingInvoice,
                allowedContentTypes: DocumentManager.invoiceContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .onDisappear {
                importTask?.cancel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .importInvoice)) { _ in
                isImportingInvoice = true
            }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        importTask?.cancel()
        
        importTask = Task { @MainActor in
            do {
                guard let url = try result.get().first else { return }
                try await documentManager.importInvoice(url: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

extension Notification.Name {
    static let importInvoice = Notification.Name("importInvoice")
}

#Preview {
    ContentView()
}
