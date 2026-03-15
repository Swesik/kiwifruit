import SwiftUI

struct ChallengeDetailView: View {
    @Bindable var viewModel: ChallengeViewModel
    let challengeId: UUID

    private var challenge: Challenge? {
        // Prefer active -> recommended -> completed -> bank
        if let c = viewModel.activeChallenges.first(where: { $0.id == challengeId }) { return c }
        if let c = viewModel.recommended.first(where: { $0.id == challengeId }) { return c }
        if let c = viewModel.completedChallenges.first(where: { $0.id == challengeId }) { return c }
        return nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if let challenge = challenge {
                VStack(alignment: .leading, spacing: 12) {
                    Text(challenge.title).font(.largeTitle).bold()
                    Text(challenge.description).font(.body).foregroundColor(.secondary)
                    if let expl = challenge.recommendationExplanation {
                        Text(expl).font(.caption).foregroundColor(.gray)
                    }

                    ProgressView(value: challenge.progress)
                        .padding()

                    Text(feedbackText(for: challenge))
                        .font(.subheadline)
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)

                    HStack(spacing: 16) {
                        if challenge.state == .available {
                            Button { viewModel.accept(challenge) } label: { Text("Accept").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent)
                        } else if challenge.state == .accepted {
                            Button { viewModel.complete(challenge) } label: { Text("Complete").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent)
                            Button { viewModel.abandon(challenge) } label: { Text("Abandon").frame(maxWidth: .infinity) }
                                .buttonStyle(.bordered)
                        } else {
                            Text("Already completed").frame(maxWidth: .infinity)
                        }
                    }
                }
                Spacer()
            } else {
                Text("Challenge not found").foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
    }
    private func feedbackText(for challenge: Challenge) -> String {
        if challenge.progress >= 1.0 { return "Nice! You've completed this challenge — claim your XP." }
        if challenge.progress > 0.5 { return "You're more than halfway there — keep the momentum!" }
        if challenge.progress > 0.0 { return "Good start — a little session each day adds up." }
        return "This challenge fits your routine — try starting with a short session." 
    }
}

struct ChallengeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ChallengeViewModel()
        let c = Challenge(title: "Sprint Reader", description: "Read 25 pages in one session", category: "sprint", difficulty: 3, progress: 0.3, rewardXP: 50)
        vm.recommended = [c]
        return ChallengeDetailView(viewModel: vm, challengeId: c.id)
    }
}
