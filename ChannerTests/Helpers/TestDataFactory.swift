//
//  TestDataFactory.swift
//  ChannerTests
//
//  Created for testing purposes
//  Provides factory methods for creating test data fixtures
//

import Foundation
@testable import Channer

/// Factory for creating test data fixtures used across multiple test files
class TestDataFactory {

    // MARK: - ThreadData

    /// Create a basic test thread
    static func createTestThread(
        number: String = "12345678",
        boardAbv: String = "g",
        title: String = "Test Thread",
        comment: String = "This is a test thread for unit testing",
        replies: Int = 10,
        images: Int = 5,
        imageUrl: String? = nil,
        hasNewReplies: Bool = false,
        categoryId: String? = nil
    ) -> ThreadData {
        // Use Codable initializer to create test data
        let stats = "\(replies)/\(images)"
        let createdAt = "01/13/25(Mon)12:00:00"
        let lastReplyTime = Int(Date().timeIntervalSince1970)

        let data = """
        {
            "number": "\(number)",
            "stats": "\(stats)",
            "title": "\(title)",
            "comment": "\(comment)",
            "imageUrl": "\(imageUrl ?? (images > 0 ? "https://i.4cdn.org/\(boardAbv)/1234567890123.jpg" : ""))",
            "boardAbv": "\(boardAbv)",
            "replies": \(replies),
            "currentReplies": null,
            "createdAt": "\(createdAt)",
            "hasNewReplies": \(hasNewReplies),
            "categoryId": \(categoryId != nil ? "\"\(categoryId!)\"" : "null"),
            "lastReplyTime": \(lastReplyTime),
            "bumpIndex": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        return try! decoder.decode(ThreadData.self, from: data)
    }

    /// Create a thread with specific properties for testing edge cases
    static func createThreadWithOptions(
        hasNewReplies: Bool = false,
        categoryId: String? = nil,
        noTitle: Bool = false,
        noImage: Bool = false
    ) -> ThreadData {
        return createTestThread(
            title: noTitle ? "" : "Test Thread",
            images: noImage ? 0 : 5,
            imageUrl: noImage ? "" : nil,
            hasNewReplies: hasNewReplies,
            categoryId: categoryId
        )
    }

    // MARK: - BookmarkCategory

    /// Create a test bookmark category
    static func createTestCategory(
        name: String = "Test Category",
        color: String = "#FF0000",
        icon: String = "star.fill"
    ) -> BookmarkCategory {
        return BookmarkCategory(
            name: name,
            color: color,
            icon: icon
        )
    }

    /// Create default test categories (matching app defaults)
    static func createDefaultCategories() -> [BookmarkCategory] {
        return [
            createTestCategory(name: "General", color: "#007AFF", icon: "star.fill"),
            createTestCategory(name: "To Read", color: "#34C759", icon: "book.fill"),
            createTestCategory(name: "Important", color: "#FF9500", icon: "exclamationmark.circle.fill"),
            createTestCategory(name: "Archives", color: "#8E8E93", icon: "archivebox.fill")
        ]
    }

    // MARK: - CachedThread (for ThreadCacheManager)

    /// Create a test cached thread
    static func createCachedThread(
        boardAbv: String = "g",
        threadNumber: String = "12345678",
        cachedDate: Date = Date(),
        cachedImages: [String] = [],
        categoryId: String? = nil
    ) -> CachedThread {
        // Create thread data
        let threadData = createTestThread(number: threadNumber, boardAbv: boardAbv)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(threadData)

        let jsonString = """
        {
            "boardAbv": "\(boardAbv)",
            "threadNumber": "\(threadNumber)",
            "threadData": "\(data.base64EncodedString())",
            "cachedImages": [\(cachedImages.map { "\"\($0)\"" }.joined(separator: ","))],
            "cachedDate": \(cachedDate.timeIntervalSince1970),
            "categoryId": \(categoryId != nil ? "\"\(categoryId!)\"" : "null")
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try! decoder.decode(CachedThread.self, from: jsonString)
    }

    // MARK: - ReplyNotification (for NotificationManager)

    /// Create a test reply notification
    static func createTestNotification(
        boardAbv: String = "g",
        threadNo: String = "12345678",
        replyNo: String = "87654321",
        replyToNo: String = "87654320",
        replyText: String = "This is a test reply notification",
        isRead: Bool = false
    ) -> ReplyNotification {
        return ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: replyNo,
            replyToNo: replyToNo,
            replyText: replyText
        )
    }

    // MARK: - SearchItem (for SearchManager)

    /// Create a test search item
    static func createSearchItem(
        query: String = "test query",
        boardAbv: String? = nil
    ) -> SearchManager.SearchItem {
        return SearchManager.SearchItem(
            query: query,
            boardAbv: boardAbv
        )
    }

    /// Create a test saved search
    static func createSavedSearch(
        name: String = "Test Saved Search",
        query: String = "test query",
        boardAbv: String? = nil
    ) -> SearchManager.SavedSearch {
        return SearchManager.SavedSearch(
            name: name,
            query: query,
            boardAbv: boardAbv
        )
    }

    // MARK: - Theme (for ThemeManager)

    /// Create a test theme
    static func createTestTheme(
        id: String = "test_theme",
        name: String = "Test Theme",
        isBuiltIn: Bool = false
    ) -> Theme {
        return Theme(
            id: id,
            name: name,
            isBuiltIn: isBuiltIn,
            backgroundColor: ColorSet(light: "#FFFFFF", dark: "#1C1C1E"),
            secondaryBackgroundColor: ColorSet(light: "#F2F2F7", dark: "#2C2C2E"),
            cellBackgroundColor: ColorSet(light: "#FFECDB", dark: "#262627"),
            cellBorderColor: ColorSet(light: "#43A047", dark: "#408547"),
            primaryTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            secondaryTextColor: ColorSet(light: "#696969", dark: "#D3D3D3"),
            greentextColor: ColorSet(light: "#789922", dark: "#8CB736"),
            alertColor: ColorSet(light: "#FF3B30", dark: "#FF3B30"),
            spoilerTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            spoilerBackgroundColor: ColorSet(light: "#000000", dark: "#696969")
        )
    }

    /// Get the default built-in theme for testing
    static func getDefaultTheme() -> Theme {
        return Theme.default
    }

    // MARK: - Content Filters

    /// Create test content filter arrays
    static func createTestFilters() -> (keywords: [String], posters: [String], images: [String]) {
        let keywords = ["spam", "advertisement", "test"]
        let posters = ["Anonymous123", "Troll456"]
        let images = ["badimage.jpg", "spam.png"]
        return (keywords, posters, images)
    }

    // MARK: - Dates

    /// Create a date relative to now
    static func dateRelativeToNow(daysAgo: Int = 0, hoursAgo: Int = 0, minutesAgo: Int = 0) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.day = -daysAgo
        components.hour = -hoursAgo
        components.minute = -minutesAgo
        return calendar.date(byAdding: components, to: now) ?? now
    }

    // MARK: - Random Data

    /// Generate random string for testing
    static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    /// Generate random thread number
    static func randomThreadNumber() -> String {
        return String(format: "%d", Int.random(in: 10000000...99999999))
    }

    /// Generate random post number
    static func randomPostNumber() -> String {
        return String(format: "%d", Int.random(in: 10000000...99999999))
    }
}
