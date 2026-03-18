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
    private let activeChallenges: [Challenge] = [
        Challenge(
            title: "Read 5 books in a month",
            subtitle: "Sci-Fi Edition",
            description: "Dive deep into the magical realms and complete 5 books within this month. Your consistency will unlock special badges!",
            progress: 0.4,
            progressLabel: "2/5 Books"
        ),
        Challenge(
            title: "Daily 30 mins",
            subtitle: "Consistency is key",
            description: "Build a daily reading habit by dedicating at least 30 minutes every day. Small steps lead to big results!",
            progress: 0.8,
            progressLabel: "24/30 Days"
        )
    ]

    private let discoverChallenges: [(title: String, description: String)] = [
        ("Fantasy marathon: 1000 pages", "Dive deep into magical realms."),
        ("Read a classic", "Time to tackle those must-reads.")
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                VStack(alignment: .leading, spacing: 32) {
                    yourChallengesSection
                    discoverMoreSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text("Challenges")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(ChallengesDesign.uiText)
            Spacer()
            NavigationLink(destination: StreakTrackerView(streakDays: 1)) {
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
                Text("1")
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
        .background(ChallengesDesign.kiwiLight)
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

            VStack(spacing: 12) {
                ForEach(activeChallenges) { challenge in
                    NavigationLink(destination: ChallengeDetailView(challenge: challenge)) {
                        activeChallengeCard(challenge: challenge)
                    }
                    .buttonStyle(.plain)
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

    // MARK: - Discover More

    private var discoverMoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discover more")
                .font(.title2).fontWeight(.black)
                .foregroundColor(ChallengesDesign.uiText)

            VStack(spacing: 12) {
                ForEach(Array(discoverChallenges.enumerated()), id: \.offset) { _, challenge in
                    discoverCard(title: challenge.title, description: challenge.description)
                }
            }
        }
    }

    private func discoverCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(ChallengesDesign.uiText)
                Text(description)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(ChallengesDesign.uiText)
            }

            Button("JOIN NOW") {}
                .font(.caption).fontWeight(.black)
                .foregroundColor(ChallengesDesign.uiText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(ChallengesDesign.kiwi)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChallengesDesign.border, lineWidth: 2))
                .sketchShadow()
        }
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
