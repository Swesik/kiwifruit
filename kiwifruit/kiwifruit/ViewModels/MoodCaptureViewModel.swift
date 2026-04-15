import Foundation
import Observation

/// Owns the async work the MoodCaptureSheet used to do inline — fetching the
/// mood-aware reflection prompt and persisting the reflection — so the View
/// stays UI-only per AI rules.
@Observable
final class MoodCaptureViewModel {
    var reflectionPrompt: String = ""
    var isLoadingPrompt = false
    var isSavingReflection = false

    private let api: APIClientProtocol

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    /// Loads a prompt tailored to the completed session. Falls back to a
    /// generic prompt if the server/AI round-trip fails.
    func loadPrompt(bookTitle: String?, durationSeconds: Int, pagesRead: Int?, mood: String?) async {
        guard !isLoadingPrompt else { return }
        isLoadingPrompt = true
        defer { isLoadingPrompt = false }

        do {
            let resp = try await api.fetchReflectionPrompt(
                bookTitle: bookTitle ?? "your book",
                durationMinutes: durationSeconds / 60,
                pagesRead: pagesRead,
                mood: mood
            )
            reflectionPrompt = resp.prompt
        } catch {
            reflectionPrompt = "What stood out to you during this reading session?"
        }
    }

    /// Persists the reflection; returns true iff it was written server-side.
    /// The View is responsible for dismissing on completion regardless.
    @discardableResult
    func saveReflection(
        bookTitle: String?,
        title: String,
        response: String,
        mood: String?,
        durationSeconds: Int
    ) async -> Bool {
        isSavingReflection = true
        defer { isSavingReflection = false }

        do {
            try await api.createReflection(
                bookTitle: bookTitle ?? "Unknown",
                title: title.isEmpty ? nil : title,
                prompt: reflectionPrompt,
                response: response,
                mood: mood,
                durationMinutes: durationSeconds / 60,
                visibility: "private"
            )
            return true
        } catch {
            print("[MoodCaptureViewModel] createReflection failed: \(error)")
            return false
        }
    }
}
