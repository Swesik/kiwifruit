import SwiftUI

public struct ChallengesView: View {
    @StateObject private var vm = ChallengeViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Text("Challenges").font(.largeTitle).bold()
                    Spacer()
                    // top-right streak badge
                    Text("\(vm.streak) day streak")
                        .font(.footnote)
                        .padding(8)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                }
                .padding([.horizontal, .top])

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Challenges").font(.title2).bold().padding(.horizontal)
                        if vm.activeChallenges.isEmpty {
                            Text("No active challenges. Explore Discover More below!").foregroundColor(.secondary).padding(.horizontal)
                        } else {
                            ForEach(vm.activeChallenges) { challenge in
                                NavigationLink(value: challenge) {
                                    ChallengeCardView(challenge: challenge, isActive: true, primaryActionTitle: "View") {
                                    } viewAction: {
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }

                        Divider().padding(.vertical)

                        Text("Discover More").font(.title2).bold().padding(.horizontal)
                        ForEach(vm.recommendedChallenges) { challenge in
                            ChallengeCardView(challenge: challenge, isActive: false, primaryActionTitle: "Join Now") {
                                vm.join(challenge)
                            } viewAction: {
                                // present detail by pushing
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 60)
                }

            }
            .navigationDestination(for: Challenge.self) { challenge in
                ChallengeDetailView(viewModel: vm, challenge: challenge)
            }
            .onAppear {
                Task { await vm.loadRecommendations() }
            }
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
    }
}
import SwiftUI

struct ChallengesView: View {
    @StateObject var viewModel = ChallengeViewModel()
    @State private var showDetail: Bool = false
    @State private var selected: Challenge? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Text("Challenges").font(.largeTitle).bold()
                    Spacer()
                    Text("\(viewModel.streak) day streak")
                        .padding(8)
                        .background(Color.yellow.opacity(0.9))
                        .cornerRadius(12)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Challenges").font(.headline)
                        ForEach(viewModel.activeChallenges) { ch in
                            ChallengeCardView(challenge: ch, actionTitle: "View", action: {}, viewAction: {
                                selected = ch
                                showDetail = true
                            })
                        }

                        Text("Discover More").font(.headline).padding(.top)
                        ForEach(viewModel.recommended) { ch in
                            ChallengeCardView(challenge: ch, actionTitle: "Join Now", action: {
                                viewModel.join(ch)
                            }, viewAction: {
                                selected = ch
                                showDetail = true
                            })
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                Task { await viewModel.loadRecommendations() }
            }
            .navigationDestination(isPresented: $showDetail) {
                if let c = selected {
                    ChallengeDetailView(viewModel: viewModel, challenge: c)
                }
            }
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
    }
}
