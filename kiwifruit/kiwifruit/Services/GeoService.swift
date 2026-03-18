import Foundation

public struct GeoInfo: Codable {
    public let country: String?
    public let displayName: String?
}

public class GeoService {
    public static let shared = GeoService()
    private init() {}

    /// Reverse geocode using Nominatim (OpenStreetMap) to get country for lat/lon.
    public func reverseGeocode(lat: Double, lon: Double) async -> GeoInfo {
        let urlStr = "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=\(lat)&lon=\(lon)"
        guard let url = URL(string: urlStr) else { return GeoInfo(country: nil, displayName: nil) }
        var req = URLRequest(url: url)
        req.setValue("Kiwifruit-App/1.0 (contact@example.com)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return GeoInfo(country: nil, displayName: nil) }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                let display = json["display_name"] as? String
                if let address = json["address"] as? [String:Any], let country = address["country"] as? String {
                    return GeoInfo(country: country, displayName: display)
                }
            }
        } catch {
            return GeoInfo(country: nil, displayName: nil)
        }
        return GeoInfo(country: nil, displayName: nil)
    }
}
