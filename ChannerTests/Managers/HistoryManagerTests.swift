//
//  HistoryManagerTests.swift
//  ChannerTests
//
//  Unit tests for HistoryManager
//

import XCTest
@testable import Channer

class HistoryManagerTests: XCTestCase {

    var manager: HistoryManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Get manager instance
        manager = HistoryManager.shared

        // Clear history before each test
        manager.clearHistory()
    }

    override func tearDown() {
        // Clean up
        manager.clearHistory()
        manager = nil

        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testHistoryManagerSingletonExists() {
        // Assert
        XCTAssertNotNil(manager, "HistoryManager singleton should exist")
    }

    func testHistoryManagerSingletonIsSame() {
        // Arrange & Act
        let manager1 = HistoryManager.shared
        let manager2 = HistoryManager.shared

        // Assert
        XCTAssertTrue(manager1 === manager2, "HistoryManager should return same singleton instance")
    }

    func testHistoryManagerInitiallyEmpty() {
        // Arrange & Act
        let history = manager.getHistoryThreads()

        // Assert
        XCTAssertEmpty(history, "History should be empty initially")
    }

    // MARK: - Add Thread Tests

    func testHistoryManagerAddThreadToHistory() {
        // Arrange
        let thread = TestDataFactory.createTestThread(number: "12345", boardAbv: "g")

        // Act
        manager.addThreadToHistory(thread)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "History should contain one thread")
        XCTAssertEqual(history.first?.number, "12345", "Thread number should match")
        XCTAssertEqual(history.first?.boardAbv, "g", "Board should match")
    }

    func testHistoryManagerAddMultipleThreads() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "b")
        let thread3 = TestDataFactory.createTestThread(number: "333", boardAbv: "v")

        // Act
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)
        manager.addThreadToHistory(thread3)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 3, "History should contain three threads")
    }

    func testHistoryManagerAddThreadNoDuplicates() {
        // Arrange
        let thread = TestDataFactory.createTestThread(number: "12345", boardAbv: "g")

        // Act
        manager.addThreadToHistory(thread)
        manager.addThreadToHistory(thread) // Try to add same thread again

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "History should contain only one thread (no duplicates)")
    }

    func testHistoryManagerAddSameThreadNumberDifferentBoard() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "12345", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "12345", boardAbv: "b")

        // Act
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 2, "History should contain both threads (different boards)")
    }

    func testHistoryManagerAddSameBoardDifferentThreadNumber() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "g")

        // Act
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 2, "History should contain both threads (different numbers)")
    }

    // MARK: - Remove Thread Tests

    func testHistoryManagerRemoveThreadFromHistory() {
        // Arrange
        let thread = TestDataFactory.createTestThread(number: "12345", boardAbv: "g")
        manager.addThreadToHistory(thread)

        // Act
        manager.removeThreadFromHistory(thread)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertEmpty(history, "History should be empty after removing thread")
    }

    func testHistoryManagerRemoveSpecificThread() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "g")
        let thread3 = TestDataFactory.createTestThread(number: "333", boardAbv: "g")
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)
        manager.addThreadToHistory(thread3)

        // Act
        manager.removeThreadFromHistory(thread2)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 2, "History should contain two threads after removal")
        XCTAssertTrue(history.contains { $0.number == "111" }, "Thread 111 should remain")
        XCTAssertFalse(history.contains { $0.number == "222" }, "Thread 222 should be removed")
        XCTAssertTrue(history.contains { $0.number == "333" }, "Thread 333 should remain")
    }

    func testHistoryManagerRemoveNonExistentThread() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "g")
        manager.addThreadToHistory(thread1)

        // Act
        manager.removeThreadFromHistory(thread2) // Try to remove thread that doesn't exist

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "History should still contain one thread")
        XCTAssertEqual(history.first?.number, "111", "Original thread should remain")
    }

    func testHistoryManagerRemoveThreadByBoardAndNumber() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "12345", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "12345", boardAbv: "b")
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)

        // Act
        manager.removeThreadFromHistory(thread1)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "History should contain one thread")
        XCTAssertEqual(history.first?.boardAbv, "b", "Thread from board 'b' should remain")
    }

    // MARK: - Clear History Tests

    func testHistoryManagerClearHistory() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "b")
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)

        // Act
        manager.clearHistory()

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertEmpty(history, "History should be empty after clearing")
    }

    func testHistoryManagerClearEmptyHistory() {
        // Act
        manager.clearHistory()

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertEmpty(history, "Clearing empty history should not cause issues")
    }

    func testHistoryManagerClearHistoryMultipleTimes() {
        // Arrange
        let thread = TestDataFactory.createTestThread()
        manager.addThreadToHistory(thread)

        // Act
        manager.clearHistory()
        manager.clearHistory()
        manager.clearHistory()

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertEmpty(history, "History should remain empty")
    }

    // MARK: - Get History Tests

    func testHistoryManagerGetHistoryThreadsReturnsArray() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "b")
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)

        // Act
        let history = manager.getHistoryThreads()

        // Assert
        XCTAssertCount(history, 2, "Should return all threads")
        XCTAssertTrue(history is [ThreadData], "Should return array of ThreadData")
    }

    func testHistoryManagerGetHistoryThreadsOrderPreserved() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "g")
        let thread3 = TestDataFactory.createTestThread(number: "333", boardAbv: "g")

        // Act
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)
        manager.addThreadToHistory(thread3)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertEqual(history[0].number, "111", "First thread should be in order")
        XCTAssertEqual(history[1].number, "222", "Second thread should be in order")
        XCTAssertEqual(history[2].number, "333", "Third thread should be in order")
    }

    // MARK: - iCloud Sync Support Tests

    func testHistoryManagerGetAllHistoryForSync() {
        // Arrange
        let thread1 = TestDataFactory.createTestThread(number: "111", boardAbv: "g")
        let thread2 = TestDataFactory.createTestThread(number: "222", boardAbv: "b")
        manager.addThreadToHistory(thread1)
        manager.addThreadToHistory(thread2)

        // Act
        let syncData = manager.getAllHistoryForSync()

        // Assert
        XCTAssertCount(syncData, 2, "Should return all threads for sync")
        XCTAssertEqual(syncData[0].boardAbv, "g", "First board should match")
        XCTAssertEqual(syncData[0].threadNumber, "111", "First thread number should match")
        XCTAssertEqual(syncData[1].boardAbv, "b", "Second board should match")
        XCTAssertEqual(syncData[1].threadNumber, "222", "Second thread number should match")
    }

    func testHistoryManagerSyncHistoryFromICloud() {
        // Arrange
        let boardAbv = "g"
        let threadNumber = "99999"
        let visitDate = Date()

        // Act
        manager.syncHistoryFromICloud(boardAbv: boardAbv, threadNumber: threadNumber, visitDate: visitDate)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "History should contain synced thread")
        XCTAssertEqual(history.first?.boardAbv, boardAbv, "Board should match synced data")
        XCTAssertEqual(history.first?.number, threadNumber, "Thread number should match synced data")
    }

    func testHistoryManagerSyncHistoryFromICloudNoDuplicates() {
        // Arrange
        let thread = TestDataFactory.createTestThread(number: "12345", boardAbv: "g")
        manager.addThreadToHistory(thread)

        // Act
        manager.syncHistoryFromICloud(boardAbv: "g", threadNumber: "12345", visitDate: Date())

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "Should not create duplicate when syncing existing thread")
    }

    func testHistoryManagerSyncMultipleThreadsFromICloud() {
        // Act
        manager.syncHistoryFromICloud(boardAbv: "g", threadNumber: "111", visitDate: Date())
        manager.syncHistoryFromICloud(boardAbv: "b", threadNumber: "222", visitDate: Date())
        manager.syncHistoryFromICloud(boardAbv: "v", threadNumber: "333", visitDate: Date())

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 3, "Should sync multiple threads from iCloud")
    }

    // MARK: - Persistence Tests

    func testHistoryManagerHistoryPersistsAcrossInstances() {
        // Arrange
        let thread = TestDataFactory.createTestThread(number: "persist123", boardAbv: "g")
        manager.addThreadToHistory(thread)

        // Give time for async save
        let expectation = XCTestExpectation(description: "Wait for save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act - Get new manager reference (simulating app restart)
        let newManager = HistoryManager.shared

        // Assert
        let history = newManager.getHistoryThreads()
        XCTAssertTrue(history.contains { $0.number == "persist123" && $0.boardAbv == "g" },
                     "History should persist across instances")
    }

    // MARK: - Edge Cases

    func testHistoryManagerAddManyThreads() {
        // Arrange
        let threads = (1...100).map { TestDataFactory.createTestThread(number: "\($0)", boardAbv: "g") }

        // Act
        threads.forEach { manager.addThreadToHistory($0) }

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 100, "Should handle large number of threads")
    }

    func testHistoryManagerThreadWithEmptyFields() {
        // Arrange
        let thread = TestDataFactory.createTestThread(
            number: "12345",
            boardAbv: "g",
            title: "",
            comment: "",
            imageUrl: ""
        )

        // Act
        manager.addThreadToHistory(thread)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "Should handle threads with empty fields")
    }

    func testHistoryManagerThreadWithSpecialCharacters() {
        // Arrange
        let thread = TestDataFactory.createTestThread(
            number: "12345",
            boardAbv: "g",
            title: "Test & <html> \"quotes\" 'single'",
            comment: "Special chars: @#$%^&*()"
        )

        // Act
        manager.addThreadToHistory(thread)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "Should handle special characters")
        XCTAssertEqual(history.first?.title, "Test & <html> \"quotes\" 'single'",
                      "Special characters should be preserved")
    }

    func testHistoryManagerThreadWithUnicodeCharacters() {
        // Arrange
        let thread = TestDataFactory.createTestThread(
            number: "12345",
            boardAbv: "g",
            title: "Unicode: 日本語 한국어 العربية 🎉"
        )

        // Act
        manager.addThreadToHistory(thread)

        // Assert
        let history = manager.getHistoryThreads()
        XCTAssertCount(history, 1, "Should handle Unicode characters")
        XCTAssertEqual(history.first?.title, "Unicode: 日本語 한국어 العربية 🎉",
                      "Unicode characters should be preserved")
    }

    // MARK: - Notification Tests

    func testHistoryManagerPostsNotificationOnICloudSync() {
        // Arrange
        let expectation = XCTestExpectation(description: "History updated notification")

        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("HistoryUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Act
        NotificationCenter.default.post(
            name: ICloudSyncManager.iCloudSyncCompletedNotification,
            object: nil
        )

        // Assert
        wait(for: [expectation], timeout: 2.0)

        NotificationCenter.default.removeObserver(observer)
    }
}
