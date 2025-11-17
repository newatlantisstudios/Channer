//
//  TestData.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation
import UIKit
import SwiftyJSON
@testable import Channer

/// Sample test data fixtures for all model types
struct TestData {

    // MARK: - ThreadData Fixtures

    static func sampleThreadData(
        number: String = "123456789",
        boardAbv: String = "g",
        title: String = "Test Thread",
        comment: String = "This is a test thread comment",
        replies: Int = 50,
        categoryId: String? = nil
    ) -> ThreadData {
        return ThreadData(
            number: number,
            stats: "R: \(replies) / I: 10",
            title: title,
            comment: comment,
            imageUrl: "https://i.4cdn.org/\(boardAbv)/\(number)s.jpg",
            boardAbv: boardAbv,
            replies: replies,
            currentReplies: replies,
            createdAt: "2024-01-15 12:00:00",
            hasNewReplies: false,
            categoryId: categoryId,
            lastReplyTime: 1234567890,
            bumpIndex: 0
        )
    }

    static func sampleThreadDataArray(count: Int = 5, boardAbv: String = "g") -> [ThreadData] {
        return (1...count).map { index in
            sampleThreadData(
                number: String(123456000 + index),
                boardAbv: boardAbv,
                title: "Test Thread \(index)",
                comment: "Comment for thread \(index)",
                replies: 10 * index
            )
        }
    }

    static func threadDataWithNewReplies() -> ThreadData {
        return ThreadData(
            number: "987654321",
            stats: "R: 75 / I: 20",
            title: "Thread With Updates",
            comment: "This thread has new replies",
            imageUrl: "https://i.4cdn.org/v/987654321s.jpg",
            boardAbv: "v",
            replies: 50,
            currentReplies: 75,
            createdAt: "2024-01-20 15:30:00",
            hasNewReplies: true,
            categoryId: nil,
            lastReplyTime: 1234567999,
            bumpIndex: 0
        )
    }

    // MARK: - BookmarkCategory Fixtures

    static func sampleCategory(
        id: String = UUID().uuidString,
        name: String = "Test Category",
        color: String = "#007AFF",
        icon: String = "folder"
    ) -> BookmarkCategory {
        return BookmarkCategory(name: name, color: color, icon: icon)
    }

    static func defaultCategories() -> [BookmarkCategory] {
        return [
            BookmarkCategory(name: "General", color: "#007AFF", icon: "folder"),
            BookmarkCategory(name: "To Read", color: "#FF9500", icon: "book"),
            BookmarkCategory(name: "Important", color: "#FF3B30", icon: "star.fill"),
            BookmarkCategory(name: "Archives", color: "#5856D6", icon: "archivebox")
        ]
    }

    static func customCategories() -> [BookmarkCategory] {
        return [
            BookmarkCategory(name: "Work", color: "#34C759", icon: "briefcase"),
            BookmarkCategory(name: "Personal", color: "#AF52DE", icon: "person"),
            BookmarkCategory(name: "Research", color: "#5AC8FA", icon: "magnifyingglass")
        ]
    }

    // MARK: - Theme Fixtures

    static func sampleTheme(
        id: String = "test-theme",
        name: String = "Test Theme",
        isBuiltIn: Bool = false
    ) -> Theme {
        return Theme(
            id: id,
            name: name,
            isBuiltIn: isBuiltIn,
            backgroundColor: ColorSet(light: "#FFFFFF", dark: "#000000"),
            secondaryBackgroundColor: ColorSet(light: "#F2F2F7", dark: "#1C1C1E"),
            cellBackgroundColor: ColorSet(light: "#FFFFFF", dark: "#2C2C2E"),
            cellBorderColor: ColorSet(light: "#E5E5EA", dark: "#3A3A3C"),
            primaryTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            secondaryTextColor: ColorSet(light: "#8E8E93", dark: "#AEAEB2"),
            greentextColor: ColorSet(light: "#34C759", dark: "#30D158"),
            alertColor: ColorSet(light: "#FF3B30", dark: "#FF453A"),
            spoilerTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            spoilerBackgroundColor: ColorSet(light: "#000000", dark: "#8E8E93")
        )
    }

