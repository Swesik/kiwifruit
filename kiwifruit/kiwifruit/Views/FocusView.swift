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
    @Environment(\.focusSessionStore) private var sessionStore: FocusSessionStore
    @Environment(\.sessionStore) private var session: SessionStore

    @State private var isSelectingBook = false
    @State private var tempBookTitle = ""

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
            }
        }
        .background(FocusDesign.uiBg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Refresh every time the tab is switched to, so elapsed times stay reasonably fresh.
            sessionStore.loadFriendSessions()
        }
    }

    private var bookSelectionView: some View {
        VStack(spacing: 32) {
            Text("Choose a book to read")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(FocusDesign.handDrawnBorder)
                .padding(.top, 48)

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

            Button(action: {
                let title = tempBookTitle.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return }
                tempBookTitle = ""
                sessionStore.startSession(bookTitle: title)
                isSelectingBook = false
            }) {
                Text("Start session")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(FocusDesign.handDrawnBorder)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(FocusDesign.kiwi)
                            .overlay(Capsule().stroke(FocusDesign.handDrawnBorder, lineWidth: 3))
                    )
                    .background(
                        Capsule()
                            .fill(FocusDesign.handDrawnBorder)
                            .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                    )
            }
            .buttonStyle(.plain)

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
        Button(action: {}) {
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
                            sessionStore.joinSession(friendSession)
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

            if !otherParticipants.isEmpty {
                participantsRow
                    .padding(.top, 24)
            }

            Spacer()

            sessionControls
        }
    }

    /// People to show in "Reading with":
    /// - If you're the host: everyone who joined (excluding yourself).
    /// - If you joined: the host + everyone else who joined (excluding yourself).
    private var otherParticipants: [User] {
        let myId = session.currentUser?.id
        let joiners = sessionStore.participants.filter { $0.id != myId }
        if sessionStore.isHost {
            return joiners
        } else {
            // Prepend the host so joiners always see who they're reading with.
            if let host = sessionStore.currentSession?.host {
                return [host] + joiners
            }
            return joiners
        }
    }

    private var participantsRow: some View {
        VStack(spacing: 8) {
            Text("Reading with")
                .font(.subheadline)
                .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.6))

            HStack(spacing: -12) {
                ForEach(otherParticipants) { user in
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

            let names = otherParticipants.map { $0.displayName ?? $0.username }.joined(separator: ", ")
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
                    sessionStore.stopSession()
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
    }

    private var completionHeader: some View {
        HStack {
            Button("close") {
                sessionStore.closeCompletion()
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Progress:")
                .font(.headline)
                .fontWeight(.black)
                .foregroundStyle(FocusDesign.handDrawnBorder)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline)
                        .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.8))

                    Slider(value: .constant(0.3), in: 0...1)
                        .disabled(true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder, lineWidth: 2))
                )
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
