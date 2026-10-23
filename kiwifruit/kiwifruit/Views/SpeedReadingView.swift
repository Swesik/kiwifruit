import SwiftUI

struct SpeedReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userPreferencesStore) private var preferencesStore
    @State private var viewModel: SpeedReadingViewModel
    @State private var wpmText: String = "240"

    init() {
        self._viewModel = State(initialValue: SpeedReadingViewModel())
    }

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
        .onAppear {
            viewModel = SpeedReadingViewModel(preferencesStore: preferencesStore)
            viewModel.loadSettings()
            wpmText = "\(viewModel.wordsPerMinute)"
            viewModel.loadBooks()
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

                // Settings section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "2D3748"))

                    // Words per minute
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Words per minute")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "2D3748"))

                        HStack(spacing: 8) {
                            TextField("WPM", text: $wpmText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "2D3748"))
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                                .padding(.horizontal, 8).padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 2))
                                .onChange(of: wpmText) {
                                    if let value = Int(wpmText), value > 0 {
                                        viewModel.wordsPerMinute = value
                                    }
                                }
                                .onSubmit {
                                    commitWpm()
                                }

                            VStack(spacing: 0) {
                                Button {
                                    let newWpm = viewModel.wordsPerMinute + 10
                                    viewModel.wordsPerMinute = newWpm
                                    wpmText = "\(newWpm)"
                                    viewModel.saveSettings()
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "2D3748"))
                                        .frame(width: 32, height: 20)
                                }

                                Button {
                                    let newWpm = max(1, viewModel.wordsPerMinute - 10)
                                    viewModel.wordsPerMinute = newWpm
                                    wpmText = "\(newWpm)"
                                    viewModel.saveSettings()
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "2D3748"))
                                        .frame(width: 32, height: 20)
                                }
                            }
                            .background(Color(hex: "D1BFAe"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "2D3748"), lineWidth: 2))
                        }
                    }

                    // Words per segment slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Words per segment: \(viewModel.wordsPerSegment)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "2D3748"))

                        HStack(spacing: 8) {
                            Text("1")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "2D3748"))
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.wordsPerSegment) },
                                    set: { newVal in
                                        viewModel.wordsPerSegment = Int(newVal.rounded())
                                        viewModel.saveSettings()
                                    }
                                ),
                                in: 1...7,
                                step: 1
                            )
                            .tint(Color(hex: "7EA2A0"))
                            Text("7")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "2D3748"))
                        }
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
        GeometryReader { geometry in
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

                chapterProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
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
                    .padding(.horizontal, 24)
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

                VStack(spacing: 4) {
                    Text("WPM")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748"))

                    TextField("WPM", text: $wpmText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "2D3748"))
                        .multilineTextAlignment(.center)
                        .frame(width: 88, height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 2))
                        .disabled(viewModel.isPlaying)
                        .opacity(viewModel.isPlaying ? 0.6 : 1)
                        .onChange(of: wpmText) {
                            if let value = Int(wpmText), value > 0 {
                                viewModel.wordsPerMinute = value
                                viewModel.saveSettings()
                            }
                        }
                        .onSubmit {
                            commitWpm()
                        }
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
        .simultaneousGesture(
            SpatialTapGesture(count: 2)
                .onEnded { value in
                    let seekDuration = Double(viewModel.doubleTapSeekSeconds)
                    viewModel.seek(by: value.location.x < geometry.size.width / 2 ? -seekDuration : seekDuration)
                }
        )
        .sheet(isPresented: $viewModel.showChapterPicker) {
            chapterPickerSheet
        }
        }
    }

    private var chapterProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "7EA2A0").opacity(0.10))
                Capsule()
                    .fill(Color(hex: "7EA2A0").opacity(0.35))
                    .frame(width: geometry.size.width * chapterProgress)
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Chapter progress")
        .accessibilityValue("\(Int(chapterProgress * 100)) percent")
    }

    private var chapterProgress: CGFloat {
        guard !viewModel.words.isEmpty else { return 0 }
        if viewModel.isFinished { return 1 }
        return min(1, CGFloat(viewModel.currentWordIndex) / CGFloat(viewModel.words.count))
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

        let displayLength = max(viewModel.maxSegmentLength, word.count)
        let halfDisplay = displayLength / 2
        let padBefore = max(0, halfDisplay - before.count)
        let padAfter = max(0, displayLength - padBefore - before.count - 1 - after.count)
        let paddedBefore = String(repeating: " ", count: padBefore) + before
        let paddedAfter = after + String(repeating: " ", count: padAfter)

        return (Text(paddedBefore).foregroundColor(Color(hex: "2D3748"))
                + Text(pivotChar).foregroundColor(.red)
                + Text(paddedAfter).foregroundColor(Color(hex: "2D3748")))
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .frame(maxWidth: .infinity)
    }

    /// Validate and commit the WPM text field value.
    private func commitWpm() {
        if let value = Int(wpmText), value > 0 {
            viewModel.wordsPerMinute = value
        } else {
            viewModel.wordsPerMinute = max(1, viewModel.wordsPerMinute)
        }
        wpmText = "\(viewModel.wordsPerMinute)"
        viewModel.saveSettings()
    }

    /// Compute the index of the center-most non-space character.
    static func pivotIndex(for word: String) -> Int {
        let chars = Array(word)
        guard !chars.isEmpty else { return 0 }

        let nonSpaceIndices = chars.indices.filter { !chars[$0].isWhitespace && !chars[$0].isPunctuation }
        guard !nonSpaceIndices.isEmpty else { return 0 }

        return nonSpaceIndices[nonSpaceIndices.count / 2]
    }
}

#Preview {
    SpeedReadingView()
}
