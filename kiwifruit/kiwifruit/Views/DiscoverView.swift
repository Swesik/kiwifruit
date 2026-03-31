import SwiftUI

private enum DiscoverDesign {
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tanLight = Color(hex: "F5E6D3")
    static let uiText = Color(hex: "2D3748")
    static let uiBorder = Color(hex: "E2E8F0")
    static let border = Color(hex: "2D3748")
}

struct DiscoverView: View {
    @Bindable var bookSearchViewModel: BookSearchViewModel
    @Bindable var bookScanViewModel: BookScanViewModel
    @Environment(\.sessionStore) private var sessionStore
    @Environment(\.recommendationsStore) private var recommendationsStore
    @Environment(\.userBooksStore) private var userBooksStore
    @State private var justAddedTitle: String? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                Text("Discover")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(DiscoverDesign.uiText)

                searchSection
                resultsSection
                    .onChange(of: bookSearchViewModel.results.count) { newCount in
                        resultsLimit = min(3, newCount)
                    }
                recommendationsSection
            }
            .padding(.horizontal, 24)
            .safeAreaPadding(.top, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(
            isPresented: Binding(
                get: { bookScanViewModel.isShowingCamera },
                set: { bookScanViewModel.isShowingCamera = $0 }
            )
        ) {
            CameraPickerView { image in
                Task {
                    if let capturedText = await bookScanViewModel.processCapturedImage(image) {
                        bookSearchViewModel.query = capturedText
                        await bookSearchViewModel.submit()
                    }
                }
            }
                    @State private var resultsLimit: Int = 3

                    var body: some View {
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Search...", text: $bookSearchViewModel.query)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(DiscoverDesign.uiText)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(DiscoverDesign.border, lineWidth: 2))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await bookSearchViewModel.submit() } }

                Button("SEARCH") { Task { await bookSearchViewModel.submit() } }
                    .font(.subheadline).fontWeight(.black)
                    .foregroundColor(DiscoverDesign.uiText)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(DiscoverDesign.kiwi)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow()
                    .disabled(bookSearchViewModel.isSearching || bookSearchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button {
                bookScanViewModel.startCamera()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "barcode")
                    Text("Search by barcode / title")
                }
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(DiscoverDesign.uiText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DiscoverDesign.kiwiLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                .sketchShadow()
            }
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results")
                .font(.title2).fontWeight(.black)
                .foregroundColor(DiscoverDesign.uiText)

            if bookSearchViewModel.isSearching || bookScanViewModel.isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 32)
                .background(Color(hex: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(spacing: 12) {
                                    ForEach(Array(bookSearchViewModel.results.prefix(resultsLimit))) { book in
                                        resultRow(book)
                                    }
                                    if bookSearchViewModel.results.count > resultsLimit {
                                        Button("LOAD MORE") {
                                            resultsLimit = min(bookSearchViewModel.results.count, min(6, resultsLimit + 3))
                                        }
                                        .font(.subheadline).fontWeight(.black)
                                        .foregroundColor(DiscoverDesign.uiText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(DiscoverDesign.kiwiLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                                        .sketchShadow()
                                        .padding(.top, 8)
                                    }
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow()

            } else if !bookSearchViewModel.results.isEmpty {
                VStack(spacing: 12) {
                    ForEach(bookSearchViewModel.results) { book in
                        resultRow(book)
                    }
                }

            } else if let statusMessage = bookScanViewModel.statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow()

            } else {
                            // Small cover image
                            if let cover = book.coverUrl, let url = URL(string: cover) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure:
                                        DiscoverDesign.uiBorder.overlay(Image(systemName: "book.closed").foregroundStyle(DiscoverDesign.uiText.opacity(0.4)))
                                    case .empty:
                                        ProgressView()
                                    @unknown default:
                                        DiscoverDesign.uiBorder
                                    }
                                }
                                .frame(width: 48, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DiscoverDesign.border, lineWidth: 2))
                                .sketchShadow(cornerRadius: 6)
                            } else {
                                DiscoverDesign.uiBorder
                                    .overlay(Image(systemName: "book.closed").foregroundStyle(DiscoverDesign.uiText.opacity(0.4)))
                                    .frame(width: 48, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DiscoverDesign.border, lineWidth: 2))
                                    .sketchShadow(cornerRadius: 6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow()
            }
        }
    }

    private func resultRow(_ book: BookSearchResult) -> some View {
                                if let isbn = book.isbn13, !isbn.isEmpty {
                                    Text("ISBN: \(isbn)")
                                        .font(.caption2)
                                        .foregroundColor(DiscoverDesign.uiText.opacity(0.5))
                                }
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DiscoverDesign.border, lineWidth: 2))
                .sketchShadow(cornerRadius: 6)

            VStack(alignment: .leading, spacing: 4) {
                                let userBook = UserBook(title: book.title, authors: book.authors, isbn13: book.isbn13, coverUrl: book.coverUrl)
                    .font(.subheadline).fontWeight(.black)
                    .foregroundColor(DiscoverDesign.uiText)
                    .lineLimit(2)
                if let authors = book.authors, !authors.isEmpty {
                    Text(authors.joined(separator: ", "))
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(DiscoverDesign.uiText.opacity(0.7))
                }
                if let isbn = book.isbn13, !isbn.isEmpty {
                    Text("ISBN: \(isbn)")
                        .font(.caption2)
                        .foregroundColor(DiscoverDesign.uiText.opacity(0.5))
                }
            }
            Spacer()

            Button {
                let userBook = UserBook(title: book.title, authors: book.authors, isbn13: book.isbn13)
                userBooksStore.add(userBook)
                justAddedTitle = book.title
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    justAddedTitle = nil
                }
            } label: {
                Text("ADD")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(DiscoverDesign.kiwiLight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DiscoverDesign.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    // Simple inline confirmation banner when user adds a book.
    @ViewBuilder
    private func addedBanner() -> some View {
        if let title = justAddedTitle {
            HStack {
                Text("Added")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(8)
            .background(DiscoverDesign.kiwi)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 1))
            .transition(.opacity)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.title2).fontWeight(.black)
                .foregroundColor(DiscoverDesign.uiText)

            if !sessionStore.isValidSession {
                Text("Sign in to see personalized picks.")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow()
            } else if recommendationsStore.isLoading && recommendationsStore.items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 32)
                .background(Color(hex: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                .sketchShadow()
            } else if let err = recommendationsStore.loadError, recommendationsStore.items.isEmpty {
                Text(err)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow()
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3),
                    spacing: 20
                ) {
                    ForEach(recommendationsStore.items) { book in
                        recommendationCell(book)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recommendationCoverImage(_ book: BookRecommendation) -> some View {
        if let assetName = BookRecommendationMockAssets.mockAssetImageName(from: book.coverUrl) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let url = URL(string: book.coverUrl),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                case .failure:
                    Color.clear
                case .empty:
                    ProgressView()
                        .tint(DiscoverDesign.uiText.opacity(0.35))
                @unknown default:
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    /// Grid covers: strict 2:3 box driven by `Rectangle` (not `AsyncImage` intrinsic size).
    /// Skip `sketchShadow` here — its offset `.background` draws outside the frame and overlaps other cells.
    private func recommendationCell(_ book: BookRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(DiscoverDesign.tanLight)
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay {
                    recommendationCoverImage(book)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DiscoverDesign.border, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.caption).fontWeight(.black)
                    .foregroundColor(DiscoverDesign.uiText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author)
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

#Preview {
    DiscoverView(
        bookSearchViewModel: BookSearchViewModel(api: MockAPIClient()),
        bookScanViewModel: BookScanViewModel(scannerService: VisionBookScannerService(), api: MockAPIClient())
    )
    .environment(\.recommendationsStore, RecommendationsStore.previewPopulated())
    .environment(\.sessionStore, SessionStore(previewLoggedIn: true))
}
