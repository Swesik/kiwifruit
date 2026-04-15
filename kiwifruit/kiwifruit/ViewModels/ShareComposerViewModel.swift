import Foundation
import Observation

/// Owns every piece of async/business work previously inline in
/// ShareComposerSheet — prompt generation, past-session/reflection lookup,
/// submit. The View stays UI-only per AI rules and binds into this model.
@Observable
final class ShareComposerViewModel {
    enum ShareType: String, CaseIterable, Identifiable {
        case bookRec = "Book rec"
        case reflection = "Reflection"
        case question = "Question"
        var id: String { rawValue }
    }

    enum ReflectionMode: String, CaseIterable, Identifiable {
        case new = "New"
        case past = "Past"
        var id: String { rawValue }
    }

    enum ReflectionVisibility: String, CaseIterable, Identifiable {
        case `private` = "Private"
        case friendsOnly = "Friends"
        case `public` = "Public"
        var id: String { rawValue }

        var apiValue: String {
            switch self {
            case .private: return "private"
            case .friendsOnly: return "friends_only"
            case .public: return "public"
            }
        }

        var icon: String {
            switch self {
            case .private: return "lock.fill"
            case .friendsOnly: return "person.2.fill"
            case .public: return "globe"
            }
        }
    }

    /// Result of a submit attempt, so the View can update its posts store /
    /// dismiss without holding any networking knowledge.
    enum SubmitOutcome {
        case success(Post)
        case reflectionOnly
        case failure
        case notAuthenticated
    }

    // MARK: - User-editable fields

    var shareType: ShareType = .bookRec
    var reflectionMode: ReflectionMode = .new

    var bookTitle: String = ""
    var bookRecText: String = ""
    var questionText: String = ""

    var reflectionTitle: String = ""
    var reflectionText: String = ""
    var reflectionVisibility: ReflectionVisibility = .friendsOnly

    // MARK: - Server-derived state

    var reflectionPrompt: String = ""
    var pastReflections: [Reflection] = []
    var selectedPastReflectionId: String? = nil

    var pastSessions: [SessionHistoryEntry] = []
    var attachedSession: SessionHistoryEntry? = nil

    var isLoadingPrompt = false
    var isLoadingPastReflections = false
    var isLoadingPastSessions = false
    var isSubmitting = false

    private let api: APIClientProtocol

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    // MARK: - Derived

    var selectedPastReflection: Reflection? {
        guard let id = selectedPastReflectionId else { return nil }
        return pastReflections.first(where: { $0.id == id })
    }

    func canSubmit(userId: String?) -> Bool {
        guard userId != nil else { return false }
        switch shareType {
        case .bookRec:
            return !bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .question:
            return !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reflection:
            if reflectionMode == .past {
                return selectedPastReflectionId != nil
            }
            return !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !isLoadingPrompt
        }
    }

    // MARK: - Attach / detach a session

    func attach(_ s: SessionHistoryEntry) async {
        attachedSession = s
        bookTitle = s.bookTitle
        reflectionPrompt = ""
        await loadPromptIfNeeded()
    }

    func detachSession() async {
        attachedSession = nil
        reflectionPrompt = ""
        await loadPromptIfNeeded()
    }

    // MARK: - Prompt

    func loadPromptIfNeeded() async {
        if isLoadingPrompt { return }
        if !reflectionPrompt.isEmpty { return }

        let bookForPrompt: String = {
            if let s = attachedSession { return s.bookTitle }
            let trimmed = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "your book" : trimmed
        }()
        let durationForPrompt = attachedSession.map { max(1, $0.durationSeconds / 60) } ?? 0
        let pagesForPrompt = attachedSession?.pagesRead
        let moodForPrompt = attachedSession?.mood

        isLoadingPrompt = true
        defer { isLoadingPrompt = false }

        do {
            let resp = try await api.fetchReflectionPrompt(
                bookTitle: bookForPrompt,
                durationMinutes: durationForPrompt,
                pagesRead: pagesForPrompt,
                mood: moodForPrompt
            )
            reflectionPrompt = resp.prompt
        } catch {
            reflectionPrompt = "What stood out to you during this reading session?"
        }
    }

    func loadPastReflectionsIfNeeded(currentUsername: String?) async {
        if isLoadingPastReflections { return }
        if !pastReflections.isEmpty { return }

        isLoadingPastReflections = true
        defer { isLoadingPastReflections = false }

        do {
            let all = try await api.fetchReflections()
            pastReflections = all.filter { $0.username == currentUsername }
        } catch {
            pastReflections = []
        }
    }

