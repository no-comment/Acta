import CoreGraphics
import Foundation
import ImageIO
import Observation
import os
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "xyz.no-comment.Acta", category: "OCRManager")

@MainActor
@Observable
final class OCRManager {
    static let shared = OCRManager()

    private let baseApiKey: String
    private var inFlightTasks: [String: Task<OCRCompletion, Error>] = [:]
    private var inFlightOCRTasks: [String: Task<OCRResult, Error>] = [:]
    private(set) var processingDocuments: Set<String> = []

    init(apiKey: String? = nil) {
        self.baseApiKey = apiKey ?? ""
    }

    func isProcessing(document: DocumentFile) -> Bool {
        processingDocuments.contains(document.filename)
    }

    func cancelAllProcessing() {
        for task in inFlightTasks.values {
            task.cancel()
        }
        for task in inFlightOCRTasks.values {
            task.cancel()
        }
    }

    /// Processes a document file using OCR and applies updates to the invoice.
    /// - Parameters:
    ///   - document: The document file to process.
    ///   - invoice: The invoice to update.
    ///   - documentManager: DocumentManager for file renames.
    func processInvoice(document: DocumentFile, invoice: Invoice, documentManager: DocumentManager) async throws {
        let key = document.filename

        if let existingTask = inFlightTasks[key] {
            let completion = try await existingTask.value
            invoice.applyOCRResult(completion.result)
            invoice.path = completion.filename
            return
        }

        // Validate early on the main actor to avoid actor isolation issues.
        try validateDocumentType(document)
        let resolvedKey = APIKeyStore.loadOpenRouterKey() ?? baseApiKey
        guard !resolvedKey.isEmpty else {
            throw OCRError.missingAPIKey
        }

        let input = OCRInput(
            filename: document.filename,
            fileExtension: document.fileExtension,
            url: document.url
        )
        let userDisplayName = OCRManager.loadUserDisplayName()
        let apiKey = resolvedKey

        let task = Task {
            let ocrTask = Task.detached {
                try Task.checkCancellation()
                return try await OCRManager.performOCR(
                    input: input,
                    apiKey: apiKey,
                    userDisplayName: userDisplayName
                )
            }
            await MainActor.run {
                inFlightOCRTasks[key] = ocrTask
            }

            let result: OCRResult
            switch await ocrTask.result {
            case .success(let value):
                result = value
            case .failure(let error):
                throw error
            }

            let newBaseName = DocumentManager.generateInvoiceFilename(
                vendorName: result.vendorName,
                date: result.date
            )

            let newFilename = try await documentManager.renameDocument(
                from: document.filename,
                to: newBaseName,
                type: .invoice
            )
            await MainActor.run {
                invoice.path = newFilename
            }

            return OCRCompletion(result: result, filename: newFilename)
        }

        inFlightTasks[key] = task
        processingDocuments.insert(key)
        defer {
            inFlightTasks[key] = nil
            inFlightOCRTasks[key] = nil
            processingDocuments.remove(key)
        }

        logger.info("🔍 Processing invoice: \(document.filename)")
        let completion: OCRCompletion
        switch await task.result {
        case .success(let value):
            completion = value
        case .failure(let error):
            throw error
        }

        invoice.applyOCRResult(completion.result)
        logger.info("✅ Invoice processed successfully: \(document.filename)")
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
        let fileType = try Self.resolveFileType(fileExtension: document.fileExtension)

        // Verify the file type conforms to one of the allowed invoice content types
        let isAllowed = DocumentManager.invoiceContentTypes.contains { allowedType in
            fileType.conforms(to: allowedType)
        }

        guard isAllowed else {
            throw OCRError.unsupportedFileType(extension: document.fileExtension)
        }
    }

    /// Processes a document file using OCR to extract invoice data.
    /// - Parameter input: The OCR input payload.
    /// - Returns: An OCRResult with extracted data.
    /// - Throws: OCRError if the file type is not supported or processing fails.
    private nonisolated static func performOCR(
        input: OCRInput,
        apiKey: String,
        userDisplayName: String?
    ) async throws -> OCRResult {
        try Task.checkCancellation()
        let url = input.url
        let fileType = try resolveFileType(fileExtension: input.fileExtension)
        let base64PDF = try makeBase64PDF(from: url, fileType: fileType)

        try Task.checkCancellation()
        let responseData = try await performOCRRequest(
            base64PDF: base64PDF,
            apiKey: apiKey,
            userDisplayName: userDisplayName
        )
        let result = try parseOCRResult(from: responseData)

        return result
    }

    private nonisolated static func resolveFileType(fileExtension: String) throws -> UTType {
        guard let fileType = UTType(filenameExtension: fileExtension) else {
            throw OCRError.unsupportedFileType(extension: fileExtension)
        }
        return fileType
    }

    private nonisolated static func makeBase64PDF(from url: URL, fileType: UTType) throws -> String {
        if fileType.conforms(to: .pdf) {
            let data = try Data(contentsOf: url)
            return data.base64EncodedString()
        }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw OCRError.processingFailed(description: "Unable to load image for OCR")
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw OCRError.processingFailed(description: "Failed to create PDF consumer")
        }

