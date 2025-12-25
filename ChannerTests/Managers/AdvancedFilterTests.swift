import XCTest
@testable import Channer

/// Unit tests for Advanced Filtering 2.0 functionality
class AdvancedFilterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear all filters before each test
        ContentFilterManager.shared.clearAllAdvancedFilters()
    }

    override func tearDown() {
        ContentFilterManager.shared.clearAllAdvancedFilters()
        super.tearDown()
    }

    // MARK: - Filter Creation Tests

    func testCreateKeywordFilter() {
        let filter = AdvancedFilter.keyword("test")
        XCTAssertEqual(filter.filterType, .keyword)
        XCTAssertEqual(filter.value, "test")
        XCTAssertTrue(filter.isEnabled)
        XCTAssertFalse(filter.isCaseSensitive)
        XCTAssertEqual(filter.filterMode, .blacklist)
    }

    func testCreateRegexFilter() {
        let filter = AdvancedFilter.regex("\\btest\\b")
        XCTAssertEqual(filter.filterType, .regex)
        XCTAssertEqual(filter.value, "\\btest\\b")
    }

    func testCreateFileTypeFilter() {
        let filter = AdvancedFilter.fileType(.hideVideos)
        XCTAssertEqual(filter.filterType, .fileType)
        XCTAssertEqual(filter.fileTypeFilter, .hideVideos)
    }

    func testCreateCountryFlagFilter() {
        let filter = AdvancedFilter.countryFlag("US", mode: .blacklist)
        XCTAssertEqual(filter.filterType, .countryFlag)
        XCTAssertEqual(filter.value, "US")
        XCTAssertEqual(filter.filterMode, .blacklist)
    }

    func testCreateTripCodeFilter() {
        let filter = AdvancedFilter.tripCode("!abc123", mode: .whitelist)
        XCTAssertEqual(filter.filterType, .tripCode)
        XCTAssertEqual(filter.value, "!abc123")
        XCTAssertEqual(filter.filterMode, .whitelist)
    }

    func testCreateTimeBasedFilter() {
        let filter = AdvancedFilter.timeBased(value: 24, unit: .hours)
        XCTAssertEqual(filter.filterType, .timeBased)
        XCTAssertEqual(filter.timeValue, 24)
        XCTAssertEqual(filter.timeUnit, .hours)
    }

    // MARK: - Filter Matching Tests

    func testKeywordFilterMatches() {
        let filter = AdvancedFilter.keyword("hello")
        let post = createTestPost(comment: "Hello world!")

        XCTAssertTrue(filter.matches(post: post))
    }

    func testKeywordFilterCaseSensitive() {
        var filter = AdvancedFilter.keyword("Hello", caseSensitive: true)
        let post = createTestPost(comment: "hello world!")

        XCTAssertFalse(filter.matches(post: post))
    }

    func testRegexFilterMatches() {
        let filter = AdvancedFilter.regex("\\d{3}-\\d{4}")
        let post = createTestPost(comment: "Call me at 555-1234")

        XCTAssertTrue(filter.matches(post: post))
    }

    func testRegexFilterNoMatch() {
        let filter = AdvancedFilter.regex("\\d{3}-\\d{4}")
        let post = createTestPost(comment: "No phone number here")

        XCTAssertFalse(filter.matches(post: post))
    }

    func testFileTypeFilterHidesVideos() {
        let filter = AdvancedFilter.fileType(.hideVideos)
        let videoPost = createTestPost(imageExtension: ".webm")
        let imagePost = createTestPost(imageExtension: ".jpg")

        XCTAssertTrue(filter.matches(post: videoPost))
        XCTAssertFalse(filter.matches(post: imagePost))
    }

    func testFileTypeFilterShowImagesOnly() {
        let filter = AdvancedFilter.fileType(.showImagesOnly)
        let videoPost = createTestPost(imageExtension: ".webm")
        let imagePost = createTestPost(imageExtension: ".jpg")

        // showImagesOnly should match (hide) non-images
        XCTAssertTrue(filter.matches(post: videoPost))
        XCTAssertFalse(filter.matches(post: imagePost))
    }

    func testCountryFlagFilterBlacklist() {
        let filter = AdvancedFilter.countryFlag("US", mode: .blacklist)
        let usPost = createTestPost(countryCode: "US")
        let ukPost = createTestPost(countryCode: "GB")

        XCTAssertTrue(filter.matches(post: usPost))
        XCTAssertFalse(filter.matches(post: ukPost))
    }

    func testTripCodeFilterMatches() {
        let filter = AdvancedFilter.tripCode("!abc123")
        let matchingPost = createTestPost(tripCode: "!abc123")
        let differentPost = createTestPost(tripCode: "!xyz789")

        XCTAssertTrue(filter.matches(post: matchingPost))
        XCTAssertFalse(filter.matches(post: differentPost))
    }

    func testTimeBasedFilterMatches() {
        let filter = AdvancedFilter.timeBased(value: 1, unit: .hours)

        // Post from 2 hours ago should be filtered
        let oldTimestamp = Int(Date().timeIntervalSince1970 - 7200)
        let oldPost = createTestPost(timestamp: oldTimestamp)

        // Post from 30 minutes ago should not be filtered
        let recentTimestamp = Int(Date().timeIntervalSince1970 - 1800)
        let recentPost = createTestPost(timestamp: recentTimestamp)

        XCTAssertTrue(filter.matches(post: oldPost))
        XCTAssertFalse(filter.matches(post: recentPost))
    }

    func testDisabledFilterDoesNotMatch() {
        var filter = AdvancedFilter.keyword("test")
        filter.isEnabled = false

        let post = createTestPost(comment: "This is a test")

        XCTAssertFalse(filter.matches(post: post))
    }

    // MARK: - ContentFilterManager Tests

    func testAddAdvancedFilter() {
        let filter = AdvancedFilter.keyword("spam")
        let result = ContentFilterManager.shared.addAdvancedFilter(filter)

        XCTAssertTrue(result)
        XCTAssertEqual(ContentFilterManager.shared.getAdvancedFilters().count, 1)
    }

    func testAddDuplicateFilterFails() {
        let filter1 = AdvancedFilter.keyword("spam")
        let filter2 = AdvancedFilter.keyword("spam")

        ContentFilterManager.shared.addAdvancedFilter(filter1)
        let result = ContentFilterManager.shared.addAdvancedFilter(filter2)

        XCTAssertFalse(result)
        XCTAssertEqual(ContentFilterManager.shared.getAdvancedFilters().count, 1)
    }

    func testRemoveAdvancedFilter() {
        let filter = AdvancedFilter.keyword("test")
        ContentFilterManager.shared.addAdvancedFilter(filter)

        let result = ContentFilterManager.shared.removeAdvancedFilter(id: filter.id)

        XCTAssertTrue(result)
        XCTAssertEqual(ContentFilterManager.shared.getAdvancedFilters().count, 0)
    }

    func testToggleAdvancedFilter() {
        var filter = AdvancedFilter.keyword("test")
        ContentFilterManager.shared.addAdvancedFilter(filter)

        ContentFilterManager.shared.toggleAdvancedFilter(id: filter.id)

        let filters = ContentFilterManager.shared.getAdvancedFilters()
        XCTAssertEqual(filters.first?.isEnabled, false)
    }

    func testGetFiltersByType() {
        ContentFilterManager.shared.addAdvancedFilter(AdvancedFilter.keyword("test1"))
        ContentFilterManager.shared.addAdvancedFilter(AdvancedFilter.regex("\\d+"))
        ContentFilterManager.shared.addAdvancedFilter(AdvancedFilter.keyword("test2"))

        let keywordFilters = ContentFilterManager.shared.getAdvancedFilters(ofType: .keyword)
        let regexFilters = ContentFilterManager.shared.getAdvancedFilters(ofType: .regex)

        XCTAssertEqual(keywordFilters.count, 2)
        XCTAssertEqual(regexFilters.count, 1)
    }

    func testValidateRegex() {
        XCTAssertTrue(ContentFilterManager.shared.isValidRegex("\\d+"))
        XCTAssertTrue(ContentFilterManager.shared.isValidRegex("hello"))
        XCTAssertFalse(ContentFilterManager.shared.isValidRegex("[invalid"))
    }

    func testFilterStatistics() {
        ContentFilterManager.shared.addAdvancedFilter(AdvancedFilter.keyword("test1"))
        ContentFilterManager.shared.addAdvancedFilter(AdvancedFilter.keyword("test2"))
        ContentFilterManager.shared.addAdvancedFilter(AdvancedFilter.regex("\\d+"))

        let stats = ContentFilterManager.shared.getFilterStatistics()

        XCTAssertEqual(stats.total, 3)
        XCTAssertEqual(stats.enabled, 3)
        XCTAssertEqual(stats.byType[.keyword], 2)
        XCTAssertEqual(stats.byType[.regex], 1)
    }

    // MARK: - Post Metadata Tests

    func testPostMetadataIsVideo() {
        let videoPost = createTestPost(imageExtension: ".webm")
        let imagePost = createTestPost(imageExtension: ".jpg")

        XCTAssertTrue(videoPost.isVideo)
        XCTAssertFalse(imagePost.isVideo)
    }

    func testPostMetadataIsImage() {
        let imagePost = createTestPost(imageExtension: ".jpg")
        let videoPost = createTestPost(imageExtension: ".webm")

        XCTAssertTrue(imagePost.isImage)
        XCTAssertFalse(videoPost.isImage)
    }

    func testPostMetadataIsGif() {
        let gifPost = createTestPost(imageExtension: ".gif")
        let imagePost = createTestPost(imageExtension: ".jpg")

        XCTAssertTrue(gifPost.isGif)
        XCTAssertFalse(imagePost.isGif)
    }

    func testPostMetadataAgeInSeconds() {
        let timestamp = Int(Date().timeIntervalSince1970 - 3600) // 1 hour ago
        let post = createTestPost(timestamp: timestamp)

        guard let age = post.ageInSeconds else {
            XCTFail("Age should not be nil")
            return
        }

        XCTAssertGreaterThan(age, 3599)
        XCTAssertLessThan(age, 3602) // Allow some tolerance
    }

    // MARK: - Country Codes Tests

    func testCountryCodeName() {
        XCTAssertEqual(CountryCodes.name(for: "US"), "United States")
        XCTAssertEqual(CountryCodes.name(for: "GB"), "United Kingdom")
        XCTAssertNil(CountryCodes.name(for: "XX"))
    }

    func testCountryCodeFlag() {
        let usFlag = CountryCodes.flag(for: "US")
        XCTAssertFalse(usFlag.isEmpty)
    }

    // MARK: - Time Unit Tests

    func testTimeUnitToSeconds() {
        XCTAssertEqual(TimeUnit.minutes.toSeconds(5), 300)
        XCTAssertEqual(TimeUnit.hours.toSeconds(2), 7200)
        XCTAssertEqual(TimeUnit.days.toSeconds(1), 86400)
        XCTAssertEqual(TimeUnit.weeks.toSeconds(1), 604800)
    }

    // MARK: - Helper Methods

    private func createTestPost(
        postNumber: String = "12345",
        comment: String = "Test comment",
        posterId: String? = nil,
        tripCode: String? = nil,
        countryCode: String? = nil,
        countryName: String? = nil,
        timestamp: Int? = nil,
        imageUrl: String? = nil,
        imageExtension: String? = nil,
        imageName: String? = nil
    ) -> PostMetadata {
        return PostMetadata(
            postNumber: postNumber,
            comment: comment,
            posterId: posterId,
            tripCode: tripCode,
            countryCode: countryCode,
            countryName: countryName,
            timestamp: timestamp,
            imageUrl: imageUrl ?? (imageExtension != nil ? "https://example.com/test\(imageExtension!)" : nil),
            imageExtension: imageExtension,
            imageName: imageName
        )
    }
}
