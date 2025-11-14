//
//  TestHelpers.swift
//  ChannerTests
//
//  Created for unit testing
//

import XCTest
import UIKit
@testable import _chan

/// Shared helper methods and utilities for all tests
class TestHelpers {

    // MARK: - Wait/Expectation Helpers

    /// Wait for async operation with timeout
    static func wait(for duration: TimeInterval) {
        Thread.sleep(forTimeInterval: duration)
    }

    /// Wait for condition to be true
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        pollingInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) -> Bool {
        let endTime = Date().addingTimeInterval(timeout)

        while Date() < endTime {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: pollingInterval)
        }

        return false
    }

    /// Create expectation and fulfill after delay
    static func createDelayedExpectation(
        testCase: XCTestCase,
        description: String,
        delay: TimeInterval
    ) -> XCTestExpectation {
        let expectation = testCase.expectation(description: description)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        return expectation
    }

    // MARK: - File System Helpers

    /// Get temporary directory for tests
    static func temporaryDirectory() -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("ChannerTests")
    }

    /// Create temporary test directory
    static func createTemporaryDirectory() -> URL {
        let tempDir = temporaryDirectory()
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Clean up temporary test directory
    static func cleanTemporaryDirectory() {
        let tempDir = temporaryDirectory()
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Create temporary file with content
    static func createTemporaryFile(
        name: String,
        content: Data,
        subdirectory: String? = nil
    ) -> URL {
        var directory = temporaryDirectory()

        if let subdirectory = subdirectory {
            directory.appendPathComponent(subdirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let fileURL = directory.appendingPathComponent(name)
        try? content.write(to: fileURL)
        return fileURL
    }

    // MARK: - Date Helpers

    /// Create date from components
    static func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Create date from timestamp
    static func date(from timestamp: Int) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    // MARK: - Random Data Generators

    /// Generate random string
    static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    /// Generate random integer in range
    static func randomInt(min: Int = 1, max: Int = 100000) -> Int {
        return Int.random(in: min...max)
    }

    /// Generate random thread number
    static func randomThreadNumber() -> Int {
        return randomInt(min: 100000, max: 999999999)
    }

    /// Generate random board abbreviation
    static func randomBoardAbbreviation() -> String {
        let boards = ["g", "v", "a", "b", "tv", "pol", "fit", "biz"]
        return boards.randomElement()!
    }

    // MARK: - Image Helpers

    /// Create solid color image for testing
    static func createTestImage(
        size: CGSize = CGSize(width: 100, height: 100),
        color: UIColor = .red
    ) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    /// Create image with text
    static func createTestImageWithText(
        _ text: String,
        size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        UIColor.lightGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]

        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        text.draw(in: textRect, withAttributes: attributes)

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    // MARK: - JSON Helpers

    /// Load JSON from file in test bundle
    static func loadJSONFromFile(_ filename: String, bundle: Bundle = .main) -> Data? {
        guard let path = bundle.path(forResource: filename, ofType: "json") else {
            return nil
        }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// Convert dictionary to JSON data
    static func jsonData(from dictionary: [String: Any]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: dictionary, options: [])
    }

    /// Convert array to JSON data
    static func jsonData(from array: [[String: Any]]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: array, options: [])
    }

    // MARK: - Assertion Helpers

    /// Assert that two dates are approximately equal (within tolerance)
    static func assertDatesEqual(
        _ date1: Date?,
        _ date2: Date?,
        tolerance: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let date1 = date1, let date2 = date2 else {
            XCTFail("One or both dates are nil", file: file, line: line)
            return
        }

        let difference = abs(date1.timeIntervalSince(date2))
        XCTAssertLessThanOrEqual(
            difference,
            tolerance,
            "Dates differ by \(difference) seconds, expected within \(tolerance) seconds",
            file: file,
            line: line
        )
    }

    /// Assert that array contains element matching predicate
    static func assertContains<T>(
        _ array: [T],
        where predicate: (T) -> Bool,
        message: String = "Array does not contain expected element",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(array.contains(where: predicate), message, file: file, line: line)
    }

    /// Assert that array does not contain element matching predicate
    static func assertDoesNotContain<T>(
        _ array: [T],
        where predicate: (T) -> Bool,
        message: String = "Array contains unexpected element",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(array.contains(where: predicate), message, file: file, line: line)
    }

    // MARK: - Notification Helpers

    /// Observe notification and call handler
    static func observeNotification(
        _ name: Notification.Name,
        timeout: TimeInterval = 5.0,
        handler: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main,
            using: handler
        )
    }

    /// Wait for notification to be posted
    static func waitForNotification(
        _ name: Notification.Name,
        timeout: TimeInterval = 5.0,
        testCase: XCTestCase
    ) -> XCTestExpectation {
        return testCase.expectation(
            forNotification: name,
            object: nil,
            handler: nil
        )
    }

    // MARK: - UserDefaults Helpers

    /// Create isolated UserDefaults suite for testing
    static func createTestUserDefaults(suiteName: String = "TestDefaults") -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Clean up test UserDefaults suite
    static func cleanupTestUserDefaults(suiteName: String = "TestDefaults") {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - Thread Safety Helpers

    /// Execute block on main thread and wait
    static func executeOnMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }

    /// Execute async block with completion
    static func executeAsync(
        _ block: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        DispatchQueue.global().async {
            block()
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {

    /// Measure execution time of block
    func measureTime(_ description: String = "Execution time", block: () -> Void) {
        let start = Date()
        block()
        let elapsed = Date().timeIntervalSince(start)
        print("[\(description)] Elapsed: \(String(format: "%.4f", elapsed))s")
    }

    /// Assert throws specific error
    func assertThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () throws -> T,
        expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(error as? E, expectedError, file: file, line: line)
        }
    }
}
