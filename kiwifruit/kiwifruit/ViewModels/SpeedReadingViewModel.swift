import Foundation
import Observation

@MainActor
@Observable
final class SpeedReadingViewModel {
    var isUploading = false
    var uploadMessage: String?

    // Book list
    var books: [EpubUploadResponse] = []
    var isLoadingBooks = false
    var selectedBook: EpubUploadResponse?

    // Chapter list
    var chapters: [EpubChapter] = []
    var showChapterPicker = false

    // Reading state
    var words: [String] = []
    var currentWordIndex: Int = 0
    var currentChapter: Int = 1
    var isPlaying = false
    var isLoadingChapter = false
    var isFinished = false

    // Configurable settings (future: expose in UI)
    var wordsPerFlash: Int = 1
    var wordsPerSecond: Double = 4.0

    private var timer: Timer?
    private var progressSaveTimer: Timer?
    private var lastSavedChapter: Int = 0
    private var lastSavedWordIndex: Int = 0

    var currentWord: String {
        guard currentWordIndex < words.count else { return "" }
        return words[currentWordIndex]
    }

    var currentChapterTitle: String? {
        chapters.first { $0.chapterNumber == currentChapter }?.title
    }

    func loadBooks() {
        guard !isLoadingBooks else { return }
        isLoadingBooks = true
        Task {
            do {
                let allBooks = try await AppAPI.shared.fetchEpubs()
                books = allBooks.filter { $0.status == "PARSED" }
            } catch {
                books = []
            }
            isLoadingBooks = false
        }
    }

    func selectBook(_ book: EpubUploadResponse) {
        stopPlayback()
        selectedBook = book
        isFinished = false
        chapters = []
        Task {
            // Fetch chapters list and progress in parallel
            async let chaptersResult = AppAPI.shared.fetchChapters(epubId: book.id)
            async let progressResult = AppAPI.shared.getSpeedReadingProgress(epubId: book.id)

            do {
                chapters = try await chaptersResult
            } catch {
                chapters = []
            }

            do {
                let progress = try await progressResult
                currentChapter = progress.chapterNumber
                currentWordIndex = progress.wordIndex
            } catch {
                currentChapter = 1
                currentWordIndex = 0
            }

            lastSavedChapter = currentChapter
            lastSavedWordIndex = currentWordIndex
            await loadChapterText()
        }
    }

    func jumpToChapter(_ chapterNumber: Int) {
        stopPlayback()
        saveProgressSync()
        currentChapter = chapterNumber
        currentWordIndex = 0
        isFinished = false
        Task {
            await loadChapterText()
        }
    }

    func deselectBook() {
        stopPlayback()
        saveProgressSync()
        selectedBook = nil
        words = []
        chapters = []
        currentWordIndex = 0
        currentChapter = 1
        isFinished = false
    }

    private func loadChapterText() async {
        guard let book = selectedBook else { return }
        isLoadingChapter = true
        do {
            let text = try await AppAPI.shared.fetchChapterText(epubId: book.id, chapterNumber: currentChapter)
            words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if currentWordIndex >= words.count {
                currentWordIndex = 0
            }
        } catch {
            words = []
        }
        isLoadingChapter = false
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard !words.isEmpty else { return }
        isPlaying = true
        let interval = 1.0 / wordsPerSecond
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceWord()
            }
        }
        startProgressSaveTimer()
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        progressSaveTimer?.invalidate()
        progressSaveTimer = nil
        saveProgressSync()
    }

    func finish() {
        stopPlayback()
        saveProgressSync()
        isFinished = true
    }

    private func stopPlayback() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        progressSaveTimer?.invalidate()
        progressSaveTimer = nil
    }

    private func advanceWord() {
        let step = wordsPerFlash
        if currentWordIndex + step < words.count {
            currentWordIndex += step
        } else {
            advanceChapter()
        }
    }

    private func advanceChapter() {
        stopPlayback()
        currentChapter += 1
        currentWordIndex = 0
        Task {
            await loadChapterText()
            if words.isEmpty {
                isFinished = true
                saveProgressSync()
            } else {
                play()
            }
        }
    }

    private func startProgressSaveTimer() {
        progressSaveTimer?.invalidate()
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveProgressSync()
            }
        }
    }

    /// Synchronously sends the progress update (fire-and-forget Task that captures values).
    /// Always sends regardless of whether values match lastSaved, ensuring the server is up to date.
    private func saveProgressSync() {
        guard let book = selectedBook else { return }
        let chapter = currentChapter
        let wordIdx = currentWordIndex
        guard chapter != lastSavedChapter || wordIdx != lastSavedWordIndex else { return }
        lastSavedChapter = chapter
        lastSavedWordIndex = wordIdx
        let epubId = book.id
        Task.detached {
            try? await AppAPI.shared.updateSpeedReadingProgress(
                epubId: epubId, chapter: chapter, wordIndex: wordIdx
            )
        }
    }

    func uploadEpub(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            uploadMessage = "Unable to access file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let fileData = try? Data(contentsOf: url) else {
            uploadMessage = "Unable to read file."
            return
        }

        let filename = url.lastPathComponent
        isUploading = true
        uploadMessage = nil
        Task {
            do {
                let response = try await AppAPI.shared.uploadEpub(fileData: fileData, filename: filename)
                isUploading = false
                uploadMessage = "Uploaded \"\(response.title)\" by \(response.author). Processing..."
                // Poll until parsed
                await pollUntilParsed(epubId: response.id)
            } catch {
                isUploading = false
                uploadMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }

    private func pollUntilParsed(epubId: String) async {
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            do {
                let detail = try await AppAPI.shared.fetchEpubDetail(epubId: epubId)
                if detail.status == "PARSED" {
                    uploadMessage = "Uploaded \"\(detail.title)\" by \(detail.author)"
                    loadBooks()
                    return
                } else if detail.status == "FAILED" {
                    uploadMessage = "Processing failed for uploaded book."
                    return
                }
            } catch {
                continue
            }
        }
        uploadMessage = "Book is still processing. Refresh later."
        loadBooks()
    }
}
