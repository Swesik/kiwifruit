//
//  CroppedTitleQueryBuilder.swift
//  kiwifruit
//
//  Created by Savannah Brown on 4/6/26.
//
import Foundation

protocol CroppedTitleQueryBuilding {
    func makeTitleQuery(from ocrText: String) -> String
}

struct CroppedTitleQueryBuilder: CroppedTitleQueryBuilding {
    func makeTitleQuery(from ocrText: String) -> String {
        let lines = normalizedLines(from: ocrText)
        guard !lines.isEmpty else {
            return collapsedWhitespace(ocrText)
        }

        let cleanedLines = removeNoise(from: lines)
        let candidateLines = cleanedLines.isEmpty ? lines : cleanedLines

        let title = candidateLines
            .prefix(3)
            .joined(separator: " ")

        return truncate(collapsedWhitespace(title), maxLength: 120)
    }

    private func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { collapsedWhitespace($0) }
            .filter { !$0.isEmpty }
    }

    private func removeNoise(from lines: [String]) -> [String] {
        OCRNoiseFilter.removeNoise(from: lines, collapseWhitespace: collapsedWhitespace)
    }

    private func collapsedWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"["“”‘’]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
