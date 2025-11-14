//
//  FavoritesManagerTests.swift
//  ChannerTests
//
//  Created for unit testing
//

import XCTest
@testable import _chan

class FavoritesManagerTests: XCTestCase {

    var sut: FavoritesManager!
    var mockUserDefaults: MockUserDefaults!
    var mockiCloudStore: MockiCloudStore!

    override func setUp() {
        super.setUp()

        // Create mocks
        mockUserDefaults = MockUserDefaults()
        mockiCloudStore = MockiCloudStore.shared
        mockiCloudStore.reset()

        // Note: Since FavoritesManager is a singleton, we'll test it with mocked dependencies
        // injected through ICloudSyncManager
        sut = FavoritesManager.shared

        // Clear any existing data
        ICloudSyncManager.shared.save([ThreadData](), forKey: "favorites")
        ICloudSyncManager.shared.save([BookmarkCategory](), forKey: "bookmarkCategories")
    }

    override func tearDown() {
        mockUserDefaults.reset()
        mockiCloudStore.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - Basic Favorite Operations Tests

    func testAddFavorite() {
        // Given
        let thread = TestData.sampleThreadData()

        // When
        sut.addFavorite(thread)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.number, thread.number)
        XCTAssertEqual(favorites.first?.boardAbv, thread.boardAbv)
    }

