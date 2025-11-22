//
//  ThemeManagerTests.swift
//  ChannerTests
//
//  Created for unit testing
//

import XCTest
import UIKit
@testable import Channer

class ThemeManagerTests: XCTestCase {

    var sut: ThemeManager!
    var mockUserDefaults: MockUserDefaults!

    override func setUp() {
        super.setUp()

        mockUserDefaults = MockUserDefaults()
        sut = ThemeManager.shared

        // Reset to default theme
        sut.setTheme(id: "default")
    }

    override func tearDown() {
        mockUserDefaults.reset()
        sut.setTheme(id: "default")
        sut = nil
        super.tearDown()
    }

    // MARK: - Theme Selection Tests

    func testDefaultThemeIsSet() {
        // When
        let theme = sut.currentTheme

        // Then
        XCTAssertEqual(theme.id, "default")
        XCTAssertEqual(theme.name, "Default")
        XCTAssertTrue(theme.isBuiltIn)
    }

    func testSetThemeByID() {
        // Given
        let themeId = "oled"

        print("DEBUG: Available themes before setting:")
        for theme in sut.availableThemes {
            print("  - \(theme.id): \(theme.name)")
        }

        // When
        print("DEBUG: Setting theme to: \(themeId)")
        sut.setTheme(id: themeId)

        print("DEBUG: Current theme after setting: \(sut.currentTheme.id) - \(sut.currentTheme.name)")

        // Then
        XCTAssertEqual(sut.currentTheme.id, themeId)
        XCTAssertEqual(sut.currentTheme.name, "OLED")
    }

    func testSetThemeUpdatesCurrentTheme() {
        // When
        sut.setTheme(id: "sepia")

        // Then
        XCTAssertEqual(sut.currentTheme.id, "sepia")
    }

    func testSetInvalidThemeDoesNothing() {
        // Given
        let initialTheme = sut.currentTheme

        // When
        sut.setTheme(id: "invalid_theme_id")

        // Then
        XCTAssertEqual(sut.currentTheme.id, initialTheme.id)
    }

