import CoreLocation
import Foundation
import Synchronization

/// Abstracts weather challenge fetching for dependency injection.
protocol WeatherChallengeServiceProtocol: Sendable {
    func fetchWeatherChallenge() async -> Challenge?
}

/// Fetches the device's current location and weather from open-meteo.com (no API key required),
/// then returns a single weather-appropriate Challenge.
final class WeatherChallengeService: NSObject, CLLocationManagerDelegate, WeatherChallengeServiceProtocol {
    static let shared = WeatherChallengeService()

    private let manager = CLLocationManager()
    private let locationContinuation = Mutex<CheckedContinuation<CLLocation?, Never>?>(nil)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // Ann Arbor, MI — used when location permission is unavailable
    private let defaultLat = 42.2808
    private let defaultLon = -83.7430

    func fetchWeatherChallenge() async -> Challenge? {
        let location = await requestLocation()
        let lat = location?.coordinate.latitude ?? defaultLat
        let lon = location?.coordinate.longitude ?? defaultLon
        let locationLabel = location != nil
            ? String(format: "%.2f, %.2f", lat, lon)
            : String(format: "%.2f, %.2f (default)", lat, lon)
        guard let condition = await fetchWeather(lat: lat, lon: lon) else { return nil }
        return makeChallenge(from: condition, locationLabel: locationLabel)
    }


    // MARK: - Location

