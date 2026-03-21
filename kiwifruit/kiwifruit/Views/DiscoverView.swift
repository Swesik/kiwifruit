import SwiftUI

private enum DiscoverDesign {
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tanLight = Color(hex: "F5E6D3")
    static let uiText = Color(hex: "2D3748")
    static let uiBorder = Color(hex: "E2E8F0")
    static let border = Color(hex: "2D3748")
}

private let recommendationURLs: [URL?] = [
    URL(string: "https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=200&h=300"),
    URL(string: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&q=80&w=200&h=300"),
    URL(string: "https://images.unsplash.com/photo-1614113489855-66422ad300a4?auto=format&fit=crop&q=80&w=200&h=300"),
    URL(string: "https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&q=80&w=200&h=300"),
    URL(string: "https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=200&h=300"),
    URL(string: "https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&q=80&w=200&h=300")
]

struct DiscoverView: View {
    @Bindable var bookSearchViewModel: BookSearchViewModel
    @Bindable var bookScanViewModel: BookScanViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                Text("Discover")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(DiscoverDesign.uiText)

                searchSection
                resultsSection
                recommendationsSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
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
        }
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
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
                .sketchShadow()

            } else if let errorMessage = bookScanViewModel.errorMessage ?? bookSearchViewModel.errorMessage {
                Text(errorMessage)
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
                Text("no results")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(DiscoverDesign.uiText.opacity(0.6))
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
        HStack(spacing: 12) {
            DiscoverDesign.uiBorder
                .overlay(Image(systemName: "book.closed").foregroundStyle(DiscoverDesign.uiText.opacity(0.4)))
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DiscoverDesign.border, lineWidth: 2))
                .sketchShadow(cornerRadius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
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
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.title2).fontWeight(.black)
                .foregroundColor(DiscoverDesign.uiText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(Array(recommendationURLs.enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { DiscoverDesign.tanLight }
                    }
                    .aspectRatio(2/3, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DiscoverDesign.border, lineWidth: 2))
                    .sketchShadow(cornerRadius: 6)
                }
            }
        }
    }
}

#Preview {
    DiscoverView(
        bookSearchViewModel: BookSearchViewModel(api: MockAPIClient()),
        bookScanViewModel: BookScanViewModel(scannerService: VisionBookScannerService(), api: MockAPIClient())
    )
}
