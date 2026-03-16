import SwiftUI

struct DiscoverView: View {
    @Bindable var bookSearchViewModel: BookSearchViewModel
    @Bindable var bookScanViewModel: BookScanViewModel

    var body: some View {
        List {
            Section("Search books") {
                HStack(spacing: 12) {
                    TextField("Title, author, or ISBN", text: $bookSearchViewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await bookSearchViewModel.submit() }
                        }

                    Button {
                        Task { await bookSearchViewModel.submit() }
                    } label: {
                        Text("Search")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        bookSearchViewModel.isSearching ||
                        bookSearchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .listRowSeparator(.hidden)

                Button {
                    bookScanViewModel.startCamera()
                } label: {
                    Label("Take Photo of Barcode/Title to Search", systemImage: "camera.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.78, green: 0.93, blue: 0.78))
                .padding(.top, 10)

                if bookSearchViewModel.isSearching || bookScanViewModel.isProcessing {
                    ProgressView()
                }

                if let msg = bookSearchViewModel.errorMessage {
                    Text(msg)
                }

                if let msg = bookScanViewModel.errorMessage {
                    Text(msg)
                }

                if let msg = bookScanViewModel.statusMessage {
                    Text(msg)
                }
            }

            Section("Results") {
                if bookSearchViewModel.results.isEmpty {
                    Text("No results yet.")
                } else {
                    ForEach(bookSearchViewModel.results) { book in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)

                            if let authors = book.authors, !authors.isEmpty {
                                Text(authors.joined(separator: ", "))
                                    .font(.subheadline)
                            }

                            if let isbn13 = book.isbn13, !isbn13.isEmpty {
                                Text("ISBN-13: \(isbn13)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            Section("Recommendations") {
                Text("Coming soon: recommended books based on your interests.")
            }
        }
        .navigationTitle("Discover")
        .sheet(
            isPresented: Binding(
                get: { bookScanViewModel.isShowingCamera },
                set: { bookScanViewModel.isShowingCamera = $0 }
            )
        ) {
            CameraPickerView { image in
                Task {
                    if let capturedText = await bookScanViewModel.processCapturedImage(image) {
                        bookSearchViewModel.query = capturedText
                        await bookSearchViewModel.submit()
                    }
                }
            }
        }
    }
}
