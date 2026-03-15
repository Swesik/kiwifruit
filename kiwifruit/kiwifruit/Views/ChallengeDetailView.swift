import SwiftUI

struct ChallengeDetailView: View {
    @ObservedObject var viewModel: ChallengeViewModel
    var challenge: Challenge

    var body: some View {
        VStack(spacing: 16) {
            Text(challenge.title).font(.largeTitle).bold()
            Text(challenge.description).font(.body).foregroundColor(.secondary)

            ProgressView(value: challenge.progress)
                .padding()

            Text(feedbackText()).font(.subheadline).padding().background(Color(UIColor.tertiarySystemBackground)).cornerRadius(8)

            HStack(spacing: 16) {
                Button(action: {
                    viewModel.join(challenge)
                }) {
                    Text("Start/Accept").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    viewModel.abandon(challenge)
                }) {
                    Text("Abandon").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
    }

    private func feedbackText() -> String {
        if challenge.progress >= 1.0 { return "Nice! You've completed this challenge — claim your XP." }
        if challenge.progress > 0.5 { return "You're more than halfway there — keep the momentum!" }
        if challenge.progress > 0.0 { return "Good start — a little session each day adds up." }
        return "This challenge fits your routine — try starting with a short session." }
}

struct ChallengeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeDetailView(viewModel: ChallengeViewModel(), challenge: Challenge(title: "Sprint Reader", description: "Read 25 pages in one session", category: "sprint", difficulty: 3, progress: 0.3, rewardXP: 50))
    }
}
