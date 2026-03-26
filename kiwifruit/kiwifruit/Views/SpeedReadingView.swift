import SwiftUI
import UniformTypeIdentifiers

struct SpeedReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var viewModel = SpeedReadingViewModel()

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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Text("Upload")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "2D3748"))
                            Button("files") {
                                showFilePicker = true
                            }
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "2D3748"))
                            .padding(.horizontal, 32).padding(.vertical, 8)
                            .background(Color(hex: "7EA2A0"))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2D3748"), lineWidth: 3))
                            .sketchShadow()
                            .disabled(viewModel.isUploading)
                        }

                        if viewModel.isUploading {
                            ProgressView("Uploading...")
                                .foregroundColor(Color(hex: "2D3748"))
                        }

                        if let message = viewModel.uploadMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "2D3748"))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.uploadEpub(from: url)
            case .failure(let error):
                viewModel.uploadMessage = "Failed to pick file: \(error.localizedDescription)"
            }
        }
    }

}

#Preview {
    SpeedReadingView()
}
