import SwiftUI

struct Challenge: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let progress: Double
    let progressLabel: String
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                VStack(alignment: .leading, spacing: 40) {
                    descriptionSection
                    progressSection
                    aiFeedbackSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("close") { dismiss() }
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(Color(hex: "2D3748"))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(hex: "D1BFAe"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "2D3748"), lineWidth: 2))
                .sketchShadow(cornerRadius: 20)

            Text(challenge.title)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color(hex: "2D3748"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("description")
                .font(.title2).fontWeight(.black)
                .foregroundColor(Color(hex: "2D3748"))
            Text(challenge.description)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(Color(hex: "2D3748"))
                .lineSpacing(4)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.title2).fontWeight(.black)
                .foregroundColor(Color(hex: "2D3748"))

            VStack(spacing: 12) {
                progressBar
                HStack {
                    Text("Start")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748").opacity(0.7))
                    Spacer()
                    Text(challenge.progressLabel)
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748"))
                    Spacer()
                    Text("Goal")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color(hex: "2D3748").opacity(0.7))
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
        }
    }

    private var progressBar: some View {
        Rectangle()
            .fill(Color(hex: "2D3748").opacity(0.15))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: "88C0D0"))
                    .frame(height: 4)
                    .scaleEffect(x: challenge.progress, y: 1, anchor: .leading)
            }
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color(hex: "88C0D0"))
                    .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 1.5))
                    .frame(width: 14, height: 14)
            }
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 1.5))
                    .frame(width: 14, height: 14)
            }
            .frame(height: 14)
    }

    // MARK: - AI Feedback

    private var aiFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adaptive AI\nFeedback")
                .font(.title2).fontWeight(.black)
                .foregroundColor(Color(hex: "2D3748"))

            Text("\"You're making great progress! Try reading 15 minutes before bed tonight to keep the momentum going.\"")
                .font(.subheadline).fontWeight(.bold)
                .italic()
                .foregroundColor(Color(hex: "2D3748"))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "E6F0DC"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 2))
                .sketchShadow()
        }
    }
}

#Preview {
    ChallengeDetailView(challenge: Challenge(
        title: "Read 5 books in a month",
        subtitle: "Sci-Fi Edition",
        description: "Dive deep into the magical realms and complete 5 books within this month. Your consistency will unlock special badges!",
        progress: 0.6,
        progressLabel: "3/5 Books"
    ))
}
