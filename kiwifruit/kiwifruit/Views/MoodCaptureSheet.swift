import SwiftUI

struct MoodCaptureSheet: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @Environment(\.dismiss) private var dismiss

    let bookTitle: String?
    let duration: String
    let onSkip: () -> Void
    /// If true, updates the last saved session's mood instead of creating a new one
    let updateExisting: Bool

    @State private var selectedMood: QuickMood? = nil

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            moodSelectionSection
            actionButtons
            Spacer()
        }
        .padding(24)
        .background(FocusDesign.uiBg)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "face.smiling")
                .font(.system(size: 48))
                .foregroundStyle(FocusDesign.kiwi)

            Text("How did you feel?")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(FocusDesign.handDrawnBorder)

            if let book = bookTitle {
                Text("while reading \"\(book)\"")
                    .font(.subheadline)
                    .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.6))
            }

            Text("for \(duration)")
                .font(.caption)
                .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.4))
        }
        .padding(.top, 20)
    }

    private var moodSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(QuickMood.allCases) { mood in
                moodButton(mood: mood)
            }
        }
        .padding(.horizontal, 16)
    }

    private func moodButton(mood: QuickMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            selectedMood = mood
        } label: {
            HStack(spacing: 16) {
                Image(systemName: moodIcon(mood))
                    .font(.system(size: 28))
                    .foregroundStyle(moodColor(mood))
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(moodColor(mood).opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(mood.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(FocusDesign.handDrawnBorder)

                    Text(moodDescription(mood))
                        .font(.caption)
                        .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.5))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(FocusDesign.kiwi)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? FocusDesign.kiwi : FocusDesign.handDrawnBorder.opacity(0.2), lineWidth: isSelected ? 3 : 1)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FocusDesign.handDrawnBorder)
                    .offset(x: FocusDesign.sketchOffset, y: FocusDesign.sketchOffset)
                    .opacity(isSelected ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                saveMood()
            } label: {
                Text("Save")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(selectedMood != nil ? FocusDesign.handDrawnBorder : FocusDesign.handDrawnBorder.opacity(0.3))
                    .frame(width: 280, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedMood != nil ? FocusDesign.kiwi : FocusDesign.kiwi.opacity(0.3))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FocusDesign.handDrawnBorder.opacity(selectedMood != nil ? 1 : 0.3), lineWidth: 3))
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedMood == nil)

            Button {
                onSkip()
                dismiss()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(FocusDesign.handDrawnBorder.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private func saveMood() {
        guard let mood = selectedMood else { return }

        if updateExisting {
            moodStore.updateMostRecentSessionMood(mood)
        } else {
            let session = MoodMapSession(
                startedAt: Date().addingTimeInterval(-600),
                endedAt: Date(),
                postSessionMood: mood
            )
            moodStore.saveSession(session)
        }

        dismiss()
    }

    private func moodIcon(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "target"
        case .inspired: return "sparkles"
        case .tired: return "zzz"
        }
    }

    private func moodColor(_ mood: QuickMood) -> Color {
        switch mood {
        case .focused: return Color(hex: "88C0D0")
        case .inspired: return Color(hex: "A3C985")
        case .tired: return Color(hex: "D1BFAe")
        }
    }

    private func moodDescription(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "Calm and concentrated"
        case .inspired: return "Happy and energized"
        case .tired: return "Low energy"
        }
    }
}

private enum FocusDesign {
    static let kiwi = Color(hex: "A3C985")
    static let tan = Color(hex: "D1BFAe")
    static let uiTeal = Color(hex: "88C0D0")
    static let uiBg = Color(hex: "FAFAFA")
    static let handDrawnBorder = Color.black
    static let sketchOffset: CGFloat = 4
}

#Preview {
    MoodCaptureSheet(
        bookTitle: "The Great Gatsby",
        duration: "45 minutes",
        onSkip: {},
        updateExisting: false
    )
}
