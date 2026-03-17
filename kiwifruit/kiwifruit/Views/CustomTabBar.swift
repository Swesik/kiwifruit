import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: Int

    private let items: [(label: String, tag: Int)] = [
        ("Profile", 0), ("Discover", 1), ("Home", 2), ("Challenges", 3), ("Focus", 4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 4)
                .foregroundColor(Color(hex: "2D3748"))

            HStack(spacing: 4) {
                ForEach(items, id: \.tag) { item in
                    Button { selection = item.tag } label: {
                        tabItemView(label: item.label, selected: selection == item.tag)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(8)
        }
        .background(Color(hex: "9CA3AF"))
    }

    private func tabItemView(label: String, selected: Bool) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundColor(Color(hex: "2D3748"))
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "D1D5DB"))
                        .sketchShadow(cornerRadius: 8)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "2D3748"), lineWidth: selected ? 2 : 0)
            )
    }
}
