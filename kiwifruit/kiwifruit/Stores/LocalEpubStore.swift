import Foundation

/// Persists imported EPUB files in the app's Documents directory and their display
/// metadata in UserDefaults. Files remain available after the app is relaunched.
final class LocalEpubStore {
    static let shared = LocalEpubStore()

    private let metadataKey = "kiwifruit.localEpubs.v1"
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func books() -> [EpubUploadResponse] {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let saved = try? JSONDecoder().decode([EpubUploadResponse].self, from: data) else {
            return []
        }
        return saved.filter { book in
            guard let url = fileURL(for: book.id) else { return false }
            return fileManager.fileExists(atPath: url.path)
        }
    }

    func importBook(data: Data, filename: String) async throws -> EpubUploadResponse {
        let id = UUID().uuidString
        let directory = try booksDirectory()
        let epubURL = directory.appendingPathComponent("\(id).epub")
        try data.write(to: epubURL, options: .atomic)
        let parsed: ParsedEPUB
        do {
            parsed = try await LocalEPUBParser.parse(
                at: epubURL,
                fallbackTitle: URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            )
        } catch {
            try? fileManager.removeItem(at: epubURL)
            throw error
        }

        let book = EpubUploadResponse(
            id: id,
            title: parsed.title,
            author: parsed.author,
            status: "PARSED",
            originalFilename: filename,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        var saved = books()
        saved.insert(book, at: 0)
        do {
            try JSONEncoder().encode(parsed.chapters).write(
                to: directory.appendingPathComponent("\(id).chapters.json"),
                options: .atomic
            )
            UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: metadataKey)
        } catch {
            try? fileManager.removeItem(at: epubURL)
            try? fileManager.removeItem(at: directory.appendingPathComponent("\(id).chapters.json"))
            throw error
        }
        return book
    }

    func chapters(for bookID: String) -> [EpubChapter] {
        guard let url = try? booksDirectory().appendingPathComponent("\(bookID).chapters.json"),
              let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([ParsedEPUB.Chapter].self, from: data) else {
            return []
        }
        return saved.map { EpubChapter(id: $0.id, chapterNumber: $0.chapterNumber, title: $0.title) }
    }

    func chapterText(for bookID: String, chapterNumber: Int) -> String? {
        guard let url = try? booksDirectory().appendingPathComponent("\(bookID).chapters.json"),
              let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([ParsedEPUB.Chapter].self, from: data) else {
            return nil
        }
        return saved.first { $0.chapterNumber == chapterNumber }?.text
    }

    func progress(for bookID: String) -> SpeedReadingProgress {
        let key = "kiwifruit.localEpubs.progress.\(bookID)"
        let progress = UserDefaults.standard.dictionary(forKey: key)
        return SpeedReadingProgress(
            chapterNumber: progress?["chapter"] as? Int ?? 1,
            wordIndex: progress?["wordIndex"] as? Int ?? 0
        )
    }

    func saveProgress(for bookID: String, chapterNumber: Int, wordIndex: Int) {
        UserDefaults.standard.set(
            ["chapter": chapterNumber, "wordIndex": wordIndex],
            forKey: "kiwifruit.localEpubs.progress.\(bookID)"
        )
    }

    private func fileURL(for id: String) -> URL? {
        try? booksDirectory().appendingPathComponent("\(id).epub")
    }

    private func booksDirectory() throws -> URL {
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = documents.appendingPathComponent("ImportedBooks", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
