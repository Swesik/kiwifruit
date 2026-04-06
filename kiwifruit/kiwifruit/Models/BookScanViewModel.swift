import Foundation
import Observation
import UIKit

enum BookScanRetryState {
    case none
    case suggestCrop
    case suggestBarcode
}

@Observable
final class BookScanViewModel {
    var isShowingCamera: Bool = false
    var isProcessing: Bool = false
    var statusMessage: String?
    var errorMessage: String?

    var retryState: BookScanRetryState = .none
    var shouldCropTitleOnNextCapture: Bool = false

    private let scannerService: BookScannerServiceProtocol
    private let api: APIClientProtocol
    private let queryBuilder: OCRBookQueryBuilding
    private let croppedTitleQueryBuilder: CroppedTitleQueryBuilding

    init(
        scannerService: BookScannerServiceProtocol,
        api: APIClientProtocol,
        queryBuilder: OCRBookQueryBuilding = OCRBookQueryBuilder(),
        croppedTitleQueryBuilder: CroppedTitleQueryBuilding = CroppedTitleQueryBuilder()
    ) {
        self.scannerService = scannerService
        self.api = api
        self.queryBuilder = queryBuilder
        self.croppedTitleQueryBuilder = croppedTitleQueryBuilder
    }

    func startCamera() {
        resetMessages()
        retryState = .none
        shouldCropTitleOnNextCapture = false
        isShowingCamera = true
    }

    func retryWithCropTitle() {
        resetMessages()
        shouldCropTitleOnNextCapture = true
        isShowingCamera = true
    }

    func retryWithBarcode() {
        resetMessages()
        retryState = .none
        shouldCropTitleOnNextCapture = false
        isShowingCamera = true
    }

    func clearRetryStateForManualSearch() {
        retryState = .none
        shouldCropTitleOnNextCapture = false
    }

    func processCapturedImage(_ image: UIImage) async -> String? {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        do {
            let wasCropRetry = shouldCropTitleOnNextCapture
            let payload = try await scannerService.extractPayload(from: image)

            switch payload {
            case .barcode(let barcode):
                retryState = .none
                shouldCropTitleOnNextCapture = false
                return try await handleBarcode(barcode)

            case .ocrText(let text):
                retryState = wasCropRetry ? .suggestBarcode : .suggestCrop
                shouldCropTitleOnNextCapture = false
                return try await handleOCRText(text, isCroppedTitleScan: wasCropRetry)
            }
        } catch {
            errorMessage = "Unable to scan book information."
            shouldCropTitleOnNextCapture = false
            retryState = .none
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

    private func handleOCRText(_ text: String, isCroppedTitleScan: Bool) async throws -> String? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            errorMessage = "No readable text was found."
            return nil
        }

        try await api.sendBookScan(barcode: nil, ocrText: cleanedText)

        let query: String
        if isCroppedTitleScan {
            query = croppedTitleQueryBuilder.makeTitleQuery(from: cleanedText)
        } else {
            query = queryBuilder.makeSearchQuery(from: cleanedText)
        }

        guard !query.isEmpty else {
            errorMessage = "Could not identify a book title from the scanned text."
            return nil
        }

        statusMessage = "Captured OCR text"
        return query
    }

    private func resetMessages() {
        errorMessage = nil
        statusMessage = nil
    }
}
