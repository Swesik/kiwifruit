import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    let viewModel: ChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                VStack(alignment: .leading, spacing: 40) {
                    descriptionSection
                    timeWindowSection
                    progressSection
                    actionSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("close") { dismiss() }
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(Color(hex: "2D3748"))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(hex: "D1BFAe"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "2D3748"), lineWidth: 2))
                .sketchShadow(cornerRadius: 20)

            Text(challenge.title)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color(hex: "2D3748"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("description")
                .font(.title2).fontWeight(.black)
                .foregroundColor(Color(hex: "2D3748"))
            Text(challenge.description)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(Color(hex: "2D3748"))
                .lineSpacing(4)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.title2).fontWeight(.black)
                .foregroundColor(Color(hex: "2D3748"))

            VStack(spacing: 12) {
                progressBar
                HStack {
                    Text("Start")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748").opacity(0.7))
                    Spacer()
                    Text(challenge.progressLabel)
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748"))
                    Spacer()
                    Text("Goal")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748").opacity(0.7))
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
        }
    }

    private var progressBar: some View {
        Rectangle()
            .fill(Color(hex: "2D3748").opacity(0.15))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: "88C0D0"))
                    .frame(height: 4)
                    .scaleEffect(x: challenge.progress, y: 1, anchor: .leading)
            }
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color(hex: "88C0D0"))
                    .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 1.5))
                    .frame(width: 14, height: 14)
            }
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 1.5))
                    .frame(width: 14, height: 14)
            }
            .frame(height: 14)
    }

    // MARK: - Time Window

    private var timeWindowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time window")
                .font(.title2).fontWeight(.black)
                .foregroundColor(Color(hex: "2D3748"))
            HStack(spacing: 12) {
                Text(challenge.windowLabel.isEmpty ? "No expiry" : challenge.windowLabel)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(Color(hex: "2D3748"))
                if let remaining = challenge.timeRemainingLabel {
                    Text(remaining)
                        .font(.caption).fontWeight(.black)
                        .foregroundColor(challenge.isExpired ? Color.red : Color(hex: "A3C985"))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(challenge.isExpired ? Color.red.opacity(0.1) : Color(hex: "A3C985").opacity(0.15))
                        )
                }
            }
        }
    }

    // MARK: - Action

    @ViewBuilder
    private var actionSection: some View {
        switch challenge.state {
        case .available:
            Button("Join challenge") {
                viewModel.accept(challenge)
                dismiss()
            }
            .font(.subheadline).fontWeight(.bold)
            .foregroundColor(Color(hex: "2D3748"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "A3C985"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 1.5))
            .disabled(!viewModel.canAcceptChallenge)
        case .accepted:
            Button("Abandon challenge") {
                viewModel.abandon(challenge)
                dismiss()
            }
            .font(.subheadline).fontWeight(.bold)
            .foregroundColor(Color(hex: "2D3748").opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "2D3748").opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748").opacity(0.3), lineWidth: 1.5))
        case .completed:
            EmptyView()
        }
    }
}

#Preview {
    ChallengeDetailView(
        challenge: Challenge(
            id: UUID(),
            title: "Read 5 books in a month",
            description: "Complete 5 books within a month.",
            goalUnit: "books/month",
            goalCount: 5,
            progress: 0.4
        ),
        viewModel: ChallengeViewModel()
    )
}
