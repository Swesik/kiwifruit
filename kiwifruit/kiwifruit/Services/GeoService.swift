import Foundation

public struct GeoInfo: Codable {
    public let country: String?
    public let displayName: String?
}

public class GeoService {
    public static let shared = GeoService()
    private init() {}

    /// Reverse geocode. Prefer OpenWeather reverse geocoding when an OpenWeather
    /// API key is available (limit=1). Fall back to Nominatim (OpenStreetMap).
    public func reverseGeocode(lat: Double, lon: Double) async -> GeoInfo {
        // Try OpenWeather first (use OPENWEATHER_KEY or password fallback)
        let keyCandidates = ["OPENWEATHER_KEY", "OPEN_WEATHER_KEY", "password"]
        var key: String? = nil
        for k in keyCandidates {
            if let env = ProcessInfo.processInfo.environment[k], !env.isEmpty { key = env; break }
            if let stored = UserDefaults.standard.string(forKey: k), !stored.isEmpty { key = stored; break }
            if let info = Bundle.main.object(forInfoDictionaryKey: k) as? String, !info.isEmpty { key = info; break }
            if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict[k] as? String, !val.isEmpty { key = val; break }
        }

        if let k = key {
            let urlStr = "https://api.openweathermap.org/geo/1.0/reverse?lat=\(lat)&lon=\(lon)&limit=1&appid=\(k)"
            if let url = URL(string: urlStr) {
                var req = URLRequest(url: url)
                req.setValue("Kiwifruit-App/1.0 (contact@example.com)", forHTTPHeaderField: "User-Agent")
                do {
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return GeoInfo(country: nil, displayName: nil) }
                    if let arr = try JSONSerialization.jsonObject(with: data) as? [[String:Any]], let first = arr.first {
                        let name = first["name"] as? String
                        let state = first["state"] as? String
                        let country = first["country"] as? String
                        var parts: [String] = []
                        if let n = name { parts.append(n) }
                        if let s = state { parts.append(s) }
                        if let c = country { parts.append(c) }
                        let display = parts.joined(separator: ", ")
                        return GeoInfo(country: country, displayName: display)
                    }
                } catch {
                    // fall through to nominatim
                }
            }
        }

        // Fallback: Nominatim OpenStreetMap
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
