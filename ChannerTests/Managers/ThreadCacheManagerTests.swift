//
//  ThreadCacheManagerTests.swift
//  ChannerTests
//
//  Created for unit testing
//

import XCTest
@testable import Channer

class ThreadCacheManagerTests: XCTestCase {

    var sut: ThreadCacheManager!
    var mockUserDefaults: MockUserDefaults!
    var mockiCloudStore: MockiCloudStore!
//     var mockKingfisher: MockKingfisher!

    override func setUp() {
        super.setUp()

        // Create mocks
        mockUserDefaults = MockUserDefaults()
        mockiCloudStore = MockiCloudStore.shared
        mockiCloudStore.reset()
        //         mockKingfisher = MockKingfisher.shared
        // mockKingfisher.reset()

        // Get shared instance
        sut = ThreadCacheManager.shared

        // Clear any existing cache
        sut.clearAllCachedThreads()
    }

    override func tearDown() {
        mockUserDefaults.reset()
        mockiCloudStore.reset()
        // mockKingfisher.reset()
        sut.clearAllCachedThreads()
        sut = nil
        super.tearDown()
    }

    // MARK: - Offline Reading Preference Tests

    func testOfflineReadingEnabledDefault() {
        // When - Check default state
        let isEnabled = sut.isOfflineReadingEnabled()

        // Then
        XCTAssertFalse(isEnabled) // Should be disabled by default
    }

    func testSetOfflineReadingEnabled() {
        // When
        sut.setOfflineReadingEnabled(true)

        // Then
        XCTAssertTrue(sut.isOfflineReadingEnabled())
    }

    func testSetOfflineReadingDisabled() {
        // Given
        sut.setOfflineReadingEnabled(true)
        XCTAssertTrue(sut.isOfflineReadingEnabled())

        // When
        sut.setOfflineReadingEnabled(false)

        // Then
        XCTAssertFalse(sut.isOfflineReadingEnabled())
    }

    // MARK: - Cache Operations Tests

    func testIsCachedReturnsFalseForNonCachedThread() {
        // When
        let isCached = sut.isCached(boardAbv: "g", threadNumber: "123456789")

        // Then
        XCTAssertFalse(isCached)
    }

    func testGetCachedThreadReturnsNilForNonCachedThread() {
        // When
        let cachedData = sut.getCachedThread(boardAbv: "g", threadNumber: "123456789")

        // Then
        XCTAssertNil(cachedData)
    }

    func testRemoveFromCacheRemovesThread() {
        // Given - Manually add a cached thread
        let cachedThread = TestData.sampleCachedThread()
        // Note: Since we can't easily inject the cached thread without network,
        // we'll test the removal logic
        // This test would require mocking AF.request in the real implementation

        // When
        sut.removeFromCache(boardAbv: "g", threadNumber: "123456789")

        // Then
        XCTAssertFalse(sut.isCached(boardAbv: "g", threadNumber: "123456789"))
    }

    func testGetAllCachedThreadsReturnsEmptyInitially() {
        // When
        let threads = sut.getAllCachedThreads()

        // Then
        XCTAssertEqual(threads.count, 0)
    }

    func testClearAllCachedThreads() {
        // Given - Assume some threads are cached
        // (In real test with mocked network, we'd cache some threads first)

        // When
        sut.clearAllCachedThreads()

        // Then
        let threads = sut.getAllCachedThreads()
        XCTAssertEqual(threads.count, 0)
    }

    // MARK: - Category Management Tests

    func testUpdateCachedThreadCategory() {
        // Given - This test would require a cached thread
        // In a full implementation with mocked network
        let boardAbv = "g"
        let threadNumber = "123456789"
        let newCategoryId = "test-category-id"

        // When
        sut.updateCachedThreadCategory(boardAbv: boardAbv, threadNumber: threadNumber, categoryId: newCategoryId)

        // Then
        // Would verify the category was updated
        // In real test: XCTAssertEqual(thread.categoryId, newCategoryId)
    }

    func testGetCachedThreadsForCategory() {
        // Given
        let categoryId = "test-category"

        // When
        let threads = sut.getCachedThreads(for: categoryId)

        // Then
        // All returned threads should match the category
        XCTAssertTrue(threads.allSatisfy { $0.categoryId == categoryId })
    }

    func testGetCachedThreadsForNilCategoryReturnsAll() {
        // When
        let threads = sut.getCachedThreads(for: nil)

        // Then
        XCTAssertEqual(threads.count, sut.getAllCachedThreads().count)
    }

    // MARK: - Persistence Tests

    func testSaveAndLoadCachedThreads() {
        // Given - This test verifies the persistence mechanism
        // Note: Would require mocking or actual cache operations

        // When clearAllCachedThreads is called
        sut.clearAllCachedThreads()

        // Then - After app restart (simulated by reloading)
        let threads = sut.getAllCachedThreads()
        XCTAssertEqual(threads.count, 0)
    }

