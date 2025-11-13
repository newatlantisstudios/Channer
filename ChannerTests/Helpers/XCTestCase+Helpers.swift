//
//  XCTestCase+Helpers.swift
//  ChannerTests
//
//  Created for testing purposes
//  Provides common test utilities and helper methods
//

import XCTest
import Foundation

// MARK: - Async Testing Helpers

extension XCTestCase {

    /// Wait for a condition to become true with a timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    ///   - pollInterval: How often to check the condition (default: 0.1 seconds)
    ///   - condition: The condition to wait for
    func waitFor(
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) {
        let expectation = XCTestExpectation(description: "Waiting for condition")

        let startTime = Date()

        Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { timer in
            if condition() {
                expectation.fulfill()
                timer.invalidate()
            } else if Date().timeIntervalSince(startTime) > timeout {
                timer.invalidate()
            }
        }

        wait(for: [expectation], timeout: timeout + 1.0)
    }

    /// Assert that a condition eventually becomes true
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    ///   - message: Failure message
    ///   - condition: The condition to wait for
    func XCTAssertEventually(
        timeout: TimeInterval = 5.0,
        message: String = "Condition did not become true in time",
        _ condition: @escaping () -> Bool
    ) {
        let expectation = XCTestExpectation(description: message)

        let startTime = Date()
        var conditionMet = false

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                conditionMet = true
                expectation.fulfill()
                timer.invalidate()
            } else if Date().timeIntervalSince(startTime) > timeout {
                timer.invalidate()
            }
        }

        wait(for: [expectation], timeout: timeout + 1.0)

        XCTAssertTrue(conditionMet, message)
    }
}

// MARK: - UserDefaults Helpers

extension XCTestCase {

    /// Create a test-specific UserDefaults suite
    /// - Parameter suiteName: Optional suite name (will generate unique one if not provided)
    /// - Returns: A new UserDefaults instance for testing
    func createTestDefaults(suiteName: String? = nil) -> UserDefaults {
        let suite = suiteName ?? "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        // Clean up any existing data
        defaults.removePersistentDomain(forName: suite)

        return defaults
    }

    /// Clean up test UserDefaults
    /// - Parameter defaults: The UserDefaults instance to clean up
    func cleanupTestDefaults(_ defaults: UserDefaults) {
        if let suiteName = defaults.dictionaryRepresentation().keys.first {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}

// MARK: - Notification Testing Helpers

extension XCTestCase {

    /// Track notifications posted during a test
    /// - Parameters:
    ///   - notificationName: The notification to track
    ///   - object: The object to observe (nil for any)
    ///   - handler: Block to execute when notification is posted
    /// - Returns: An observer token that should be removed in tearDown
    @discardableResult
    func trackNotification(
        _ notificationName: Notification.Name,
        object: Any? = nil,
        handler: @escaping (Notification) -> Void = { _ in }
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: notificationName,
            object: object,
            queue: .main,
            using: handler
        )
    }

    /// Wait for a specific notification to be posted
    /// - Parameters:
    ///   - notificationName: The notification to wait for
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    ///   - object: The object to observe (nil for any)
    func waitForNotification(
        _ notificationName: Notification.Name,
        timeout: TimeInterval = 5.0,
        object: Any? = nil
    ) {
        let expectation = XCTNSNotificationExpectation(
            name: notificationName,
            object: object
        )

        wait(for: [expectation], timeout: timeout)
    }

    /// Assert that a notification was posted
    /// - Parameters:
    ///   - notificationName: The notification to check
    ///   - timeout: Maximum time to wait (default: 2 seconds)
    ///   - message: Failure message
    func XCTAssertNotificationPosted(
        _ notificationName: Notification.Name,
        timeout: TimeInterval = 2.0,
        message: String? = nil
    ) {
        let expectation = XCTNSNotificationExpectation(name: notificationName)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

        let failureMessage = message ?? "Notification \(notificationName.rawValue) was not posted"
        XCTAssertEqual(result, .completed, failureMessage)
    }
}

// MARK: - File System Helpers

extension XCTestCase {

    /// Create a temporary test directory
    /// - Returns: URL to the temporary directory
    func createTestDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChannerTests")
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return tempDir
    }

    /// Clean up a test directory
    /// - Parameter directory: The directory to remove
    func cleanupTestDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Write test data to a file
    /// - Parameters:
    ///   - data: The data to write
    ///   - filename: The filename
    ///   - directory: The directory (will use temp if not specified)
    /// - Returns: URL to the written file
    @discardableResult
    func writeTestFile(
        _ data: Data,
        filename: String,
        in directory: URL? = nil
    ) -> URL {
        let dir = directory ?? createTestDirectory()
        let fileURL = dir.appendingPathComponent(filename)

        try? data.write(to: fileURL)

        return fileURL
    }
}

// MARK: - JSON Testing Helpers

extension XCTestCase {

    /// Encode and decode a Codable object to test serialization
    /// - Parameter object: The object to test
    /// - Returns: The decoded object
    func roundTripJSON<T: Codable>(_ object: T) throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Assert that a Codable object can be encoded and decoded
    /// - Parameter object: The object to test
    func XCTAssertCodable<T: Codable & Equatable>(_ object: T) {
        do {
            let roundTripped = try roundTripJSON(object)
            XCTAssertEqual(object, roundTripped, "Object did not survive round-trip encoding")
        } catch {
            XCTFail("Failed to encode/decode object: \(error)")
        }
    }
}

// MARK: - Threading Helpers

extension XCTestCase {

    /// Execute code on main thread and wait for completion
    /// - Parameter block: Code to execute
    func executeOnMain(_ block: @escaping () -> Void) {
        let expectation = XCTestExpectation(description: "Main thread execution")

        DispatchQueue.main.async {
            block()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    /// Execute code on background thread and wait for completion
    /// - Parameter block: Code to execute
    func executeOnBackground(_ block: @escaping () -> Void) {
        let expectation = XCTestExpectation(description: "Background thread execution")

        DispatchQueue.global(qos: .background).async {
            block()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Collection Assertions

extension XCTestCase {

    /// Assert that a collection is empty
    func XCTAssertEmpty<T: Collection>(_ collection: T, _ message: String = "Collection should be empty") {
        XCTAssertTrue(collection.isEmpty, message)
    }

    /// Assert that a collection is not empty
    func XCTAssertNotEmpty<T: Collection>(_ collection: T, _ message: String = "Collection should not be empty") {
        XCTAssertFalse(collection.isEmpty, message)
    }

    /// Assert that a collection has a specific count
    func XCTAssertCount<T: Collection>(_ collection: T, _ expected: Int, _ message: String? = nil) {
        let msg = message ?? "Expected collection to have \(expected) items, but had \(collection.count)"
        XCTAssertEqual(collection.count, expected, msg)
    }
}