    func testSetThemePostsNotification() {
        // Given
        let expectation = TestHelpers.waitForNotification(.themeDidChange, testCase: self)

        // When
        sut.setTheme(id: "oled")

        // Then
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Built-in Themes Tests

    func testDefaultThemeExists() {
        // When
        let themes = sut.availableThemes

        // Then
        XCTAssertTrue(themes.contains(where: { $0.id == "default" }))
    }

    func testOLEDThemeExists() {
        // When
        let themes = sut.availableThemes

        // Then
        XCTAssertTrue(themes.contains(where: { $0.id == "oled" }))
    }

    func testAllBuiltInThemesAreAvailable() {
        // Given - Expected built-in themes
        let expectedThemes = ["default", "oled", "sepia", "dark_purple", "sunset_orange", "mint_green"]

        // When
        let availableThemes = sut.availableThemes

        // Then
        for expectedId in expectedThemes {
            XCTAssertTrue(availableThemes.contains(where: { $0.id == expectedId }),
                         "Missing built-in theme: \(expectedId)")
        }
    }

    // MARK: - Custom Theme Tests

    func testAddCustomTheme() {
        // Given
        let customTheme = TestData.sampleTheme(id: "custom-test", name: "Test Theme", isBuiltIn: false)

        // When
        let success = sut.addCustomTheme(customTheme)

        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(sut.availableThemes.contains(where: { $0.id == "custom-test" }))
    }

    func testAddDuplicateCustomThemeFails() {
        // Given
        let customTheme = TestData.sampleTheme(id: "custom-test", name: "Test Theme", isBuiltIn: false)
        _ = sut.addCustomTheme(customTheme)

        // When
        let success = sut.addCustomTheme(customTheme)

        // Then
        XCTAssertFalse(success)
    }

    func testUpdateCustomTheme() {
        // Given
        var customTheme = TestData.sampleTheme(id: "custom-test", name: "Original", isBuiltIn: false)
        _ = sut.addCustomTheme(customTheme)

        // When
        customTheme.name = "Updated"
        let success = sut.updateCustomTheme(customTheme)

        // Then
        XCTAssertTrue(success)
        let updated = sut.availableThemes.first(where: { $0.id == "custom-test" })
        XCTAssertEqual(updated?.name, "Updated")
    }

    func testUpdateBuiltInThemeFails() {
        // Given
        var builtInTheme = Theme.default
        builtInTheme.name = "Modified Default"

        // When
        let success = sut.updateCustomTheme(builtInTheme)

        // Then
        XCTAssertFalse(success)
    }

    func testUpdateNonExistentThemeFails() {
        // Given
        let nonExistent = TestData.sampleTheme(id: "non-existent", name: "Does Not Exist", isBuiltIn: false)

        // When
        let success = sut.updateCustomTheme(nonExistent)

        // Then
        XCTAssertFalse(success)
    }

    func testDeleteCustomTheme() {
        // Given
        let customTheme = TestData.sampleTheme(id: "custom-delete", name: "To Delete", isBuiltIn: false)
        _ = sut.addCustomTheme(customTheme)
        XCTAssertTrue(sut.availableThemes.contains(where: { $0.id == "custom-delete" }))

        // When
        let success = sut.deleteCustomTheme(id: "custom-delete")

        // Then
        XCTAssertTrue(success)
        XCTAssertFalse(sut.availableThemes.contains(where: { $0.id == "custom-delete" }))
    }

    func testDeleteBuiltInThemeFails() {
        // When
        let success = sut.deleteCustomTheme(id: "default")

        // Then
        XCTAssertFalse(success)
        XCTAssertTrue(sut.availableThemes.contains(where: { $0.id == "default" }))
    }

    func testDeleteCurrentThemeSwitchesToDefault() {
        // Given
        let customTheme = TestData.sampleTheme(id: "custom-current", name: "Current", isBuiltIn: false)
        _ = sut.addCustomTheme(customTheme)
        sut.setTheme(id: "custom-current")
        XCTAssertEqual(sut.currentTheme.id, "custom-current")

        // When
        let success = sut.deleteCustomTheme(id: "custom-current")

        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(sut.currentTheme.id, "default")
    }

    // MARK: - Theme Color Properties Tests

    func testBackgroundColorReturnsValidColor() {
        // When
        let color = sut.backgroundColor

        // Then
        XCTAssertNotNil(color)
    }

    func testPrimaryTextColorReturnsValidColor() {
        // When
        let color = sut.primaryTextColor

        // Then
        XCTAssertNotNil(color)
    }

    func testGreentextColorReturnsValidColor() {
        // When
        let color = sut.greentextColor

        // Then
        XCTAssertNotNil(color)
    }

    func testColorsUpdateAfterThemeChange() {
        // Given - Get the default theme's background color
        sut.setTheme(id: "default")
        let defaultTheme = sut.currentTheme

        // When - Switch to OLED theme
        sut.setTheme(id: "oled")
        let oledTheme = sut.currentTheme

        // Then - The theme's ColorSet values should be different
        // We test the dark mode colors since OLED and Default have different dark backgrounds
        print("DEBUG TEST: Default dark bg: \(defaultTheme.backgroundColor.dark)")
        print("DEBUG TEST: OLED dark bg: \(oledTheme.backgroundColor.dark)")

        XCTAssertNotEqual(defaultTheme.backgroundColor.dark, oledTheme.backgroundColor.dark,
                         "OLED theme should have different dark background than Default theme")

        // Also verify the themes are actually different
        XCTAssertNotEqual(defaultTheme.id, oledTheme.id)
        XCTAssertEqual(oledTheme.id, "oled")

        // Verify OLED has true black for dark mode
        XCTAssertEqual(oledTheme.backgroundColor.dark, "#000000")
    }

    func testDefaultThemeUsesResolvedSystemColors() {
        let lightTrait = UITraitCollection(userInterfaceStyle: .light)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)
        let theme = Theme.default

        XCTAssertEqual(theme.backgroundColor.light, UIColor.systemBackground.resolvedColor(with: lightTrait).hexString)
        XCTAssertEqual(theme.secondaryBackgroundColor.light, UIColor.secondarySystemBackground.resolvedColor(with: lightTrait).hexString)
        XCTAssertEqual(theme.alertColor.light, UIColor.systemRed.resolvedColor(with: lightTrait).hexString)
        XCTAssertEqual(theme.alertColor.dark, UIColor.systemRed.resolvedColor(with: darkTrait).hexString)
    }

    // MARK: - ColorSet Tests

    func testColorSetLightModeColor() {
        // Given
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")
        let lightTraitCollection = UITraitCollection(userInterfaceStyle: .light)

        // When
        let color = colorSet.color(for: lightTraitCollection)

        // Then
        XCTAssertEqual(color.hexString, "#FFFFFF")
    }

    func testColorSetDarkModeColor() {
        // Given
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")
        let darkTraitCollection = UITraitCollection(userInterfaceStyle: .dark)

        // When
        let color = colorSet.color(for: darkTraitCollection)

        // Then
        XCTAssertEqual(color.hexString, "#000000")
    }

