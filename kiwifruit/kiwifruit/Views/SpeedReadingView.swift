import SwiftUI
import UniformTypeIdentifiers

struct SpeedReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var viewModel = SpeedReadingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("close") {
                    viewModel.deselectBook()
                    dismiss()
                }
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(Color(hex: "2D3748"))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(hex: "D1BFAe"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "2D3748"), lineWidth: 2))
                .sketchShadow(cornerRadius: 20)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)

            if viewModel.selectedBook != nil {
                speedReadingPlayerView
            } else {
                bookListView
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadBooks() }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.uploadEpub(from: url)
            case .failure(let error):
                viewModel.uploadMessage = "Failed to pick file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Book List View

    private var bookListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 48) {
                Text("Speed Reading")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "2D3748"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                // Continue section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Continue:")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "2D3748"))

                    if viewModel.isLoadingBooks {
                        ProgressView()
                            .foregroundColor(Color(hex: "2D3748"))
                    } else if viewModel.books.isEmpty {
                        Text("no books uploaded yet")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(Color(hex: "2D3748"))
                    } else {
                        ForEach(viewModel.books) { book in
                            Button {
                                viewModel.selectBook(book)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(book.title)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Color(hex: "2D3748"))
                                        Text(book.author)
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: "2D3748").opacity(0.7))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(hex: "2D3748"))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(Color(hex: "7EA2A0").opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 2))
                            }
                        }
                    }
                }

                // Upload section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Text("Upload")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "2D3748"))
                        Button("files") {
                            showFilePicker = true
                        }
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "2D3748"))
                        .padding(.horizontal, 32).padding(.vertical, 8)
                        .background(Color(hex: "7EA2A0"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 3))
                        .sketchShadow()
                        .disabled(viewModel.isUploading)
                    }

                    if viewModel.isUploading {
                        ProgressView("Uploading...")
                            .foregroundColor(Color(hex: "2D3748"))
                    }

                    if let message = viewModel.uploadMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "2D3748"))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Speed Reading Player View

    private var speedReadingPlayerView: some View {
        VStack(spacing: 0) {
            if let book = viewModel.selectedBook {
                Text(book.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "2D3748"))
                    .padding(.top, 24)

                Button {
                    viewModel.showChapterPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.currentChapterTitle ?? "Chapter \(viewModel.currentChapter)")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "2D3748").opacity(0.7))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "2D3748").opacity(0.5))
                    }
                }
                .padding(.top, 4)
                .disabled(viewModel.chapters.isEmpty)
            }

            Spacer()

            if viewModel.isLoadingChapter {
                ProgressView("Loading chapter...")
                    .foregroundColor(Color(hex: "2D3748"))
            } else if viewModel.isFinished {
                Text("Finished!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(hex: "2D3748"))
            } else {
                wordDisplayView
            }

            Spacer()

            // Controls
            HStack(spacing: 32) {
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "2D3748"))
                        .frame(width: 64, height: 64)
                        .background(Color(hex: "7EA2A0"))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 3))
                        .sketchShadow(cornerRadius: 32)
                }
                .disabled(viewModel.isLoadingChapter || viewModel.isFinished)

                Button {
                    viewModel.finish()
                } label: {
                    Text("finish")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "2D3748"))
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color(hex: "D1BFAe"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 2))
                        .sketchShadow()
                }
            }
            .padding(.bottom, 48)

            Button("back to books") {
                viewModel.deselectBook()
            }
            .font(.subheadline).fontWeight(.bold)
            .foregroundColor(Color(hex: "2D3748"))
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $viewModel.showChapterPicker) {
            chapterPickerSheet
        }
    }

    // MARK: - Chapter Picker

    private var chapterPickerSheet: some View {
        NavigationStack {
            List(viewModel.chapters) { chapter in
                Button {
                    viewModel.jumpToChapter(chapter.chapterNumber)
                    viewModel.showChapterPicker = false
                } label: {
                    HStack {
                        Text(chapter.title.isEmpty ? "Chapter \(chapter.chapterNumber)" : chapter.title)
                            .foregroundColor(Color(hex: "2D3748"))
                        Spacer()
                        if chapter.chapterNumber == viewModel.currentChapter {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(hex: "7EA2A0"))
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.showChapterPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Word Display

    private var wordDisplayView: some View {
        let word = viewModel.currentWord
        let pivot = Self.pivotIndex(for: word)
        let chars = Array(word)

        let before = pivot > 0 ? String(chars[..<pivot]) : ""
        let pivotChar = pivot < chars.count ? String(chars[pivot]) : ""
        let after = pivot + 1 < chars.count ? String(chars[(pivot + 1)...]) : ""

        return ZStack {
            // Invisible full word to reserve consistent space
            Text(word)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .hidden()

            HStack(spacing: 0) {
                // Right-align everything before the pivot
                Text(before)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "2D3748"))
                    .fixedSize()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

                // The pivot character in red
                Text(pivotChar)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
                    .fixedSize()

                // Left-align everything after the pivot
                Text(after)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "2D3748"))
                    .fixedSize()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Compute the index of the center-most non-space character.
    static func pivotIndex(for word: String) -> Int {
        let chars = Array(word)
        guard !chars.isEmpty else { return 0 }

        let nonSpaceIndices = chars.indices.filter { !chars[$0].isWhitespace }
        guard !nonSpaceIndices.isEmpty else { return 0 }

        return nonSpaceIndices[nonSpaceIndices.count / 2]
    }
}

#Preview {
    SpeedReadingView()
}
