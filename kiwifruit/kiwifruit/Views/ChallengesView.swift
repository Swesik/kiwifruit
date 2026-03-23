import SwiftUI

private enum ChallengesDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tealCard = Color(hex: "CFE6EC")
    static let brownCard = Color(hex: "D1BFAe")
}

struct ChallengesView: View {
    @Environment(\.challengeViewModel) private var viewModel: ChallengeViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                VStack(alignment: .leading, spacing: 32) {
                    yourChallengesSection
                    if !viewModel.completedChallenges.isEmpty {
                        completedChallengesSection
                    }
                    discoverMoreSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.updateProgress() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text("Challenges")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(ChallengesDesign.uiText)
            Spacer()
            NavigationLink(destination: StreakTrackerView(streakDays: viewModel.streak, activeDays: viewModel.activeDays, hasSessionToday: viewModel.hasSessionToday, firstSessionMonth: viewModel.firstSessionMonth, sessionActiveDays: viewModel.sessionActiveDays)) {
                streakBadge
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 8)
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("\(viewModel.streak)")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(ChallengesDesign.uiText)
                Text("day")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ChallengesDesign.uiText)
            }
            Text("streak")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ChallengesDesign.uiText)
        }
        .frame(width: 80, height: 80)
        .background(viewModel.hasSessionToday ? ChallengesDesign.kiwi : ChallengesDesign.kiwiLight)
        .clipShape(Circle())
        .overlay(Circle().stroke(ChallengesDesign.border, lineWidth: 2))
        .sketchShadowCircle()
        .rotationEffect(.degrees(2))
    }

    // MARK: - Your Challenges

    private var yourChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your challenges")
                .font(.title2).fontWeight(.black)
                .foregroundColor(ChallengesDesign.uiText)

            if viewModel.activeChallenges.isEmpty {
                Text("No active challenges — join one below!")
                    .font(.subheadline)
                    .foregroundColor(ChallengesDesign.uiText.opacity(0.5))
                    .padding(.leading, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.activeChallenges) { challenge in
                        NavigationLink(destination: ChallengeDetailView(challenge: challenge, viewModel: viewModel)) {
                            activeChallengeCard(challenge: challenge)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func activeChallengeCard(challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(ChallengesDesign.uiText)
                    Text(challenge.subtitle)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(ChallengesDesign.uiText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("view →")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(ChallengesDesign.uiText)
            }

            progressBar(progress: challenge.progress)
                .padding(.top, 24)
        }
        .padding(16)
        .background(ChallengesDesign.tealCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChallengesDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    private func progressBar(progress: Double) -> some View {
        Rectangle()
            .fill(ChallengesDesign.border.opacity(0.2))
            .frame(height: 2)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(ChallengesDesign.border)
                    .frame(height: 2)
                    .scaleEffect(x: progress, y: 1, anchor: .leading)
            }
            .overlay(alignment: .leading) {
                Circle()
                    .fill(ChallengesDesign.border)
                    .frame(width: 8, height: 8)
            }
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(ChallengesDesign.border, lineWidth: 2))
                    .frame(width: 8, height: 8)
            }
            .frame(height: 8)
    }

    // MARK: - Completed

    private var completedChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completed")
                .font(.title2).fontWeight(.black)
                .foregroundColor(ChallengesDesign.uiText)

            VStack(spacing: 12) {
                ForEach(viewModel.completedChallenges) { challenge in
                    NavigationLink(destination: ChallengeDetailView(challenge: challenge, viewModel: viewModel)) {
                        completedChallengeCard(challenge: challenge)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func completedChallengeCard(challenge: Challenge) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(ChallengesDesign.uiText)
                Text("+\(challenge.rewardXP) XP")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(ChallengesDesign.uiText.opacity(0.6))
            }
            Spacer()
            Text("Done")
                .font(.caption).fontWeight(.black)
                .foregroundColor(ChallengesDesign.uiText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ChallengesDesign.kiwi)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChallengesDesign.border, lineWidth: 2))
        }
        .padding(16)
        .background(ChallengesDesign.kiwiLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChallengesDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    // MARK: - Discover More

    private var discoverMoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discover more")
                .font(.title2).fontWeight(.black)
                .foregroundColor(ChallengesDesign.uiText)

            VStack(spacing: 12) {
                ForEach(viewModel.discoverChallenges) { challenge in
                    NavigationLink(destination: ChallengeDetailView(challenge: challenge, viewModel: viewModel)) {
                        discoverCard(challenge: challenge)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func discoverCard(challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(challenge.title)
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(ChallengesDesign.uiText)
            Text(challenge.description)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(ChallengesDesign.uiText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ChallengesDesign.brownCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChallengesDesign.border, lineWidth: 2))
        .sketchShadow()
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
