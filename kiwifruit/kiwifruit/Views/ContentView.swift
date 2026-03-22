import SwiftUI

struct ContentView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    @Environment(\.readingSessionStore) private var readingSessionStore: ReadingSessionStore
    @Environment(\.recommendationsStore) private var recommendationsStore: RecommendationsStore
    @State private var selection: Int = 2

    @State private var bookSearchViewModel = BookSearchViewModel(api: AppAPI.shared)
    @State private var bookScanViewModel = BookScanViewModel(
        scannerService: VisionBookScannerService(),
        api: AppAPI.shared
    )

    private var currentUser: User {
        if let user = session.currentUser { return user }
        if let id = session.userId, let user = postsStore.posts.first(where: { $0.author.id == id })?.author {
            return user
        }
        return MockData.sampleUser
    }

    var body: some View {
        VStack(spacing: 0) {
            currentView
            CustomTabBar(selection: $selection)
        }
        .onAppear {
            if session.isValidSession && session.userId != nil { Task { await postsStore.loadInitial() } }
        }
        .onChange(of: session.userId) { _, new in
            if new != nil {
                selection = 2
                Task { await postsStore.loadInitial(force: true) }
                Task { await recommendationsStore.load(force: true) }
            } else {
                recommendationsStore.reset()
            }
        }
        .onChange(of: session.isValidSession) { _, valid in
            if valid && session.userId != nil {
                selection = 2
                Task { await postsStore.loadInitial(force: true) }
                Task { await recommendationsStore.load(force: true) }
                readingSessionStore.loadFriendSessions()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !(session.isValidSession && session.userId != nil) }, set: { _ in })) {
            LoginView()
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch selection {
        case 0: NavigationStack { ProfileView(user: currentUser) }.id(0)
        case 1: NavigationStack { DiscoverView(bookSearchViewModel: bookSearchViewModel, bookScanViewModel: bookScanViewModel) }.id(1)
        case 2: NavigationStack { FeedView() }.id(2)
        case 3: NavigationStack { ChallengesView() }.id(3)
        case 4: NavigationStack { FocusView() }.id(4)
        default: EmptyView()
        }
    }
}

#Preview {
    ContentView()
}
