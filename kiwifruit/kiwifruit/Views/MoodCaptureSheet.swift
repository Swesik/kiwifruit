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
    /// Face-detection result from the mood camera; nil if manual entry.
    var suggestedMood: QuickMood? = nil
    var suggestedConfidencePercent: Int? = nil
    let onSkip: () -> Void
    let updateExisting: Bool

    @State private var selectedMood: QuickMood? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if suggestedMood != nil {
                detectedMoodSection
            } else {
                moodSelectionSection
            }
            Spacer()
            actionButtons
        }
        .padding(24)
        .background(Color.white)
        .onAppear {
            selectedMood = suggestedMood
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestedMood != nil ? "We detected:" : "How did you feel?")
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

    // MARK: - Detected Mood (camera path)

    private var detectedMoodSection: some View {
        VStack(spacing: 16) {
            // Primary card — pre-selected, prominent.
            if let mood = suggestedMood {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedMood = mood }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(mood.displayName)
                                    .font(.title2).fontWeight(.black)
                                    .foregroundColor(MoodCaptureDesign.uiText)
                                if let pct = suggestedConfidencePercent {
                                    Text("· \(pct)% confident")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundColor(MoodCaptureDesign.kiwi)
                                }
                            }
                            Text(moodDescription(mood))
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(MoodCaptureDesign.uiText.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(MoodCaptureDesign.kiwi)
                    }
                    .padding(20)
                    .background(moodCardColor(mood))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MoodCaptureDesign.border, lineWidth: 2))
                    .sketchShadow()
                }
                .buttonStyle(.plain)
            }

            // Tap to change alternatives.
            VStack(alignment: .leading, spacing: 4) {
                Text("Not you? Tap to change:")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(MoodCaptureDesign.uiText.opacity(0.5))

                ForEach(QuickMood.allCases) { mood in
                    if mood != suggestedMood {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedMood = mood }
                        } label: {
                            HStack {
                                Text(mood.displayName)
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundColor(MoodCaptureDesign.uiText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(MoodCaptureDesign.uiText.opacity(0.4))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(selectedMood == mood ? moodCardColor(mood) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MoodCaptureDesign.border.opacity(selectedMood == mood ? 1 : 0.25), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Mood Selection (manual path — no camera suggestion)

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
                Text(selectedMood != nil ? "Confirm" : "Save")
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(selectedMood != nil ? .white : MoodCaptureDesign.uiText.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedMood != nil ? MoodCaptureDesign.kiwi : MoodCaptureDesign.kiwi.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
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
        suggestedMood: .focused,
        suggestedConfidencePercent: 72,
        onSkip: {},
        updateExisting: false
    )
}
