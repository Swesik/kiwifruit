import Foundation

final class ReverseGeocodeService {
    static let shared = ReverseGeocodeService()
    private init() {}

    struct ResultData: Codable {
        struct Address: Codable {
            let city: String?
            let town: String?
            let village: String?
            let state: String?
            let country: String?
        }
        let display_name: String?
        let address: Address?
    }

    /// Reverse geocode lat/lon using Nominatim (OpenStreetMap). Returns (place, country) or nil on failure.
    func reverse(lat: Double, lon: Double) async -> (place: String?, country: String?)? {
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/reverse")!
        comps.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", lat)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", lon)),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "addressdetails", value: "1")
        ]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        // Nominatim requires a descriptive User-Agent or Referer
        req.setValue("kiwifruit/1.0 (https://example.com)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoder = JSONDecoder()
            let obj = try decoder.decode(ResultData.self, from: data)
            // choose the best place name available
            let place = obj.address?.city ?? obj.address?.town ?? obj.address?.village ?? obj.address?.state ?? obj.display_name
            let country = obj.address?.country
            return (place, country)
        } catch {
            return nil
        }
    }
}
