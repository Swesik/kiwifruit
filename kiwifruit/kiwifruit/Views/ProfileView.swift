import SwiftUI

struct RecentUpdateItem: Identifiable {
    let id = UUID()
    let kind: String
    let timeAgo: String
    let quote: String
    let imageURL: URL?
}

enum ProfileDesign {
    static let kiwiLight = Color(hex: "E6F0DC")
    static let kiwi = Color(hex: "A3C985")
    static let tanLight = Color(hex: "F5E6D3")
    static let cardBackground = Color(hex: "CFE6EC") // uiTeal #88C0D0 at 40% on white
    static let uiText = Color(hex: "2D3748")
    static let uiBorder = Color(hex: "E2E8F0")
    static let border = Color(hex: "2D3748")
}

struct ProfileView: View {
    let user: User

    @Environment(\.userBooksStore) private var userBooksStore
    @State private var showingSettings = false

    private let recentUpdates: [RecentUpdateItem] = [
        RecentUpdateItem(
            kind: "Reading Status", timeAgo: "2h ago",
            quote: "Just hit chapter 15! The plot twist was absolutely mind-blowing. Can't wait to see what happens next.",
            imageURL: URL(string: "https://images.unsplash.com/photo-1614113489855-66422ad300a4?auto=format&fit=crop&q=80&w=200&h=300")
        ),
        RecentUpdateItem(
            kind: "Finished", timeAgo: "Yesterday",
            quote: "Finally finished this masterpiece. 5/5 stars. Highly recommend to anyone who loves deep world-building.",
            imageURL: URL(string: "https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=200&h=300")
        )
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                profileHeaderSection
                recentUpdatesSection
                myLibrarySection
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Header

    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            ProfileDesign.kiwiLight
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .overlay(alignment: .bottom) {
                    avatarCircle.offset(y: 48)
                }
                .overlay(alignment: .topTrailing) {
                    Button("Settings") { showingSettings = true }
                        .font(.subheadline).fontWeight(.black)
                        .foregroundColor(ProfileDesign.uiText)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
                        .sketchShadow()
                        .padding(.trailing, 16).padding(.top, 16)
                }
                .padding(.bottom, 48)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName ?? user.username)
                            .font(.title2).fontWeight(.black)
                            .foregroundColor(ProfileDesign.uiText)
                        Text("Avid Reader • Sci-Fi Lover")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(ProfileDesign.uiText.opacity(0.9))
                    }
                    Spacer()
                    Button("Edit") {}
                        .font(.subheadline).fontWeight(.black)
                        .foregroundColor(ProfileDesign.uiText)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(ProfileDesign.kiwi)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
                        .sketchShadow()
                }
                .padding(.horizontal, 24).padding(.top, 16)

                Text("\"Currently lost in a galaxy far, far away. Goal: 50 books this year!\"")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(ProfileDesign.uiText)
                    .lineSpacing(4)
                    .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
        }
    }

    private var avatarCircle: some View {
        AsyncImage(url: user.avatarURL) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else if phase.error != nil { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary) }
            else { ProgressView() }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(Circle().stroke(ProfileDesign.border, lineWidth: 2))
        .background(Circle().fill(Color.white))
        .sketchShadowCircle()
    }

    // MARK: - Recent Updates

    private var recentUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Updates")
                .font(.title2).fontWeight(.black)
                .foregroundColor(ProfileDesign.uiText)
                .padding(.horizontal, 20).padding(.top, 20)

            ForEach(recentUpdates) { recentUpdateCard($0).padding(.horizontal, 20) }

            NavigationLink(destination: AllUpdatesView(updates: recentUpdates)) {
                Text("LOAD MORE")
                    .font(.subheadline).fontWeight(.black)
                    .foregroundColor(ProfileDesign.uiText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ProfileDesign.kiwiLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
                    .sketchShadow()
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 20)
        }
        .background(Color.white)
    }

    private func recentUpdateCard(_ item: RecentUpdateItem) -> some View {
        RecentUpdateCard(item: item)
    }

    // MARK: - My Library

    private var myLibrarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Library")
                    .font(.title2).fontWeight(.black)
                    .foregroundColor(ProfileDesign.uiText)
                Spacer()
                Button("Add") {}
                    .font(.subheadline).fontWeight(.black)
                    .foregroundColor(ProfileDesign.uiText)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(ProfileDesign.kiwi)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
                    .sketchShadow()
            }
            .padding(.horizontal, 20).padding(.top, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(userBooksStore.items) { book in
                        libraryBookTile(book)
                    }
                    addBookPlaceholder
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
            }
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }

    private var addBookPlaceholder: some View {
        VStack(spacing: 4) {
            Text("+").font(.title).fontWeight(.black).foregroundColor(ProfileDesign.uiText)
            Text("Add Book").font(.caption2).fontWeight(.bold).foregroundColor(ProfileDesign.uiText)
        }
        .frame(width: 96, height: 144)
        .background(ProfileDesign.tanLight.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ProfileDesign.border, lineWidth: 2))
        .sketchShadow(cornerRadius: 6)
    }

    private func libraryBookTile(_ book: UserBook) -> some View {
        VStack(spacing: 6) {
            if let cover = book.coverUrl, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else if phase.error != nil { ProfileDesign.uiBorder.overlay(Image(systemName: "book.closed")) }
                    else { ProfileDesign.uiBorder.overlay(ProgressView()) }
                }
                .frame(width: 72, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ProfileDesign.border, lineWidth: 2))
                .sketchShadow(cornerRadius: 6)
            } else {
                bookCoverImage(url: nil)
                    .frame(width: 72, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ProfileDesign.border, lineWidth: 2))
                    .sketchShadow(cornerRadius: 6)
            }
            Text(book.title)
                .font(.caption2).fontWeight(.black)
                .foregroundColor(ProfileDesign.uiText)
                .lineLimit(2)
                .frame(width: 96)
            if let authors = book.authors, !authors.isEmpty {
                Text(authors.joined(separator: ", "))
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(ProfileDesign.uiText.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 96)
            }
        }
        .frame(width: 96)
    }

    @ViewBuilder
    private func bookCoverImage(url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else if phase.error != nil { ProfileDesign.uiBorder.overlay(Image(systemName: "book.closed")) }
            else { ProfileDesign.uiBorder.overlay(ProgressView()) }
        }
    }
}

// MARK: - Shared card used by ProfileView and AllUpdatesView

struct RecentUpdateCard: View {
    let item: RecentUpdateItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.kind.uppercased())
                        .font(.caption2).fontWeight(.black)
                        .foregroundColor(ProfileDesign.uiText)
                    Spacer()
                    Text(item.timeAgo)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(ProfileDesign.uiText.opacity(0.85))
                }
                Text("\"\(item.quote)\"")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(ProfileDesign.uiText)
                    .lineSpacing(4).padding(.bottom, 8)

                Button("Edit") {}
                    .font(.caption2).fontWeight(.black)
                    .foregroundColor(ProfileDesign.uiText)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ProfileDesign.border, lineWidth: 2))
                    .sketchShadow(cornerRadius: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else if phase.error != nil { ProfileDesign.uiBorder.overlay(Image(systemName: "book.closed")) }
                else { ProfileDesign.uiBorder.overlay(ProgressView()) }
            }
            .frame(width: 80, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ProfileDesign.border, lineWidth: 2))
            .sketchShadow(cornerRadius: 6)
        }
        .padding(16)
        .background(ProfileDesign.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
        .sketchShadow()
    }
}

#Preview {
    NavigationStack {
        ProfileView(user: MockData.sampleUser)
    }
}