        var rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &rect, nil) else {
            throw OCRError.processingFailed(description: "Failed to create PDF context")
        }

        pdfContext.beginPDFPage(nil)
        pdfContext.draw(cgImage, in: rect)
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return pdfData.base64EncodedString()
    }

    private nonisolated static func performOCRRequest(
        base64PDF: String,
        apiKey: String,
        userDisplayName: String?
    ) async throws -> Data {
        let userContext: String
        if let userDisplayName, !userDisplayName.isEmpty {
            userContext = """
            The user's name or company is "\(userDisplayName)".
            Use this to determine invoice direction:
            - incoming: invoice addressed to the user (buyer/recipient/payer).
            - outgoing: invoice issued by the user to someone else (seller/issuer).
            Return vendor as the counterparty name, not the user's own name.
            If direction cannot be determined, return null.
            """
        } else {
            userContext = ""
        }

        let prompt = """
        Extract invoice data from this document. Focus on the main vendor, the invoice identifier, totals,
        pre-tax amount, and tax percentage when available.
        \(userContext)
        If a field is not present, return null. Use ISO 8601 dates (YYYY-MM-DD).
        Return taxPercentage as a decimal fraction (e.g., 0.07 for 7%).
        For currency, prefer a symbol (e.g., $ or €) rather than a currency code.
        """

        let responseSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "vendor": ["type": ["string", "null"]],
                "invoiceNumber": ["type": ["string", "null"]],
                "date": ["type": ["string", "null"]],
                "totalAmount": ["type": ["number", "null"]],
                "preTaxAmount": ["type": ["number", "null"]],
                "taxPercentage": [
                    "type": ["number", "null"],
                    "minimum": 0,
                    "maximum": 1
                ],
                "currency": ["type": ["string", "null"]],
                "taxAmount": ["type": ["number", "null"]],
                "direction": [
                    "anyOf": [
                        [
                            "type": "string",
                            "enum": ["incoming", "outgoing"]
                        ],
                        [
                            "type": "null"
                        ]
                    ]
                ]
            ],
            "required": [
                "vendor",
                "invoiceNumber",
                "date",
                "totalAmount",
                "preTaxAmount",
                "taxPercentage",
                "currency",
                "taxAmount",
                "direction"
            ],
            "additionalProperties": false
        ]

        let requestBody: [String: Any] = [
            "model": "openai/gpt-5-mini",
            "plugins": [
                [
                    "id": "file-parser",
                    "pdf": [
                        "engine": "mistral-ocr"
                    ]
                ],
                [
                    "id": "response-healing"
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "invoice",
                    "strict": true,
                    "schema": responseSchema
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "file",
                            "file": [
                                "filename": "invoice.pdf",
                                "file_data": "data:application/pdf;base64,\(base64PDF)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OCRError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return data
    }

    private nonisolated static func parseOCRResult(from data: Data) throws -> OCRResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any]
        else {
            throw OCRError.invalidResponse
        }

        let parsed: [String: Any]
        if let content = message["content"] as? [String: Any] {
            parsed = content
        } else if let content = message["content"] as? String {
            guard let jsonData = content.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                throw OCRError.processingFailed(description: "Failed to parse OCR JSON")
            }
            parsed = object
        } else if let contentArray = message["content"] as? [[String: Any]] {
            let contentText = contentArray.compactMap { $0["text"] as? String }.joined(separator: "\n")
            guard let jsonData = contentText.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                throw OCRError.processingFailed(description: "Failed to parse OCR JSON")
            }
            parsed = object
        } else {
            throw OCRError.invalidResponse
        }

        let vendor = parsed["vendor"] as? String
        let invoiceNumber = parsed["invoiceNumber"] as? String
        let currency = (parsed["currency"] as? String)?.uppercased()
        let direction = (parsed["direction"] as? String).flatMap(Invoice.Direction.init(rawValue:))

        let date: Date? = {
            guard let dateString = parsed["date"] as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: dateString)
        }()

        let totalAmount = parseNumber(from: parsed["totalAmount"])
        let preTaxAmount = parseNumber(from: parsed["preTaxAmount"])
        let taxPercentage = parseNumber(from: parsed["taxPercentage"])

        return OCRResult(
            vendorName: vendor,
            date: date,
            invoiceNo: invoiceNumber,
            totalAmount: totalAmount,
            preTaxAmount: preTaxAmount,
            taxPercentage: taxPercentage,
            currency: currency,
            direction: direction
        )
    }

    private nonisolated static func parseNumber(from value: Any?) -> Double? {
        if let number = value as? Double {
            return number
        }
        if let number = value as? Int {
            return Double(number)
        }
        if let string = value as? String,
           let number = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return number
        }
        return nil
    }
}

extension OCRManager {
    static func loadUserDisplayName() -> String? {
        guard let value = UserDefaults.standard.string(forKey: SettingsKeys.userDisplayName) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - OCR Input

private struct OCRInput {
    let filename: String
    let fileExtension: String
    let url: URL
}

private struct OCRCompletion {
    let result: OCRResult
    let filename: String
}

// MARK: - OCR Result

struct OCRResult {
    let vendorName: String?
    let date: Date?
    let invoiceNo: String?
    let totalAmount: Double?
    let preTaxAmount: Double?
    let taxPercentage: Double?
    let currency: String?
    let direction: Invoice.Direction?
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case missingAPIKey
    case unsupportedDocumentType(message: String)
    case unsupportedFileType(extension: String)
    case processingFailed(description: String)
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenRouter API key not configured. Set OPENROUTER_API_KEY to enable OCR."
        case .unsupportedDocumentType(let message):
            return message
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext). Only PDF and image files are supported for OCR processing."
        case .processingFailed(let description):
            return "OCR processing failed: \(description)"
        case .invalidResponse:
            return "Invalid response from OCR service."
        case .apiError(let statusCode, let message):
            return "OCR service error (\(statusCode)): \(message)"
        }
    }
}
