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
    @State private var pendingImportURL: URL?
    @State private var duplicateDocument: DocumentFile?
    @State private var showDuplicateAlert = false
    
    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
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
            .alert("Duplicate File", isPresented: $showDuplicateAlert) {
                Button("Import Anyway") {
                    if let url = pendingImportURL {
                        performImport(url: url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingImportURL = nil
                    duplicateDocument = nil
                }
            } message: {
                if let duplicate = duplicateDocument {
                    Text("This file appears to be identical to '\(duplicate.displayName)'. Do you still want to import it?")
                } else {
                    Text("This file already exists. Do you still want to import it?")
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
                guard let url = try result.get().first else { return }
                
                // Check for duplicates first
                if let duplicate = try documentManager.findDuplicate(of: url, type: .invoice) {
                    pendingImportURL = url
                    duplicateDocument = duplicate
                    showDuplicateAlert = true
                } else {
                        let document = try await documentManager.importInvoice(url: url)
                        createInvoiceRecord(for: document)
                    }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func performImport(url: URL) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }
        
        importTask?.cancel()
        
        importTask = Task { @MainActor in
            do {
                let document = try await documentManager.importInvoice(url: url)
                createInvoiceRecord(for: document)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            pendingImportURL = nil
            duplicateDocument = nil
        }
    }
    
    private func createInvoiceRecord(for document: DocumentFile) {
        let filename = document.filename
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.path == filename }
        )
        let existingInvoices = (try? modelContext.fetch(descriptor)) ?? []
        guard existingInvoices.isEmpty else {
            print("invoiceImporter: skipping duplicate invoice for \(filename)")
            return
        }
        print("invoiceImporter: inserting invoice for \(filename)")
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
    @State private var pendingImportURL: URL?
    @State private var duplicateDocument: DocumentFile?
    @State private var showDuplicateAlert = false
    
    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, documentManager != nil else { return false }
                handleDroppedFile(url: url)
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
            .alert("Duplicate File", isPresented: $showDuplicateAlert) {
                Button("Import Anyway") {
                    if let url = pendingImportURL {
                        performImport(url: url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingImportURL = nil
                    duplicateDocument = nil
                }
            } message: {
                if let duplicate = duplicateDocument {
                    Text("This file appears to be identical to '\(duplicate.displayName)'. Do you still want to import it?")
                } else {
                    Text("This file already exists. Do you still want to import it?")
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
    
    private func handleDroppedFile(url: URL) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }
        
        // Validate file type
        guard let uti = UTType(filenameExtension: url.pathExtension),
              DocumentManager.invoiceContentTypes.contains(where: { uti.conforms(to: $0) }) else {
            errorMessage = "Only PDF and image files can be imported"
            showError = true
            return
        }
        
        importTask?.cancel()
        
        importTask = Task { @MainActor in
            do {
                // Check for duplicates first
                if let duplicate = try documentManager.findDuplicate(of: url, type: .invoice) {
                    pendingImportURL = url
                    duplicateDocument = duplicate
                    showDuplicateAlert = true
                } else {
                    let document = try await documentManager.importInvoice(url: url)
                    createInvoiceRecord(for: document)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func performImport(url: URL) {
        guard let documentManager else {
            errorMessage = "iCloud is not available"
            showError = true
            return
        }
        
        importTask?.cancel()
        
        importTask = Task { @MainActor in
            do {
                let document = try await documentManager.importInvoice(url: url)
                createInvoiceRecord(for: document)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            pendingImportURL = nil
            duplicateDocument = nil
        }
    }
    
    private func createInvoiceRecord(for document: DocumentFile) {
        let filename = document.filename
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.path == filename }
        )
        let existingInvoices = (try? modelContext.fetch(descriptor)) ?? []
        guard existingInvoices.isEmpty else {
            print("invoiceDropImporter: skipping duplicate invoice for \(filename)")
            return
        }
        print("invoiceDropImporter: inserting invoice for \(filename)")
        let invoice = Invoice(path: filename, tags: [], status: .new)
        modelContext.insert(invoice)
        try? modelContext.save()
    }
}
