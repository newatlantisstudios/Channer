//
//  ContentFilterManagerTests.swift
//  ChannerTests
//
//  Unit tests for ContentFilterManager
//

import XCTest
@testable import Channer

class ContentFilterManagerTests: XCTestCase {

    var manager: ContentFilterManager!
    var mockDefaults: MockUserDefaults!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create mock UserDefaults
        mockDefaults = MockUserDefaults()

        // Note: Since ContentFilterManager uses UserDefaults.standard directly,
        // we'll test by clearing defaults before each test
        clearFilters()
    }

    override func tearDown() {
        clearFilters()
        mockDefaults = nil
        manager = nil

        super.tearDown()
    }

    // MARK: - Helper Methods

    private func clearFilters() {
        UserDefaults.standard.removeObject(forKey: "content_filters")
        UserDefaults.standard.removeObject(forKey: "poster_filters")
        UserDefaults.standard.removeObject(forKey: "image_filters")
        UserDefaults.standard.removeObject(forKey: "content_filter_enabled")
        UserDefaults.standard.synchronize()
    }

    private func setTestFilters(keywords: [String], posters: [String], images: [String]) {
        UserDefaults.standard.set(keywords, forKey: "content_filters")
        UserDefaults.standard.set(posters, forKey: "poster_filters")
        UserDefaults.standard.set(images, forKey: "image_filters")
        UserDefaults.standard.synchronize()
    }

    // MARK: - Initialization Tests

    func testContentFilterManagerSingletonExists() {
        // Arrange & Act
        manager = ContentFilterManager.shared

        // Assert
        XCTAssertNotNil(manager, "ContentFilterManager singleton should exist")
    }

    func testContentFilterManagerSingletonIsSame() {
        // Arrange & Act
        let manager1 = ContentFilterManager.shared
        let manager2 = ContentFilterManager.shared

        // Assert
        XCTAssertTrue(manager1 === manager2, "ContentFilterManager should return same singleton instance")
    }

    func testContentFilterManagerDefaultFilterEnabledState() {
        // Arrange
        clearFilters() // Ensure no existing state

        // Act
        manager = ContentFilterManager.shared

        // Assert
        XCTAssertTrue(manager.isFilteringEnabled(), "Content filtering should be enabled by default")
    }

    // MARK: - Filter Enabled/Disabled Tests

    func testContentFilterManagerSetFilteringEnabled() {
        // Arrange
        manager = ContentFilterManager.shared

        // Act
        manager.setFilteringEnabled(true)

        // Assert
        XCTAssertTrue(manager.isFilteringEnabled(), "Filtering should be enabled")
    }

    func testContentFilterManagerSetFilteringDisabled() {
        // Arrange
        manager = ContentFilterManager.shared

        // Act
        manager.setFilteringEnabled(false)

        // Assert
        XCTAssertFalse(manager.isFilteringEnabled(), "Filtering should be disabled")
    }

    func testContentFilterManagerToggleFilteringState() {
        // Arrange
        manager = ContentFilterManager.shared
        manager.setFilteringEnabled(true)

        // Act
        manager.setFilteringEnabled(false)
        let afterDisable = manager.isFilteringEnabled()

        manager.setFilteringEnabled(true)
        let afterEnable = manager.isFilteringEnabled()

        // Assert
        XCTAssertFalse(afterDisable, "Filtering should be disabled after setting to false")
        XCTAssertTrue(afterEnable, "Filtering should be enabled after setting to true")
    }

    func testContentFilterManagerFilteringStatePersists() {
        // Arrange
        manager = ContentFilterManager.shared
        manager.setFilteringEnabled(false)

        // Act - Get a new reference to simulate app restart
        let newManager = ContentFilterManager.shared

        // Assert
        XCTAssertFalse(newManager.isFilteringEnabled(), "Filtering state should persist")
    }

    // MARK: - Get All Filters Tests

    func testContentFilterManagerGetAllFiltersReturnsEmptyByDefault() {
        // Arrange
        manager = ContentFilterManager.shared
        clearFilters()

        // Act
        let filters = manager.getAllFilters()

        // Assert
        XCTAssertEmpty(filters.keywords, "Keywords should be empty by default")
        XCTAssertEmpty(filters.posters, "Posters should be empty by default")
        XCTAssertEmpty(filters.images, "Images should be empty by default")
    }

    func testContentFilterManagerGetAllFiltersReturnsStoredFilters() {
        // Arrange
        manager = ContentFilterManager.shared
        let testKeywords = ["spam", "advertisement"]
        let testPosters = ["TrollUser", "SpamBot"]
        let testImages = ["badimage.jpg", "spam.png"]
        setTestFilters(keywords: testKeywords, posters: testPosters, images: testImages)

        // Act
        let filters = manager.getAllFilters()

        // Assert
        XCTAssertEqual(filters.keywords, testKeywords, "Keywords should match stored values")
        XCTAssertEqual(filters.posters, testPosters, "Posters should match stored values")
        XCTAssertEqual(filters.images, testImages, "Images should match stored values")
    }

    func testContentFilterManagerGetAllFiltersWithSomeEmpty() {
        // Arrange
        manager = ContentFilterManager.shared
        let testKeywords = ["spam"]
        setTestFilters(keywords: testKeywords, posters: [], images: [])

        // Act
        let filters = manager.getAllFilters()

        // Assert
        XCTAssertEqual(filters.keywords, testKeywords, "Keywords should be returned")
        XCTAssertEmpty(filters.posters, "Posters should be empty")
        XCTAssertEmpty(filters.images, "Images should be empty")
    }

    // MARK: - iCloud Sync Tests

    func testContentFilterManagerSyncKeywordsFromICloud() {
        // Arrange
        manager = ContentFilterManager.shared
        let iCloudKeywords = ["test1", "test2", "test3"]

        // Act
        manager.syncKeywordsFromICloud(iCloudKeywords)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, iCloudKeywords, "Keywords should be synced from iCloud")
    }

    func testContentFilterManagerSyncPostersFromICloud() {
        // Arrange
        manager = ContentFilterManager.shared
        let iCloudPosters = ["poster1", "poster2"]

        // Act
        manager.syncPostersFromICloud(iCloudPosters)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.posters, iCloudPosters, "Posters should be synced from iCloud")
    }

    func testContentFilterManagerSyncImagesFromICloud() {
        // Arrange
        manager = ContentFilterManager.shared
        let iCloudImages = ["image1.jpg", "image2.png"]

        // Act
        manager.syncImagesFromICloud(iCloudImages)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.images, iCloudImages, "Images should be synced from iCloud")
    }

    func testContentFilterManagerSyncOverwritesExistingFilters() {
        // Arrange
        manager = ContentFilterManager.shared
        let oldKeywords = ["old1", "old2"]
        let newKeywords = ["new1", "new2", "new3"]
        setTestFilters(keywords: oldKeywords, posters: [], images: [])

        // Act
        manager.syncKeywordsFromICloud(newKeywords)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, newKeywords, "New keywords should replace old ones")
        XCTAssertNotEqual(filters.keywords, oldKeywords, "Old keywords should be gone")
    }

    func testContentFilterManagerSyncEmptyArrayClearsFilters() {
        // Arrange
        manager = ContentFilterManager.shared
        let oldKeywords = ["old1", "old2"]
        setTestFilters(keywords: oldKeywords, posters: [], images: [])

        // Act
        manager.syncKeywordsFromICloud([])

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEmpty(filters.keywords, "Keywords should be cleared when syncing empty array")
    }

    func testContentFilterManagerSyncDoesNotAffectOtherFilterTypes() {
        // Arrange
        manager = ContentFilterManager.shared
        let keywords = ["keyword1"]
        let posters = ["poster1"]
        let images = ["image1.jpg"]
        setTestFilters(keywords: keywords, posters: posters, images: images)

        // Act
        manager.syncKeywordsFromICloud(["newkeyword1", "newkeyword2"])

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertNotEqual(filters.keywords, keywords, "Keywords should be updated")
        XCTAssertEqual(filters.posters, posters, "Posters should remain unchanged")
        XCTAssertEqual(filters.images, images, "Images should remain unchanged")
    }

    // MARK: - Data Persistence Tests

    func testContentFilterManagerFiltersPersistAcrossInstances() {
        // Arrange
        manager = ContentFilterManager.shared
        let testKeywords = ["persist1", "persist2"]
        manager.syncKeywordsFromICloud(testKeywords)

        // Act - Simulate getting a new manager instance
        let newManager = ContentFilterManager.shared

        // Assert
        let filters = newManager.getAllFilters()
        XCTAssertEqual(filters.keywords, testKeywords, "Filters should persist across instances")
    }

    func testContentFilterManagerMultipleSyncOperationsPersist() {
        // Arrange
        manager = ContentFilterManager.shared

        // Act
        manager.syncKeywordsFromICloud(["k1"])
        manager.syncPostersFromICloud(["p1"])
        manager.syncImagesFromICloud(["i1.jpg"])

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, ["k1"], "Keywords should persist")
        XCTAssertEqual(filters.posters, ["p1"], "Posters should persist")
        XCTAssertEqual(filters.images, ["i1.jpg"], "Images should persist")
    }

    // MARK: - Edge Cases

    func testContentFilterManagerSyncWithSpecialCharacters() {
        // Arrange
        manager = ContentFilterManager.shared
        let specialKeywords = ["test@123", "user#456", "filter$789", "quote\"test"]

        // Act
        manager.syncKeywordsFromICloud(specialKeywords)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, specialKeywords, "Special characters should be preserved")
    }

    func testContentFilterManagerSyncWithUnicodeCharacters() {
        // Arrange
        manager = ContentFilterManager.shared
        let unicodeKeywords = ["测试", "тест", "テスト", "🔥"]

        // Act
        manager.syncKeywordsFromICloud(unicodeKeywords)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, unicodeKeywords, "Unicode characters should be preserved")
    }

    func testContentFilterManagerSyncWithEmptyStrings() {
        // Arrange
        manager = ContentFilterManager.shared
        let keywords = ["", "valid", ""]

        // Act
        manager.syncKeywordsFromICloud(keywords)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, keywords, "Empty strings should be preserved")
    }

    func testContentFilterManagerSyncWithLargeArray() {
        // Arrange
        manager = ContentFilterManager.shared
        let largeArray = (1...1000).map { "filter\($0)" }

        // Act
        manager.syncKeywordsFromICloud(largeArray)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords.count, 1000, "Large arrays should be handled")
        XCTAssertEqual(filters.keywords, largeArray, "All items should be preserved")
    }

    func testContentFilterManagerSyncWithDuplicates() {
        // Arrange
        manager = ContentFilterManager.shared
        let keywords = ["test", "test", "duplicate", "duplicate"]

        // Act
        manager.syncKeywordsFromICloud(keywords)

        // Assert
        let filters = manager.getAllFilters()
        XCTAssertEqual(filters.keywords, keywords, "Duplicates should be preserved (no deduplication)")
    }
}
