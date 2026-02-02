import SwiftUI

struct ContentView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.postsStore) private var postsStore: PostsStore

    private var currentUser: User {
        if let id = session.userId, let user = postsStore.posts.first(where: { $0.author.id == id })?.author {
            return user
        }
        return MockData.sampleUser
    }

    var body: some View {
        TabView {
            NavigationStack { FeedView() }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            NavigationStack { ProfileView(user: currentUser) }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
            Text("Challenges")
                .tabItem {
                    Label("Challenges", systemImage: "flag.checkered")
                }
            Text("Focus")
                .tabItem {
                    Label("Focus", systemImage: "leaf.fill")
                }
        }
    }
}

    // Present login if no user is signed in.
    @State private var showingLogin = false

    init() {
        // no-op init to keep SwiftUI happy with computed properties
    }

    private func loginBinding() -> Binding<Bool> {
        Binding(get: { session.userId == nil }, set: { _ in })
    }

    // Attach full-screen login presentation to the view hierarchy
    // using an extension-style computed modifier in the body scope.
    // SwiftUI will evaluate `session.userId` changes and present/dismiss.
}

extension ContentView {
    func withLogin() -> some View {
        self
            .onAppear { showingLogin = session.userId == nil }
            .onChange(of: session.userId) { new in showingLogin = new == nil }
            .fullScreenCover(isPresented: $showingLogin) {
                LoginView()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
