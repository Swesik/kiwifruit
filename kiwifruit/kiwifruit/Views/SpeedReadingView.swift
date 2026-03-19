import SwiftUI

struct SpeedReadingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("close") { dismiss() }
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(Color(hex: "2D3748"))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color(hex: "D1BFAe"))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "2D3748"), lineWidth: 2))
                    .sketchShadow(cornerRadius: 20)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 48) {
                    Text("Speed Reading")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: "2D3748"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    // Continue section
                    HStack(spacing: 16) {
                        Text("Continue:")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "2D3748"))
                        Text("nothing for now!")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(Color(hex: "2D3748"))
                    }

                    // Upload section
                    HStack(spacing: 16) {
                        Text("Upload")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "2D3748"))
                        Button("files") {}
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "2D3748"))
                            .padding(.horizontal, 32).padding(.vertical, 8)
                            .background(Color(hex: "7EA2A0"))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 3))
                            .sketchShadow()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SpeedReadingView()
}