    func testAddFavoriteToCategory() {
        // Given
        let thread = TestData.sampleThreadData()
        let category = TestData.sampleCategory(name: "Important")
        _ = sut.createCategory(name: category.name, color: category.color, icon: category.icon)
        let categories = sut.getCategories()
        guard let categoryId = categories.first(where: { $0.name == "Important" })?.id else {
            XCTFail("Category not found")
            return
        }

        // When
        sut.addFavorite(thread, to: categoryId)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.categoryId, categoryId)
    }

    func testAddMultipleFavorites() {
        // Given
        let threads = TestData.sampleThreadDataArray(count: 5)

        // When
        threads.forEach { sut.addFavorite($0) }

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 5)
    }

    func testRemoveFavorite() {
        // Given
        let thread = TestData.sampleThreadData()
        sut.addFavorite(thread)
        XCTAssertEqual(sut.loadFavorites().count, 1)

        // When
        sut.removeFavorite(threadNumber: thread.number)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 0)
    }

    func testRemoveNonExistentFavorite() {
        // Given
        let thread = TestData.sampleThreadData()
        sut.addFavorite(thread)

        // When
        sut.removeFavorite(threadNumber: "999999999")

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 1)
    }

    func testIsFavorited() {
        // Given
        let thread = TestData.sampleThreadData()

        // When
        sut.addFavorite(thread)

        // Then
        XCTAssertTrue(sut.isFavorited(threadNumber: thread.number))
        XCTAssertFalse(sut.isFavorited(threadNumber: "999999999"))
    }

    func testUpdateFavorite() {
        // Given
        var thread = TestData.sampleThreadData()
        sut.addFavorite(thread)

        // When
        thread.replies = 100
        thread.stats = "R: 100 / I: 25"
        sut.updateFavorite(thread: thread)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.first?.replies, 100)
        XCTAssertEqual(favorites.first?.stats, "R: 100 / I: 25")
    }

    func testUpdateNonExistentFavorite() {
        // Given
        let thread = TestData.sampleThreadData()

        // When
        sut.updateFavorite(thread: thread)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 0) // Should not add, only update
    }

    // MARK: - New Replies Flag Tests

    func testMarkThreadHasNewReplies() {
        // Given
        let thread = TestData.sampleThreadData()
        sut.addFavorite(thread)

        // When
        sut.markThreadHasNewReplies(threadNumber: thread.number)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertTrue(favorites.first?.hasNewReplies ?? false)
    }

    func testClearNewRepliesFlag() {
        // Given
        let thread = TestData.sampleThreadData()
        sut.addFavorite(thread)
        sut.markThreadHasNewReplies(threadNumber: thread.number)
        XCTAssertTrue(sut.loadFavorites().first?.hasNewReplies ?? false)

        // When
        sut.clearNewRepliesFlag(threadNumber: thread.number)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertFalse(favorites.first?.hasNewReplies ?? true)
    }

    func testMarkThreadAsSeen() {
        // Given
        var thread = TestData.sampleThreadData()
        thread.replies = 50
        thread.currentReplies = 75
        sut.addFavorite(thread)

        // When
        sut.markThreadAsSeen(threadID: thread.number)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.first?.replies, 75) // Should match currentReplies
    }

    // MARK: - Category Management Tests

    func testLoadCategoriesCreatesDefaults() {
        // When
        sut.loadCategories()

        // Then
        let categories = sut.getCategories()
        XCTAssertGreaterThan(categories.count, 0)
        XCTAssertTrue(categories.contains(where: { $0.name == "General" }))
    }

    func testCreateCategory() {
        // Given
        let name = "Test Category"
        let color = "#FF0000"
        let icon = "star"

        // When
        let category = sut.createCategory(name: name, color: color, icon: icon)

        // Then
        XCTAssertEqual(category.name, name)
        XCTAssertEqual(category.color, color)
        XCTAssertEqual(category.icon, icon)
        XCTAssertFalse(category.id.isEmpty)

        let categories = sut.getCategories()
        XCTAssertTrue(categories.contains(where: { $0.id == category.id }))
    }

    func testUpdateCategory() {
        // Given
        var category = sut.createCategory(name: "Original", color: "#000000", icon: "folder")
        let originalId = category.id

        // When
        category.name = "Updated"
        category.color = "#FFFFFF"
        category.icon = "star"
        sut.updateCategory(category)

        // Then
        let updatedCategory = sut.getCategory(by: originalId)
        XCTAssertNotNil(updatedCategory)
        XCTAssertEqual(updatedCategory?.name, "Updated")
        XCTAssertEqual(updatedCategory?.color, "#FFFFFF")
        XCTAssertEqual(updatedCategory?.icon, "star")
    }

    func testDeleteCategory() {
        // Given
        let category = sut.createCategory(name: "To Delete", color: "#000000", icon: "trash")
        let categoryId = category.id
        let thread = TestData.sampleThreadData()
        sut.addFavorite(thread, to: categoryId)

        // When
        sut.deleteCategory(id: categoryId)

        // Then
        let categories = sut.getCategories()
        XCTAssertFalse(categories.contains(where: { $0.id == categoryId }))

        // Favorites should be moved to default category
        let favorites = sut.loadFavorites()
        XCTAssertNotEqual(favorites.first?.categoryId, categoryId)
        XCTAssertNotNil(favorites.first?.categoryId) // Should have a category
    }

    func testGetCategoryById() {
        // Given
        let category = sut.createCategory(name: "Test", color: "#000000", icon: "folder")

        // When
        let retrieved = sut.getCategory(by: category.id)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, category.id)
        XCTAssertEqual(retrieved?.name, "Test")
    }

    func testGetCategoryByInvalidId() {
        // When
        let retrieved = sut.getCategory(by: "invalid-id")

        // Then
        XCTAssertNil(retrieved)
    }

    // MARK: - Favorites with Categories Tests

    func testGetFavoritesForCategory() {
        // Given
        let category1 = sut.createCategory(name: "Cat1", color: "#000000", icon: "1.circle")
        let category2 = sut.createCategory(name: "Cat2", color: "#FFFFFF", icon: "2.circle")

        let thread1 = TestData.sampleThreadData(number: "111111")
        let thread2 = TestData.sampleThreadData(number: "222222")
        let thread3 = TestData.sampleThreadData(number: "333333")

        sut.addFavorite(thread1, to: category1.id)
        sut.addFavorite(thread2, to: category1.id)
        sut.addFavorite(thread3, to: category2.id)

        // When
        let cat1Favorites = sut.getFavorites(for: category1.id)
        let cat2Favorites = sut.getFavorites(for: category2.id)

        // Then
        XCTAssertEqual(cat1Favorites.count, 2)
        XCTAssertEqual(cat2Favorites.count, 1)
        XCTAssertTrue(cat1Favorites.contains(where: { $0.number == "111111" }))
        XCTAssertTrue(cat1Favorites.contains(where: { $0.number == "222222" }))
        XCTAssertTrue(cat2Favorites.contains(where: { $0.number == "333333" }))
    }

    func testGetAllFavoritesWithoutCategoryFilter() {
        // Given
        let category = sut.createCategory(name: "Cat", color: "#000000", icon: "folder")
        let thread1 = TestData.sampleThreadData(number: "111111")
        let thread2 = TestData.sampleThreadData(number: "222222")

        sut.addFavorite(thread1, to: category.id)
        sut.addFavorite(thread2, to: category.id)

        // When
        let allFavorites = sut.getFavorites(for: nil)

        // Then
        XCTAssertEqual(allFavorites.count, 2)
    }

    func testChangeFavoriteCategory() {
        // Given
        let category1 = sut.createCategory(name: "Cat1", color: "#000000", icon: "1.circle")
        let category2 = sut.createCategory(name: "Cat2", color: "#FFFFFF", icon: "2.circle")
        let thread = TestData.sampleThreadData()

        sut.addFavorite(thread, to: category1.id)
        XCTAssertEqual(sut.loadFavorites().first?.categoryId, category1.id)

        // When
        sut.changeFavoriteCategory(threadNumber: thread.number, to: category2.id)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.first?.categoryId, category2.id)
    }

    // MARK: - Persistence Tests

    func testSaveAndLoadFavorites() {
        // Given
        let threads = TestData.sampleThreadDataArray(count: 3)
        threads.forEach { sut.addFavorite($0) }

        // When - Simulate app restart by reloading
        let loadedFavorites = sut.loadFavorites()

        // Then
        XCTAssertEqual(loadedFavorites.count, 3)
        XCTAssertEqual(Set(loadedFavorites.map { $0.number }), Set(threads.map { $0.number }))
    }

    func testSaveAndLoadCategories() {
        // Given
        _ = sut.createCategory(name: "Cat1", color: "#FF0000", icon: "1.circle")
        _ = sut.createCategory(name: "Cat2", color: "#00FF00", icon: "2.circle")

        // When - Reload categories
        sut.loadCategories()
        let categories = sut.getCategories()

        // Then
        XCTAssertTrue(categories.contains(where: { $0.name == "Cat1" }))
        XCTAssertTrue(categories.contains(where: { $0.name == "Cat2" }))
    }

    // MARK: - iCloud Sync Tests

    func testSyncFavoriteFromICloud() {
        // Given
        let boardAbv = "g"
        let threadNumber = "123456789"
        XCTAssertFalse(sut.isFavorited(threadNumber: threadNumber))

        // When
        sut.syncFavoriteFromICloud(boardAbv: boardAbv, threadNumber: threadNumber)

        // Then
        XCTAssertTrue(sut.isFavorited(threadNumber: threadNumber))
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.first?.boardAbv, boardAbv)
        XCTAssertEqual(favorites.first?.number, threadNumber)
    }

    func testSyncExistingFavoriteFromICloud() {
        // Given
        let thread = TestData.sampleThreadData()
        sut.addFavorite(thread)
        let originalCount = sut.loadFavorites().count

        // When - Try to sync the same thread
        sut.syncFavoriteFromICloud(boardAbv: thread.boardAbv, threadNumber: thread.number)

        // Then - Should not create duplicate
        XCTAssertEqual(sut.loadFavorites().count, originalCount)
    }

    func testGetAllFavoritesForSync() {
        // Given
        let threads = TestData.sampleThreadDataArray(count: 3)
        threads.forEach { sut.addFavorite($0) }

        // When
        let syncData = sut.getAllFavoritesForSync()

        // Then
        XCTAssertEqual(syncData.count, 3)
        XCTAssertTrue(syncData.contains(where: { $0.threadNumber == threads[0].number }))
        XCTAssertTrue(syncData.contains(where: { $0.boardAbv == threads[0].boardAbv }))
    }

    // MARK: - Migration Tests

    func testMigrateExistingFavoritesToDefaultCategory() {
        // Given - Add favorites without categories (simulating old data)
        var thread = TestData.sampleThreadData()
        thread.categoryId = nil

        // Directly save to bypass automatic category assignment
        ICloudSyncManager.shared.save([thread], forKey: "favorites")

        // When - Load categories (triggers migration)
        sut.loadCategories()

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertNotNil(favorites.first?.categoryId)
        XCTAssertFalse(favorites.first?.categoryId?.isEmpty ?? true)
    }

    // MARK: - Offline Cache Integration Tests

    func testCacheAllFavorites() {
        // Given
        let threads = TestData.sampleThreadDataArray(count: 3)
        threads.forEach { sut.addFavorite($0) }
        let expectation = self.expectation(description: "Cache all favorites")

        // When
        sut.cacheAllFavorites { successCount, failureCount in
            // Then
            // Note: In real app this would trigger network requests
            // In tests with mocks, behavior depends on mock configuration
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testCheckFavoritesCacheStatus() {
        // Given
        let threads = TestData.sampleThreadDataArray(count: 3)
        threads.forEach { sut.addFavorite($0) }
        let expectation = self.expectation(description: "Check cache status")

        // When
        sut.checkFavoritesCacheStatus { cachedCount, uncachedCount in
            // Then
            XCTAssertEqual(cachedCount + uncachedCount, 3)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Edge Cases Tests

    func testAddFavoriteWithEmptyNumber() {
        // Given
        var thread = TestData.sampleThreadData()
        thread = ThreadData(
            number: "",
            stats: thread.stats,
            title: thread.title,
            comment: thread.comment,
            imageUrl: thread.imageUrl,
            boardAbv: thread.boardAbv,
            replies: thread.replies,
            createdAt: thread.createdAt,
            categoryId: thread.categoryId
        )

        // When
        sut.addFavorite(thread)

        // Then
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 1) // Should still add
    }

    func testConcurrentFavoriteOperations() {
        // Given
        let expectation = self.expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10

        // When - Add favorites concurrently
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let thread = TestData.sampleThreadData(number: String(100000 + index))
            sut.addFavorite(thread)
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 5.0)
        let favorites = sut.loadFavorites()
        XCTAssertEqual(favorites.count, 10)
    }

    func testRemoveAllFavorites() {
        // Given
        let threads = TestData.sampleThreadDataArray(count: 5)
        threads.forEach { sut.addFavorite($0) }
        XCTAssertEqual(sut.loadFavorites().count, 5)

        // When
        threads.forEach { sut.removeFavorite(threadNumber: $0.number) }

        // Then
        XCTAssertEqual(sut.loadFavorites().count, 0)
    }
}
