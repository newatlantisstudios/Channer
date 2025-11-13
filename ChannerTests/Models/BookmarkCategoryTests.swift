//
//  BookmarkCategoryTests.swift
//  ChannerTests
//
//  Unit tests for BookmarkCategory data model
//

import XCTest
@testable import Channer

class BookmarkCategoryTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBookmarkCategoryInitialization() {
        // Act
        let category = BookmarkCategory(name: "Test Category")

        // Assert
        XCTAssertNotNil(category.id, "Category should have an ID")
        XCTAssertEqual(category.name, "Test Category", "Name should match")
        XCTAssertNotNil(category.createdAt, "Created date should be set")
        XCTAssertNotNil(category.updatedAt, "Updated date should be set")
    }

    func testBookmarkCategoryDefaultColor() {
        // Act
        let category = BookmarkCategory(name: "Test")

        // Assert
        XCTAssertEqual(category.color, "#007AFF", "Default color should be system blue")
    }

    func testBookmarkCategoryDefaultIcon() {
        // Act
        let category = BookmarkCategory(name: "Test")

        // Assert
        XCTAssertEqual(category.icon, "folder", "Default icon should be folder")
    }

    func testBookmarkCategoryCustomColorAndIcon() {
        // Act
        let category = BookmarkCategory(name: "Important", color: "#FF0000", icon: "star.fill")

        // Assert
        XCTAssertEqual(category.color, "#FF0000", "Color should be set")
        XCTAssertEqual(category.icon, "star.fill", "Icon should be set")
    }

    func testBookmarkCategoryUniqueIDs() {
        // Act
        let category1 = BookmarkCategory(name: "Category 1")
        let category2 = BookmarkCategory(name: "Category 2")

        // Assert
        XCTAssertNotEqual(category1.id, category2.id, "Each category should have unique ID")
    }

    // MARK: - Property Tests

    func testBookmarkCategoryNameCanBeModified() {
        // Arrange
        var category = BookmarkCategory(name: "Original")

        // Act
        category.name = "Modified"

        // Assert
        XCTAssertEqual(category.name, "Modified", "Name should be modifiable")
    }

    func testBookmarkCategoryColorCanBeModified() {
        // Arrange
        var category = BookmarkCategory(name: "Test")

        // Act
        category.color = "#00FF00"

        // Assert
        XCTAssertEqual(category.color, "#00FF00", "Color should be modifiable")
    }

    func testBookmarkCategoryIconCanBeModified() {
        // Arrange
        var category = BookmarkCategory(name: "Test")

        // Act
        category.icon = "bookmark.fill"

        // Assert
        XCTAssertEqual(category.icon, "bookmark.fill", "Icon should be modifiable")
    }

    func testBookmarkCategoryUpdatedAtCanBeModified() {
        // Arrange
        var category = BookmarkCategory(name: "Test")
        let newDate = Date().addingTimeInterval(-3600) // 1 hour ago

        // Act
        category.updatedAt = newDate

        // Assert
        XCTAssertEqual(category.updatedAt, newDate, "Updated date should be modifiable")
    }

    // MARK: - Codable Tests

    func testBookmarkCategoryCodable() {
        // Arrange
        let category = TestDataFactory.createTestCategory(
            name: "Test Category",
            color: "#FF0000",
            icon: "star.fill"
        )

        // Act & Assert
        XCTAssertCodable(category)
    }

    func testBookmarkCategoryEncodeDecode() {
        // Arrange
        let original = BookmarkCategory(
            name: "Test Category",
            color: "#34C759",
            icon: "book.fill"
        )

        // Act
        do {
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(BookmarkCategory.self, from: encoded)

            // Assert
            XCTAssertEqual(decoded.id, original.id, "ID should match")
            XCTAssertEqual(decoded.name, original.name, "Name should match")
            XCTAssertEqual(decoded.color, original.color, "Color should match")
            XCTAssertEqual(decoded.icon, original.icon, "Icon should match")
        } catch {
            XCTFail("Encoding/Decoding failed: \(error)")
        }
    }

    func testBookmarkCategoryArrayCodable() {
        // Arrange
        let categories = TestDataFactory.createDefaultCategories()

        // Act
        do {
            let encoded = try JSONEncoder().encode(categories)
            let decoded = try JSONDecoder().decode([BookmarkCategory].self, from: encoded)

            // Assert
            XCTAssertEqual(decoded.count, categories.count, "Should decode same number of categories")
            for (index, category) in categories.enumerated() {
                XCTAssertEqual(decoded[index].id, category.id, "Category ID should match")
                XCTAssertEqual(decoded[index].name, category.name, "Category name should match")
            }
        } catch {
            XCTFail("Encoding/Decoding array failed: \(error)")
        }
    }

    // MARK: - Default Categories Tests

    func testDefaultCategoriesCreation() {
        // Act
        let categories = TestDataFactory.createDefaultCategories()

        // Assert
        XCTAssertCount(categories, 4, "Should have 4 default categories")

        let names = categories.map { $0.name }
        XCTAssertTrue(names.contains("General"), "Should have General category")
        XCTAssertTrue(names.contains("To Read"), "Should have To Read category")
        XCTAssertTrue(names.contains("Important"), "Should have Important category")
        XCTAssertTrue(names.contains("Archives"), "Should have Archives category")
    }

    func testDefaultCategoriesHaveUniqueColors() {
        // Act
        let categories = TestDataFactory.createDefaultCategories()

        // Assert
        let colors = categories.map { $0.color }
        let uniqueColors = Set(colors)
        XCTAssertEqual(colors.count, uniqueColors.count, "Each default category should have unique color")
    }

    func testDefaultCategoriesHaveUniqueIcons() {
        // Act
        let categories = TestDataFactory.createDefaultCategories()

        // Assert
        let icons = categories.map { $0.icon }
        let uniqueIcons = Set(icons)
        XCTAssertEqual(icons.count, uniqueIcons.count, "Each default category should have unique icon")
    }

    // MARK: - Edge Cases

    func testBookmarkCategoryWithEmptyName() {
        // Act
        let category = BookmarkCategory(name: "")

        // Assert
        XCTAssertEqual(category.name, "", "Should allow empty name")
    }

    func testBookmarkCategoryWithLongName() {
        // Arrange
        let longName = String(repeating: "A", count: 1000)

        // Act
        let category = BookmarkCategory(name: longName)

        // Assert
        XCTAssertEqual(category.name, longName, "Should handle long names")
    }

    func testBookmarkCategoryWithSpecialCharactersInName() {
        // Act
        let category = BookmarkCategory(name: "Test @#$%^&*() <html> \"quotes\"")

        // Assert
        XCTAssertEqual(category.name, "Test @#$%^&*() <html> \"quotes\"",
                      "Special characters should be preserved")
    }

    func testBookmarkCategoryWithUnicodeInName() {
        // Act
        let category = BookmarkCategory(name: "カテゴリ 범주 🔖")

        // Assert
        XCTAssertEqual(category.name, "カテゴリ 범주 🔖", "Unicode should be preserved")
    }

    func testBookmarkCategoryWithInvalidColorFormat() {
        // Act
        let category = BookmarkCategory(name: "Test", color: "invalid")

        // Assert
        XCTAssertEqual(category.color, "invalid", "Should store invalid color (validation happens elsewhere)")
    }

    func testBookmarkCategoryWithInvalidIcon() {
        // Act
        let category = BookmarkCategory(name: "Test", icon: "nonexistent.icon")

        // Assert
        XCTAssertEqual(category.icon, "nonexistent.icon", "Should store invalid icon name")
    }

    // MARK: - Date Tests

    func testBookmarkCategoryCreatedAtBeforeUpdatedAt() {
        // Act
        let category = BookmarkCategory(name: "Test")

        // Assert
        XCTAssertLessThanOrEqual(category.createdAt, category.updatedAt,
                                "Created date should be before or equal to updated date")
    }

    func testBookmarkCategoryUpdateDateChanges() {
        // Arrange
        var category = BookmarkCategory(name: "Test")
        let originalUpdatedAt = category.updatedAt

        // Wait a moment
        Thread.sleep(forTimeInterval: 0.1)

        // Act
        category.updatedAt = Date()

        // Assert
        XCTAssertGreaterThan(category.updatedAt, originalUpdatedAt,
                           "Updated date should change")
    }

    // MARK: - ID Format Tests

    func testBookmarkCategoryIDIsUUIDString() {
        // Act
        let category = BookmarkCategory(name: "Test")

        // Assert
        XCTAssertNotNil(UUID(uuidString: category.id), "ID should be valid UUID string")
    }

    func testBookmarkCategoryIDIsNotEmpty() {
        // Act
        let category = BookmarkCategory(name: "Test")

        // Assert
        XCTAssertFalse(category.id.isEmpty, "ID should not be empty")
    }

    // MARK: - Persistence Simulation Tests

    func testBookmarkCategoryJSONRoundTrip() {
        // Arrange
        let category = BookmarkCategory(
            name: "Persistence Test",
            color: "#FF9500",
            icon: "archivebox.fill"
        )

        // Act
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(category)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(BookmarkCategory.self, from: jsonData)

            // Assert
            XCTAssertEqual(decoded.id, category.id, "ID should survive round trip")
            XCTAssertEqual(decoded.name, category.name, "Name should survive round trip")
            XCTAssertEqual(decoded.color, category.color, "Color should survive round trip")
            XCTAssertEqual(decoded.icon, category.icon, "Icon should survive round trip")
        } catch {
            XCTFail("JSON round trip failed: \(error)")
        }
    }
}