    func loadPastSessionsIfNeeded() async {
        if isLoadingPastSessions { return }
        if !pastSessions.isEmpty { return }

        isLoadingPastSessions = true
        defer { isLoadingPastSessions = false }

        do {
            pastSessions = try await api.fetchSessionHistory()
        } catch {
            pastSessions = []
        }
    }

    // MARK: - Submit

    func submit(userId: String?) async -> SubmitOutcome {
        guard let userId else { return .notAuthenticated }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch shareType {
            case .bookRec:
                let title = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let body = bookRecText.trimmingCharacters(in: .whitespacesAndNewlines)
                let caption = body.isEmpty ? "Book rec: \(title)" : "Book rec: \(title)\n\n\(body)"
                let created = try await api.createPost(authorId: userId, imageData: nil, caption: caption)
                return .success(created)

            case .question:
                let q = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
                let caption = "Question: \(q)"
                let created = try await api.createPost(authorId: userId, imageData: nil, caption: caption)
                return .success(created)

            case .reflection:
                let post = try await submitReflection(userId: userId)
                return post.map(SubmitOutcome.success) ?? .reflectionOnly
            }
        } catch {
            print("[ShareComposerViewModel] submit failed: \(error)")
            return .failure
        }
    }

    /// Snapshot of what we persisted / what we'll use to build the post
    /// caption. Extracted so the main submit function stays short.
    private struct ReflectionSnapshot {
        let bookTitle: String
        let responseText: String
        let titleText: String?
        let mood: String?
        let durationMinutes: Int?
    }

    /// Saves (or updates) the reflection, then publishes a feed post whose
    /// caption embeds a session-summary block when session data is available.
    private func submitReflection(userId: String) async throws -> Post? {
        let snapshot: ReflectionSnapshot
        if reflectionMode == .past, let r = selectedPastReflection {
            snapshot = try await updateExistingReflection(r)
        } else {
            snapshot = try await createNewReflection()
        }
        let caption = await buildCaption(snapshot: snapshot)
        return try await api.createPost(authorId: userId, imageData: nil, caption: caption)
    }

    private func updateExistingReflection(_ r: Reflection) async throws -> ReflectionSnapshot {
        try await api.updateReflection(
            id: r.id,
            title: nil,
            response: nil,
            visibility: reflectionVisibility.apiValue
        )
        return ReflectionSnapshot(
            bookTitle: r.bookTitle,
            responseText: r.response,
            titleText: r.title,
            mood: r.mood,
            durationMinutes: r.durationMinutes
        )
    }

    private func createNewReflection() async throws -> ReflectionSnapshot {
        let trimmedTitle = reflectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResponse = reflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBook = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (attachedSession?.bookTitle ?? "Unknown")
            : bookTitle
        let mood = attachedSession?.mood
        let duration = attachedSession.map { max(1, $0.durationSeconds / 60) }
        let fallbackPrompt = "What stood out to you during this reading session?"

        try await api.createReflection(
            bookTitle: resolvedBook,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            prompt: reflectionPrompt.isEmpty ? fallbackPrompt : reflectionPrompt,
            response: trimmedResponse,
            mood: mood,
            durationMinutes: duration,
            visibility: reflectionVisibility.apiValue
        )
        return ReflectionSnapshot(
            bookTitle: resolvedBook,
            responseText: trimmedResponse,
            titleText: trimmedTitle.isEmpty ? nil : trimmedTitle,
            mood: mood,
            durationMinutes: duration
        )
    }

    private func buildCaption(snapshot: ReflectionSnapshot) async -> String {
        var parts: [String] = []
        if let t = snapshot.titleText, !t.isEmpty { parts.append(t) }
        parts.append(snapshot.responseText)

        if let dur = snapshot.durationMinutes, dur > 0 {
            let summary = try? await api.generateSessionSummary(
                bookTitle: snapshot.bookTitle,
                durationMinutes: dur,
                pagesRead: attachedSession?.pagesRead,
                mood: snapshot.mood
            )
            if let summary, !summary.isEmpty {
                parts.append("")
                parts.append(sessionDateLabel())
                parts.append(summary)
            }
        }
        return parts.joined(separator: "\n")
    }

    private func sessionDateLabel() -> String {
        let iso = ISO8601DateFormatter()
        let date: Date = {
            if let s = attachedSession, let d = iso.date(from: s.endedAt) { return d }
            if let r = selectedPastReflection, let d = iso.date(from: r.createdAt) { return d }
            return Date()
        }()
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
