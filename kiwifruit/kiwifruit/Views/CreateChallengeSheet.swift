import SwiftUI

private enum CreateDesign {
    static let border = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tan = Color(hex: "D1BFAe")
    static let bg = Color(hex: "FAFAFA")
    static let sketchOffset: CGFloat = 4
}

struct CreateChallengeSheet: View {
    let viewModel: ChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var goalCount = ""
    @State private var selectedGoalType = 0 // 0=minutes, 1=books, 2=pages
    @State private var selectedTimeWindow = 0 // 0=week, 1=month

    private let goalTypes = ["Minutes", "Books", "Pages"]
    private let timeWindows = ["Week", "Month"]

    private var goalUnit: String {
        "\(goalTypes[selectedGoalType].lowercased())/\(timeWindows[selectedTimeWindow].lowercased())"
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(goalCount.trimmingCharacters(in: .whitespaces)) ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    titleField
                    descriptionField
                    goalSection
                    timeWindowSection
                    createButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
        }
        .background(CreateDesign.bg)
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Create challenge")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(CreateDesign.border)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CreateDesign.border)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(CreateDesign.border, lineWidth: 2))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.subheadline).fontWeight(.black)
                .foregroundColor(CreateDesign.border)

            TextField("e.g. Read before bed every day", text: $title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CreateDesign.border, lineWidth: 2))
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CreateDesign.border)
                        .offset(x: 2, y: 2)
                )
        }
    }

    // MARK: - Description

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.subheadline).fontWeight(.black)
                .foregroundColor(CreateDesign.border)

            TextField("Optional — describe your challenge", text: $description, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CreateDesign.border, lineWidth: 2))
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CreateDesign.border)
                        .offset(x: 2, y: 2)
                )
        }
    }

    // MARK: - Goal

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal")
                .font(.subheadline).fontWeight(.black)
                .foregroundColor(CreateDesign.border)

            HStack(spacing: 12) {
                TextField("Amount", text: $goalCount)
                    .keyboardType(.numberPad)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(width: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CreateDesign.border, lineWidth: 2))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(CreateDesign.border)
                            .offset(x: 2, y: 2)
                    )

                segmentedPicker(items: goalTypes, selection: $selectedGoalType)
            }
        }
    }

    // MARK: - Time Window

    private var timeWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time window")
                .font(.subheadline).fontWeight(.black)
                .foregroundColor(CreateDesign.border)

            segmentedPicker(items: timeWindows, selection: $selectedTimeWindow)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
            let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
            let count = Int(goalCount.trimmingCharacters(in: .whitespaces)) ?? 0
            viewModel.createCustomChallenge(
                title: trimmedTitle,
                description: trimmedDesc.isEmpty ? "Custom challenge: \(trimmedTitle)" : trimmedDesc,
                goalUnit: goalUnit,
                goalCount: count
            )
            dismiss()
        } label: {
            Text("Create challenge")
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(canCreate ? CreateDesign.border : CreateDesign.border.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canCreate ? CreateDesign.kiwi : CreateDesign.kiwi.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(CreateDesign.border.opacity(canCreate ? 1 : 0.3), lineWidth: 2)
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canCreate ? CreateDesign.border : Color.clear)
                        .offset(x: 2, y: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
        .padding(.top, 8)
    }

    // MARK: - Custom Segmented Picker

    private func segmentedPicker(items: [String], selection: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection.wrappedValue = idx
                    }
                } label: {
                    Text(items[idx])
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(CreateDesign.border)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == idx ? CreateDesign.kiwi : CreateDesign.kiwiLight)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CreateDesign.border, lineWidth: 2))
        .sketchShadow()
    }
}

#Preview {
    CreateChallengeSheet(viewModel: ChallengeViewModel())
}
