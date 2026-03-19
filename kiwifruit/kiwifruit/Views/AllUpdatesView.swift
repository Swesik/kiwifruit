import SwiftUI

struct AllUpdatesView: View {
    let updates: [RecentUpdateItem]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(updates) { item in
                    RecentUpdateCard(item: item).padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .navigationTitle("Recent Updates")
        .navigationBarTitleDisplayMode(.large)
    }
}
