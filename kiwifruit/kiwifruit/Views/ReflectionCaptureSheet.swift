import SwiftUI

private enum ReflectionDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
}

struct ReflectionCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    let bookTitle: String?
    let durationSeconds: Int?
    var pagesRead: Int? = nil
    var onSave: (() -> Void)? = nil

    @State private var viewModel: ReflectionCaptureViewModel
    @State private var reflectionTitle: String = ""
    @State private var reflectionText: String = ""

    init(
        bookTitle: String?,
        durationSeconds: Int?,
        pagesRead: Int? = nil,
        onSave: (() -> Void)? = nil,
        viewModel: ReflectionCaptureViewModel = ReflectionCaptureViewModel()
    ) {
        self.bookTitle = bookTitle
        self.durationSeconds = durationSeconds
        self.pagesRead = pagesRead
        self.onSave = onSave
        self._viewModel = State(wrappedValue: viewModel)
    }

    private var canSave: Bool {
        !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isSavingReflection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reflect")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(ReflectionDesign.uiText)
                .padding(.top, 24)

            if viewModel.isLoadingPrompt {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating prompt...")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(ReflectionDesign.uiText.opacity(0.6))
                }
                .padding(.vertical, 32)
            } else {
                TextField("Title (optional)", text: $reflectionTitle)
                    .textFieldStyle(.plain)
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ReflectionDesign.border.opacity(0.3), lineWidth: 1.5))

                Text(viewModel.reflectionPrompt)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(ReflectionDesign.uiText.opacity(0.7))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ReflectionDesign.kiwiLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ReflectionDesign.border.opacity(0.3), lineWidth: 1.5))

                TextEditor(text: $reflectionText)
                    .font(.subheadline)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ReflectionDesign.border.opacity(0.3), lineWidth: 1.5)
                    )

                Button {
                    Task {
                        let saved = await viewModel.saveReflection(
                            bookTitle: bookTitle,
                            title: reflectionTitle,
                            response: reflectionText,
                            durationSeconds: durationSeconds
                        )
                        if saved { onSave?() }
                        dismiss()
                    }
                } label: {
                    Text(viewModel.isSavingReflection ? "Saving..." : "Save Reflection")
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(canSave ? .white : ReflectionDesign.uiText.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canSave ? ReflectionDesign.kiwi : ReflectionDesign.kiwi.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ReflectionDesign.border.opacity(canSave ? 1 : 0.3), lineWidth: 2)
                                )
                        )
                        .sketchShadow()
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Skip")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(ReflectionDesign.uiText.opacity(0.4))
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
                pagesRead: pagesRead
            )
        }
    }
}

#Preview {
    ReflectionCaptureSheet(bookTitle: "The Great Gatsby", durationSeconds: 2700)
}
