import SwiftUI

@main
struct kiwifruitApp: App {
    // Shared stores injected into the SwiftUI environment so all views
    // observe the same source-of-truth instances.
    private let postsStore = PostsStore()
    private let sessionStore = SessionStore()
    private let moodSessionStore = MoodSessionStore()
    private let userPreferencesStore = UserPreferencesStore(
        repository: UserDefaultsUserPreferencesRepository()
    )
    private let readingSessionStore = ReadingSessionStore()
    private let recommendationsStore = RecommendationsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.postsStore, postsStore)
                .environment(\.sessionStore, sessionStore)
                .environment(\.moodSessionStore, moodSessionStore)
                .environment(\.userPreferencesStore, userPreferencesStore)
                .environment(\.readingSessionStore, readingSessionStore)
                .environment(\.recommendationsStore, recommendationsStore)
        }
    }
}

