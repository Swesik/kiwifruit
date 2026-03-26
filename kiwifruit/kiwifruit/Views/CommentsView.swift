import SwiftUI

struct CommentsView: View {
    let post: Post
    @Environment(\.commentsStore) private var commentsStore: CommentsStore
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var newCommentText: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(commentsStore.comments(for: post)) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.author.displayName ?? c.author.username)
                                .font(.subheadline)
                                .bold()
                            Text(c.text)
                                .font(.body)
                            Text(c.createdAt, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }

                HStack {
                    TextField("Add a comment...", text: $newCommentText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Send") { Task { await addComment() } }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.userId == nil)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { await commentsStore.fetchForPost(post) }
            .alert("Comment Error", isPresented: $showErrorAlert, actions: { Button("OK", role: .cancel) {} }, message: { Text(errorMessage ?? "Failed to post comment") })
        }
    }

    private func addComment() async {
        guard session.userId != nil else { return }
        // Use the signed-in user if available; otherwise fall back to a minimal placeholder
        let author: User? = session.currentUser ?? session.userId.map { User(id: $0, username: "", displayName: nil, avatarURL: nil) }
        let success = await commentsStore.createComment(newCommentText, post: post, author: author)
        if !success {
            errorMessage = "Couldn't post comment to server — saved locally."
            showErrorAlert = true
        }
        newCommentText = ""
    }
}

#Preview {
    CommentsView(post: MockData.makePosts(count: 1, page: 0)[0])
}
