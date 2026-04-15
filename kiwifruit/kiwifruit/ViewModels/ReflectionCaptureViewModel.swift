import Foundation
import Observation

/// Owns the async work previously inline in ReflectionCaptureSheet: fetching
/// the reflection prompt and persisting the user's reflection. Keeps the
/// View UI-only per AI rules.
@Observable
final class ReflectionCaptureViewModel {
    var reflectionPrompt: String = ""
    var isLoadingPrompt = false
    var isSavingReflection = false

    private let api: APIClientProtocol

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    func loadPrompt(bookTitle: String?, durationSeconds: Int?, pagesRead: Int?) async {
        guard !isLoadingPrompt else { return }
        isLoadingPrompt = true
        defer { isLoadingPrompt = false }

        do {
            let resp = try await api.fetchReflectionPrompt(
                bookTitle: bookTitle ?? "your book",
                durationMinutes: max(1, (durationSeconds ?? 0) / 60),
                pagesRead: pagesRead,
                mood: nil
            )
            reflectionPrompt = resp.prompt
        } catch {
            reflectionPrompt = "What stood out to you during this reading session?"
        }
    }

    /// Saves a non-mood reflection. Returns true iff the server wrote it.
    @discardableResult
    func saveReflection(
        bookTitle: String?,
        title: String,
        response: String,
        durationSeconds: Int?
    ) async -> Bool {
        isSavingReflection = true
        defer { isSavingReflection = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await api.createReflection(
                bookTitle: bookTitle ?? "Unknown",
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                prompt: reflectionPrompt,
                response: response,
                mood: nil,
                durationMinutes: (durationSeconds ?? 0) / 60,
                visibility: "private"
            )
            return true
        } catch {
            print("[ReflectionCaptureViewModel] createReflection failed: \(error)")
            return false
        }
    }
}
