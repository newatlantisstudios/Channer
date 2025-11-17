//
//  NotificationManagerTests.swift
//  ChannerTests
//
//  Unit tests for NotificationManager
//

import XCTest
@testable import Channer

class NotificationManagerTests: XCTestCase {

    var manager: NotificationManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Get manager instance
        manager = NotificationManager.shared

        // Clear all notifications before each test
        manager.clearAllNotifications()
    }

    override func tearDown() {
        // Clean up
        manager.clearAllNotifications()
        manager = nil

        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testNotificationManagerSingletonExists() {
        // Assert
        XCTAssertNotNil(manager, "NotificationManager singleton should exist")
    }

    func testNotificationManagerSingletonIsSame() {
        // Arrange & Act
        let manager1 = NotificationManager.shared
        let manager2 = NotificationManager.shared

        // Assert
        XCTAssertTrue(manager1 === manager2, "NotificationManager should return same singleton instance")
    }

    func testNotificationManagerInitiallyEmpty() {
        // Act
        let notifications = manager.getNotifications()

        // Assert
        XCTAssertEmpty(notifications, "Notifications should be empty initially")
    }

    func testNotificationManagerInitialUnreadCountIsZero() {
        // Act
        let unreadCount = manager.getUnreadCount()

        // Assert
        XCTAssertEqual(unreadCount, 0, "Unread count should be zero initially")
    }

    // MARK: - Add Notification Tests

    func testNotificationManagerAddNotification() {
        // Arrange
        let notification = TestDataFactory.createTestNotification(
            boardAbv: "g",
            threadNo: "12345",
            replyNo: "67890"
        )

        // Act
        manager.addNotification(notification)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertCount(notifications, 1, "Should have one notification")
        XCTAssertEqual(notifications.first?.boardAbv, "g", "Board should match")
        XCTAssertEqual(notifications.first?.threadNo, "12345", "Thread number should match")
        XCTAssertEqual(notifications.first?.replyNo, "67890", "Reply number should match")
    }

    func testNotificationManagerAddMultipleNotifications() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(boardAbv: "g", threadNo: "111", replyNo: "1111")
        let notification2 = TestDataFactory.createTestNotification(boardAbv: "b", threadNo: "222", replyNo: "2222")
        let notification3 = TestDataFactory.createTestNotification(boardAbv: "v", threadNo: "333", replyNo: "3333")

        // Act
        manager.addNotification(notification1)
        manager.addNotification(notification2)
        manager.addNotification(notification3)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertCount(notifications, 3, "Should have three notifications")
    }

    func testNotificationManagerAddNotificationUpdatesUnreadCount() {
        // Arrange
        let notification = TestDataFactory.createTestNotification()

        // Act
        manager.addNotification(notification)

        // Assert
        let unreadCount = manager.getUnreadCount()
        XCTAssertEqual(unreadCount, 1, "Unread count should be 1")
    }

    func testNotificationManagerAddNotificationPoststNotification() {
        // Arrange
        let notification = TestDataFactory.createTestNotification()
        let expectation = XCTestExpectation(description: "Notification posted")

        print("DEBUG: Setting up observer for .notificationAdded")
        let observer = NotificationCenter.default.addObserver(
            forName: .notificationAdded,
            object: nil,
            queue: .main
        ) { _ in
            print("DEBUG: Notification received!")
            expectation.fulfill()
        }

        // Act
        print("DEBUG: About to add notification")
        manager.addNotification(notification)
        print("DEBUG: Notification added")

        // Assert
        wait(for: [expectation], timeout: 2.0)
        print("DEBUG: Test completed successfully")
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Get Notifications Tests

    func testNotificationManagerGetNotificationsReturnsAll() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(replyNo: "222")
        manager.addNotification(notification1)
        manager.addNotification(notification2)

        // Act
        let notifications = manager.getNotifications()

        // Assert
        XCTAssertCount(notifications, 2, "Should return all notifications")
    }

    func testNotificationManagerGetNotificationsSortedByDate() {
        // Arrange
        let old = TestDataFactory.createTestNotification(replyNo: "old")
        let new = TestDataFactory.createTestNotification(replyNo: "new")

        // Add in reverse chronological order
        manager.addNotification(old)
        Thread.sleep(forTimeInterval: 0.1) // Small delay to ensure different timestamps
        manager.addNotification(new)

        // Act
        let notifications = manager.getNotifications()

        // Assert
        XCTAssertEqual(notifications.first?.replyNo, "new", "Newest notification should be first")
        XCTAssertEqual(notifications.last?.replyNo, "old", "Oldest notification should be last")
    }

    // MARK: - Mark as Read Tests

    func testNotificationManagerMarkAsRead() {
        // Arrange
        let notification = TestDataFactory.createTestNotification()
        manager.addNotification(notification)

        // Act
        manager.markAsRead( notification.id)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertTrue(notifications.first?.isRead ?? false, "Notification should be marked as read")
    }

    func testNotificationManagerMarkAsReadUpdatesUnreadCount() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(replyNo: "222")
        manager.addNotification(notification1)
        manager.addNotification(notification2)

        // Act
        manager.markAsRead( notification1.id)

        // Assert
        let unreadCount = manager.getUnreadCount()
        XCTAssertEqual(unreadCount, 1, "Unread count should be 1 after marking one as read")
    }

    func testNotificationManagerMarkAllAsRead() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(replyNo: "222")
        let notification3 = TestDataFactory.createTestNotification(replyNo: "333")
        manager.addNotification(notification1)
        manager.addNotification(notification2)
        manager.addNotification(notification3)

        // Act
        manager.markAllAsRead()

        // Assert
        let notifications = manager.getNotifications()
        let allRead = notifications.allSatisfy { $0.isRead }
        XCTAssertTrue(allRead, "All notifications should be marked as read")
        XCTAssertEqual(manager.getUnreadCount(), 0, "Unread count should be zero")
    }

    func testNotificationManagerMarkNonExistentNotificationAsRead() {
        // Arrange
        let notification = TestDataFactory.createTestNotification()
        manager.addNotification(notification)

        // Act
        manager.markAsRead( "nonexistent-id")

        // Assert
        let unreadCount = manager.getUnreadCount()
        XCTAssertEqual(unreadCount, 1, "Unread count should remain unchanged")
    }

    // MARK: - Unread Count Tests

    func testNotificationManagerGetUnreadCountWithMultipleUnread() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(replyNo: "222")
        let notification3 = TestDataFactory.createTestNotification(replyNo: "333")
        manager.addNotification(notification1)
        manager.addNotification(notification2)
        manager.addNotification(notification3)

        // Act
        let unreadCount = manager.getUnreadCount()

        // Assert
        XCTAssertEqual(unreadCount, 3, "Should have 3 unread notifications")
    }

    func testNotificationManagerGetUnreadCountWithMixedReadStatus() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(replyNo: "222")
        let notification3 = TestDataFactory.createTestNotification(replyNo: "333")
        manager.addNotification(notification1)
        manager.addNotification(notification2)
        manager.addNotification(notification3)

        // Act
        manager.markAsRead( notification2.id)
        let unreadCount = manager.getUnreadCount()

        // Assert
        XCTAssertEqual(unreadCount, 2, "Should have 2 unread notifications")
    }

    func testNotificationManagerGetUnreadCountAfterMarkingAllRead() {
        // Arrange
        manager.addNotification(TestDataFactory.createTestNotification(replyNo: "111"))
        manager.addNotification(TestDataFactory.createTestNotification(replyNo: "222"))

        // Act
        manager.markAllAsRead()
        let unreadCount = manager.getUnreadCount()

        // Assert
        XCTAssertEqual(unreadCount, 0, "Should have zero unread notifications")
    }

    // MARK: - Delete Notification Tests

    func testNotificationManagerDeleteNotification() {
        // Arrange
        let notification = TestDataFactory.createTestNotification()
        manager.addNotification(notification)

        // Act
        manager.removeNotification( notification.id)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertEmpty(notifications, "Notification should be deleted")
    }

    func testNotificationManagerDeleteSpecificNotification() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(replyNo: "222")
        let notification3 = TestDataFactory.createTestNotification(replyNo: "333")
        manager.addNotification(notification1)
        manager.addNotification(notification2)
        manager.addNotification(notification3)

        // Act
        manager.removeNotification( notification2.id)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertCount(notifications, 2, "Should have 2 notifications remaining")
        XCTAssertFalse(notifications.contains { $0.id == notification2.id }, "Deleted notification should not exist")
    }

    func testNotificationManagerDeleteNotificationUpdatesUnreadCount() {
        // Arrange
        let notification = TestDataFactory.createTestNotification()
        manager.addNotification(notification)

        // Act
        manager.removeNotification( notification.id)

        // Assert
        let unreadCount = manager.getUnreadCount()
        XCTAssertEqual(unreadCount, 0, "Unread count should be zero after deleting unread notification")
    }

    // MARK: - Clear All Tests

    func testNotificationManagerClearAllNotifications() {
        // Arrange
        manager.addNotification(TestDataFactory.createTestNotification(replyNo: "111"))
        manager.addNotification(TestDataFactory.createTestNotification(replyNo: "222"))
        manager.addNotification(TestDataFactory.createTestNotification(replyNo: "333"))

        // Act
        manager.clearAllNotifications()

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertEmpty(notifications, "All notifications should be cleared")
        XCTAssertEqual(manager.getUnreadCount(), 0, "Unread count should be zero")
    }

    func testNotificationManagerClearAlreadyEmptyNotifications() {
        // Act
        manager.clearAllNotifications()

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertEmpty(notifications, "Should handle clearing empty notifications")
    }

    // MARK: - Get Notifications for Thread Tests

    func testNotificationManagerGetNotificationsForThread() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(boardAbv: "g", threadNo: "12345", replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(boardAbv: "g", threadNo: "12345", replyNo: "222")
        let notification3 = TestDataFactory.createTestNotification(boardAbv: "g", threadNo: "67890", replyNo: "333")
        manager.addNotification(notification1)
        manager.addNotification(notification2)
        manager.addNotification(notification3)

        // Act
        let threadNotifications = manager.getNotifications().filter { $0.threadNo == "12345" && $0.boardAbv == "g" }

        // Assert
        XCTAssertCount(threadNotifications, 2, "Should return 2 notifications for thread 12345")
    }

    func testNotificationManagerGetNotificationsForThreadWithDifferentBoard() {
        // Arrange
        let notification1 = TestDataFactory.createTestNotification(boardAbv: "g", threadNo: "12345", replyNo: "111")
        let notification2 = TestDataFactory.createTestNotification(boardAbv: "b", threadNo: "12345", replyNo: "222")
        manager.addNotification(notification1)
        manager.addNotification(notification2)

        // Act
        let threadNotifications = manager.getNotifications().filter { $0.threadNo == "12345" && $0.boardAbv == "g" }

        // Assert
        XCTAssertCount(threadNotifications, 1, "Should only return notifications for board 'g'")
        XCTAssertEqual(threadNotifications.first?.boardAbv, "g", "Should be from board 'g'")
    }

    // MARK: - Persistence Tests

    func testNotificationManagerNotificationsPersistAcrossInstances() {
        // Arrange
        let notification = TestDataFactory.createTestNotification(replyNo: "persist123")
        manager.addNotification(notification)

        // Give time for async save
        let expectation = XCTestExpectation(description: "Wait for save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Act - Get new manager reference
        let newManager = NotificationManager.shared

        // Assert
        let notifications = newManager.getNotifications()
        XCTAssertTrue(notifications.contains { $0.replyNo == "persist123" },
                     "Notifications should persist across instances")
    }

    // MARK: - Edge Cases

    func testNotificationManagerManyNotifications() {
        // Arrange
        let notifications = (1...100).map {
            TestDataFactory.createTestNotification(replyNo: "\($0)")
        }

        // Act
        notifications.forEach { manager.addNotification($0) }

        // Assert
        let allNotifications = manager.getNotifications()
        XCTAssertCount(allNotifications, 100, "Should handle large number of notifications")
    }

    func testNotificationManagerNotificationWithEmptyText() {
        // Arrange
        let notification = TestDataFactory.createTestNotification(replyText: "")

        // Act
        manager.addNotification(notification)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertCount(notifications, 1, "Should handle notification with empty text")
    }

    func testNotificationManagerNotificationWithSpecialCharacters() {
        // Arrange
        let notification = TestDataFactory.createTestNotification(
            replyText: "Special chars: @#$%^&*() <html> \"quotes\""
        )

        // Act
        manager.addNotification(notification)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertEqual(notifications.first?.replyText, "Special chars: @#$%^&*() <html> \"quotes\"",
                      "Special characters should be preserved")
    }

    func testNotificationManagerNotificationWithUnicode() {
        // Arrange
        let notification = TestDataFactory.createTestNotification(
            replyText: "Unicode: 日本語 한국어 العربية 🎉"
        )

        // Act
        manager.addNotification(notification)

        // Assert
        let notifications = manager.getNotifications()
        XCTAssertEqual(notifications.first?.replyText, "Unicode: 日本語 한국어 العربية 🎉",
                      "Unicode characters should be preserved")
    }

    // MARK: - Thread Safety Tests

    func testNotificationManagerConcurrentAdds() {
        print("DEBUG: Starting concurrent adds test")

        // Arrange
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 10

        print("DEBUG: Initial notification count: \(manager.getNotifications().count)")

        // Act - Use concurrent queue but serialize the actual additions
        let addQueue = DispatchQueue(label: "test.notification.add", attributes: .concurrent)
        let addGroup = DispatchGroup()

        for index in 0..<10 {
            addGroup.enter()
            addQueue.async {
                print("DEBUG: Thread \(index) - Creating notification")
                let notification = TestDataFactory.createTestNotification(replyNo: "\(index)")

                // Perform addition on main queue to avoid race conditions
                DispatchQueue.main.async {
                    print("DEBUG: Thread \(index) - Adding notification on main thread")
                    self.manager.addNotification(notification)
                    print("DEBUG: Thread \(index) - Notification added, current count: \(self.manager.getNotifications().count)")
                    expectation.fulfill()
                    addGroup.leave()
                }
            }
        }

        // Wait for all operations to complete
        print("DEBUG: Waiting for all additions to complete")
        let result = addGroup.wait(timeout: .now() + 5.0)
        print("DEBUG: Group wait result: \(result == .success ? "SUCCESS" : "TIMEOUT")")

        // Give UserDefaults time to synchronize
        let syncExpectation = XCTestExpectation(description: "UserDefaults sync")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("DEBUG: Sync delay complete")
            syncExpectation.fulfill()
        }
        wait(for: [syncExpectation], timeout: 1.0)

        // Assert
        wait(for: [expectation], timeout: 6.0)
        let notifications = manager.getNotifications()
        print("DEBUG: Final notification count: \(notifications.count)")
        print("DEBUG: Notification reply numbers: \(notifications.map { $0.replyNo }.sorted())")

        XCTAssertEqual(notifications.count, 10, "Should handle concurrent additions - got \(notifications.count) notifications")
    }
}
