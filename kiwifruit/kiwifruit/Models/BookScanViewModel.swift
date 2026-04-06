import Foundation
import Observation
import UIKit

@Observable
final class BookScanViewModel {
    var isShowingCamera: Bool = false
    var isProcessing: Bool = false
    var statusMessage: String?
    var errorMessage: String?
    var showBarcodeRetry: Bool = false

    private let scannerService: BookScannerServiceProtocol
    private let api: APIClientProtocol
    private let queryBuilder: OCRBookQueryBuilding

    init(
        scannerService: BookScannerServiceProtocol,
        api: APIClientProtocol,
        queryBuilder: OCRBookQueryBuilding = OCRBookQueryBuilder()
    ) {
        self.scannerService = scannerService
        self.api = api
        self.queryBuilder = queryBuilder
    }

    func startCamera() {
        errorMessage = nil
        statusMessage = nil
        showBarcodeRetry = false
        isShowingCamera = true
    }

    func retryWithBarcode() {
        errorMessage = nil
        statusMessage = nil
        showBarcodeRetry = false
        isShowingCamera = true
    }

    func processCapturedImage(_ image: UIImage) async -> String? {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        do {
            let payload = try await scannerService.extractPayload(from: image)

            switch payload {
            case .barcode(let barcode):
                showBarcodeRetry = false
                return try await handleBarcode(barcode)

            case .ocrText(let text):
                showBarcodeRetry = true
                return try await handleOCRText(text)
            }
        } catch {
            errorMessage = "Unable to scan book information."
            showBarcodeRetry = false
            return nil
        }
    }

    private func handleBarcode(_ barcode: String) async throws -> String? {
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedBarcode.isEmpty else {
            errorMessage = "Scanned barcode was empty."
            return nil
        }

        try await api.sendBookScan(barcode: cleanedBarcode, ocrText: nil)
        statusMessage = "Captured barcode"
        return cleanedBarcode
    }

    private func handleOCRText(_ text: String) async throws -> String? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            errorMessage = "No readable text was found."
            return nil
        }

        try await api.sendBookScan(barcode: nil, ocrText: cleanedText)

        let query = queryBuilder.makeSearchQuery(from: cleanedText)
        guard !query.isEmpty else {
            errorMessage = "Could not identify a book title from the scanned text."
            return nil
        }

        statusMessage = "Captured OCR text"
        return query
    }
}