    static func defaultTheme() -> Theme {
        return Theme(
            id: "default",
            name: "Default",
            isBuiltIn: true,
            backgroundColor: ColorSet(light: "#FFFFFF", dark: "#000000"),
            secondaryBackgroundColor: ColorSet(light: "#F2F2F7", dark: "#1C1C1E"),
            cellBackgroundColor: ColorSet(light: "#FFFFFF", dark: "#2C2C2E"),
            cellBorderColor: ColorSet(light: "#E5E5EA", dark: "#3A3A3C"),
            primaryTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            secondaryTextColor: ColorSet(light: "#8E8E93", dark: "#AEAEB2"),
            greentextColor: ColorSet(light: "#34C759", dark: "#30D158"),
            alertColor: ColorSet(light: "#FF3B30", dark: "#FF453A"),
            spoilerTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            spoilerBackgroundColor: ColorSet(light: "#000000", dark: "#8E8E93")
        )
    }

    static func oledTheme() -> Theme {
        return Theme(
            id: "oled",
            name: "OLED",
            isBuiltIn: true,
            backgroundColor: ColorSet(light: "#FFFFFF", dark: "#000000"),
            secondaryBackgroundColor: ColorSet(light: "#F2F2F7", dark: "#000000"),
            cellBackgroundColor: ColorSet(light: "#FFFFFF", dark: "#0A0A0A"),
            cellBorderColor: ColorSet(light: "#E5E5EA", dark: "#1C1C1C"),
            primaryTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            secondaryTextColor: ColorSet(light: "#8E8E93", dark: "#AEAEB2"),
            greentextColor: ColorSet(light: "#34C759", dark: "#30D158"),
            alertColor: ColorSet(light: "#FF3B30", dark: "#FF453A"),
            spoilerTextColor: ColorSet(light: "#000000", dark: "#FFFFFF"),
            spoilerBackgroundColor: ColorSet(light: "#000000", dark: "#8E8E93")
        )
    }



    // MARK: - CachedThread Fixtures

    static func sampleCachedThread(
        boardAbv: String = "g",
        threadNumber: String = "123456789",
        categoryId: String? = nil
    ) -> CachedThread {
        let threadJson = sampleThreadRepliesJSON(threadNumber: threadNumber)
        let threadData = try! threadJson.rawData()

        return CachedThread(
            boardAbv: boardAbv,
            threadNumber: threadNumber,
            threadData: threadData,
            cachedImages: [
                "https://i.4cdn.org/\(boardAbv)/\(threadNumber).jpg",
                "https://i.4cdn.org/\(boardAbv)/123456790.jpg"
            ],
            cachedDate: Date(),
            categoryId: categoryId
        )
    }

    static func sampleCachedThreadArray(count: Int = 3, boardAbv: String = "g") -> [CachedThread] {
        return (1...count).map { index in
            sampleCachedThread(
                boardAbv: boardAbv,
                threadNumber: String(123456000 + index)
            )
        }
    }

    // MARK: - JSON Fixtures

    /// Sample thread list JSON (catalog format)
    static func sampleThreadListJSON(
        boardAbv: String = "g",
        threadCount: Int = 5
    ) -> JSON {
        var threads: [[String: Any]] = []

        for i in 1...threadCount {
            let threadNo = 123456000 + i
            threads.append([
                "no": threadNo,
                "sub": "Test Thread \(i)",
                "com": "This is the comment for thread \(i)",
                "tim": 1234567890 + i,
                "ext": ".jpg",
                "filename": "image\(i)",
                "replies": 10 + i,
                "images": 5 + i,
                "last_modified": 1234567890 + i + 100,
                "bumplimit": 0,
                "imagelimit": 0
            ])
        }

        return JSON(["threads": [["threads": threads]]])
    }

    /// Sample thread replies JSON (thread format)
    static func sampleThreadRepliesJSON(
        threadNumber: String = "123456789",
        replyCount: Int = 10
    ) -> JSON {
        var posts: [[String: Any]] = []

        // OP post
        posts.append([
            "no": Int(threadNumber)!,
            "sub": "Original Post Subject",
            "com": "This is the original post content with <span class=\"quote\">&gt;greentext</span>",
            "tim": 1234567890,
            "filename": "original_image",
            "ext": ".jpg",
            "w": 1920,
            "h": 1080,
            "tn_w": 250,
            "tn_h": 250,
            "md5": "abcdef123456",
            "resto": 0
        ])

        // Reply posts
        for i in 1...replyCount {
            var post: [String: Any] = [
                "no": Int(threadNumber)! + i,
                "com": "Reply #\(i) content with some text",
                "time": 1234567890 + (i * 60),
                "resto": Int(threadNumber)!
            ]

            // Add image to some replies
            if i % 3 == 0 {
                post["tim"] = 1234567890 + i
                post["filename"] = "reply_image_\(i)"
                post["ext"] = ".jpg"
                post["w"] = 1024
                post["h"] = 768
            }

            posts.append(post)
        }

        return JSON(["posts": posts])
    }

