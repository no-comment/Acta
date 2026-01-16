import SwiftUI
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
    @Environment(DocumentManager.self) private var documentManager
    
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
                    try await documentManager.importInvoice(url: url)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func performImport(url: URL) {
        importTask?.cancel()
        
        importTask = Task { @MainActor in
            do {
                try await documentManager.importInvoice(url: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            pendingImportURL = nil
            duplicateDocument = nil
        }
    }
}

extension View {
    /// Adds invoice importing capabilities with duplicate detection.
    /// - Parameter isPresented: A binding that controls when the file importer is shown.
    /// - Returns: A view with invoice importing capabilities.
    func invoiceImporter(isPresented: Binding<Bool>) -> some View {
        modifier(InvoiceImporterModifier(isPresented: isPresented))
    }
}
