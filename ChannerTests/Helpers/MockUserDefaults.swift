//
//  MockUserDefaults.swift
//  ChannerTests
//
//  Created for testing purposes
//  Provides an in-memory UserDefaults implementation for isolated testing
//

import Foundation

/// Mock UserDefaults for testing that stores data in memory
/// This prevents tests from polluting the real app's UserDefaults
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    private var callLog: [String] = []

    // MARK: - Tracking

    /// Number of times set operations were called
    var setCallCount: Int {
        return callLog.filter { $0.hasPrefix("set") }.count
    }

    /// Number of times get operations were called
    var getCallCount: Int {
        return callLog.filter { $0.hasPrefix("get") }.count
    }

    /// Log all method calls for debugging
    var allCalls: [String] {
        return callLog
    }

    // MARK: - Override Storage Methods

    override func object(forKey defaultName: String) -> Any? {
        callLog.append("get:\(defaultName)")
        return storage[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        callLog.append("set:\(defaultName)")
        if let value = value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }

    override func string(forKey defaultName: String) -> String? {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? String
    }

    override func array(forKey defaultName: String) -> [Any]? {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? [Any]
    }

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? [String: Any]
    }

    override func data(forKey defaultName: String) -> Data? {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? Data
    }

    override func stringArray(forKey defaultName: String) -> [String]? {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? [String]
    }

    override func integer(forKey defaultName: String) -> Int {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? Int ?? 0
    }

    override func float(forKey defaultName: String) -> Float {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? Float ?? 0.0
    }

    override func double(forKey defaultName: String) -> Double {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? Double ?? 0.0
    }

    override func bool(forKey defaultName: String) -> Bool {
        callLog.append("get:\(defaultName)")
        return storage[defaultName] as? Bool ?? false
    }

    override func removeObject(forKey defaultName: String) {
        callLog.append("remove:\(defaultName)")
        storage.removeValue(forKey: defaultName)
    }

    override func set(_ value: Int, forKey defaultName: String) {
        callLog.append("set:\(defaultName)")
        storage[defaultName] = value
    }

    override func set(_ value: Float, forKey defaultName: String) {
        callLog.append("set:\(defaultName)")
        storage[defaultName] = value
    }

    override func set(_ value: Double, forKey defaultName: String) {
        callLog.append("set:\(defaultName)")
        storage[defaultName] = value
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        callLog.append("set:\(defaultName)")
        storage[defaultName] = value
    }

    // MARK: - Test Helpers

    /// Reset all stored data and call logs
    func reset() {
        storage.removeAll()
        callLog.removeAll()
    }

    /// Check if a key exists in storage
    func hasKey(_ key: String) -> Bool {
        return storage[key] != nil
    }

    /// Get all stored keys
    func allKeys() -> [String] {
        return Array(storage.keys)
    }

    /// Get the raw storage for inspection
    func inspectStorage() -> [String: Any] {
        return storage
    }
}

// MARK: - XCTestCase Extension for UserDefaults

extension XCTestCase {
    /// Create a fresh MockUserDefaults for each test
    func createMockDefaults() -> MockUserDefaults {
        return MockUserDefaults()
    }
}
