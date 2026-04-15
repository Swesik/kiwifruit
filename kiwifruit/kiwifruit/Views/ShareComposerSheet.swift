import SwiftUI

private enum ShareDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let teal = Color(hex: "88C0D0")
    static let inputBg = Color(hex: "F9FAFB")   // gray-50
    static let disabledBg = Color(hex: "D1D5DB") // gray-300
    static let subtleText = Color(hex: "718096")  // gray-600
}

struct ShareComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sessionStore) private var session
    @Environment(\.postsStore) private var postsStore

    @State private var viewModel = ShareComposerViewModel()
    @State private var showingSessionPicker = false

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        tabSwitcher(vm: vm)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 16)

                        content(vm: vm)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }
                }

                submitButton(vm: vm)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        Color.white
                            .overlay(alignment: .top) { Divider() }
                    )
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ShareDesign.subtleText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Share")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(ShareDesign.uiText)
                }
            }
            .onChange(of: vm.shareType) { _, newValue in
                if newValue == .reflection {
                    Task { await loadReflectionDeps() }
                }
            }
            .task {
                if vm.shareType == .reflection {
                    await loadReflectionDeps()
                }
            }
            .sheet(isPresented: $showingSessionPicker) {
                sessionPickerSheet(vm: vm)
            }
        }
    }

    private func loadReflectionDeps() async {
        await viewModel.loadPromptIfNeeded()
        await viewModel.loadPastReflectionsIfNeeded(currentUsername: session.currentUser?.username)
        await viewModel.loadPastSessionsIfNeeded()
    }

    // MARK: - Tab Switcher

    private func tabSwitcher(vm: ShareComposerViewModel) -> some View {
        HStack(spacing: 8) {
            ForEach(ShareComposerViewModel.ShareType.allCases) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { vm.shareType = type }
                } label: {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ShareDesign.uiText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(vm.shareType == type ? ShareDesign.kiwi : Color(hex: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ShareDesign.border, lineWidth: vm.shareType == type ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: ShareComposerViewModel) -> some View {
        switch vm.shareType {
        case .bookRec:
            VStack(alignment: .leading, spacing: 16) {
                fieldLabel("Book Title *")
                fieldInput("Enter book title...", text: $viewModel.bookTitle)

                fieldLabel("Why do you recommend it?")
                fieldTextArea("Share your thoughts...", text: $viewModel.bookRecText)
            }

        case .question:
            VStack(alignment: .leading, spacing: 16) {
                fieldLabel("Your Question *")
                fieldTextArea("What would you like to ask the community?", text: $viewModel.questionText)
            }

        case .reflection:
            VStack(alignment: .leading, spacing: 16) {
                reflectionModePicker(vm: vm)
                visibilityPicker(vm: vm)

                if vm.reflectionMode == .past {
                    pastReflectionsContent(vm: vm)
                } else {
                    newReflectionContent(vm: vm)
                }
            }
        }
    }

    // MARK: - Session attach (New Reflection mode)

    private func sessionAttachSection(vm: ShareComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Attach a session (optional)")

            if let s = vm.attachedSession {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.bookTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ShareDesign.uiText)
                        Text(sessionMetaLine(s))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ShareDesign.subtleText)
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.detachSession() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ShareDesign.subtleText)
                            .padding(6)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(ShareDesign.border.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "E6F0DC"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border, lineWidth: 2))
            } else {
                Button {
                    showingSessionPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 12, weight: .bold))
                        Text(vm.pastSessions.isEmpty ? "No past sessions yet" : "Choose a session")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(vm.pastSessions.isEmpty ? ShareDesign.subtleText : ShareDesign.uiText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ShareDesign.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border.opacity(0.5), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(vm.pastSessions.isEmpty || vm.isLoadingPastSessions)
            }
        }
    }

    private func sessionMetaLine(_ s: SessionHistoryEntry) -> String {
        let minutes = max(1, s.durationSeconds / 60)
        var parts = ["\(minutes) min"]
        if let p = s.pagesRead, p > 0 { parts.append("\(p) pages") }
        if let m = s.mood, !m.isEmpty { parts.append(m) }
        return parts.joined(separator: " \u{2022} ")
    }

    // MARK: - Reflection Mode Picker

    private func reflectionModePicker(vm: ShareComposerViewModel) -> some View {
        HStack(spacing: 8) {
            ForEach(ShareComposerViewModel.ReflectionMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { vm.reflectionMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ShareDesign.uiText)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(vm.reflectionMode == mode ? ShareDesign.kiwi : Color(hex: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ShareDesign.border, lineWidth: vm.reflectionMode == mode ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Visibility Picker

    private func visibilityPicker(vm: ShareComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Visibility")

            HStack(spacing: 8) {
                ForEach(ShareComposerViewModel.ReflectionVisibility.allCases) { vis in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.reflectionVisibility = vis }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: vis.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(vis.rawValue)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(ShareDesign.uiText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(vm.reflectionVisibility == vis ? ShareDesign.kiwi : Color(hex: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ShareDesign.border, lineWidth: vm.reflectionVisibility == vis ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Past Reflections

    private func pastReflectionsContent(vm: ShareComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Select Reflection")

            if vm.isLoadingPastReflections {
                simpleInfoCard {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading...")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(ShareDesign.subtleText)
                    }
                }
            } else if vm.pastReflections.isEmpty {
                simpleInfoCard {
                    Text("No reflections found")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(ShareDesign.subtleText)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.pastReflections) { r in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedPastReflectionId = (vm.selectedPastReflectionId == r.id) ? nil : r.id
                            }
                        } label: {
                            pastReflectionCard(r, isSelected: vm.selectedPastReflectionId == r.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func pastReflectionCard(_ r: Reflection, isSelected: Bool) -> some View {
        let title = r.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Reflection"
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ShareDesign.uiText)
            Text("\(r.bookTitle) \u{2022} \(r.visibility)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ShareDesign.subtleText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? ShareDesign.kiwiLight : ShareDesign.inputBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? ShareDesign.border : ShareDesign.border.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: - New Reflection

    private func newReflectionContent(vm: ShareComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionAttachSection(vm: vm)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Book Title")
                fieldInput("Optional book reference...", text: $viewModel.bookTitle)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Title")
                fieldInput("Give your reflection a title...", text: $viewModel.reflectionTitle)
            }

            if vm.isLoadingPrompt {
                promptCard {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Generating prompt...")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(ShareDesign.subtleText)
                    }
                }
            } else if !vm.reflectionPrompt.isEmpty {
                promptCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI Prompt:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ShareDesign.uiText.opacity(0.7))
                        Text(vm.reflectionPrompt)
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(ShareDesign.subtleText)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Your Reflection *")
                fieldTextArea("Write your reflection here...", text: $viewModel.reflectionText)
            }
        }
    }

    // MARK: - Submit Button

    private func submitButton(vm: ShareComposerViewModel) -> some View {
        let canSubmit = vm.canSubmit(userId: session.userId)

        return Button {
            Task { await performSubmit() }
        } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(vm.isSubmitting ? "Sharing..." : "SHARE")
                    .font(.system(size: 18, weight: .black))
                    .tracking(2)
            }
            .foregroundColor(canSubmit ? ShareDesign.uiText : ShareDesign.subtleText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(canSubmit ? ShareDesign.kiwi : ShareDesign.disabledBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ShareDesign.border, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || vm.isSubmitting)
    }

    private func performSubmit() async {
        let outcome = await viewModel.submit(userId: session.userId)
        switch outcome {
        case .success(let post):
            postsStore.prepend(post)
            dismiss()
        case .reflectionOnly:
            dismiss()
        case .failure, .notAuthenticated:
            // swallow for now; a future pass can surface a user-facing error
            break
        }
    }

    // MARK: - Session picker modal

    private func sessionPickerSheet(vm: ShareComposerViewModel) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if vm.pastSessions.isEmpty {
                        Text("No past sessions found")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(ShareDesign.subtleText)
                            .padding(24)
                    } else {
                        ForEach(vm.pastSessions) { s in
                            Button {
                                showingSessionPicker = false
                                Task { await viewModel.attach(s) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.bookTitle)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(ShareDesign.uiText)
                                    Text(sessionMetaLine(s))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(ShareDesign.subtleText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(ShareDesign.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Attach a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSessionPicker = false }
                }
            }
        }
    }

    // MARK: - Small field helpers

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(ShareDesign.uiText)
    }

    private func fieldInput(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(12)
            .background(ShareDesign.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border, lineWidth: 2))
    }

    private func fieldTextArea(_ placeholder: String, text: Binding<String>) -> some View {
        TextEditor(text: text)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .padding(8)
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(ShareDesign.subtleText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .background(ShareDesign.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border, lineWidth: 2))
    }

    private func simpleInfoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ShareDesign.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border, lineWidth: 2))
    }

    private func promptCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ShareDesign.teal.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareDesign.border, lineWidth: 2))
    }
}

#Preview {
    NavigationStack {
        ShareComposerSheet()
    }
}
