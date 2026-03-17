import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class BookScanViewModel {
    var isShowingCamera: Bool = false
    var isProcessing: Bool = false
    var statusMessage: String?
    var errorMessage: String?

    private let scannerService: BookScannerServiceProtocol
    private let api: APIClientProtocol

    init(scannerService: BookScannerServiceProtocol, api: APIClientProtocol) {
        self.scannerService = scannerService
        self.api = api
    }

    func startCamera() {
        errorMessage = nil
        statusMessage = nil
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
                try await api.sendBookScan(barcode: barcode, ocrText: nil)
                statusMessage = "Captured barcode"
                return barcode

            case .ocrText(let text):
                try await api.sendBookScan(barcode: nil, ocrText: text)
                statusMessage = "Captured OCR text"
                return text
            }
        } catch {
            errorMessage = "Unable to scan book information."
            return nil
        }
    }
}
