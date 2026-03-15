import SwiftUI

struct CompletedChallengesView: View {
    @Bindable var viewModel: ChallengeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completed Challenges").font(.title).bold()
                Spacer()
                Text("Total: \(viewModel.totalPoints) XP").font(.subheadline).foregroundColor(.secondary)
            }
            .padding()

            List {
                ForEach(viewModel.completedChallenges) { c in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c.title).font(.headline)
                            Text(c.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Text("+\(c.rewardXP) XP").bold().foregroundColor(.orange)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Completed")
    }
}

struct CompletedChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ChallengeViewModel()
        let c = Challenge(title: "Sprint", description: "Go fast.", category: "sprint", difficulty: 2, progress: 1.0, rewardXP: 30, state: .completed)
        vm.completedChallenges = [c]
        vm.totalPoints = 30
        return CompletedChallengesView(viewModel: vm)
    }
}