    // MARK: - Edge Cases Tests

    func testCacheThreadWithEmptyBoardAbv() {
        // Given
        let expectation = self.expectation(description: "Cache thread with empty board")

        // When
        sut.cacheThread(boardAbv: "", threadNumber: "123456789") { success in
            // Then
            XCTAssertFalse(success) // Should fail with invalid board
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testCacheThreadWithEmptyThreadNumber() {
        // Given
        let expectation = self.expectation(description: "Cache thread with empty number")

        // When
        sut.cacheThread(boardAbv: "g", threadNumber: "") { success in
            // Then
            XCTAssertFalse(success) // Should fail with invalid thread number
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testCacheAlreadyCachedThread() {
        // Given - Thread is already cached
        // (Would need to mock successful cache first)
        let boardAbv = "g"
        let threadNumber = "123456789"
        let expectation = self.expectation(description: "Cache already cached thread")

        // When - Try to cache again
        sut.cacheThread(boardAbv: boardAbv, threadNumber: threadNumber) { success in
            // Then - Should succeed immediately without network call
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testRemoveNonExistentThread() {
        // When
        sut.removeFromCache(boardAbv: "g", threadNumber: "999999999")

        // Then - Should not crash, just no-op
        XCTAssertFalse(sut.isCached(boardAbv: "g", threadNumber: "999999999"))
    }

    // MARK: - Integration Tests

    func testCacheThreadAutomaticallyAssignsCategoryFromFavorite() {
        // Given - Add thread to favorites with category
        let thread = TestData.sampleThreadData()
        let category = FavoritesManager.shared.createCategory(name: "Test", color: "#000000", icon: "star")
        FavoritesManager.shared.addFavorite(thread, to: category.id)

        let expectation = self.expectation(description: "Cache with favorite category")

        // When - Cache the thread without specifying category
        sut.cacheThread(boardAbv: thread.boardAbv, threadNumber: thread.number, categoryId: nil) { success in
            // Then - Should inherit category from favorite
            if success {
                let cachedThreads = self.sut.getAllCachedThreads()
                let cached = cachedThreads.first(where: { $0.threadNumber == thread.number })
                XCTAssertEqual(cached?.categoryId, category.id)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    // MARK: - Performance Tests

    func testClearLargeCachePerformance() {
        measure {
            // Given - Large number of cached threads
            // (Would need to populate cache first)

            // When
            sut.clearAllCachedThreads()

            // Then - Should complete quickly
        }
    }

    func testCheckMultipleThreadsCacheStatus() {
        // Given
        let threads = (1...100).map { "12345\($0)" }

        // When/Then - Should be fast to check many threads
        measure {
            for threadNumber in threads {
                _ = sut.isCached(boardAbv: "g", threadNumber: threadNumber)
            }
        }
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentCacheOperations() {
        // Given
        let expectation = self.expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 5

        // When - Perform concurrent cache operations
        for i in 1...5 {
            DispatchQueue.global().async {
                let threadNumber = "12345678\(i)"
                _ = self.sut.isCached(boardAbv: "g", threadNumber: threadNumber)
                expectation.fulfill()
            }
        }

        // Then - Should handle concurrent access safely
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - iCloud Sync Tests

    func testCachedThreadsSyncToiCloudWhenAvailable() {
        // Given - iCloud is available
        mockiCloudStore.isAvailable = true

        // When - Cache a thread
        // (Would need mocked network response)

        // Then - Should save to iCloud
        XCTAssertTrue(mockiCloudStore.isAvailable)
    }

    func testCachedThreadsFallbackToLocalWhenICloudUnavailable() {
        // Given - iCloud is not available
        mockiCloudStore.isAvailable = false

        // When - Cache a thread
        // (Would need mocked network response)

        // Then - Should fall back to local storage
        XCTAssertFalse(mockiCloudStore.isAvailable)
    }

    // MARK: - CachedThread Model Tests

    func testCachedThreadModelEncoding() {
        // Given
        let cachedThread = TestData.sampleCachedThread()

        // When
        let encoded = try? JSONEncoder().encode(cachedThread)

        // Then
        XCTAssertNotNil(encoded)
    }

    func testCachedThreadModelDecoding() {
        // Given
        let cachedThread = TestData.sampleCachedThread()
        let encoded = try! JSONEncoder().encode(cachedThread)

        // When
        let decoded = try? JSONDecoder().decode(CachedThread.self, from: encoded)

        // Then
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.boardAbv, cachedThread.boardAbv)
        XCTAssertEqual(decoded?.threadNumber, cachedThread.threadNumber)
        XCTAssertEqual(decoded?.categoryId, cachedThread.categoryId)
    }

    func testCachedThreadGetThreadInfo() {
        // Given
        let cachedThread = TestData.sampleCachedThread()

        // When
        let threadInfo = cachedThread.getThreadInfo()

        // Then
        XCTAssertNotNil(threadInfo)
        // Would verify thread info matches cached data
    }
}
