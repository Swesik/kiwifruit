import SwiftUI

public struct ChallengeDetailView: View {
    @ObservedObject public var viewModel: ChallengeViewModel
    public var challenge: Challenge

    public init(viewModel: ChallengeViewModel, challenge: Challenge) {
        self.viewModel = viewModel
        self.challenge = challenge
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(challenge.title).font(.largeTitle).bold()
            Text(challenge.description).font(.body)

            ProgressView(value: challenge.progress)
                .padding(.vertical)

            // Adaptive AI feedback (mocked)
            Text(adaptiveFeedback())
                .italic()
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.join(challenge)
                }) {
                    Text("Start / Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    viewModel.abandon(challenge)
                }) {
                    Text("Abandon")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Challenge")
    }

    private func adaptiveFeedback() -> String {
        if challenge.progress >= 1.0 { return "Amazing — you completed this challenge! Claim your XP." }
        if challenge.progress > 0.0 { return "Nice progress — keep going to complete the challenge." }
        switch challenge.difficulty {
        case 1: return "This is an easy win — set aside a short focused time." 
        case 2: return "A moderate challenge — try to schedule 15–20 minutes." 
        default: return "This one is tough — break it into smaller sprints." 
        }
    }
}

struct ChallengeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ChallengeViewModel()
        ChallengeDetailView(viewModel: vm, challenge: Challenge(title: "Sprint Reader", description: "Read 25 pages in one session.", category: "speed", difficulty: 3, progress: 0.2, rewardXP: 40))
    }
}
import SwiftUI

struct ChallengeDetailView: View {
    @Environment(\.presentationMode) var presentation
    @ObservedObject var viewModel: ChallengeViewModel
    var challenge: Challenge

    var body: some View {
        VStack(spacing: 16) {
            Text(challenge.title).font(.largeTitle).bold()
            Text(challenge.description).font(.body).foregroundColor(.secondary)

            ProgressView(value: challenge.progress)
                .padding()

            // Adaptive AI feedback (mocked)
            Text(feedbackText()).font(.subheadline).padding().background(Color(UIColor.tertiarySystemBackground)).cornerRadius(8)

            HStack(spacing: 16) {
                Button(action: {
                    viewModel.join(challenge)
                    presentation.wrappedValue.dismiss()
                }) {
                    Text("Start/Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    viewModel.abandon(challenge)
                    presentation.wrappedValue.dismiss()
                }) {
                    Text("Abandon")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
    }

    private func feedbackText() -> String {
        // Simple mocked AI feedback based on progress
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
