import Foundation

protocol GeoRepository {
    func reverseGeocode(lat: Double, lon: Double) async -> GeoInfo
}

protocol PersistenceRepository {
    func integer(forKey key: String) -> Int?
    func setInteger(_ value: Int, forKey key: String)
    func array(forKey key: String) -> [String]?
    func setArray(_ array: [String]?, forKey key: String)
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
    func dictionary(forKey key: String) -> [String:Double]?
    func setDictionary(_ dict: [String:Double]?, forKey key: String)
}

// MARK: - Default adapters

class UserDefaultsPersistence: PersistenceRepository {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func integer(forKey key: String) -> Int? { return defaults.object(forKey: key) as? Int }
    func setInteger(_ value: Int, forKey key: String) { defaults.set(value, forKey: key) }
    func array(forKey key: String) -> [String]? { return defaults.array(forKey: key) as? [String] }
    func setArray(_ array: [String]?, forKey key: String) { defaults.set(array, forKey: key) }
    func data(forKey key: String) -> Data? { return defaults.data(forKey: key) }
    func setData(_ data: Data?, forKey key: String) { defaults.set(data, forKey: key) }
    func dictionary(forKey key: String) -> [String:Double]? { return defaults.dictionary(forKey: key) as? [String:Double] }
    func setDictionary(_ dict: [String:Double]?, forKey key: String) { defaults.set(dict, forKey: key) }
}

// MARK: - Conform existing services to protocols

extension GeoService: GeoRepository {}
