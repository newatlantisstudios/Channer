//
//  MockUserDefaults.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation

/// Mock implementation of UserDefaults for testing
/// Stores values in memory instead of persisting to disk
class MockUserDefaults: UserDefaults {

    private var storage: [String: Any] = [:]
    private var registeredDefaults: [String: Any] = [:]

    // MARK: - Initialization

    override init?(suiteName suitename: String?) {
        super.init(suiteName: suitename)
    }

    override init() {
        super.init()
    }

    // MARK: - Getter Methods

    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }

    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }

    override func array(forKey defaultName: String) -> [Any]? {
        return storage[defaultName] as? [Any]
    }

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        return storage[defaultName] as? [String: Any]
    }

    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }

    override func stringArray(forKey defaultName: String) -> [String]? {
        return storage[defaultName] as? [String]
    }

    override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }

    override func float(forKey defaultName: String) -> Float {
        return storage[defaultName] as? Float ?? 0.0
    }

    override func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }

    override func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }

    override func url(forKey defaultName: String) -> URL? {
        return storage[defaultName] as? URL
    }

    // MARK: - Setter Methods

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ value: Int, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ value: Float, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ value: Double, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ url: URL?, forKey defaultName: String) {
        storage[defaultName] = url
    }

    // MARK: - Remove Methods

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }

    // MARK: - Synchronization

    override func synchronize() -> Bool {
        // In memory storage doesn't need synchronization
        return true
    }

    // MARK: - Registration

    override func register(defaults registrationDictionary: [String: Any]) {
        registeredDefaults.merge(registrationDictionary) { (_, new) in new }
    }

    // MARK: - Dictionary Representation

    override func dictionaryRepresentation() -> [String: Any] {
        return storage
    }

    // MARK: - Test Helpers

    /// Clears all stored values (useful for test cleanup)
    func reset() {
        storage.removeAll()
        registeredDefaults.removeAll()
    }

    /// Returns all stored keys for verification in tests
    func allKeys() -> [String] {
        return Array(storage.keys)
    }

    /// Check if a key exists
    func hasValue(forKey key: String) -> Bool {
        return storage[key] != nil
    }
}