    private func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation.withLock { cont in
                cont = continuation
            }
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                continuation.resume(returning: nil)
                locationContinuation.withLock { cont in
                    cont = nil
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation.withLock { cont in
            cont?.resume(returning: locations.first)
            cont = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation.withLock { cont in
            cont?.resume(returning: nil)
            cont = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            locationContinuation.withLock { cont in
                cont?.resume(returning: nil)
                cont = nil
            }
        default:
            break
        }
    }

    // MARK: - Weather

    private struct WeatherCondition {
        let weatherCode: Int
        let temperatureCelsius: Double
    }

    private func fetchWeather(lat: Double, lon: Double) async -> WeatherCondition? {
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=weather_code,temperature_2m"
            + "&forecast_days=1"
        guard let url = URL(string: urlStr) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let current = json["current"] as? [String: Any]
        else { return nil }

        return WeatherCondition(
            weatherCode: current["weather_code"] as? Int ?? 0,
            temperatureCelsius: current["temperature_2m"] as? Double ?? 20.0
        )
    }

    // MARK: - Challenge generation (one per WMO weather code group)
    //
    // WMO codes: 0=clear, 1-3=cloudy, 45-48=fog, 51-55=drizzle,
    // 56-57=freezing drizzle, 61-65=rain, 66-67=freezing rain,
    // 71-77=snow, 80-82=showers, 85-86=snow showers, 95=thunderstorm, 96-99=hail

    private func weatherLabel(for code: Int, temp: Double, locationLabel: String) -> String {
        let tempStr = "\(Int(temp.rounded()))°C"
        let condition: String
        switch code {
        case 0:          condition = "Clear sky"
        case 1:          condition = "Mainly clear"
        case 2:          condition = "Partly cloudy"
        case 3:          condition = "Overcast"
        case 45...48:    condition = "Foggy"
        case 51...53:    condition = "Light drizzle"
        case 55:         condition = "Dense drizzle"
        case 56...57:    condition = "Freezing drizzle"
        case 61:         condition = "Light rain"
        case 63:         condition = "Moderate rain"
        case 65:         condition = "Heavy rain"
        case 66...67:    condition = "Freezing rain"
        case 71:         condition = "Light snow"
        case 73:         condition = "Moderate snow"
        case 75...77:    condition = "Heavy snow"
        case 80:         condition = "Light showers"
        case 81:         condition = "Moderate showers"
        case 82:         condition = "Violent showers"
        case 85...86:    condition = "Snow showers"
        case 95:         condition = "Thunderstorm"
        case 96...99:    condition = "Thunderstorm with hail"
        default:         condition = "Mixed conditions"
        }
        return "Currently: \(condition), \(tempStr). [loc: \(locationLabel)]"
    }

    private func makeChallenge(from c: WeatherCondition, locationLabel: String) -> Challenge? {
        let weather = weatherLabel(for: c.weatherCode, temp: c.temperatureCelsius, locationLabel: locationLabel)
        let code = c.weatherCode
        let tempF = c.temperatureCelsius * 9 / 5 + 32

        switch code {
        case 0:
            return Challenge(
                id: UUID(uuidString: "EEE10001-0000-0000-0000-000000000000") ?? UUID(),
                title: "Sunny Spot Challenge",
                description: "\(weather) Grab your book, find a sunny patch outside, and read for 30 minutes.",
                goalUnit: "minutes/week",
                goalCount: 30,
                rewardXP: 25
            )
        case 1...3:
            if tempF > 65 {
                return Challenge(
                    id: UUID(uuidString: "EEE10002-0000-0000-0000-000000000000") ?? UUID(),
                    title: "Cloudy Day Pages",
                    description: "\(weather) No glare, no sweat — perfect reading light. Knock out 50 pages today.",
                    goalUnit: "pages/month",
                    goalCount: 50,
                    rewardXP: 20
                )
            } else {
                return Challenge(
                    id: UUID(uuidString: "EEE10003-0000-0000-0000-000000000000") ?? UUID(),
                    title: "Grey Sky, Good Book",
                    description: "\(weather) A grey sky is basically nature's reading lamp. Read for 45 minutes.",
                    goalUnit: "minutes/week",
                    goalCount: 45,
                    rewardXP: 20
                )
            }
        case 45...48:
            return Challenge(
                id: UUID(uuidString: "EEE10004-0000-0000-0000-000000000000") ?? UUID(),
                title: "Foggy Morning Mystery",
                description: "\(weather) Can't see past the fog? Perfect excuse to disappear into a mystery novel. Read for 60 minutes.",
                goalUnit: "minutes/week",
                goalCount: 60,
                rewardXP: 25
            )
        case 51...55:
            return Challenge(
                id: UUID(uuidString: "EEE10005-0000-0000-0000-000000000000") ?? UUID(),
                title: "Drizzle & Pages",
                description: "\(weather) Light rain makes the best reading soundtrack. Hit 75 minutes this week.",
                goalUnit: "minutes/week",
                goalCount: 75,
                rewardXP: 25
            )
        case 56...57:
            return Challenge(
                id: UUID(uuidString: "EEE10006-0000-0000-0000-000000000000") ?? UUID(),
                title: "Stay In, Read On",
                description: "\(weather) You have no excuse not to read. Finish a book this month.",
                goalUnit: "books/month",
                goalCount: 1,
                rewardXP: 30
            )
        case 61...65:
            return Challenge(
                id: UUID(uuidString: "EEE10007-0000-0000-0000-000000000000") ?? UUID(),
                title: "Rainy Day Bookworm",
                description: "\(weather) Blanket, hot drink, 2 hours of reading. Go.",
                goalUnit: "minutes/week",
                goalCount: 120,
                rewardXP: 35
            )
        case 66...67:
            return Challenge(
                id: UUID(uuidString: "EEE10008-0000-0000-0000-000000000000") ?? UUID(),
                title: "Ice Storm Stories",
                description: "\(weather) Zero guilt about staying in all day. Read 100 pages.",
                goalUnit: "pages/month",
                goalCount: 100,
                rewardXP: 30
            )
        case 71...77:
            return Challenge(
                id: UUID(uuidString: "EEE10009-0000-0000-0000-000000000000") ?? UUID(),
                title: "Snow Day Bookworm",
                description: "\(weather) Read 3 hours this week and pretend you're in a cabin.",
                goalUnit: "minutes/week",
                goalCount: 180,
                rewardXP: 40
            )
        case 80...82:
            return Challenge(
                id: UUID(uuidString: "EEE1000A-0000-0000-0000-000000000000") ?? UUID(),
                title: "April Showers, Bookish Hours",
                description: "\(weather) Scattered showers = scattered reading sessions. Stack up 90 minutes this week.",
                goalUnit: "minutes/week",
                goalCount: 90,
                rewardXP: 25
            )
        case 85...86:
            return Challenge(
                id: UUID(uuidString: "EEE1000B-0000-0000-0000-000000000000") ?? UUID(),
                title: "Snowflake & Stories",
                description: "\(weather) Watch the snowflakes, read between the flurries. 60 minutes today.",
                goalUnit: "minutes/week",
                goalCount: 60,
                rewardXP: 25
            )
        case 95:
            return Challenge(
                id: UUID(uuidString: "EEE1000C-0000-0000-0000-000000000000") ?? UUID(),
                title: "Thunder & Lightning Read",
                description: "\(weather) Nothing beats reading during a thunderstorm. Power through 150 pages this week.",
                goalUnit: "pages/month",
                goalCount: 150,
                rewardXP: 40
            )
        case 96...99:
            return Challenge(
                id: UUID(uuidString: "EEE1000D-0000-0000-0000-000000000000") ?? UUID(),
                title: "Hailstorm Hideout",
                description: "\(weather) Read 2 books this month — you're not going anywhere.",
                goalUnit: "books/month",
                goalCount: 2,
                rewardXP: 50
            )
        default:
            return nil
        }
    }
}
