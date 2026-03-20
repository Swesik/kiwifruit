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
    @State private var lookedUpPlace: String = ""

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

                                    if weatherToggle {
                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Latitude", text: $latText).textFieldStyle(.roundedBorder).keyboardType(.decimalPad).frame(width: 180)
                                            TextField("Longitude", text: $lonText).textFieldStyle(.roundedBorder).keyboardType(.decimalPad).frame(width: 180)
                                            HStack(spacing: 8) {
                                                Button("Lookup Place") {
                                                    if let lat = Double(latText), let lon = Double(lonText) {
                                                        Task {
                                                            let result = await vm.reverseGeocode(lat: lat, lon: lon)
                                                            lookedUpPlace = result ?? "Unknown location"
                                                        }
                                                    }
                                                }
                                                .buttonStyle(.bordered)

                                                Button("Create Weather Challenge") {
                                                    if let lat = Double(latText), let lon = Double(lonText) {
                                                        Task {
                                                            let c = await vm.createWeatherChallenge(lat: lat, lon: lon, placeName: lookedUpPlace)
                                                            await MainActor.run {
                                                                vm.applyAccept(c)
                                                            }
                                                            latText = ""; lonText = ""; lookedUpPlace = ""
                                                        }
                                                    }
                                                }
                                                .buttonStyle(.borderedProminent)
                                            }
                                            if !lookedUpPlace.isEmpty {
                                                Text("Place: \(lookedUpPlace)").font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                    } else {
                                        Picker("Type", selection: $newType) {
                                            Text("Pages/week").tag("pages")
                                            Text("Minutes/week").tag("minutes")
                                            Text("Books/month").tag("books")
                                        }
                                        .pickerStyle(.segmented)

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
                                                let c = vm.createChallenge(type: "pages", pagesPerWeek: Int(pagesPerWeekVal))
                                                Task { await MainActor.run { vm.applyAccept(c) } }
                                            } else if newType == "minutes" {
                                                let c = vm.createChallenge(type: "minutes", minutesPerWeek: Int(minutesPerWeekVal))
                                                Task { await MainActor.run { vm.applyAccept(c) } }
                                            } else {
                                                let c = vm.createChallenge(type: "books", booksCount: Int(booksCountVal))
                                                Task { await MainActor.run { vm.applyAccept(c) } }
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
                                    Task {
                                        if let _ = vm.complete(challenge) {
                                            await MainActor.run { vm.applyComplete(challengeId: challenge.id) }
                                        }
                                    }
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
                            Button(action: {
                                Task {
                                    let recs = await vm.loadRecommendations()
                                    await MainActor.run {
                                        vm.recommended = recs
                                    }
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        ForEach(vm.recommended) { challenge in
                            ChallengeCardView(challenge: challenge, action: {
                                // action -> join (alias to accept) keeping success handling
                                let res = vm.accept(challenge)
                                if !res.success { showLimitAlert = true }
                                else if let prepared = res.prepared {
                                    Task { await MainActor.run { vm.applyAccept(prepared) } }
                                }
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
            // No automatic refresh; user must tap the refresh button
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
