import SwiftUI

private let allGenres = [
    "fantasy", "sci-fi", "mystery", "classic", "dystopian",
    "memoir", "nonfiction", "fiction"
]

struct SettingsView: View {
    @Environment(\.userPreferencesStore) private var store: UserPreferencesStore
    @Environment(\.recommendationsStore) private var recommendationsStore
    @Environment(\.dismiss) private var dismiss

    @State private var dailyGoal: Int = 30
    @State private var selectedGenres: Set<String> = []
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(
                        "\(dailyGoal) min",
                        value: $dailyGoal,
                        in: 5...240,
                        step: 5
                    )
                } header: {
                    Text("Daily Reading Goal")
                }

                Section {
                    ForEach(allGenres, id: \.self) { genre in
                        Button(action: { toggle(genre) }) {
                            HStack {
                                Text(genre)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedGenres.contains(genre) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "A3C985"))
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Preferred Genres")
                } footer: {
                    Text("Used to personalise book recommendations.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            await store.update(
                                dailyGoal: dailyGoal,
                                genres: Array(selectedGenres)
                            )
                            // Refresh recommendations to reflect new preferences
                            recommendationsStore.reset()
                            await recommendationsStore.load()
                            isSaving = false
                            dismiss()
                        }
                    }
                    .fontWeight(.black)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                dailyGoal = store.dailyGoalMinutes
                selectedGenres = Set(store.preferredGenres)
            }
        }
    }

    private func toggle(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }
}

#Preview {
    SettingsView()
}
