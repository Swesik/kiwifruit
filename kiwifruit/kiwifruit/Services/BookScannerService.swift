import Foundation
import Vision
import UIKit

protocol BookScannerServiceProtocol {
    func extractPayload(from image: UIImage) async throws -> BookScanPayload
}

final class VisionBookScannerService: BookScannerServiceProtocol {
    func extractPayload(from image: UIImage) async throws -> BookScanPayload {
        guard let cgImage = image.cgImage else {
            throw URLError(.cannotDecodeContentData)
        }

        if let barcode = try await detectEAN13(in: cgImage) {
            return .barcode(barcode)
        }

        let recognizedText = try await recognizeText(in: cgImage)
        let cleanedText = cleanOCRText(recognizedText)

        if cleanedText.isEmpty {
            throw URLError(.cannotParseResponse)
        }

        return .ocrText(cleanedText)
    }

    func extractPayloadFromTitleCrop(from image: UIImage) async throws -> BookScanPayload {
        guard let cgImage = image.cgImage else {
            throw URLError(.cannotDecodeContentData)
        }

        let croppedImage = cropToLikelyTitleRegion(in: cgImage)
        let recognizedText = try await recognizeText(in: croppedImage)
        let cleanedText = cleanOCRText(recognizedText)

        if cleanedText.isEmpty {
            throw URLError(.cannotParseResponse)
        }

        return .ocrText(cleanedText)
    }

    private func detectEAN13(in cgImage: CGImage) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNBarcodeObservation] ?? []
                let barcode = observations.first {
                    $0.symbology == .ean13 && $0.payloadStringValue != nil
                }?.payloadStringValue

                continuation.resume(returning: barcode)
            }

            request.symbologies = [.ean13]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func cropToLikelyTitleRegion(in cgImage: CGImage) -> CGImage {
        let width = cgImage.width
        let height = cgImage.height

        let cropWidth = Int(Double(width) * 0.9)
        let cropHeight = Int(Double(height) * 0.28)
        let originX = max((width - cropWidth) / 2, 0)
        let originY = max(Int(Double(height) * 0.12), 0)

        let rect = CGRect(
            x: originX,
            y: originY,
            width: min(cropWidth, width - originX),
            height: min(cropHeight, height - originY)
        )

        return cgImage.cropping(to: rect) ?? cgImage
    }

    private func cleanOCRText(_ text: String) -> String {
        text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .joined(separator: "\n")
    }
}
