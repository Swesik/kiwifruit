import SwiftUI

struct ChallengesView: View {
    @State private var vm = ChallengeViewModel()
    @State private var selected: Challenge? = nil
    @State private var showDetail = false
    @State private var showLimitAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Challenges").font(.largeTitle).bold()
                        Text("Total Points: \(vm.totalPoints)").font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(vm.streak) day streak").font(.footnote).padding(8).background(Capsule().fill(Color.blue.opacity(0.2)))
                        Text("\(vm.totalPoints) XP").font(.caption2).padding(6).background(Capsule().fill(Color.orange.opacity(0.2)))
                        NavigationLink("Completed", destination: CompletedChallengesView(viewModel: vm))
                    }
                }
                .padding([.horizontal, .top])

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Challenges").font(.title2).bold().padding(.horizontal)
                        if vm.activeChallenges.isEmpty {
                            Text("No active challenges. Explore Discover More below!").foregroundColor(.secondary).padding(.horizontal)
                        } else {
                            ForEach(vm.activeChallenges) { challenge in
                                    ChallengeCardView(challenge: challenge, actionTitle: "Complete") {
                                        // action -> complete when accepted
                                        vm.complete(challenge)
                                    } viewAction: {
                                        selected = challenge; showDetail = true
                                    }
                                .padding(.horizontal)
                            }
                        }

                        Divider().padding(.vertical)

                        HStack {
                            Text("Discover More").font(.title2).bold()
                            Spacer()
                            Button(action: { Task { await vm.refreshRecommendations() } }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        ForEach(vm.recommended) { challenge in
                            ChallengeCardView(challenge: challenge, actionTitle: "Join Now") {
                                // action -> accept
                                let success = vm.accept(challenge)
                                if !success { showLimitAlert = true }
                            } viewAction: {
                                selected = challenge; showDetail = true
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationDestination(isPresented: $showDetail) {
                if let c = selected { ChallengeDetailView(viewModel: vm, challengeId: c.id) }
            }
            .onAppear { Task { await vm.loadRecommendations() } }
            .alert("Maximum active challenges reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can have up to 3 active challenges. Abandon an active challenge to accept a new one.")
            }
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
    }
}
