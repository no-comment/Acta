import Foundation
import SwiftCloudDrive
import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "xyz.no-comment.Acta", category: "DocumentManager")

@MainActor
@Observable
final class DocumentManager {
    private let drive: CloudDrive
    
    /// Content types allowed for invoice imports
    static let invoiceContentTypes: [UTType] = [
        .pdf,
        .jpeg, .png, .heic,
        .gif, .tiff, .bmp, .webP
    ]
    
    enum LoadingState {
        case idle
        case loading
        case loaded
        case failed(String)
    }
    
    var invoices: [DocumentFile] = []
    var bankStatements: [DocumentFile] = []
    var loadingState: LoadingState = .idle
    
    init(drive: CloudDrive) {
        self.drive = drive
        
        // Initialize in background
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        loadingState = .loading
        
        do {
            // Create folders if they don't exist
            try await ensureFolderExists(for: .invoice)
            try await ensureFolderExists(for: .bankStatement)
            
            // Load initial lists
            try await refreshDocuments(type: .invoice)
            try await refreshDocuments(type: .bankStatement)
            
            loadingState = .loaded
        } catch {
            logger.error("❌ Failed to initialize DocumentManager: \(error.localizedDescription)")
            loadingState = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Public API
    
    /// Imports an invoice by copying it to the iCloud Drive invoices folder
    /// - Parameter url: The URL of the file to import
    /// - Returns: The imported document file metadata
    @discardableResult
    func importInvoice(url: URL) async throws -> DocumentFile {
        try await importDocument(url: url, type: .invoice)
    }
    
    /// Imports a bank statement by copying it to the iCloud Drive bank statements folder
    /// 
    /// Bank statements can be any file type (PDF, CSV, Excel, images, etc.) as different
    /// financial institutions provide statements in various formats.
    /// 
    /// - Parameter url: The URL of the file to import
    /// - Returns: The imported document file metadata
    @discardableResult
    func importBankStatement(url: URL) async throws -> DocumentFile {
        try await importDocument(url: url, type: .bankStatement)
    }
    
    /// Lists all invoices in the iCloud Drive invoices folder
    /// - Returns: Array of invoice file metadata
    func listInvoices() async throws -> [DocumentFile] {
        try await refreshDocuments(type: .invoice)
        return invoices
    }
    
    /// Lists all bank statements in the iCloud Drive bank statements folder
    /// - Returns: Array of bank statement file metadata
    func listBankStatements() async throws -> [DocumentFile] {
        try await refreshDocuments(type: .bankStatement)
        return bankStatements
    }
    
    /// Deletes a document from iCloud Drive
    /// - Parameters:
    ///   - document: The document file to delete
    ///   - type: The type of document
    func deleteDocument(_ document: DocumentFile, type: DocumentType) async throws {
        let folderPath = type.folderPath
        let path = RootRelativePath(path: "\(folderPath)/\(document.filename)")
        try await drive.removeFile(at: path)
        logger.info("🗑️ Deleted \(type.displayName): \(document.filename)")
        
        try await refreshDocuments(type: type)
    }
    
    /// Gets the URL for a document file
    /// - Parameters:
    ///   - document: The document file
    ///   - type: The type of document
    /// - Returns: The local URL to the file
    func getURL(for document: DocumentFile, type: DocumentType) -> URL {
        return drive.rootDirectory
            .appendingPathComponent(type.folderPath)
            .appendingPathComponent(document.filename)
    }
    
    /// Checks if a file with the same content already exists in the specified folder
    /// Uses a two-phase approach: first compares file sizes (fast), then byte comparison if sizes match
    /// - Parameters:
    ///   - url: The URL of the file to check
    ///   - type: The document type (determines which folder to check)
    /// - Returns: The existing document if a duplicate is found, nil otherwise
    func findDuplicate(of url: URL, type: DocumentType) throws -> DocumentFile? {
        // Get security scoped access if needed
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Get source file size first (fast check)
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let sourceSize = sourceAttributes[.size] as? Int64 else {
            return nil
        }
        
        // Get all documents in the folder
        let documents = type == .invoice ? invoices : bankStatements
        
        // Find documents with matching size
        let sameSizeDocuments = documents.filter { $0.fileSize == sourceSize }
        
        // If no size matches, no duplicates possible
        guard !sameSizeDocuments.isEmpty else {
            return nil
        }
        
        // Read source file for byte comparison
        let sourceData = try Data(contentsOf: url)
        
        // Compare bytes with same-size files
        for document in sameSizeDocuments {
            let documentURL = getURL(for: document, type: type)
            guard let documentData = try? Data(contentsOf: documentURL) else { continue }
            
            if sourceData == documentData {
                logger.info("🔍 Found duplicate: \(document.filename)")
                return document
            }
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func importDocument(url: URL, type: DocumentType) async throws -> DocumentFile {
        logger.info("📥 Importing \(type.displayName) from: \(url.path)")
        
        // Validate file type for invoices (only PDF and images)
        if type == .invoice {
            try validateInvoiceFileType(url: url)
        }
        
        // Get security scoped access if needed
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Read the file data
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.error("❌ Failed to read file at \(url.path): \(error.localizedDescription)")
            throw DocumentManagerError.unableToReadFile(description: error.localizedDescription)
        }
        
        // Generate unique filename to avoid collisions
        let originalFilename = url.lastPathComponent
        let filename = generateUniqueFilename(original: originalFilename)
        let destinationPath = RootRelativePath(path: "\(type.folderPath)/\(filename)")
        
        // Check if file already exists
        if try await drive.fileExists(at: destinationPath) {
            throw DocumentManagerError.fileAlreadyExists(filename: filename)
        }
        
        // Write to iCloud Drive
        try await drive.writeFile(with: data, at: destinationPath)
        logger.info("✅ \(type.displayName) imported successfully: \(filename)")
        
        // Refresh the list
        try await refreshDocuments(type: type)
        
        // Return the newly created file
        let documents = type == .invoice ? invoices : bankStatements
        guard let document = documents.first(where: { $0.filename == filename }) else {
            throw DocumentManagerError.fileNotFoundAfterImport
        }
        
        return document
    }
    
    private func ensureFolderExists(for type: DocumentType) async throws {
        let folderPath = RootRelativePath(path: type.folderPath)
        do {
            try await drive.createDirectory(at: folderPath)
            logger.info("📁 Created \(type.displayName) folder")
        } catch {
            // If directory already exists, that's fine - we just wanted to ensure it exists
            // For other errors, check if the directory exists now
            if try await !drive.fileExists(at: folderPath) {
                // Directory still doesn't exist and we got an error - rethrow
                throw error
            }
            // Directory exists now (created by another process or already existed), continue
        }
    }
    
    private func refreshDocuments(type: DocumentType) async throws {
        let folderURL = drive.rootDirectory.appendingPathComponent(type.folderPath)
        
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            logger.warning("⚠️ \(type.displayName) folder doesn't exist yet")
            if type == .invoice {
                invoices = []
            } else {
                bankStatements = []
            }
            return
        }
        
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        let documents = fileURLs.compactMap { url -> DocumentFile? in
            guard !url.hasDirectoryPath else { return nil }
            
            let attributes: [FileAttributeKey: Any]?
            do {
                attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            } catch {
                logger.warning("⚠️ Failed to get attributes for \(url.lastPathComponent): \(error.localizedDescription)")
                attributes = nil
            }
            
            let modificationDate = attributes?[.modificationDate] as? Date
            let fileSize = attributes?[.size] as? Int64
            
            if modificationDate == nil {
                logger.warning("⚠️ Could not get modification date for \(url.lastPathComponent)")
            }
            if fileSize == nil {
                logger.warning("⚠️ Could not get file size for \(url.lastPathComponent)")
            }
            
            return DocumentFile(
                filename: url.lastPathComponent,
                modificationDate: modificationDate ?? Date(),
                fileSize: fileSize ?? 0,
                type: type
            )
        }
        .sorted { $0.modificationDate > $1.modificationDate }
        
        if type == .invoice {
            invoices = documents
        } else {
            bankStatements = documents
        }
        
        logger.info("📋 Loaded \(documents.count) \(type.displayName)s")
    }
    
    private func generateUniqueFilename(original: String) -> String {
        let fileExtension = (original as NSString).pathExtension
        let baseName = (original as NSString).deletingPathExtension
        
        // Add timestamp in milliseconds to make it unique
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let uniqueName = "\(baseName)_\(timestamp)"
        
        if fileExtension.isEmpty {
            return uniqueName
        } else {
            return "\(uniqueName).\(fileExtension)"
        }
    }
    
    private func validateInvoiceFileType(url: URL) throws {
        // Get the UTType for the file
        guard let fileType = UTType(filenameExtension: url.pathExtension) else {
            throw DocumentManagerError.unsupportedFileType(extension: url.pathExtension)
        }
        
        // Check if the file type conforms to any of the allowed types
        let isAllowed = Self.invoiceContentTypes.contains { allowedType in
            fileType.conforms(to: allowedType)
        }
        
        guard isAllowed else {
            throw DocumentManagerError.unsupportedFileType(extension: url.pathExtension)
        }
    }
}

// MARK: - Models

enum DocumentType {
    case invoice
    case bankStatement
    
    var folderPath: String {
        switch self {
        case .invoice: return "Invoices"
        case .bankStatement: return "BankStatements"
        }
    }
    
    var displayName: String {
        switch self {
        case .invoice: return "Invoice"
        case .bankStatement: return "Bank Statement"
        }
    }
}

struct DocumentFile: Identifiable {
    let id = UUID()
    let filename: String
    let modificationDate: Date
    let fileSize: Int64
    let type: DocumentType
    
    var displayName: String {
        (filename as NSString).deletingPathExtension
    }
    
    var fileExtension: String {
        (filename as NSString).pathExtension
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Errors

enum DocumentManagerError: LocalizedError {
    case unableToReadFile(description: String)
    case fileNotFoundAfterImport
    case fileAlreadyExists(filename: String)
    case unsupportedFileType(extension: String)
    
    var errorDescription: String? {
        switch self {
        case .unableToReadFile(let description):
            return "Unable to read the selected file: \(description)"
        case .fileNotFoundAfterImport:
            return "File was imported but could not be found afterward"
        case .fileAlreadyExists(let filename):
            return "A file named '\(filename)' already exists"
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext). Only PDF and image files are supported for invoices."
        }
    }
}

enum InitializationError: LocalizedError {
    case notSignedIntoiCloud
    case containerNotAvailable
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notSignedIntoiCloud:
            return "You are not signed into iCloud. Please sign in to use Acta."
        case .containerNotAvailable:
            return "iCloud Drive is not available. Please check your iCloud settings."
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }
}
