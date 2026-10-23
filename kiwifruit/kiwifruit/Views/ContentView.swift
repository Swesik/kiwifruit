import SwiftUI

struct ContentView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.userPreferencesStore) private var userPreferencesStore: UserPreferencesStore
    @Environment(\.recommendationsStore) private var recommendationsStore: RecommendationsStore
    @Environment(\.userBooksStore) private var userBooksStore: UserBooksStore
    @State private var selection: Int = 2

    @State private var bookSearchViewModel = BookSearchViewModel(api: AppAPI.shared)
    @State private var bookScanViewModel = BookScanViewModel(
        scannerService: VisionBookScannerService(),
        api: AppAPI.shared
    )

    var body: some View {
        VStack(spacing: 0) {
            currentView
            CustomTabBar(selection: $selection)
        }
        .onAppear {
            if session.isValidSession && session.userId != nil {
                Task { await userPreferencesStore.load() }
            }
        }
        .onChange(of: session.userId) { _, new in
            if new != nil {
                selection = 2
                Task { await recommendationsStore.load() }
            } else {
                recommendationsStore.reset()
                userBooksStore.reset()
            }
        }
        .onChange(of: session.isValidSession) { _, valid in
            if valid && session.userId != nil {
                selection = 2
                Task { await recommendationsStore.load() }
            }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch selection {
        case 0: NavigationStack { ProfileView(user: session.currentUser) }.id(0)
        case 1: NavigationStack { DiscoverView(bookSearchViewModel: bookSearchViewModel, bookScanViewModel: bookScanViewModel) }.id(1)
        case 2: NavigationStack { ReadView() }.id(2)
        case 3: NavigationStack { ChallengesView() }.id(3)
        default: EmptyView()
        }
    }
}

#Preview {
    ContentView()
}
