import SwiftUI

private enum RecommendationDetailDesign {
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tanLight = Color(hex: "F5E6D3")
    static let uiText = Color(hex: "2D3748")
    static let border = Color(hex: "2D3748")
}

struct RecommendationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var description = "Loading..."
    @State private var isLoading = true
    let book: BookRecommendation

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Close button header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(RecommendationDetailDesign.uiText)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.white)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // "We Recommend:" title
                        Text("We Recommend:")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(RecommendationDetailDesign.uiText)

                        // Book cover and title/author
                        HStack(alignment: .top, spacing: 20) {
                            // Book cover
                            VStack {
                                Rectangle()
                                    .fill(RecommendationDetailDesign.tanLight)
                                    .aspectRatio(2 / 3, contentMode: .fit)
                                    .frame(maxWidth: 120)
                                    .overlay {
                                        recommendationCoverImage(book)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(RecommendationDetailDesign.border, lineWidth: 2)
                                    )
                            }

                            // Title and author
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title)
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(RecommendationDetailDesign.uiText)
                                    .lineLimit(3)

                                Text(book.author)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(RecommendationDetailDesign.uiText.opacity(0.7))
                                    .lineLimit(2)

                                Spacer()
                            }
                            .frame(maxHeight: 180, alignment: .topLeading)

                            Spacer()
                        }
                        .frame(height: 180)

                        Divider()
                            .background(RecommendationDetailDesign.border)

                        // Description section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundColor(RecommendationDetailDesign.uiText)

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(RecommendationDetailDesign.uiText.opacity(0.35))
                                    Text("Loading...")
                                        .font(.body)
                                        .foregroundColor(RecommendationDetailDesign.uiText.opacity(0.6))
                                }
                            } else {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(RecommendationDetailDesign.uiText.opacity(0.8))
                                    .lineSpacing(2)
                            }
                        }

                        // Why? section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why?")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundColor(RecommendationDetailDesign.uiText)

                            Text("Based on your reading history and preferences, we think you'll love this book. Its genre and themes align perfectly with the types of stories you enjoy.")
                                .font(.body)
                                .foregroundColor(RecommendationDetailDesign.uiText.opacity(0.8))
                                .lineSpacing(2)
                        }

                        // Add status button
                        Button(action: {}) {
                            Text("Add Status")
                                .font(.subheadline).fontWeight(.black)
                                .foregroundColor(RecommendationDetailDesign.uiText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RecommendationDetailDesign.kiwi)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(RecommendationDetailDesign.border, lineWidth: 2)
                                )
                        }
                        .sketchShadow()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Task {
                await fetchDescription()
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
                        .tint(RecommendationDetailDesign.uiText.opacity(0.35))
                @unknown default:
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    private func fetchDescription() async {
        isLoading = true

        do {
            let desc = try await AppAPI.shared.fetchBookDescription(title: book.title, author: book.author)
            
            // If we got "No description available" (cached or from API), retry once
            if desc == "No description available" {
                print("Got empty description, retrying...")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                let retryDesc = try await AppAPI.shared.fetchBookDescription(title: book.title, author: book.author)
                description = retryDesc
                print("Retry result: \(retryDesc.prefix(100))")
            } else {
                description = desc
                print("Successfully loaded description: \(desc.prefix(100))")
            }
        } catch {
            description = "Unable to load description"
            print("Failed to fetch book description: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    RecommendationDetailView(
        book: BookRecommendation(
            bookId: 1,
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            coverUrl: BookRecommendationMockAssets.coverUrl(forMockIndex: 0)
        )
    )
}
