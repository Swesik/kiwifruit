import SwiftUI
import UniformTypeIdentifiers

private enum FocusDesign {
    static let kiwi = Color(hex: "A3C985")
    static let tan = Color(hex: "D1BFAe")
    static let uiTeal = Color(hex: "88C0D0")
    static let uiBg = Color(hex: "FAFAFA")
    static let handDrawnBorder = Color.black
    static let sketchOffset: CGFloat = 4
}

private struct ReadButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ReadView: View {
    @Environment(\.readingSessionStore) private var sessionStore: ReadingSessionStore
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.challengeViewModel) private var challengeViewModel: ChallengeViewModel
    @Environment(\.recommendationsStore) private var recommendationsStore: RecommendationsStore
    @Environment(\.userPreferencesStore) private var preferencesStore: UserPreferencesStore

    @State private var isSelectingBook = false
    @State private var tempBookTitle = ""
    @State private var tempStartingPage = ""
    @State private var showEndPageSheet = false
    @State private var tempEndingPage = ""
    @State private var showingSpeedReading = false
    @State private var showFilePicker = false
    @State private var speedReadingViewModel = SpeedReadingViewModel()
    @State private var didFinishBook = false
    @State private var showingReflectionCapture = false
    @State private var didSaveReflection = false

    var body: some View {
        Group {
            if isSelectingBook {
                bookSelectionView
            } else {
                VStack(spacing: 0) {
                    switch sessionStore.status {
                    case .idle:
                        startSessionView
                    case .active, .paused:
                        activeSessionView
                    case .completed:
                        completionView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(FocusDesign.uiBg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            speedReadingViewModel = SpeedReadingViewModel(preferencesStore: preferencesStore)
            // Set up callback to refresh recommendations when session completes
            sessionStore.onSessionCompleted = { [weak recommendationsStore] in
                Task {
                    await recommendationsStore?.load(limit: 8)
                }
            }
        }
        .sheet(isPresented: $showingSpeedReading) { SpeedReadingView() }
        .sheet(isPresented: $showingReflectionCapture) {
            ReflectionCaptureSheet(
                bookTitle: sessionStore.bookTitle,
                durationSeconds: sessionStore.completedSeconds,
                pagesRead: sessionStore.completedPagesRead,
                onSave: { didSaveReflection = true }
            )
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                speedReadingViewModel.uploadEpub(from: url)
            case .failure(let error):
                speedReadingViewModel.uploadMessage = "Failed to pick file: \(error.localizedDescription)"
            }
        }
    }

    private var bookSelectionView: some View {
        VStack(spacing: 32) {
            HStack {
                Button(action: {
                    tempBookTitle = ""
                    tempStartingPage = ""
                    isSelectingBook = false
                }) {
                    Text("Back")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(FocusDesign.handDrawnBorder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                        )
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 16)

            Text("Choose a book to read")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .padding(.top, 16)

            TextField("Book title", text: $tempBookTitle)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
                .font(.title3)
                .foregroundStyle(FocusDesign.handDrawnBorder)

                .padding(.horizontal, 32)

            TextField("Starting page", text: $tempStartingPage)
                .keyboardType(.numberPad)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
                .font(.title3)
                .foregroundStyle(FocusDesign.handDrawnBorder)

                .padding(.horizontal, 32)

            let canStart = sessionStore.canStartSession(bookTitle: tempBookTitle, startingPage: tempStartingPage)

            Button(action: {
                let title = tempBookTitle.trimmingCharacters(in: .whitespaces)
                let startPage = Int(tempStartingPage.trimmingCharacters(in: .whitespaces))
                tempBookTitle = ""
                tempStartingPage = ""
                sessionStore.startSession(bookTitle: title, startingPage: startPage)
                isSelectingBook = false
            }) {
                Text("Start session")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(canStart ? FocusDesign.handDrawnBorder : FocusDesign.handDrawnBorder.opacity(0.3))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(canStart ? FocusDesign.kiwi : FocusDesign.kiwi.opacity(0.3))
                            .overlay(Capsule().stroke(FocusDesign.handDrawnBorder.opacity(canStart ? 1 : 0.3), lineWidth: 3))
                    )
                    .background(
                        Capsule()
                            .fill(FocusDesign.handDrawnBorder.opacity(canStart ? 1 : 0.3))
                            .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canStart)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var startSessionView: some View {
        ScrollView {
            VStack(spacing: 0) {
                startSessionButton
                speedReadingButton
                uploadFilesButton
                if speedReadingViewModel.isUploading {
                    ProgressView("Uploading...")
                        .padding(.top, 12)
                }
                if let message = speedReadingViewModel.uploadMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(FocusDesign.handDrawnBorder)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
    }

    private var startSessionButton: some View {
        Button(action: {
            showingSpeedReading = true
        }) {
            Text("start")
                .font(.system(size: 36, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .frame(width: 256, height: 256)
                .background(
                    Circle()
                        .fill(FocusDesign.tan)
                        .overlay(Circle().stroke(FocusDesign.handDrawnBorder, lineWidth: 4))
                )
                .background(
                    Circle()
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 32)
    }

    private var speedReadingButton: some View {
        Button(action: { isSelectingBook = true }) {
            Text("Start session")
                .font(.system(size: 20, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .frame(width: 220)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(FocusDesign.uiTeal)
                        .overlay(Capsule().stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    Capsule()
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 32)
    }

    private var uploadFilesButton: some View {
        Button("upload book") {
            showFilePicker = true
        }
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(FocusDesign.handDrawnBorder)
        .frame(width: 220)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(FocusDesign.uiTeal)
                .overlay(Capsule().stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
        )
        .background(
            Capsule()
                .fill(FocusDesign.handDrawnBorder)
                .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
        )
        .buttonStyle(ReadButtonPressStyle())
        .disabled(speedReadingViewModel.isUploading)
        .padding(.top, 20)
    }

    private var activeSessionView: some View {
        VStack(spacing: 0) {
            Spacer()


            Text(formattedTime)
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(FocusDesign.handDrawnBorder)

            if let book = sessionStore.bookTitle {
                Text("You are reading \(book)")
                    .font(.title2)
                    .foregroundStyle(FocusDesign.uiTeal)
                    .padding(.top, 8)
            }

            if sessionStore.status == .paused {
                Text("Get back to it!")
                    .font(.title3)
                    .foregroundStyle(FocusDesign.kiwi)
                    .padding(.top, 8)
            }


            Spacer()

            sessionControls
        }
        .sheet(isPresented: $showEndPageSheet) {
            endPageSheet
        }
    }

    private var endPageSheet: some View {
        let endPage = Int(tempEndingPage.trimmingCharacters(in: .whitespaces))
        let canSubmit = sessionStore.canSubmitEndPage(tempEndingPage)

        return VStack(spacing: 32) {
            HStack {
                Spacer()
                Button(action: {
                    tempEndingPage = ""
                    showEndPageSheet = false
                    if sessionStore.status == .paused { sessionStore.togglePause() }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FocusDesign.handDrawnBorder)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .overlay(Circle().stroke(FocusDesign.handDrawnBorder, lineWidth: 2))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)

            Text("What page did you end on?")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            TextField("Ending page", text: $tempEndingPage)
                .keyboardType(.numberPad)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
                .font(.title3)
                .foregroundStyle(FocusDesign.handDrawnBorder)

                .padding(.horizontal, 32)

            if let end = endPage, let start = sessionStore.startingPage, end <= start {
                Text("Must be greater than starting page (\(start))")
                    .font(.footnote)
                    .foregroundStyle(Color.red.opacity(0.7))
            }

            Toggle(isOn: $didFinishBook) {
                Text("I finished this book")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(FocusDesign.handDrawnBorder)
            }
            .padding(.horizontal, 32)
            .tint(FocusDesign.kiwi)

            Button(action: {
                let endPage = Int(tempEndingPage.trimmingCharacters(in: .whitespaces))
                let bookTitle = sessionStore.bookTitle
                let finished = didFinishBook
                tempEndingPage = ""
                didFinishBook = false
                showEndPageSheet = false
                sessionStore.stopSession(endingPage: endPage)
                if finished, let title = bookTitle {
                    Task { await challengeViewModel.markBookCompleted(title: title) }
                }
            }) {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(canSubmit ? FocusDesign.handDrawnBorder : FocusDesign.handDrawnBorder.opacity(0.3))
                    .frame(width: 280, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canSubmit ? FocusDesign.kiwi : FocusDesign.kiwi.opacity(0.3))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder.opacity(canSubmit ? 1 : 0.3), lineWidth: 3))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(FocusDesign.uiBg)
        .presentationDetents([.medium])
        .interactiveDismissDisabled(true)
    }

    private var sessionControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button(sessionStore.status == .paused ? "Resume" : "Pause") {
                    sessionStore.togglePause()
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .frame(width: 140, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )

                Button("Stop") {
                    // Freeze the timer now so the sheet doesn't add extra seconds.
                    if sessionStore.status == .active { sessionStore.togglePause() }
                    showEndPageSheet = true
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .frame(width: 140, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
            }

        }
        .padding(.bottom, 80)
    }

    private var completionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                completionHeader
                readingTimeSummary

                if didSaveReflection {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(FocusDesign.kiwi)
                        Text("Reflection saved")
                            .font(.subheadline).fontWeight(.bold)
                    }
                    .foregroundStyle(FocusDesign.handDrawnBorder)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(FocusDesign.kiwi.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(FocusDesign.kiwi, lineWidth: 2))
                    )
                    .sketchShadow()
                } else {
                    Button(action: { showingReflectionCapture = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .bold))
                            Text("Reflect on this session")
                                .font(.subheadline).fontWeight(.bold)
                        }
                        .foregroundStyle(FocusDesign.handDrawnBorder)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(FocusDesign.handDrawnBorder, lineWidth: 2))
                        )
                        .sketchShadow()
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(FocusDesign.handDrawnBorder)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
            )
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var completionHeader: some View {
        HStack {
            Button("close") {
                sessionStore.closeCompletion()
                challengeViewModel.clearRecentlyCompleted()
                Task { await recommendationsStore.load() }
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(FocusDesign.handDrawnBorder)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
            )
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var readingTimeSummary: some View {
        VStack(spacing: 8) {
            Text("You read")
                .font(.title2)
                .foregroundStyle(FocusDesign.handDrawnBorder)
            Text("for")
                .font(.title3)
                .foregroundStyle(FocusDesign.handDrawnBorder)
            Text(formattedCompletedTime)
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(FocusDesign.handDrawnBorder)
            Text("time")
                .font(.title)
                .foregroundStyle(FocusDesign.handDrawnBorder)
            if let pages = sessionStore.completedPagesRead {
                Text("\(pages) pages")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(FocusDesign.uiTeal)
                    .padding(.top, 4)
            }
        }
        .frame(width: 280, height: 280)
        .background(
            Circle()
                .fill(FocusDesign.kiwi.opacity(0.6))
                .overlay(Circle().stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
        )
        .background(
            Circle()
                .fill(FocusDesign.handDrawnBorder)
                .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
        )
    }

    private var challengeProgressSection: some View {
        let allChallenges = challengeViewModel.activeChallenges + challengeViewModel.recentlyCompleted
        return VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Progress:")
                .font(.headline)
                .fontWeight(.black)
                .foregroundStyle(FocusDesign.handDrawnBorder)

            if allChallenges.isEmpty {
                Text("No active challenges — join one in the Challenges tab!")
                    .font(.subheadline)
                    .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.5))
                    .padding(.leading, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(allChallenges) { challenge in
                        let isCompleted = challenge.state == .completed
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(challenge.title)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(FocusDesign.handDrawnBorder)
                                Spacer()
                                if isCompleted {
                                    Text("Completed!")
                                        .font(.caption)
                                        .fontWeight(.black)
                                        .foregroundStyle(FocusDesign.kiwi)
                                }
                            }
                            Rectangle()
                                .fill(FocusDesign.handDrawnBorder.opacity(0.15))
                                .frame(height: 6)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(FocusDesign.kiwi)
                                        .frame(height: 6)
                                        .scaleEffect(x: challenge.progress, y: 1, anchor: .leading)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            Text(challenge.progressLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.7))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isCompleted ? FocusDesign.kiwi.opacity(0.08) : Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                    isCompleted ? FocusDesign.kiwi : FocusDesign.handDrawnBorder,
                                    lineWidth: isCompleted ? 2 : 2
                                ))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var formattedTime: String {
        let minutes = sessionStore.elapsedSeconds / 60
        let seconds = sessionStore.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedCompletedTime: String {
        let minutes = sessionStore.completedSeconds / 60
        let seconds = sessionStore.completedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

}

#Preview {
    ReadView()
}
