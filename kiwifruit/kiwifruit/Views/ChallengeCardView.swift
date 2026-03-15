import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let actionTitle: String
    let action: () -> Void
    let viewAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title).font(.headline)
                    Text(challenge.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
            }

            ProgressView(value: challenge.progress)

            HStack {
                Spacer()
                Button(actionTitle) { action() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1)))
    }
}

struct ChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeCardView(challenge: Challenge(title: "Outdoor Reading", description: "Read outside for 15 minutes", category: "outdoor", difficulty: 2, progress: 0.2, rewardXP: 35), actionTitle: "Join Now", action: {}, viewAction: {})
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