    func testColorSetOLEDBlackSpecialCase() {
        // Given
        let colorSet = ColorSet(light: "#FFFFFF", dark: "#000000")
        let darkTraitCollection = UITraitCollection(userInterfaceStyle: .dark)

        // When
        let color = colorSet.color(for: darkTraitCollection)

        // Then
        XCTAssertEqual(color, UIColor.black) // True black for OLED
    }

    // MARK: - UIColor Extension Tests

    func testUIColorHexInitialization() {
        // When
        let color = UIColor(hex: "#FF0000")

        // Then
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.hexString, "#FF0000")
    }

    func testUIColorHexInitializationWithoutHash() {
        // When
        let color = UIColor(hex: "00FF00")

        // Then
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.hexString, "#00FF00")
    }

    func testUIColorInvalidHexReturnsNil() {
        // When
        let color = UIColor(hex: "invalid")

        // Then
        XCTAssertNil(color)
    }

    func testUIColorHexStringConversion() {
        // Given
        let red = UIColor.red

        // When
        let hexString = red.hexString

        // Then
        XCTAssertTrue(hexString.hasPrefix("#"))
        XCTAssertEqual(hexString.count, 7) // #RRGGBB
    }

    func testUIColorIsGreenish() {
        // Given
        let greenColor = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
        let redColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)

        // Then
        XCTAssertTrue(greenColor.isGreenish())
        XCTAssertFalse(redColor.isGreenish())
    }

    // MARK: - Theme Model Tests

    func testThemeEquality() {
        // Given
        let theme1 = TestData.defaultTheme()
        let theme2 = TestData.defaultTheme()

        // Then
        XCTAssertEqual(theme1, theme2)
    }

    func testThemeInequality() {
        // Given
        let theme1 = TestData.defaultTheme()
        let theme2 = TestData.oledTheme()

        // Then
        XCTAssertNotEqual(theme1, theme2)
    }

    func testThemeEncoding() {
        // Given
        let theme = TestData.sampleTheme()

        // When
        let encoded = try? JSONEncoder().encode(theme)

        // Then
        XCTAssertNotNil(encoded)
    }

    func testThemeDecoding() {
        // Given
        let theme = TestData.sampleTheme()
        let encoded = try! JSONEncoder().encode(theme)

        // When
        let decoded = try? JSONDecoder().decode(Theme.self, from: encoded)

        // Then
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.id, theme.id)
        XCTAssertEqual(decoded?.name, theme.name)
    }

    // MARK: - Persistence Tests

    func testCustomThemesPersistence() {
        // Given
        let customTheme = TestData.sampleTheme(id: "persist-test", name: "Persist", isBuiltIn: false)
        _ = sut.addCustomTheme(customTheme)

        // When - Simulate app restart
        // Note: In real app, would create new ThemeManager instance
        // Here we verify the theme is in availableThemes

        // Then
        XCTAssertTrue(sut.availableThemes.contains(where: { $0.id == "persist-test" }))
    }

    func testSelectedThemePersistence() {
        // Given
        sut.setTheme(id: "oled")

        // When - Simulate app restart
        // In real app: ThemeManager would load saved theme from UserDefaults

        // Then
        // Verify theme selection was persisted
        XCTAssertEqual(sut.currentTheme.id, "oled")
    }

    // MARK: - Edge Cases

    func testAddCustomThemeWithSameIDAsBuiltInFails() {
        // Given
        let fakeDefault = TestData.sampleTheme(id: "default", name: "Fake Default", isBuiltIn: false)

        // When
        let success = sut.addCustomTheme(fakeDefault)

        // Then
        XCTAssertFalse(success) // Should fail due to duplicate ID
    }

    func testMultipleCustomThemes() {
        // Given
        let themes = (1...10).map {
            TestData.sampleTheme(id: "custom-\($0)", name: "Custom \($0)", isBuiltIn: false)
        }

        // When
        themes.forEach { _ = sut.addCustomTheme($0) }

        // Then
        for theme in themes {
            XCTAssertTrue(sut.availableThemes.contains(where: { $0.id == theme.id }))
        }
    }

    // MARK: - Performance Tests

    func testThemeSwitchingPerformance() {
        measure {
            sut.setTheme(id: "oled")
            sut.setTheme(id: "default")
            sut.setTheme(id: "sepia")
        }
    }

    func testColorPropertyAccessPerformance() {
        measure {
            for _ in 0..<100 {
                _ = sut.backgroundColor
                _ = sut.primaryTextColor
                _ = sut.greentextColor
            }
        }
    }
}
