import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A view modifier that adds invoice importing capabilities with duplicate detection.
///
/// This modifier handles the complete invoice import flow:
/// 1. Presents a file importer when triggered
/// 2. Checks for duplicate files before importing
/// 3. Shows a confirmation alert if a duplicate is found
/// 4. Shows error alerts if import fails
///
/// Usage:
/// ```swift
/// SomeView()
///     .invoiceImporter(isPresented: $showImporter)
/// ```
struct InvoiceImporterModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    
    let documentManager: DocumentManager?
    
    @Binding var isPresented: Bool
    
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var importTask: Task<Void, Never>?

    // Duplicate detection state
    @State private var pendingImportURLs: [URL] = []
    @State private var duplicateCount = 0
    @State private var showDuplicateAlert = false

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: DocumentManager.invoiceContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .alert("Duplicate Files", isPresented: $showDuplicateAlert) {
                Button("Add Anyway") {
                    performImport(urls: pendingImportURLs)
                }
                Button("Skip", role: .cancel) {
                    pendingImportURLs = []
                    duplicateCount = 0
                }
            } message: {
                if duplicateCount == 1 {
                    Text("1 file appears to be a duplicate. Do you still want to import it?")
                } else {
                    Text("\(duplicateCount) files appear to be duplicates. Do you still want to import them?")
                }
            }
            .onDisappear {
                importTask?.cancel()
            }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }

        importTask?.cancel()

        importTask = Task { @MainActor in
            do {
                let urls = try result.get()
                guard !urls.isEmpty else { return }

                var duplicates: [URL] = []

                for url in urls {
                    // Check for duplicates first
                    if try documentManager.findDuplicate(of: url, type: .invoice) != nil {
                        duplicates.append(url)
                    } else {
                        let document = try await documentManager.importInvoice(url: url)
                        createInvoiceRecord(for: document)
                    }
                }

                // Show duplicate alert if any duplicates were found
                if !duplicates.isEmpty {
                    pendingImportURLs = duplicates
                    duplicateCount = duplicates.count
                    showDuplicateAlert = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func performImport(urls: [URL]) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }

        importTask?.cancel()

        importTask = Task { @MainActor in
            do {
                for url in urls {
                    let document = try await documentManager.importInvoice(url: url)
                    createInvoiceRecord(for: document)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            pendingImportURLs = []
            duplicateCount = 0
        }
    }

    private func createInvoiceRecord(for document: DocumentFile) {
        let filename = document.filename
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.path == filename }
        )
        let existingInvoices = (try? modelContext.fetch(descriptor)) ?? []
        guard existingInvoices.isEmpty else { return }
        let invoice = Invoice(path: filename, tags: [], status: .new)
        modelContext.insert(invoice)
        try? modelContext.save()
    }
}

extension View {
    /// Adds invoice importing capabilities with duplicate detection.
    /// - Parameters:
    ///   - isPresented: A binding that controls when the file importer is shown.
    ///   - documentManager: The document manager to use for importing. If nil, import will show an error.
    /// - Returns: A view with invoice importing capabilities.
    func invoiceImporter(isPresented: Binding<Bool>, documentManager: DocumentManager?) -> some View {
        modifier(InvoiceImporterModifier(documentManager: documentManager, isPresented: isPresented))
    }
    
    /// Adds drag and drop invoice importing capabilities with duplicate detection.
    /// - Parameter documentManager: The document manager to use for importing. If nil, drops will be rejected.
    /// - Returns: A view with drag and drop invoice importing capabilities.
    func invoiceDropImporter(documentManager: DocumentManager?) -> some View {
        modifier(InvoiceDropImporterModifier(documentManager: documentManager))
    }
}

// MARK: - Drop Importer

/// A view modifier that adds drag and drop invoice importing capabilities.
///
/// This modifier handles the complete drag and drop import flow:
/// 1. Accepts dropped PDF and image files
/// 2. Shows a visual overlay when files are being dragged over
/// 3. Checks for duplicate files before importing
/// 4. Shows a confirmation alert if a duplicate is found
/// 5. Shows error alerts if import fails
///
/// Usage:
/// ```swift
/// SomeView()
///     .invoiceDropImporter(documentManager: documentManager)
/// ```
struct InvoiceDropImporterModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    let documentManager: DocumentManager?

    @State private var isTargeted = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var importTask: Task<Void, Never>?

    // Duplicate detection state
    @State private var pendingImportURLs: [URL] = []
    @State private var duplicateCount = 0
    @State private var showDuplicateAlert = false
    
    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty, documentManager != nil else { return false }
                handleDroppedFiles(urls: urls)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .overlay {
                if isTargeted {
                    dropOverlay
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .alert("Duplicate Files", isPresented: $showDuplicateAlert) {
                Button("Add Anyway") {
                    performImport(urls: pendingImportURLs)
                }
                Button("Skip", role: .cancel) {
                    pendingImportURLs = []
                    duplicateCount = 0
                }
            } message: {
                if duplicateCount == 1 {
                    Text("1 file appears to be a duplicate. Do you still want to import it?")
                } else {
                    Text("\(duplicateCount) files appear to be duplicates. Do you still want to import them?")
                }
            }
            .onDisappear {
                importTask?.cancel()
            }
    }
    
    private var dropOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Drop to Import")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func handleDroppedFiles(urls: [URL]) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }

        // Filter to valid file types
        let validURLs = urls.filter { url in
            guard let uti = UTType(filenameExtension: url.pathExtension) else { return false }
            return DocumentManager.invoiceContentTypes.contains(where: { uti.conforms(to: $0) })
        }

        guard !validURLs.isEmpty else {
            errorMessage = "Only PDF and image files can be imported"
            showError = true
            return
        }

        importTask?.cancel()

        importTask = Task { @MainActor in
            do {
                var duplicates: [URL] = []

                for url in validURLs {
                    // Check for duplicates first
                    if try documentManager.findDuplicate(of: url, type: .invoice) != nil {
                        duplicates.append(url)
                    } else {
                        let document = try await documentManager.importInvoice(url: url)
                        createInvoiceRecord(for: document)
                    }
                }

                // Show duplicate alert if any duplicates were found
                if !duplicates.isEmpty {
                    pendingImportURLs = duplicates
                    duplicateCount = duplicates.count
                    showDuplicateAlert = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performImport(urls: [URL]) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }

        importTask?.cancel()

        importTask = Task { @MainActor in
            do {
                for url in urls {
                    let document = try await documentManager.importInvoice(url: url)
                    createInvoiceRecord(for: document)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            pendingImportURLs = []
            duplicateCount = 0
        }
    }
    
    private func createInvoiceRecord(for document: DocumentFile) {
        let filename = document.filename
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.path == filename }
        )
        let existingInvoices = (try? modelContext.fetch(descriptor)) ?? []
        guard existingInvoices.isEmpty else { return }
        let invoice = Invoice(path: filename, tags: [], status: .new)
        modelContext.insert(invoice)
        try? modelContext.save()
    }
}
