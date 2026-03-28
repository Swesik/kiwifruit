import SwiftUI

private enum MoodCaptureDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tealCard = Color(hex: "CFE6EC")
    static let tan = Color(hex: "D1BFAe")
}

struct MoodCaptureSheet: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @Environment(\.dismiss) private var dismiss

    let bookTitle: String?
    let duration: String
    let onSkip: () -> Void
    let updateExisting: Bool

    @State private var selectedMood: QuickMood? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            moodSelectionSection
            Spacer()
            actionButtons
        }
        .padding(24)
        .background(Color.white)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did you feel?")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(MoodCaptureDesign.uiText)

            if let book = bookTitle {
                Text("while reading \"\(book)\"")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(MoodCaptureDesign.uiText.opacity(0.6))
            }

            Text(duration)
                .font(.caption).fontWeight(.bold)
                .foregroundColor(MoodCaptureDesign.uiText.opacity(0.4))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Mood Selection

    private var moodSelectionSection: some View {
        VStack(spacing: 12) {
            ForEach(QuickMood.allCases) { mood in
                moodButton(mood: mood)
            }
        }
    }

    private func moodButton(mood: QuickMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMood = mood
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mood.displayName)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(MoodCaptureDesign.uiText)
                    Text(moodDescription(mood))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(MoodCaptureDesign.uiText.opacity(0.6))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(MoodCaptureDesign.uiText)
                }
            }
            .padding(16)
            .background(isSelected ? moodCardColor(mood) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? MoodCaptureDesign.border : MoodCaptureDesign.border.opacity(0.3), lineWidth: 2)
            )
            .sketchShadow()
        }
        .buttonStyle(.plain)
    }

    private func moodCardColor(_ mood: QuickMood) -> Color {
        switch mood {
        case .focused: return MoodCaptureDesign.tealCard
        case .inspired: return MoodCaptureDesign.kiwiLight
        case .tired: return Color(hex: "F5E6D3")
        }
    }

    private func moodDescription(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "Calm and concentrated"
        case .inspired: return "Happy and energized"
        case .tired: return "Low energy"
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveMood) {
                Text("Save")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(selectedMood != nil ? MoodCaptureDesign.uiText : MoodCaptureDesign.uiText.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedMood != nil ? MoodCaptureDesign.kiwi : MoodCaptureDesign.kiwi.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MoodCaptureDesign.border.opacity(selectedMood != nil ? 1 : 0.3), lineWidth: 2)
                            )
                    )
                    .sketchShadow()
            }
            .buttonStyle(.plain)
            .disabled(selectedMood == nil)

            Button {
                onSkip()
                dismiss()
            } label: {
                Text("Skip")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(MoodCaptureDesign.uiText.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Save

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
}

#Preview {
    MoodCaptureSheet(
        bookTitle: "The Great Gatsby",
        duration: "45 minutes",
        onSkip: {},
        updateExisting: false
    )
}
