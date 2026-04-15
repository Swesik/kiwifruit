import CoreLocation
import Foundation
import Synchronization

/// Abstracts weather challenge fetching for dependency injection.
protocol WeatherChallengeServiceProtocol: Sendable {
    func fetchWeatherChallenge() async -> Challenge?
}

/// Resolves the device's current location (with a hard timeout + default
/// fallback) and hands it off to the server, which fetches the weather and
/// asks OpenAI to compose a weather-inspired challenge. iOS no longer owns
/// any weather-to-challenge logic — it's all on the server now.
final class WeatherChallengeService: NSObject, CLLocationManagerDelegate, WeatherChallengeServiceProtocol {
    static let shared = WeatherChallengeService()

    private let manager = CLLocationManager()
    private let locationContinuation = Mutex<CheckedContinuation<CLLocation?, Never>?>(nil)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // Ann Arbor, MI — used when location permission is unavailable.
    private let defaultLat = 42.2808
    private let defaultLon = -83.7430

    func fetchWeatherChallenge() async -> Challenge? {
        let location = await requestLocation()
        let lat = location?.coordinate.latitude ?? defaultLat
        let lon = location?.coordinate.longitude ?? defaultLon

        do {
            let resp = try await AppAPI.shared.fetchWeatherChallenge(latitude: lat, longitude: lon)
            guard resp.available, let data = resp.challenge else { return nil }
            return Challenge(
                title: data.title,
                description: data.description,
                goalUnit: data.goalUnit,
                goalCount: data.goalCount,
                rewardXP: data.rewardXP,
                isAdaptive: false,
                reason: data.reason,
                isWeather: true
            )
        } catch {
            print("[WeatherChallengeService] fetchWeatherChallenge failed: \(error)")
            return nil
        }
    }

    // MARK: - Location

    private func requestLocation() async -> CLLocation? {
        // Race the permission / location delegate callbacks against a short
        // timeout. If neither resolves in 3 seconds we resume with nil and
        // fall back to default coordinates — prevents the continuation leak
        // that was hanging weather forever when the simulator left
        // authorizationStatus in .notDetermined.
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
                locationContinuation.withLock { cont in
                    cont?.resume(returning: nil)
                    cont = nil
                }
                return
            }

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.locationContinuation.withLock { cont in
                    cont?.resume(returning: nil)
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
}
