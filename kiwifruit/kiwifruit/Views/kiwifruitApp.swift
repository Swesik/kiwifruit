import SwiftUI

@main
struct kiwifruitApp: App {
    // Shared stores injected into the SwiftUI environment so all views
    // observe the same source-of-truth instances.
    private let sessionStore = SessionStore()
    private let userPreferencesStore = UserPreferencesStore()
    private let readingSessionStore = ReadingSessionStore()
    private let recommendationsStore = RecommendationsStore()
    private let userBooksStore = UserBooksStore()
    private let challengeViewModel = ChallengeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environment(\.sessionStore, sessionStore)
                .environment(\.userPreferencesStore, userPreferencesStore)
                .environment(\.readingSessionStore, readingSessionStore)
                .environment(\.recommendationsStore, recommendationsStore)
                .environment(\.userBooksStore, userBooksStore)
                .environment(\.challengeViewModel, challengeViewModel)
        }
    }
}
