import SwiftUI
import UniformTypeIdentifiers

struct BankStatementsView: View {
    @State private var isTargeted = false
    @State private var importURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                return handleDrop(url: url)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .overlay {
                if isTargeted {
                    dropOverlay
                }
            }
            .sheet(isPresented: sheetPresented) {
                if let importURL {
                    BankStatementCSVImportView(url: importURL)
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }

    private var content: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Drop a CSV to Import")
                .font(.headline)
            Text("Preview and map bank statement columns before importing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var dropOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Drop CSV to Parse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var sheetPresented: Binding<Bool> {
        Binding(
            get: { importURL != nil },
            set: { newValue in
                if !newValue {
                    importURL = nil
                }
            }
        )
    }

    private func handleDrop(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            errorMessage = "Unsupported file type"
            showError = true
            return false
        }

        if type.conforms(to: .commaSeparatedText) || type.conforms(to: .plainText) {
            importURL = url
            return true
        }

        errorMessage = "Only CSV files can be imported"
        showError = true
        return false
    }
}

#Preview {
    BankStatementsView()
}
