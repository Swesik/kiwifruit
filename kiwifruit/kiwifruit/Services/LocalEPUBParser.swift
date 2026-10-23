import Foundation
import ReadiumShared
import ReadiumStreamer

struct ParsedEPUB {
    struct Chapter: Codable, Identifiable {
        let chapterNumber: Int
        let title: String
        let text: String

        var id: String { String(chapterNumber) }
    }

    let title: String
    let author: String
    let chapters: [Chapter]
}

enum LocalEPUBParser {
    static func parse(at url: URL, fallbackTitle: String) async throws -> ParsedEPUB {
        guard let fileURL = FileURL(url: url) else {
            throw ParserError.invalidFileURL
        }

        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)
        let opener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            )
        )

        let asset = try await assetRetriever.retrieve(url: fileURL).get()
        let publication = try await opener.open(asset: asset, allowUserInteraction: false).get()
        defer { publication.close() }

        guard publication.conforms(to: .epub) else {
            throw ParserError.notAnEPUB
        }
        guard let content = publication.content() else {
            throw ParserError.noReadableContent
        }

        let elements = await content.elements()
        var textByHref: [String: [String]] = [:]
        var headingByHref: [String: String] = [:]

        for element in elements {
            guard let text = (element as? TextualContentElement)?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty else { continue }

            let href = element.locator.href.string
            textByHref[href, default: []].append(text)
            if let textElement = element as? TextContentElement,
               case .heading = textElement.role,
               headingByHref[href] == nil {
                headingByHref[href] = text
            }
        }

        var chapters: [ParsedEPUB.Chapter] = []
        for link in publication.readingOrder {
            let key = normalizedHref(link.href)
            let matchingHref = textByHref.keys.first { normalizedHref($0) == key }
            guard let matchingHref,
                  let textParts = textByHref[matchingHref],
                  !textParts.isEmpty else { continue }

            let number = chapters.count + 1
            let title = headingByHref[matchingHref] ?? link.title ?? "Chapter \(number)"
            chapters.append(ParsedEPUB.Chapter(
                chapterNumber: number,
                title: title,
                text: textParts.joined(separator: "\n")
            ))
        }

        guard !chapters.isEmpty else { throw ParserError.noReadableContent }
        return ParsedEPUB(
            title: publication.metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? fallbackTitle,
            author: publication.metadata.authors.map(\.name).joined(separator: ", ").nilIfEmpty ?? "Unknown author",
            chapters: chapters
        )
    }

    private static func normalizedHref(_ href: String) -> String {
        String(href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            .removingPercentEncoding ?? href
    }

    private enum ParserError: Error {
        case invalidFileURL
        case notAnEPUB
        case noReadableContent
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
