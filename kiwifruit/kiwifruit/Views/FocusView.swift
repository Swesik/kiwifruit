import SwiftUI

private enum FocusDesign {
    static let kiwi = Color(hex: "A3C985")
    static let tan = Color(hex: "D1BFAe")
    static let uiTeal = Color(hex: "88C0D0")
    static let uiBg = Color(hex: "FAFAFA")
    static let handDrawnBorder = Color.black
    static let sketchOffset: CGFloat = 4
}

struct FocusView: View {
    @Environment(\.readingSessionStore) private var sessionStore: ReadingSessionStore
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.challengeViewModel) private var challengeViewModel: ChallengeViewModel

    @State private var isSelectingBook = false
    @State private var tempBookTitle = ""
    @State private var tempStartingPage = ""
    @State private var showEndPageSheet = false
    @State private var tempEndingPage = ""
    @State private var pendingJoinSession: ActiveFriendSession? = nil
    @State private var tempJoinBookTitle = ""
    @State private var tempJoinStartingPage = ""
    @State private var showingSpeedReading = false
    @State private var didFinishBook = false

    var body: some View {
        Group {
            if isSelectingBook {
                bookSelectionView
            } else if let joinSession = pendingJoinSession {
                joinSelectionView(for: joinSession)
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
            // Refresh every time the tab is switched to, so elapsed times stay reasonably fresh.
            sessionStore.loadFriendSessions()
        }
        .sheet(isPresented: $showingSpeedReading) { SpeedReadingView() }
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
                .colorScheme(.light)
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
                .colorScheme(.light)
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

    private func joinSelectionView(for friendSession: ActiveFriendSession) -> some View {
        let hostName = friendSession.session.host.displayName ?? friendSession.session.host.username
        let canJoin = sessionStore.canJoinSession(bookTitle: tempJoinBookTitle, startingPage: tempJoinStartingPage)

        return VStack(spacing: 32) {
            HStack {
                Button(action: {
                    tempJoinBookTitle = ""
                    tempJoinStartingPage = ""
                    pendingJoinSession = nil
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

            Text("Joining \(hostName)'s session")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            TextField("Book title", text: $tempJoinBookTitle)
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
                .colorScheme(.light)
                .padding(.horizontal, 32)

            TextField("Starting page", text: $tempJoinStartingPage)
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
                .colorScheme(.light)
                .padding(.horizontal, 32)

            Button(action: {
                let title = tempJoinBookTitle.trimmingCharacters(in: .whitespaces)
                let startPage = Int(tempJoinStartingPage.trimmingCharacters(in: .whitespaces))
                tempJoinBookTitle = ""
                tempJoinStartingPage = ""
                pendingJoinSession = nil
                sessionStore.joinSession(friendSession, bookTitle: title, startingPage: startPage)
            }) {
                Text("Join session")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(canJoin ? FocusDesign.handDrawnBorder : FocusDesign.handDrawnBorder.opacity(0.3))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(canJoin ? FocusDesign.kiwi : FocusDesign.kiwi.opacity(0.3))
                            .overlay(Capsule().stroke(FocusDesign.handDrawnBorder.opacity(canJoin ? 1 : 0.3), lineWidth: 3))
                    )
                    .background(
                        Capsule()
                            .fill(FocusDesign.handDrawnBorder.opacity(canJoin ? 1 : 0.3))
                            .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canJoin)

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
                joinSection
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                sessionStore.loadFriendSessions()
            }
        }
    }

    private var startSessionButton: some View {
        Button(action: {
            isSelectingBook = true
        }) {
            Text("Start\nsession")
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
        Button(action: { showingSpeedReading = true }) {
            Text("launch speed reading")
                .font(.system(size: 20, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(FocusDesign.handDrawnBorder)
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

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Join :")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .padding(.top, 48)

            if sessionStore.activeFriendSessions.isEmpty {
                Text("No friends reading right now")
                    .font(.subheadline)
                    .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.4))
                    .padding(.leading, 16)
            } else {
                ForEach(sessionStore.activeFriendSessions) { friendSession in
                    friendSessionRow(friendSession: friendSession)
                        .onTapGesture {
                            pendingJoinSession = friendSession
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private func friendSessionRow(friendSession: ActiveFriendSession) -> some View {
        let name = friendSession.session.host.displayName ?? friendSession.session.host.username
        let minutes = friendSession.hostElapsedSeconds / 60
        let duration = minutes >= 60 ? "\(minutes / 60)hr" : "\(minutes)m"

        return Text(name)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(FocusDesign.handDrawnBorder)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.leading, 40) // 56 avatar - 28 overlap + 12 gap
            .padding(.trailing, 90) // clear the 80pt timer circle + 10pt offset
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(FocusDesign.handDrawnBorder)
                    .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
            )
            .padding(.leading, 28) // shift pill right so avatar covers its left edge
            .overlay {
                HStack {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(FocusDesign.handDrawnBorder, lineWidth: 4))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(FocusDesign.handDrawnBorder)
                        )
                        .background(
                            Circle()
                                .fill(FocusDesign.handDrawnBorder)
                                .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                        )

                    Spacer(minLength: 0)

                    Text(duration)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(FocusDesign.handDrawnBorder)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(FocusDesign.kiwi)
                                .overlay(Circle().stroke(FocusDesign.handDrawnBorder, lineWidth: 4))
                        )
                        .background(
                            Circle()
                                .fill(FocusDesign.handDrawnBorder)
                                .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                        )
                        .offset(x: 10)
                }
                .frame(height: 80)
            }
            .frame(maxWidth: 280)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
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

            if !sessionStore.otherParticipants(currentUserId: session.currentUser?.id).isEmpty {
                participantsRow
                    .padding(.top, 24)
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
                .colorScheme(.light)
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

            Button("Done") {
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
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(canSubmit ? FocusDesign.handDrawnBorder : FocusDesign.handDrawnBorder.opacity(0.3))
            .frame(width: 280, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSubmit ? FocusDesign.kiwi : FocusDesign.kiwi.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder.opacity(canSubmit ? 1 : 0.3), lineWidth: 3))
            )
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(FocusDesign.uiBg)
        .presentationDetents([.medium])
        .interactiveDismissDisabled(true)
    }

    private var participantsRow: some View {
        VStack(spacing: 8) {
            Text("Reading with")
                .font(.subheadline)
                .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.6))

            HStack(spacing: -12) {
                ForEach(sessionStore.otherParticipants(currentUserId: session.currentUser?.id)) { user in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(FocusDesign.handDrawnBorder)
                        )
                        .background(
                            Circle()
                                .fill(FocusDesign.handDrawnBorder)
                                .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                        )
                }
            }

            let names = sessionStore.otherParticipants(currentUserId: session.currentUser?.id).map { $0.displayName ?? $0.username }.joined(separator: ", ")
            Text(names)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(FocusDesign.handDrawnBorder)
        }
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

            Button("mood session") {}
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .frame(width: 300, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FocusDesign.kiwi)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FocusDesign.handDrawnBorder)
                        .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                )
        }
        .padding(.bottom, 80)
    }

    private var completionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                completionHeader
                readingTimeSummary

                Button("mood session stats") {}
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(FocusDesign.handDrawnBorder)
                    .frame(width: 300, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FocusDesign.kiwi)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FocusDesign.handDrawnBorder)
                            .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                    )

                challengeProgressSection

                Spacer()
                    .frame(height: 40)
            }
        }
        .task { await challengeViewModel.updateProgress() }
        .alert("Session not saved", isPresented: Binding(
            get: { sessionStore.saveError != nil },
            set: { if !$0 { sessionStore.saveError = nil } }
        )) {
            Button("OK") { sessionStore.saveError = nil }
        } message: {
            Text(sessionStore.saveError ?? "")
        }
    }

    private var completionHeader: some View {
        HStack {
            Button("close") {
                sessionStore.closeCompletion()
                challengeViewModel.clearRecentlyCompleted()
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
    FocusView()
}
