//
//  OCRNoiseFilter.swift
//  kiwifruit
//
//  Created by Savannah Brown on 4/21/26.
//

import Foundation

struct OCRNoiseFilter {
    static let noiseTerms = [
        "bestseller",
        "new york times",
        "the #i",
        "the #1",
        "book club",
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
        "read with jenna",
        "#readwithjenna",
        "book club favorites",
        "readers's guide",
        "good morning america",
        "a gma book club pick",
        "now a major motion picture"
    ]

    static func removeNoise(
        from lines: [String],
        collapseWhitespace: (String) -> String
    ) -> [String] {
        lines
            .map { line in
                var cleanedLine = line

                for term in noiseTerms {
                    cleanedLine = removeCaseInsensitiveOccurrences(of: term, from: cleanedLine)
                }

                return collapseWhitespace(cleanedLine)
            }
            .filter { !$0.isEmpty }
    }

    private static func removeCaseInsensitiveOccurrences(of term: String, from text: String) -> String {
        var result = text

        while let range = result.range(of: term, options: .caseInsensitive) {
            result.removeSubrange(range)
        }

        return result
    }
}
