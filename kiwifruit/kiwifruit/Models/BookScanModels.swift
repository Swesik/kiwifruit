//
//  BookScanModel.swift
//  kiwifruit
//
//  Created by Savannah Brown on 3/15/26.
//
import Foundation

enum BookScanPayload: Codable, Hashable {
    case barcode(String)
    case ocrText(String)

    var barcodeValue: String? {
        switch self {
        case .barcode(let value): return value
        case .ocrText: return nil
        }
    }

    var ocrTextValue: String? {
        switch self {
        case .barcode: return nil
        case .ocrText(let value): return value
        }
    }
}

struct BookScanResponse: Codable, Hashable {
    let status: String
    let barcode: String?
    let ocrText: String?
}

