//
//  MockiCloudStore.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation

/// Mock implementation of NSUbiquitousKeyValueStore for testing iCloud sync
/// Stores values in memory and allows simulation of sync scenarios
class MockiCloudStore {

    static let shared = MockiCloudStore()

    private var storage: [String: Any] = [:]
    private var syncEnabled: Bool = true
    private var conflictData: [String: Any]? = nil

    // MARK: - Mock Control Properties

    /// Simulate iCloud availability
    var isAvailable: Bool = true

    /// Simulate sync delays (in seconds)
    var syncDelay: TimeInterval = 0

    /// Track synchronize() calls for verification
    var synchronizeCallCount: Int = 0

    /// Callback triggered when synchronize is called
    var onSynchronize: (() -> Void)?

    // MARK: - Storage Methods

    func set(_ value: Any?, forKey key: String) {
        guard isAvailable else {
            // Simulate iCloud unavailable - don't store
            return
        }

        if let value = value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }

        // Post change notification if sync enabled
        if syncEnabled {
            postChangeNotification(for: key)
        }
    }

    func object(forKey key: String) -> Any? {
        guard isAvailable else {
            return nil
        }
        return storage[key]
    }

    func string(forKey key: String) -> String? {
        return object(forKey: key) as? String
    }

    func array(forKey key: String) -> [Any]? {
        return object(forKey: key) as? [Any]
    }

    func dictionary(forKey key: String) -> [String: Any]? {
        return object(forKey: key) as? [String: Any]
    }

    func data(forKey key: String) -> Data? {
        return object(forKey: key) as? Data
    }

    func longLong(forKey key: String) -> Int64 {
        return object(forKey: key) as? Int64 ?? 0
    }

    func double(forKey key: String) -> Double {
        return object(forKey: key) as? Double ?? 0.0
    }

    func bool(forKey key: String) -> Bool {
        return object(forKey: key) as? Bool ?? false
    }

    func dictionaryRepresentation() -> [String: Any] {
        return storage
    }

    func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    // MARK: - Synchronization

    func synchronize() -> Bool {
        synchronizeCallCount += 1
        onSynchronize?()

        guard isAvailable else {
            return false
        }

        // Simulate sync delay if configured
        if syncDelay > 0 {
            Thread.sleep(forTimeInterval: syncDelay)
        }

        return true
    }

    // MARK: - Test Helpers

    /// Reset all storage and counters
    func reset() {
        storage.removeAll()
        synchronizeCallCount = 0
        isAvailable = true
        syncEnabled = true
        syncDelay = 0
        conflictData = nil
        onSynchronize = nil
    }

    /// Get all stored keys
    func allKeys() -> [String] {
        return Array(storage.keys)
    }

    /// Check if a key exists
    func hasValue(forKey key: String) -> Bool {
        return storage[key] != nil
    }

    /// Simulate a conflict by setting conflict data
    func simulateConflict(forKey key: String, withValue value: Any) {
        conflictData = [key: value]
        postConflictNotification(for: key)
    }

    /// Get simulated conflict data
    func getConflictData(forKey key: String) -> Any? {
        return conflictData?[key]
    }

    /// Simulate external change (from another device)
    func simulateExternalChange(forKey key: String, value: Any?) {
        set(value, forKey: key)
        postChangeNotification(for: key, external: true)
    }

    // MARK: - Notification Helpers

    private func postChangeNotification(for key: String, external: Bool = false) {
        let userInfo: [String: Any] = [
            "changedKeys": [key],
            "reason": external ? NSUbiquitousKeyValueStoreServerChange : NSUbiquitousKeyValueStoreInitialSyncChange
        ]

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: self,
            userInfo: userInfo
        )
    }

    private func postConflictNotification(for key: String) {
        let userInfo: [String: Any] = [
            "changedKeys": [key],
            "reason": NSUbiquitousKeyValueStoreServerChange
        ]

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: self,
            userInfo: userInfo
        )
    }

    // MARK: - Batch Operations

    /// Set multiple values at once
    func setMultiple(_ values: [String: Any]) {
        for (key, value) in values {
            set(value, forKey: key)
        }
    }

    /// Remove multiple keys at once
    func removeMultiple(_ keys: [String]) {
        for key in keys {
            removeObject(forKey: key)
        }
    }
}

// MARK: - NSUbiquitousKeyValueStore Extension for Testing

extension NSUbiquitousKeyValueStore {
    /// Swizzle to redirect to mock in tests
    static var useMockStore: Bool = false
}
