import Foundation
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "xyz.no-comment.Acta", category: "OCRManager")

@MainActor
final class OCRManager {

    /// Processes a document file using OCR to extract invoice data
    /// - Parameter document: The document file to process
    /// - Returns: An Invoice object with extracted data
    /// - Throws: OCRError if the file type is not supported or processing fails
    func processInvoice(from document: DocumentFile) async throws -> Invoice {
        // Validate that the document is an allowed invoice type
        try validateDocumentType(document)

        logger.info("🔍 Processing invoice: \(document.filename)")

        // TODO: Replace with actual OCR API call
        let invoice = createMockInvoice(for: document)

        logger.info("✅ Invoice processed successfully: \(document.filename)")

        return invoice
    }

    // MARK: - Private Helpers

    private func validateDocumentType(_ document: DocumentFile) throws {
        // Only process invoice documents
        guard document.type == .invoice else {
            throw OCRError.unsupportedDocumentType(
                message: "Only invoice documents can be processed. Received: \(document.type.displayName)"
            )
        }

        // Check if file extension is in allowed types
        guard let fileType = UTType(filenameExtension: document.fileExtension) else {
            throw OCRError.unsupportedFileType(extension: document.fileExtension)
        }

        // Verify the file type conforms to one of the allowed invoice content types
        let isAllowed = DocumentManager.invoiceContentTypes.contains { allowedType in
            fileType.conforms(to: allowedType)
        }

        guard isAllowed else {
            throw OCRError.unsupportedFileType(extension: document.fileExtension)
        }
    }

    private func createMockInvoice(for document: DocumentFile) -> Invoice {
        // Generate mock invoice data based on the document
        let mockVendors = ["Acme Corporation", "Global Supplies Inc.", "TechVendor GmbH", "Office Essentials Ltd."]
        let mockCurrencies = ["USD", "EUR", "GBP"]

        // Use filename hash to seed random generation for consistency
        let seed = document.filename.hashValue
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(seed)))

        let vendorName = mockVendors.randomElement(using: &generator)
        let currency = mockCurrencies.randomElement(using: &generator) ?? "USD"
        let preTaxAmount = Double.random(in: 100...5000, using: &generator).rounded(toPlaces: 2)
        let taxPercentage = [0.07, 0.19, 0.20, 0.25].randomElement(using: &generator) ?? 0.19
        let totalAmount = (preTaxAmount * (1 + taxPercentage)).rounded(toPlaces: 2)

        let invoice = Invoice(
            path: document.filename,
            tags: [],
            status: .processed,
            vendorName: vendorName,
            date: document.modificationDate,
            invoiceNo: "INV-\(String(format: "%06d", Int.random(in: 1...999999, using: &generator)))",
            totalAmount: totalAmount,
            preTaxAmount: preTaxAmount,
            taxPercentage: taxPercentage,
            currency: currency,
            direction: .outgoing
        )

        return invoice
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case unsupportedDocumentType(message: String)
    case unsupportedFileType(extension: String)
    case processingFailed(description: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentType(let message):
            return message
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext). Only PDF and image files are supported for OCR processing."
        case .processingFailed(let description):
            return "OCR processing failed: \(description)"
        }
    }
}

// MARK: - Helpers

/// A seeded random number generator for consistent mock data generation
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
