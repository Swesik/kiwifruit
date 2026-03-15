import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let action: () -> Void
    let viewAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title).font(.headline)
                    Text(challenge.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                    if let expl = challenge.recommendationExplanation {
                        Text(expl).font(.caption).foregroundColor(.gray).lineLimit(2)
                    }
                }
                Spacer()
                // Points badge
                Text("\(challenge.rewardXP) XP")
                    .font(.caption2).bold()
                    .padding(6)
                    .background(Capsule().fill(Color.yellow.opacity(0.9)))
            }

            ProgressView(value: challenge.progress)

            HStack {
                if challenge.state == .available {
                    Button("Accept") { action() }
                        .buttonStyle(.borderedProminent)
                } else if challenge.state == .accepted {
                    Button("Complete") { action() }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button("View") { viewAction() }
                        .buttonStyle(.bordered)
                } else if challenge.state == .completed {
                    Text("Completed").font(.footnote).foregroundColor(.green).bold()
                    Spacer()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1)))
        .contentShape(Rectangle())
        .onTapGesture {
            // tapping anywhere should open detail/view
            viewAction()
        }
    }
}

struct ChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeCardView(challenge: Challenge(title: "Outdoor Reading", description: "Read outside for 15 minutes", category: "outdoor", difficulty: 2, progress: 0.2, rewardXP: 35), action: {}, viewAction: {})
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
