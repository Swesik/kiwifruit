import SwiftUI

private enum MoodCaptureDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    // Distinct mood colors: blue (focused), yellow (inspired), lavender (tired).
    static let moodFocused = Color(hex: "DBEAFE")   // light blue
    static let moodInspired = Color(hex: "FEF9C3")  // warm yellow
    static let moodTired    = Color(hex: "EDE9FE")  // soft lavender
}

struct MoodCaptureSheet: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @Environment(\.dismiss) private var dismiss

    let bookTitle: String?
    let duration: String
    let durationSeconds: Int
    var pagesRead: Int? = nil
    /// Face-detection result from the mood camera; nil if manual entry.
    var suggestedMood: QuickMood? = nil
    var suggestedConfidencePercent: Int? = nil
    let onSkip: () -> Void
    let updateExisting: Bool

    @State private var viewModel: MoodCaptureViewModel

    @State private var selectedMood: QuickMood? = nil
    @State private var showReflection = false
    @State private var reflectionTitle: String = ""
    @State private var reflectionText: String = ""

    init(
        bookTitle: String?,
        duration: String,
        durationSeconds: Int,
        pagesRead: Int? = nil,
        suggestedMood: QuickMood? = nil,
        suggestedConfidencePercent: Int? = nil,
        onSkip: @escaping () -> Void,
        updateExisting: Bool,
        viewModel: MoodCaptureViewModel = MoodCaptureViewModel()
    ) {
        self.bookTitle = bookTitle
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.pagesRead = pagesRead
        self.suggestedMood = suggestedMood
        self.suggestedConfidencePercent = suggestedConfidencePercent
        self.onSkip = onSkip
        self.updateExisting = updateExisting
        self._viewModel = State(wrappedValue: viewModel)
    }

    @AppStorage("kiwifruit.settings.reflectionEntry.moodSessionsEnabled") private var reflectionEntryMoodSessionsEnabled: Bool = true

    var body: some View {
        if showReflection {
            reflectionView
        } else {
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
                        Image(systemName: moodSymbol(mood))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(MoodCaptureDesign.uiText)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(mood.displayName)
                                    .font(.title2).fontWeight(.black)
                                    .foregroundColor(MoodCaptureDesign.uiText)
                                if let pct = suggestedConfidencePercent {
                                    Text("· \(pct)%")
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
        case .focused: return MoodCaptureDesign.moodFocused
        case .inspired: return MoodCaptureDesign.moodInspired
        case .tired: return MoodCaptureDesign.moodTired
        }
    }

    private func moodDescription(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "Calm and concentrated"
        case .inspired: return "Happy and energized"
        case .tired: return "Low energy"
        }
    }

    private func moodSymbol(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "brain.head.profile"
        case .inspired: return "sparkles"
        case .tired: return "moon.zzz.fill"
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

        if reflectionEntryMoodSessionsEnabled {
            showReflection = true
        } else {
            dismiss()
        }
    }

    // MARK: - Reflection

    private var reflectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reflect")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(MoodCaptureDesign.uiText)
                .padding(.top, 24)

            if viewModel.isLoadingPrompt {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating prompt...")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(MoodCaptureDesign.uiText.opacity(0.6))
                }
                .padding(.vertical, 32)
            } else {
                TextField("Title (optional)", text: $reflectionTitle)
                    .textFieldStyle(.plain)
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodCaptureDesign.border.opacity(0.3), lineWidth: 1.5))

                Text(viewModel.reflectionPrompt)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(MoodCaptureDesign.uiText.opacity(0.7))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MoodCaptureDesign.kiwiLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodCaptureDesign.border.opacity(0.3), lineWidth: 1.5))

                TextEditor(text: $reflectionText)
                    .font(.subheadline)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MoodCaptureDesign.border.opacity(0.3), lineWidth: 1.5)
                    )

                Button {
                    Task {
                        await viewModel.saveReflection(
                            bookTitle: bookTitle,
                            title: reflectionTitle,
                            response: reflectionText,
                            mood: selectedMood?.rawValue,
                            durationSeconds: durationSeconds
                        )
                        dismiss()
                    }
                } label: {
                    Text(viewModel.isSavingReflection ? "Saving..." : "Save Reflection")
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(reflectionText.isEmpty ? MoodCaptureDesign.uiText.opacity(0.3) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(reflectionText.isEmpty ? MoodCaptureDesign.kiwi.opacity(0.3) : MoodCaptureDesign.kiwi)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(MoodCaptureDesign.border.opacity(reflectionText.isEmpty ? 0.3 : 1), lineWidth: 2)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(reflectionText.isEmpty || viewModel.isSavingReflection)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Skip")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(MoodCaptureDesign.uiText.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .padding(24)
        .background(Color.white)
        .task {
            await viewModel.loadPrompt(
                bookTitle: bookTitle,
                durationSeconds: durationSeconds,
                pagesRead: pagesRead,
                mood: selectedMood?.rawValue
            )
        }
    }
}

#Preview {
    MoodCaptureSheet(
        bookTitle: "The Great Gatsby",
        duration: "45 minutes",
        durationSeconds: 2700,
        suggestedMood: .focused,
        suggestedConfidencePercent: 72,
        onSkip: {},
        updateExisting: false
    )
}
