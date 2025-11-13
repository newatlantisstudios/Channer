//
//  ThemeManagerTests.swift
//  ChannerTests
//
//  Unit tests for ThemeManager
//

import XCTest
@testable import Channer

class ThemeManagerTests: XCTestCase {

    var manager: ThemeManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Get manager instance
        manager = ThemeManager.shared

        // Reset to default theme
        manager.setTheme(id: "default")

        // Clear any custom themes
        UserDefaults.standard.removeObject(forKey: "channer_custom_themes")
    }

    override func tearDown() {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "channer_custom_themes")
        UserDefaults.standard.removeObject(forKey: "channer_selected_theme_id")

        manager = nil

        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testThemeManagerSingletonExists() {
        // Assert
        XCTAssertNotNil(manager, "ThemeManager singleton should exist")
    }

    func testThemeManagerSingletonIsSame() {
        // Arrange & Act
        let manager1 = ThemeManager.shared
        let manager2 = ThemeManager.shared

        // Assert
        XCTAssertTrue(manager1 === manager2, "ThemeManager should return same singleton instance")
    }

    func testThemeManagerHasDefaultTheme() {
        // Assert
        XCTAssertEqual(manager.currentTheme.id, "default", "Should have default theme initially")
    }

    func testThemeManagerHasBuiltInThemes() {
        // Assert
        XCTAssertGreaterThan(manager.availableThemes.count, 0, "Should have at least one built-in theme")

        let builtInThemes = manager.availableThemes.filter { $0.isBuiltIn }
        XCTAssertGreaterThan(builtInThemes.count, 0, "Should have at least one built-in theme")
    }

    // MARK: - Set Theme Tests

    func testThemeManagerSetThemeByID() {
        // Arrange
        guard let firstBuiltInTheme = manager.availableThemes.first(where: { $0.isBuiltIn }) else {
            XCTFail("No built-in themes available")
            return
        }

        // Act
        manager.setTheme(id: firstBuiltInTheme.id)

        // Assert
        XCTAssertEqual(manager.currentTheme.id, firstBuiltInTheme.id, "Current theme should be set")
    }

    func testThemeManagerSetThemePostsNotification() {
        // Arrange
        guard let firstTheme = manager.availableThemes.first else {
            XCTFail("No themes available")
            return
        }

        let expectation = XCTestExpectation(description: "Theme change notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Act
        manager.setTheme(id: firstTheme.id)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testThemeManagerSetNonExistentTheme() {
        // Arrange
        let originalTheme = manager.currentTheme

        // Act
        manager.setTheme(id: "nonexistent_theme_id")

        // Assert
        XCTAssertEqual(manager.currentTheme.id, originalTheme.id, "Theme should not change for invalid ID")
    }

    func testThemeManagerSetThemePersists() {
        // Arrange
        guard let firstTheme = manager.availableThemes.first else {
            XCTFail("No themes available")
            return
        }

        // Act
        manager.setTheme(id: firstTheme.id)

        // Assert
        let savedThemeId = UserDefaults.standard.string(forKey: "channer_selected_theme_id")
        XCTAssertEqual(savedThemeId, firstTheme.id, "Theme selection should persist")
    }

    // MARK: - Add Custom Theme Tests

    func testThemeManagerAddCustomTheme() {
        // Arrange
        let customTheme = TestDataFactory.createTestTheme(id: "test_custom", name: "Test Custom")

        // Act
        let success = manager.addCustomTheme(customTheme)

        // Assert
        XCTAssertTrue(success, "Adding custom theme should succeed")
        XCTAssertTrue(manager.availableThemes.contains { $0.id == "test_custom" },
                     "Custom theme should be in available themes")
    }

    func testThemeManagerAddMultipleCustomThemes() {
        // Arrange
        let theme1 = TestDataFactory.createTestTheme(id: "custom1", name: "Custom 1")
        let theme2 = TestDataFactory.createTestTheme(id: "custom2", name: "Custom 2")

        // Act
        let success1 = manager.addCustomTheme(theme1)
        let success2 = manager.addCustomTheme(theme2)

        // Assert
        XCTAssertTrue(success1 && success2, "Both themes should be added successfully")
        XCTAssertEqual(manager.availableThemes.filter { !$0.isBuiltIn }.count, 2,
                      "Should have 2 custom themes")
    }

    func testThemeManagerAddDuplicateThemeID() {
        // Arrange
        let theme1 = TestDataFactory.createTestTheme(id: "duplicate", name: "First")
        let theme2 = TestDataFactory.createTestTheme(id: "duplicate", name: "Second")

        // Act
        let success1 = manager.addCustomTheme(theme1)
        let success2 = manager.addCustomTheme(theme2)

        // Assert
        XCTAssertTrue(success1, "First theme should be added")
        XCTAssertFalse(success2, "Duplicate theme should fail")
    }

    func testThemeManagerCustomThemePersists() {
        // Arrange
        let customTheme = TestDataFactory.createTestTheme(id: "persist_test", name: "Persist Test")

        // Act
        manager.addCustomTheme(customTheme)

        // Assert
        let data = UserDefaults.standard.data(forKey: "channer_custom_themes")
        XCTAssertNotNil(data, "Custom themes should be saved")

        if let data = data {
            let decoder = JSONDecoder()
            let customThemes = try? decoder.decode([Theme].self, from: data)
            XCTAssertNotNil(customThemes, "Custom themes should be decodable")
            XCTAssertTrue(customThemes?.contains { $0.id == "persist_test" } ?? false,
                         "Custom theme should be in saved data")
        }
    }

    // MARK: - Update Custom Theme Tests

    func testThemeManagerUpdateCustomTheme() {
        // Arrange
        let originalTheme = TestDataFactory.createTestTheme(id: "update_test", name: "Original")
        manager.addCustomTheme(originalTheme)

        var updatedTheme = originalTheme
        updatedTheme.name = "Updated"

        // Act
        let success = manager.updateCustomTheme(updatedTheme)

        // Assert
        XCTAssertTrue(success, "Update should succeed")
        let theme = manager.availableThemes.first { $0.id == "update_test" }
        XCTAssertEqual(theme?.name, "Updated", "Theme name should be updated")
    }

    func testThemeManagerUpdateBuiltInThemeFails() {
        // Arrange
        var defaultTheme = Theme.default
        defaultTheme.name = "Modified Default"

        // Act
        let success = manager.updateCustomTheme(defaultTheme)

        // Assert
        XCTAssertFalse(success, "Updating built-in theme should fail")
    }

    func testThemeManagerUpdateCurrentThemePostsNotification() {
        // Arrange
        let customTheme = TestDataFactory.createTestTheme(id: "current_update", name: "Current")
        manager.addCustomTheme(customTheme)
        manager.setTheme(id: "current_update")

        var updatedTheme = customTheme
        updatedTheme.name = "Updated Current"

        let expectation = XCTestExpectation(description: "Theme change notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Act
        manager.updateCustomTheme(updatedTheme)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testThemeManagerUpdateNonExistentTheme() {
        // Arrange
        let theme = TestDataFactory.createTestTheme(id: "nonexistent", name: "Does Not Exist")

        // Act
        let success = manager.updateCustomTheme(theme)

        // Assert
        XCTAssertFalse(success, "Updating nonexistent theme should fail")
    }

    // MARK: - Delete Custom Theme Tests

    func testThemeManagerDeleteCustomTheme() {
        // Arrange
        let customTheme = TestDataFactory.createTestTheme(id: "delete_test", name: "Delete Me")
        manager.addCustomTheme(customTheme)

        // Act
        let success = manager.deleteCustomTheme(id: "delete_test")

        // Assert
        XCTAssertTrue(success, "Deletion should succeed")
        XCTAssertFalse(manager.availableThemes.contains { $0.id == "delete_test" },
                      "Theme should be removed from available themes")
    }

    func testThemeManagerDeleteBuiltInThemeFails() {
        // Act
        let success = manager.deleteCustomTheme(id: "default")

        // Assert
        XCTAssertFalse(success, "Deleting built-in theme should fail")
        XCTAssertTrue(manager.availableThemes.contains { $0.id == "default" },
                     "Built-in theme should still exist")
    }

    func testThemeManagerDeleteCurrentThemeSwitchesToDefault() {
        // Arrange
        let customTheme = TestDataFactory.createTestTheme(id: "current_delete", name: "Current")
        manager.addCustomTheme(customTheme)
        manager.setTheme(id: "current_delete")

        // Act
        manager.deleteCustomTheme(id: "current_delete")

        // Assert
        XCTAssertEqual(manager.currentTheme.id, "default", "Should switch to default theme")
    }

    func testThemeManagerDeleteNonExistentTheme() {
        // Act
        let success = manager.deleteCustomTheme(id: "nonexistent")

        // Assert
        XCTAssertFalse(success, "Deleting nonexistent theme should fail")
    }

    // MARK: - Available Themes Tests

    func testThemeManagerAvailableThemesIncludesBuiltIn() {
        // Assert
        let builtInThemes = manager.availableThemes.filter { $0.isBuiltIn }
        XCTAssertGreaterThan(builtInThemes.count, 0, "Should have built-in themes")
    }

    func testThemeManagerAvailableThemesIncludesCustom() {
        // Arrange
        let customTheme = TestDataFactory.createTestTheme(id: "available_test", name: "Available")
        manager.addCustomTheme(customTheme)

        // Assert
        let customThemes = manager.availableThemes.filter { !$0.isBuiltIn }
        XCTAssertGreaterThan(customThemes.count, 0, "Should have custom themes")
        XCTAssertTrue(customThemes.contains { $0.id == "available_test" },
                     "Should include the added custom theme")
    }

    // MARK: - UIColor Extension Tests

    func testUIColorHexStringConversion() {
        // Arrange
        let red = UIColor.red

        // Act
        let hexString = red.hexString

        // Assert
        XCTAssertEqual(hexString.uppercased(), "#FF0000", "Red should convert to #FF0000")
    }

    func testUIColorInitWithHexString() {
        // Act
        let red = UIColor(hex: "#FF0000")
        let green = UIColor(hex: "#00FF00")
        let blue = UIColor(hex: "#0000FF")

        // Assert
        XCTAssertNotNil(red, "Should create red color from hex")
        XCTAssertNotNil(green, "Should create green color from hex")
        XCTAssertNotNil(blue, "Should create blue color from hex")
    }

    func testUIColorInitWithHexStringWithoutHash() {
        // Act
        let color = UIColor(hex: "FF0000")

        // Assert
        XCTAssertNotNil(color, "Should create color from hex without #")
    }

    func testUIColorInitWithInvalidHexString() {
        // Act
        let color = UIColor(hex: "invalid")

        // Assert
        XCTAssertNil(color, "Should return nil for invalid hex string")
    }

    func testUIColorHexRoundTrip() {
        // Arrange
        let originalColor = UIColor(red: 0.5, green: 0.7, blue: 0.3, alpha: 1.0)

        // Act
        let hexString = originalColor.hexString
        let recreatedColor = UIColor(hex: hexString)

        // Assert
        XCTAssertNotNil(recreatedColor, "Should recreate color from hex string")

        // Extract RGB components
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        originalColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        recreatedColor?.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        // Allow small differences due to rounding
        XCTAssertEqual(r1, r2, accuracy: 0.01, "Red component should match")
        XCTAssertEqual(g1, g2, accuracy: 0.01, "Green component should match")
        XCTAssertEqual(b1, b2, accuracy: 0.01, "Blue component should match")
    }

    func testUIColorIsGreenish() {
        // Arrange
        let green = UIColor.green
        let red = UIColor.red
        let greenish = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)

        // Assert
        XCTAssertTrue(green.isGreenish(), "Pure green should be greenish")
        XCTAssertFalse(red.isGreenish(), "Red should not be greenish")
        XCTAssertTrue(greenish.isGreenish(), "Greenish color should be detected")
    }

    // MARK: - ColorSet Tests

    func testColorSetLightModeColor() {
        // Arrange
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")
        let lightTrait = UITraitCollection(userInterfaceStyle: .light)

        // Act
        let color = colorSet.color(for: lightTrait)

        // Assert
        XCTAssertEqual(color.hexString.uppercased(), "#FFFFFF", "Should return light color in light mode")
    }

    func testColorSetDarkModeColor() {
        // Arrange
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)

        // Act
        let color = colorSet.color(for: darkTrait)

        // Assert
        XCTAssertEqual(color, UIColor.black, "Should return dark color in dark mode")
    }

    func testColorSetOLEDBlackSpecialCase() {
        // Arrange
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)

        // Act
        let color = colorSet.color(for: darkTrait)

        // Assert
        XCTAssertEqual(color, UIColor.black, "Should return true black for OLED")
    }

    // MARK: - Theme Equality Tests

    func testThemeEquality() {
        // Arrange
        let theme1 = TestDataFactory.createTestTheme(id: "test1", name: "Test 1")
        let theme2 = TestDataFactory.createTestTheme(id: "test1", name: "Test 1")

        // Assert
        XCTAssertEqual(theme1, theme2, "Themes with same properties should be equal")
    }

    func testThemeInequality() {
        // Arrange
        let theme1 = TestDataFactory.createTestTheme(id: "test1", name: "Test 1")
        let theme2 = TestDataFactory.createTestTheme(id: "test2", name: "Test 2")

        // Assert
        XCTAssertNotEqual(theme1, theme2, "Themes with different IDs should not be equal")
    }

    // MARK: - Theme Codable Tests

    func testThemeCodable() {
        // Arrange
        let theme = TestDataFactory.createTestTheme()

        // Act & Assert
        XCTAssertCodable(theme)
    }

    func testColorSetCodable() {
        // Arrange
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")

        // Act & Assert
        XCTAssertCodable(colorSet)
    }

    // MARK: - Edge Cases

    func testThemeManagerManyCustomThemes() {
        // Arrange
        let themes = (1...50).map {
            TestDataFactory.createTestTheme(id: "theme\($0)", name: "Theme \($0)")
        }

        // Act
        themes.forEach { manager.addCustomTheme($0) }

        // Assert
        let customThemes = manager.availableThemes.filter { !$0.isBuiltIn }
        XCTAssertEqual(customThemes.count, 50, "Should handle many custom themes")
    }

    func testThemeManagerThemeWithSpecialCharacters() {
        // Arrange
        let theme = TestDataFactory.createTestTheme(
            id: "special_chars",
            name: "Theme with @#$%^&*() chars"
        )

        // Act
        manager.addCustomTheme(theme)

        // Assert
        let savedTheme = manager.availableThemes.first { $0.id == "special_chars" }
        XCTAssertEqual(savedTheme?.name, "Theme with @#$%^&*() chars",
                      "Special characters should be preserved")
    }

    func testThemeManagerThemeWithUnicode() {
        // Arrange
        let theme = TestDataFactory.createTestTheme(
            id: "unicode_test",
            name: "テーマ 주제 🎨"
        )

        // Act
        manager.addCustomTheme(theme)

        // Assert
        let savedTheme = manager.availableThemes.first { $0.id == "unicode_test" }
        XCTAssertEqual(savedTheme?.name, "テーマ 주제 🎨",
                      "Unicode characters should be preserved")
    }
}
