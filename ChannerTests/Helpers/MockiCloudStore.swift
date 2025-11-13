//
//  MockiCloudStore.swift
//  ChannerTests
//
//  Created for testing purposes
//  Provides a mock implementation of NSUbiquitousKeyValueStore for testing iCloud sync
//

import Foundation

/// Mock NSUbiquitousKeyValueStore for testing iCloud sync functionality
/// This allows testing sync behavior without actual iCloud access
class MockiCloudStore {
    // MARK: - Storage

    private var storage: [String: Any] = [:]
    private var callLog: [(method: String, key: String)] = []

    // MARK: - Simulation Controls

    /// Simulate iCloud being unavailable
    var simulateUnavailable = false

    /// Simulate sync delay (in seconds)
    var simulatedSyncDelay: TimeInterval = 0.0

    /// Should the next sync operation fail?
    var shouldFailNextSync = false

    // MARK: - Call Tracking

    var setCallCount: Int {
        return callLog.filter { $0.method == "set" }.count
    }

    var getCallCount: Int {
        return callLog.filter { $0.method == "get" }.count
    }

    var synchronizeCallCount: Int {
        return callLog.filter { $0.method == "synchronize" }.count
    }

    var allCalls: [(method: String, key: String)] {
        return callLog
    }

    // MARK: - NSUbiquitousKeyValueStore-like Interface

    /// Get data for key
    func data(forKey key: String) -> Data? {
        callLog.append(("get", key))
        guard !simulateUnavailable else { return nil }
        return storage[key] as? Data
    }

    /// Set data for key
    func set(_ data: Data?, forKey key: String) {
        callLog.append(("set", key))
        guard !simulateUnavailable else { return }

        if let data = data {
            storage[key] = data
        } else {
            storage.removeValue(forKey: key)
        }

        // Trigger sync notification after a delay
        if simulatedSyncDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + simulatedSyncDelay) { [weak self] in
                self?.postSyncNotification()
            }
        }
    }

    /// Get object for key
    func object(forKey key: String) -> Any? {
        callLog.append(("get", key))
        guard !simulateUnavailable else { return nil }
        return storage[key]
    }

    /// Set object for key
    func set(_ object: Any?, forKey key: String) {
        callLog.append(("set", key))
        guard !simulateUnavailable else { return }

        if let object = object {
            storage[key] = object
        } else {
            storage.removeValue(forKey: key)
        }
    }

    /// Get string for key
    func string(forKey key: String) -> String? {
        callLog.append(("get", key))
        guard !simulateUnavailable else { return nil }
        return storage[key] as? String
    }

    /// Set string for key
    func set(_ string: String?, forKey key: String) {
        callLog.append(("set", key))
        guard !simulateUnavailable else { return }

        if let string = string {
            storage[key] = string
        } else {
            storage.removeValue(forKey: key)
        }
    }

    /// Get array for key
    func array(forKey key: String) -> [Any]? {
        callLog.append(("get", key))
        guard !simulateUnavailable else { return nil }
        return storage[key] as? [Any]
    }

    /// Set array for key
    func set(_ array: [Any]?, forKey key: String) {
        callLog.append(("set", key))
        guard !simulateUnavailable else { return }

        if let array = array {
            storage[key] = array
        } else {
            storage.removeValue(forKey: key)
        }
    }

    /// Get dictionary for key
    func dictionary(forKey key: String) -> [String: Any]? {
        callLog.append(("get", key))
        guard !simulateUnavailable else { return nil }
        return storage[key] as? [String: Any]
    }

    /// Set dictionary for key
    func set(_ dictionary: [String: Any]?, forKey key: String) {
        callLog.append(("set", key))
        guard !simulateUnavailable else { return }

        if let dictionary = dictionary {
            storage[key] = dictionary
        } else {
            storage.removeValue(forKey: key)
        }
    }

    /// Get bool for key
    func bool(forKey key: String) -> Bool {
        callLog.append(("get", key))
        guard !simulateUnavailable else { return false }
        return storage[key] as? Bool ?? false
    }

    /// Set bool for key
    func set(_ bool: Bool, forKey key: String) {
        callLog.append(("set", key))
        guard !simulateUnavailable else { return }
        storage[key] = bool
    }

    /// Remove object for key
    func removeObject(forKey key: String) {
        callLog.append(("remove", key))
        guard !simulateUnavailable else { return }
        storage.removeValue(forKey: key)
    }

    /// Synchronize with iCloud (mock)
    @discardableResult
    func synchronize() -> Bool {
        callLog.append(("synchronize", ""))

        if shouldFailNextSync {
            shouldFailNextSync = false
            return false
        }

        guard !simulateUnavailable else { return false }

        // Post sync notification
        postSyncNotification()

        return true
    }

    /// Get all keys
    func dictionaryRepresentation() -> [String: Any] {
        return storage
    }

    // MARK: - Test Helpers

    /// Reset all storage and call logs
    func reset() {
        storage.removeAll()
        callLog.removeAll()
        simulateUnavailable = false
        simulatedSyncDelay = 0.0
        shouldFailNextSync = false
    }

    /// Check if a key exists
    func hasKey(_ key: String) -> Bool {
        return storage[key] != nil
    }

    /// Get all keys
    func allKeys() -> [String] {
        return Array(storage.keys)
    }

    /// Manually trigger a sync notification (simulating external iCloud change)
    func simulateExternalChange(key: String, value: Any?) {
        if let value = value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
        postSyncNotification(changedKeys: [key])
    }

    /// Post iCloud sync notification
    private func postSyncNotification(changedKeys: [String]? = nil) {
        var userInfo: [String: Any] = [:]
        if let keys = changedKeys {
            userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] = keys
        }

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            userInfo: userInfo
        )
    }

    /// Simulate a sync conflict
    func simulateConflict(forKey key: String, localValue: Any, remoteValue: Any) {
        // Store remote value
        storage[key] = remoteValue

        // Post notification with conflict info
        let userInfo: [String: Any] = [
            NSUbiquitousKeyValueStoreChangedKeysKey: [key],
            NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange
        ]

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Create a fresh MockiCloudStore for each test
    func createMockiCloudStore() -> MockiCloudStore {
        return MockiCloudStore()
    }
}
