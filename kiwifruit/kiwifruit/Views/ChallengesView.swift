import SwiftUI

struct ChallengesView: View {
    @StateObject private var vm = ChallengeViewModel()
    @State private var selected: Challenge? = nil
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Text("Challenges").font(.largeTitle).bold()
                    Spacer()
                    Text("\(vm.streak) day streak").font(.footnote).padding(8).background(Capsule().fill(Color.blue.opacity(0.2)))
                }
                .padding([.horizontal, .top])

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Challenges").font(.title2).bold().padding(.horizontal)
                        if vm.activeChallenges.isEmpty {
                            Text("No active challenges. Explore Discover More below!").foregroundColor(.secondary).padding(.horizontal)
                        } else {
                            ForEach(vm.activeChallenges) { challenge in
                                Button { selected = challenge; showDetail = true } label: {
                                    ChallengeCardView(challenge: challenge, actionTitle: "View", action: {}, viewAction: {})
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }

                        Divider().padding(.vertical)

                        Text("Discover More").font(.title2).bold().padding(.horizontal)
                        ForEach(vm.recommended) { challenge in
                            ChallengeCardView(challenge: challenge, actionTitle: "Join Now") {
                                vm.join(challenge)
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
                if let c = selected { ChallengeDetailView(viewModel: vm, challenge: c) }
            }
            .onAppear { Task { await vm.loadRecommendations() } }
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
    }
}
