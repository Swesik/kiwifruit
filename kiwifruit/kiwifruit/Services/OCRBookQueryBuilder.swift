//
//  OCRBookQueryBuilder.swift
//  kiwifruit
//
//  Created by Savannah Brown on 4/5/26.
//
import Foundation

protocol OCRBookQueryBuilding {
    func makeSearchQuery(from ocrText: String) -> String
}

struct OCRBookQueryBuilder: OCRBookQueryBuilding {
    func makeSearchQuery(from ocrText: String) -> String {
        let lines = normalizedLines(from: ocrText)
        guard !lines.isEmpty else {
            return collapsedWhitespace(ocrText)
        }

        let filteredLines = filterNoise(lines)
        let candidateLines = filteredLines.isEmpty ? lines : filteredLines

        let title = detectTitle(from: candidateLines)
        let author = detectAuthor(from: candidateLines)

        let query = buildQuery(title: title, author: author, fallbackLines: candidateLines)
        return truncate(query, maxLength: 120)
    }

    private func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { line in
                let withoutQuoted = removeQuotedContent(from: line)
                let withoutAttribution = removeLeadingAttribution(from: withoutQuoted)
                let withoutWrappingQuotes = stripWrappingQuotes(from: withoutAttribution)
                return collapsedWhitespace(withoutWrappingQuotes)
            }
            .filter { !$0.isEmpty }
    }

    private func filterNoise(_ lines: [String]) -> [String] {
        let noiseTerms = [
            "bestseller",
            "new york times",
            "edition",
            "revised",
            "updated",
            "published by",
            "publisher",
            "isbn",
            "copyright",
            "translated by",
            "foreword by",
            "illustrated by",
            "a novel",
            "an novel",
            "now a major motion picture"
        ]

        return lines.filter { line in
            let lower = line.lowercased()
            return !noiseTerms.contains(where: { lower.contains($0) })
        }
    }

    private func detectTitle(from lines: [String]) -> String? {
        guard let first = lines.first else { return nil }

        if lines.count >= 2, shouldMergeIntoTitle(first: first, second: lines[1]) {
            return "\(first) \(lines[1])"
        }

        return first
    }

    private func detectAuthor(from lines: [String]) -> String? {
        for line in lines {
            if let author = extractAuthorFromByLine(line) {
                return author
            }
        }

        for line in lines.dropFirst().prefix(3) {
            if isPlausibleAuthorLine(line) {
                return line
            }
        }

        return nil
    }

    private func buildQuery(title: String?, author: String?, fallbackLines: [String]) -> String {
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanAuthor = author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !cleanTitle.isEmpty && !cleanAuthor.isEmpty {
            return "\(cleanTitle) \(cleanAuthor)"
        }

        if !cleanTitle.isEmpty {
            return cleanTitle
        }

        if !cleanAuthor.isEmpty {
            return cleanAuthor
        }

        return fallbackLines.prefix(2).joined(separator: " ")
    }

    private func shouldMergeIntoTitle(first: String, second: String) -> Bool {
        let firstCount = wordCount(in: first)
        let secondCount = wordCount(in: second)

        guard firstCount > 0, secondCount > 0 else { return false }
        guard firstCount <= 6, secondCount <= 6 else { return false }
        guard !isPlausibleAuthorLine(second) else { return false }

        return true
    }

    private func extractAuthorFromByLine(_ line: String) -> String? {
        let pattern = #"(?i)\bby\s+([A-Za-z][A-Za-z .'\-]{1,80})"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
            ),
            let captureRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }

        let author = String(line[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return author.isEmpty ? nil : author
    }

    private func isPlausibleAuthorLine(_ line: String) -> Bool {
        let words = line
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard words.count >= 2 && words.count <= 4 else { return false }

        let containsDigits = line.contains { $0.isNumber }
        if containsDigits { return false }

        let letterCharacterCount = line.filter(\.isLetter).count
        return letterCharacterCount >= 6
    }

    private func wordCount(in text: String) -> Int {
        text.split(separator: " ").count
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

    private func removeQuotedContent(from text: String) -> String {
        let patterns = [
            #""[^"]*""#,
            #"“[^”]*”"#,
            #"‘[^’]*’"#
        ]

        return patterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
    }

    private func removeLeadingAttribution(from text: String) -> String {
        text.replacingOccurrences(
            of: #"^[\s]*[-–—]\s*[A-Za-z][A-Za-z .'\-]{1,60}"#,
            with: "",
            options: .regularExpression
        )
    }

    private func stripWrappingQuotes(from text: String) -> String {
        var result = text
        let quoteSet = CharacterSet(charactersIn: "\"'“”‘’")

        while !result.isEmpty {
            let trimmed = result.trimmingCharacters(in: quoteSet)
            if trimmed == result { break }
            result = trimmed
        }

        return result
    }
}
