import SwiftUI

public struct ChallengeCardView: View {
    public var challenge: Challenge
    public var isActive: Bool = false
    public var primaryActionTitle: String
    public var primaryAction: () -> Void
    public var viewAction: () -> Void

    public init(challenge: Challenge, isActive: Bool = false, primaryActionTitle: String = "Join Now", primaryAction: @escaping () -> Void = {}, viewAction: @escaping () -> Void = {}) {
        self.challenge = challenge
        self.isActive = isActive
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.viewAction = viewAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title).font(.headline)
                    Text(challenge.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
            }

            if isActive {
                ProgressView(value: challenge.progress)
                HStack {
                    Button("View") { viewAction() }
                    Spacer()
                    Text("3 XP")
                }
            } else {
                HStack {
                    Button(primaryActionTitle) { primaryAction() }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Text("\(challenge.rewardXP) XP").foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}

struct ChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeCardView(challenge: Challenge(title: "Outdoor Reading", description: "Read outside for 15 minutes.", category: "outdoor", difficulty: 2, progress: 0.3, rewardXP: 25))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
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
                    Text(challenge.description).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("View") { viewAction() }
                    .buttonStyle(.bordered)
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