    /// Sample board list JSON
    static func sampleBoardListJSON() -> JSON {
        let boards: [[String: Any]] = [
            ["board": "g", "title": "Technology", "ws_board": 1],
            ["board": "v", "title": "Video Games", "ws_board": 1],
            ["board": "a", "title": "Anime & Manga", "ws_board": 1],
            ["board": "tv", "title": "Television & Film", "ws_board": 1],
            ["board": "pol", "title": "Politically Incorrect", "ws_board": 0],
            ["board": "fit", "title": "Fitness", "ws_board": 1]
        ]

        return JSON(["boards": boards])
    }

    /// Sample search results JSON
    static func sampleSearchResultsJSON(resultCount: Int = 3) -> JSON {
        var results: [[String: Any]] = []

        for i in 1...resultCount {
            results.append([
                "no": 123456000 + i,
                "board": "g",
                "sub": "Search Result \(i)",
                "com": "This thread matches the search query \(i)",
                "replies": 20 + i,
                "images": 10 + i,
                "time": 1234567890 + (i * 1000)
            ])
        }

        return JSON(["results": results])
    }

    // MARK: - Notification Fixtures

    static func sampleReplyNotification(
        boardAbv: String = "g",
        threadNo: String = "123456789",
        replyNo: String = "123456790",
        replyToNo: String = "123456789",
        replyText: String = "Test reply text"
    ) -> ReplyNotification {
        return ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: replyNo,
            replyToNo: replyToNo,
            replyText: replyText
        )
    }


    // MARK: - Search Fixtures

    static func sampleSearchItem(
        query: String = "test query",
        boardAbv: String = "g"
    ) -> SearchManager.SearchItem {
        return SearchManager.SearchItem(
            query: query,
            boardAbv: boardAbv
        )
    }

    static func sampleSavedSearch(
        name: String = "My Search",
        query: String = "test query",
        boardAbv: String? = nil
    ) -> SearchManager.SavedSearch {
        return SearchManager.SavedSearch(
            name: name,
            query: query,
            boardAbv: boardAbv
        )
    }

    // MARK: - URL Fixtures

    static func sampleImageURL(
        boardAbv: String = "g",
        filename: String = "1234567890"
    ) -> URL {
        return URL(string: "https://i.4cdn.org/\(boardAbv)/\(filename).jpg")!
    }

    static func sampleThumbnailURL(
        boardAbv: String = "g",
        filename: String = "1234567890"
    ) -> URL {
        return URL(string: "https://i.4cdn.org/\(boardAbv)/\(filename)s.jpg")!
    }

    static func sampleVideoURL(
        boardAbv: String = "g",
        filename: String = "1234567890"
    ) -> URL {
        return URL(string: "https://i.4cdn.org/\(boardAbv)/\(filename).webm")!
    }

    static func sampleThreadURL(
        boardAbv: String = "g",
        threadNumber: String = "123456789"
    ) -> URL {
        return URL(string: "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json")!
    }

    static func sampleBoardCatalogURL(boardAbv: String = "g") -> URL {
        return URL(string: "https://a.4cdn.org/\(boardAbv)/catalog.json")!
    }

    // MARK: - Error Fixtures

    static func sampleNetworkError() -> NSError {
        return NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
        )
    }

    static func sampleServerError() -> NSError {
        return NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorBadServerResponse,
            userInfo: [NSLocalizedDescriptionKey: "Server returned error"]
        )
    }

    static func sampleNotFoundError() -> NSError {
        return NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorFileDoesNotExist,
            userInfo: [NSLocalizedDescriptionKey: "Thread not found (404)"]
        )
    }

    // MARK: - HTML Content Fixtures

    static func sampleHTMLComment() -> String {
        return """
        This is a regular comment with <span class="quote">&gt;greentext</span> and
        <a href="#p123456" class="quotelink">&gt;&gt;123456</a> reply link.
        <br><br>
        Multiple lines are supported.
        <span class="spoiler">This is a spoiler</span>
        """
    }

    static func sampleThreadTitle() -> String {
        return "Test Thread - Technology Discussion"
    }

    // MARK: - Date Fixtures

    static func sampleDate(daysAgo: Int = 0, hoursAgo: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = -daysAgo
        components.hour = -hoursAgo
        return calendar.date(byAdding: components, to: Date())!
    }

    static func sampleTimestamp(daysAgo: Int = 0) -> Int {
        return Int(sampleDate(daysAgo: daysAgo).timeIntervalSince1970)
    }
}
