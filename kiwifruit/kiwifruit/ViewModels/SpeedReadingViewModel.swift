import Foundation
import Observation

@Observable
final class SpeedReadingViewModel {
    var isUploading = false
    var uploadMessage: String?

    func uploadEpub(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            uploadMessage = "Unable to access file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let fileData = try? Data(contentsOf: url) else {
            uploadMessage = "Unable to read file."
            return
        }

        let filename = url.lastPathComponent
        isUploading = true
        uploadMessage = nil
        Task {
            do {
                let response = try await AppAPI.shared.uploadEpub(fileData: fileData, filename: filename)
                isUploading = false
                uploadMessage = "Uploaded \"\(response.title)\" by \(response.author)"
            } catch {
                isUploading = false
                uploadMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
}
