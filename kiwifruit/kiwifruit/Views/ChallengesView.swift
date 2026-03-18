import SwiftUI

struct ChallengesView: View {
    @State private var vm = ChallengeViewModel()
    @State private var selected: Challenge? = nil
    @State private var showDetail = false
    @State private var showLimitAlert = false
    @State private var newType: String = "pages"
    @State private var pagesPerWeekVal: Double = 50
    @State private var minutesPerWeekVal: Double = 120
    @State private var booksCountVal: Double = 2
    @State private var weatherToggle: Bool = false
    @State private var latText: String = ""
    @State private var lonText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Challenges").font(.largeTitle).bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(vm.streak) day streak").font(.footnote).padding(8).background(Capsule().fill(Color.blue.opacity(0.2)))
                        Text("\(vm.totalPoints) XP").font(.caption2).padding(6).background(Capsule().fill(Color.orange.opacity(0.2)))
                    }
                }
                .padding([.horizontal, .top])

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Create Challenge section (moved above user's challenges)
                        Divider().padding(.vertical)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create Challenge").font(.title3).bold().padding(.horizontal)
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Generate challenge from weather (use lat/lon)", isOn: $weatherToggle)

                                    Picker("Type", selection: $newType) {
                                        Text("Pages/week").tag("pages")
                                        Text("Minutes/week").tag("minutes")
                                        Text("Books/month").tag("books")
                                    }
                                    .pickerStyle(.segmented)

                                    if weatherToggle {
                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Latitude", text: $latText).textFieldStyle(.roundedBorder).keyboardType(.decimalPad).frame(width: 180)
                                            TextField("Longitude", text: $lonText).textFieldStyle(.roundedBorder).keyboardType(.decimalPad).frame(width: 180)
                                            Button("Create Weather Challenge") {
                                                if let lat = Double(latText), let lon = Double(lonText) {
                                                    Task { await vm.createWeatherChallenge(lat: lat, lon: lon) }
                                                    latText = ""; lonText = ""
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    } else {
                                        if newType == "pages" {
                                            VStack(alignment: .leading) {
                                                Text("Pages per week: \(Int(pagesPerWeekVal))")
                                                Slider(value: $pagesPerWeekVal, in: 0...500, step: 5)
                                            }
                                        } else if newType == "minutes" {
                                            VStack(alignment: .leading) {
                                                Text("Minutes per week: \(Int(minutesPerWeekVal))")
                                                Slider(value: $minutesPerWeekVal, in: 0...600, step: 5)
                                            }
                                        } else if newType == "books" {
                                            VStack(alignment: .leading) {
                                                Text("Books this month: \(Int(booksCountVal))")
                                                Slider(value: $booksCountVal, in: 0...20, step: 1)
                                            }
                                        }

                                        Button("Create and Add") {
                                            if newType == "pages" {
                                                vm.createChallenge(type: "pages", pagesPerWeek: Int(pagesPerWeekVal))
                                            } else if newType == "minutes" {
                                                vm.createChallenge(type: "minutes", minutesPerWeek: Int(minutesPerWeekVal))
                                            } else {
                                                vm.createChallenge(type: "books", booksCount: Int(booksCountVal))
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                        }

                        Text("Your Challenges").font(.title2).bold().padding(.horizontal)
                        if vm.activeChallenges.isEmpty {
                            Text("No active challenges. Explore Discover More below!").foregroundColor(.secondary).padding(.horizontal)
                        } else {
                            ForEach(vm.activeChallenges) { challenge in
                                ChallengeCardView(challenge: challenge, action: {
                                    // action -> complete when accepted
                                    vm.complete(challenge)
                                }, viewAction: {
                                    selected = challenge; showDetail = true
                                })
                                .padding(.horizontal)
                            }
                        }

                        // (create section was moved above)

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
                            ChallengeCardView(challenge: challenge, action: {
                                // action -> join (alias to accept) keeping success handling
                                let success = vm.accept(challenge)
                                if !success { showLimitAlert = true }
                            }, viewAction: {
                                selected = challenge; showDetail = true
                            })
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationDestination(isPresented: $showDetail) {
                Group {
                    if let c = selected {
                        ChallengeDetailView(viewModel: vm, challengeId: c.id)
                    } else {
                        EmptyView()
                    }
                }
            }
            .onAppear { Task { await vm.loadRecommendations() } }
            .alert("Maximum active challenges reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can have up to 3 active challenges. Abandon an active challenge to join a new one.")
            }
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
    }
}
