import SwiftUI

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
    let user: User?

    @Environment(\.userBooksStore) private var userBooksStore
    @State private var showingSettings = false
    @State private var showingSignIn = false


    private let libraryURLs: [URL?] = [
        URL(string: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&q=80&w=200&h=300"),
        URL(string: "https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=200&h=300"),
        URL(string: "https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&q=80&w=200&h=300")
    ]

    var body: some View {
        Group {
            if let user {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileHeaderSection(user: user)
                        moodSessionHistorySection
                        myLibrarySection
                    }
                }
            } else {
                signedOutView
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            LoginView()
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var signedOutView: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3.weight(.bold))
                        .foregroundColor(ProfileDesign.uiText)
                        .frame(width: 44, height: 44)
                        .background(ProfileDesign.kiwiLight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ProfileDesign.border, lineWidth: 2))
                        .sketchShadow()
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
            Text("Sign in to access your profile page")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(ProfileDesign.uiText.opacity(0.7))
            Button("Sign In") { showingSignIn = true }
                .font(.headline).fontWeight(.black)
                .foregroundColor(ProfileDesign.uiText)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(ProfileDesign.kiwi)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
                .sketchShadow()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private func profileHeaderSection(user: User) -> some View {
        VStack(spacing: 0) {
            ProfileDesign.kiwiLight
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .overlay(alignment: .bottom) {
                    avatarCircle(user: user).offset(y: 48)
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

    private func avatarCircle(user: User) -> some View {
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

    // MARK: - Mood Session History

    private var moodSessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(destination: MoodHistoryView()) {
                HStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(ProfileDesign.uiText)
                        .frame(width: 48, height: 48)
                        .background(ProfileDesign.kiwiLight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ProfileDesign.border, lineWidth: 2))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mood Session History")
                            .font(.subheadline).fontWeight(.black)
                            .foregroundColor(ProfileDesign.uiText)
                        Text("Your reading mood history")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(ProfileDesign.uiText.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ProfileDesign.uiText.opacity(0.5))
                }
                .padding(16)
                .background(ProfileDesign.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ProfileDesign.border, lineWidth: 2))
                .sketchShadow()
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .background(Color.white)
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
                HStack(spacing: 12) {
                    ForEach(userBooksStore.items) { book in
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
                                .lineLimit(1)
                            if let authors = book.authors, !authors.isEmpty {
                                Text(authors.joined(separator: ", "))
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(ProfileDesign.uiText.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 96)
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

#Preview {
    NavigationStack {
        ProfileView(user: MockData.sampleUser)
    }
}
