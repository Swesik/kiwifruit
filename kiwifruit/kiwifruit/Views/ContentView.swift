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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
