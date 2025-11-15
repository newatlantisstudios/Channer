import UIKit

extension UIColor {
    // Helper method to determine if a color is "greenish"
    func isGreenish() -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Check if green component is dominant
        return green > red * 1.5 && green > blue * 1.5
    }
    
    // Convert UIColor to hex string
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
    
    // Initialize UIColor with hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

/// A pair of colors for light and dark mode
struct ColorSet: Codable, Equatable {
    var light: String
    var dark: String
    
    /// Get the appropriate UIColor based on the current trait collection
    func color(for traitCollection: UITraitCollection) -> UIColor {
        // Special case for OLED black to ensure true black in dark mode
        if dark == "#000000" && traitCollection.userInterfaceStyle == .dark {
            return UIColor.black
        }
        
        let hexString = traitCollection.userInterfaceStyle == .dark ? dark : light
        return UIColor(hex: hexString) ?? .black
    }
}

/// Represents a theme with a set of colors and settings that can be applied to the app
struct Theme: Codable, Equatable {
    // Theme metadata
    var id: String
    var name: String
    var isBuiltIn: Bool
    
    // Background Colors
    var backgroundColor: ColorSet
    var secondaryBackgroundColor: ColorSet
    
    // Cell Colors
    var cellBackgroundColor: ColorSet
    var cellBorderColor: ColorSet
    
    // Text Colors
    var primaryTextColor: ColorSet
    var secondaryTextColor: ColorSet
    var greentextColor: ColorSet
    
    // Alert Color
    var alertColor: ColorSet
    
    // Spoiler Colors
    var spoilerTextColor: ColorSet
    var spoilerBackgroundColor: ColorSet
    
    /// Creates a default theme with the app's original colors
    static var `default`: Theme {
        return Theme(
            id: "default",
            name: "Default",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor.systemBackground.hexString,
                dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor.secondarySystemBackground.hexString,
                dark: UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0).hexString
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0).hexString,
                dark: UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0).hexString
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0).hexString,
                dark: UIColor(red: 0.25, green: 0.52, blue: 0.28, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor.darkGray.hexString,
                dark: UIColor.lightGray.hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0).hexString,
                dark: UIColor(red: 140/255, green: 183/255, blue: 54/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor.systemRed.hexString,
                dark: UIColor.systemRed.hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.darkGray.hexString
            )
        )
    }
    
    /// Creates a night blue themed color scheme
    static var nightBlue: Theme {
        return Theme(
            id: "night_blue",
            name: "Night Blue",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor(red: 240/255, green: 245/255, blue: 255/255, alpha: 1.0).hexString,
                dark: UIColor(red: 16/255, green: 32/255, blue: 58/255, alpha: 1.0).hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor(red: 230/255, green: 240/255, blue: 255/255, alpha: 1.0).hexString,
                dark: UIColor(red: 25/255, green: 45/255, blue: 70/255, alpha: 1.0).hexString
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 220/255, green: 235/255, blue: 255/255, alpha: 1.0).hexString,
                dark: UIColor(red: 35/255, green: 55/255, blue: 80/255, alpha: 1.0).hexString
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 100/255, green: 149/255, blue: 237/255, alpha: 1.0).hexString, 
                dark: UIColor(red: 65/255, green: 105/255, blue: 225/255, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor(red: 25/255, green: 45/255, blue: 75/255, alpha: 1.0).hexString,
                dark: UIColor(red: 240/255, green: 248/255, blue: 255/255, alpha: 1.0).hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor(red: 65/255, green: 90/255, blue: 140/255, alpha: 1.0).hexString,
                dark: UIColor(red: 180/255, green: 200/255, blue: 220/255, alpha: 1.0).hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 76/255, green: 154/255, blue: 42/255, alpha: 1.0).hexString,
                dark: UIColor(red: 102/255, green: 187/255, blue: 106/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0).hexString,
                dark: UIColor(red: 253/255, green: 92/255, blue: 99/255, alpha: 1.0).hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor(red: 50/255, green: 80/255, blue: 140/255, alpha: 1.0).hexString,
                dark: UIColor(red: 30/255, green: 60/255, blue: 90/255, alpha: 1.0).hexString
            )
        )
    }
    
    /// Creates a sepia themed color scheme
    static var sepia: Theme {
        return Theme(
            id: "sepia",
            name: "Sepia",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor(red: 249/255, green: 240/255, blue: 219/255, alpha: 1.0).hexString,
                dark: UIColor(red: 50/255, green: 40/255, blue: 32/255, alpha: 1.0).hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor(red: 242/255, green: 232/255, blue: 212/255, alpha: 1.0).hexString,
                dark: UIColor(red: 60/255, green: 48/255, blue: 38/255, alpha: 1.0).hexString
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 235/255, green: 224/255, blue: 200/255, alpha: 1.0).hexString,
                dark: UIColor(red: 76/255, green: 61/255, blue: 51/255, alpha: 1.0).hexString
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 160/255, green: 120/255, blue: 80/255, alpha: 1.0).hexString,
                dark: UIColor(red: 180/255, green: 140/255, blue: 100/255, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor(red: 55/255, green: 40/255, blue: 30/255, alpha: 1.0).hexString,
                dark: UIColor(red: 234/255, green: 225/255, blue: 210/255, alpha: 1.0).hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor(red: 120/255, green: 100/255, blue: 80/255, alpha: 1.0).hexString,
                dark: UIColor(red: 195/255, green: 180/255, blue: 165/255, alpha: 1.0).hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 90/255, green: 120/255, blue: 40/255, alpha: 1.0).hexString,
                dark: UIColor(red: 130/255, green: 170/255, blue: 60/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor(red: 180/255, green: 70/255, blue: 60/255, alpha: 1.0).hexString,
                dark: UIColor(red: 220/255, green: 100/255, blue: 80/255, alpha: 1.0).hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor(red: 120/255, green: 100/255, blue: 80/255, alpha: 1.0).hexString,
                dark: UIColor(red: 90/255, green: 75/255, blue: 60/255, alpha: 1.0).hexString
            )
        )
    }
    
    
    /// Creates a dark purple theme
    static var darkPurple: Theme {
        return Theme(
            id: "dark_purple",
            name: "Dark Purple",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor(red: 245/255, green: 240/255, blue: 255/255, alpha: 1.0).hexString,
                dark: UIColor(red: 30/255, green: 20/255, blue: 40/255, alpha: 1.0).hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor(red: 235/255, green: 230/255, blue: 250/255, alpha: 1.0).hexString,
                dark: UIColor(red: 45/255, green: 35/255, blue: 60/255, alpha: 1.0).hexString
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 240/255, green: 235/255, blue: 255/255, alpha: 1.0).hexString,
                dark: UIColor(red: 55/255, green: 40/255, blue: 75/255, alpha: 1.0).hexString
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 130/255, green: 80/255, blue: 180/255, alpha: 1.0).hexString,
                dark: UIColor(red: 150/255, green: 100/255, blue: 200/255, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor(red: 60/255, green: 30/255, blue: 90/255, alpha: 1.0).hexString,
                dark: UIColor(red: 230/255, green: 220/255, blue: 250/255, alpha: 1.0).hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor(red: 100/255, green: 70/255, blue: 130/255, alpha: 1.0).hexString,
                dark: UIColor(red: 190/255, green: 170/255, blue: 220/255, alpha: 1.0).hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 85/255, green: 160/255, blue: 80/255, alpha: 1.0).hexString,
                dark: UIColor(red: 120/255, green: 200/255, blue: 110/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor(red: 220/255, green: 60/255, blue: 90/255, alpha: 1.0).hexString,
                dark: UIColor(red: 255/255, green: 80/255, blue: 120/255, alpha: 1.0).hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor(red: 130/255, green: 80/255, blue: 180/255, alpha: 1.0).hexString,
                dark: UIColor(red: 100/255, green: 60/255, blue: 140/255, alpha: 1.0).hexString
            )
        )
    }
    
    /// Creates a sunset orange theme
    static var sunsetOrange: Theme {
        return Theme(
            id: "sunset_orange",
            name: "Sunset Orange",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor(red: 255/255, green: 250/255, blue: 245/255, alpha: 1.0).hexString,
                dark: UIColor(red: 40/255, green: 25/255, blue: 20/255, alpha: 1.0).hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor(red: 252/255, green: 242/255, blue: 235/255, alpha: 1.0).hexString,
                dark: UIColor(red: 50/255, green: 35/255, blue: 30/255, alpha: 1.0).hexString
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 255/255, green: 245/255, blue: 235/255, alpha: 1.0).hexString,
                dark: UIColor(red: 60/255, green: 40/255, blue: 35/255, alpha: 1.0).hexString
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 240/255, green: 140/255, blue: 70/255, alpha: 1.0).hexString,
                dark: UIColor(red: 250/255, green: 160/255, blue: 80/255, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor(red: 60/255, green: 40/255, blue: 30/255, alpha: 1.0).hexString,
                dark: UIColor(red: 255/255, green: 240/255, blue: 230/255, alpha: 1.0).hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor(red: 180/255, green: 100/255, blue: 60/255, alpha: 1.0).hexString,
                dark: UIColor(red: 240/255, green: 160/255, blue: 120/255, alpha: 1.0).hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 80/255, green: 140/255, blue: 40/255, alpha: 1.0).hexString,
                dark: UIColor(red: 120/255, green: 180/255, blue: 80/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor(red: 220/255, green: 60/255, blue: 60/255, alpha: 1.0).hexString,
                dark: UIColor(red: 255/255, green: 90/255, blue: 90/255, alpha: 1.0).hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor(red: 220/255, green: 120/255, blue: 60/255, alpha: 1.0).hexString,
                dark: UIColor(red: 160/255, green: 90/255, blue: 45/255, alpha: 1.0).hexString
            )
        )
    }
    
    /// Creates a mint green theme
    static var mintGreen: Theme {
        return Theme(
            id: "mint_green",
            name: "Mint Green",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor(red: 240/255, green: 255/255, blue: 250/255, alpha: 1.0).hexString,
                dark: UIColor(red: 20/255, green: 40/255, blue: 35/255, alpha: 1.0).hexString
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor(red: 230/255, green: 250/255, blue: 245/255, alpha: 1.0).hexString,
                dark: UIColor(red: 30/255, green: 50/255, blue: 45/255, alpha: 1.0).hexString
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 235/255, green: 255/255, blue: 245/255, alpha: 1.0).hexString,
                dark: UIColor(red: 35/255, green: 60/255, blue: 55/255, alpha: 1.0).hexString
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 80/255, green: 200/255, blue: 160/255, alpha: 1.0).hexString,
                dark: UIColor(red: 100/255, green: 220/255, blue: 180/255, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor(red: 30/255, green: 80/255, blue: 70/255, alpha: 1.0).hexString,
                dark: UIColor(red: 220/255, green: 255/255, blue: 240/255, alpha: 1.0).hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor(red: 60/255, green: 130/255, blue: 120/255, alpha: 1.0).hexString,
                dark: UIColor(red: 160/255, green: 220/255, blue: 200/255, alpha: 1.0).hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 40/255, green: 150/255, blue: 90/255, alpha: 1.0).hexString,
                dark: UIColor(red: 90/255, green: 200/255, blue: 140/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor(red: 220/255, green: 70/255, blue: 90/255, alpha: 1.0).hexString,
                dark: UIColor(red: 255/255, green: 90/255, blue: 110/255, alpha: 1.0).hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor(red: 80/255, green: 170/255, blue: 150/255, alpha: 1.0).hexString,
                dark: UIColor(red: 60/255, green: 130/255, blue: 120/255, alpha: 1.0).hexString
            )
        )
    }

    /// Creates an OLED black theme optimized for OLED displays
    static var oled: Theme {
        return Theme(
            id: "oled",
            name: "OLED",
            isBuiltIn: true,
            backgroundColor: ColorSet(
                light: UIColor.systemBackground.hexString,
                dark: "#000000" // True black for OLED
            ),
            secondaryBackgroundColor: ColorSet(
                light: UIColor.secondarySystemBackground.hexString,
                dark: "#0A0A0A" // Near black
            ),
            cellBackgroundColor: ColorSet(
                light: UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0).hexString,
                dark: "#1A1A1A" // Dark gray
            ),
            cellBorderColor: ColorSet(
                light: UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0).hexString,
                dark: UIColor(red: 0.25, green: 0.52, blue: 0.28, alpha: 1.0).hexString
            ),
            primaryTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            secondaryTextColor: ColorSet(
                light: UIColor.darkGray.hexString,
                dark: UIColor.lightGray.hexString
            ),
            greentextColor: ColorSet(
                light: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0).hexString,
                dark: UIColor(red: 140/255, green: 183/255, blue: 54/255, alpha: 1.0).hexString
            ),
            alertColor: ColorSet(
                light: UIColor.systemRed.hexString,
                dark: UIColor.systemRed.hexString
            ),
            spoilerTextColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.white.hexString
            ),
            spoilerBackgroundColor: ColorSet(
                light: UIColor.black.hexString,
                dark: UIColor.darkGray.hexString
            )
        )
    }
}

// MARK: - Theme Manager
/// A singleton class that manages the theme colors for the app.
class ThemeManager {
    // MARK: - Singleton Instance
    static let shared = ThemeManager()
    
    // MARK: - Properties
    private let themeKey = "channer_selected_theme_id"
    private let customThemesKey = "channer_custom_themes"
    
    /// All available themes (built-in and custom)
    private(set) var availableThemes: [Theme] = []
    
    /// The currently active theme
    private(set) var currentTheme: Theme
    
    // MARK: - Color Properties (with theme support)
    
    // Background Colors
    var backgroundColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.backgroundColor.color(for: traitCollection)
        }
    }
    
    var secondaryBackgroundColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.secondaryBackgroundColor.color(for: traitCollection)
        }
    }
    
    // Cell Background Colors
    var cellBackgroundColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.cellBackgroundColor.color(for: traitCollection)
        }
    }
    
    var cellBorderColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.cellBorderColor.color(for: traitCollection)
        }
    }
    
    // Text Colors
    var primaryTextColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.primaryTextColor.color(for: traitCollection)
        }
    }
    
    var secondaryTextColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.secondaryTextColor.color(for: traitCollection)
        }
    }
    
    // Special Text Colors
    var greentextColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.greentextColor.color(for: traitCollection)
        }
    }
    
    var alertColor: UIColor {
        return UIColor { traitCollection in
            return self.currentTheme.alertColor.color(for: traitCollection)
        }
    }
    
    // MARK: - Initializer
    private init() {
        // Initialize currentTheme with a default value
        currentTheme = Theme.default
        
        // Load built-in themes
        let builtInThemes = [
            Theme.default,
            Theme.oled,
            Theme.nightBlue,
            Theme.sepia,
            Theme.darkPurple,
            Theme.sunsetOrange,
            Theme.mintGreen
        ]
        
        // Initialize availableThemes with just built-in themes first
        availableThemes = builtInThemes
        
        // Load custom themes
        let customThemes = loadCustomThemes()
        
        // Combine all themes
        availableThemes = builtInThemes + customThemes
        
        // Load saved theme or use default
        let savedThemeId = UserDefaults.standard.string(forKey: themeKey) ?? "default"
        if let savedTheme = availableThemes.first(where: { $0.id == savedThemeId }) {
            currentTheme = savedTheme
        }
    }
    
    // MARK: - Theme Management
    
    /// Set the active theme by ID and save the selection
    func setTheme(id: String) {
        print("DEBUG ThemeManager: setTheme called with id: \(id)")
        print("DEBUG ThemeManager: Available themes count: \(availableThemes.count)")

        guard let theme = availableThemes.first(where: { $0.id == id }) else {
            print("DEBUG ThemeManager: Theme not found with id: \(id)")
            return
        }

        print("DEBUG ThemeManager: Found theme: \(theme.name) (id: \(theme.id))")
        currentTheme = theme
        UserDefaults.standard.set(id, forKey: themeKey)

        // Force recreate all theme colors
        refreshThemeColors()

        // Post notification for UI updates
        NotificationCenter.default.post(name: .themeDidChange, object: nil)

        print("DEBUG ThemeManager: Current theme set to: \(currentTheme.name) (id: \(currentTheme.id))")
    }
    
    /// Refreshes all theme color objects to ensure they're using the current theme
    private func refreshThemeColors() {
        // This forces all the computed properties to be reevaluated
        // which will create new UIColor objects with the current theme values
        _ = backgroundColor
        _ = secondaryBackgroundColor
        _ = cellBackgroundColor
        _ = cellBorderColor
        _ = primaryTextColor
        _ = secondaryTextColor
        _ = greentextColor
        _ = alertColor
    }
    
    /// Add a new custom theme
    @discardableResult
    func addCustomTheme(_ theme: Theme) -> Bool {
        // Check if a theme with the same ID already exists
        if availableThemes.contains(where: { $0.id == theme.id }) {
            return false
        }
        
        // Add to available themes
        availableThemes.append(theme)
        
        // Save to user defaults
        saveCustomThemes()
        return true
    }
    
    /// Update an existing custom theme
    @discardableResult
    func updateCustomTheme(_ theme: Theme) -> Bool {
        // Can only update custom themes
        guard !theme.isBuiltIn else { return false }
        
        // Find and update the theme
        if let index = availableThemes.firstIndex(where: { $0.id == theme.id }) {
            availableThemes[index] = theme
            
            // If the current theme was updated, use the updated version
            if currentTheme.id == theme.id {
                currentTheme = theme
                NotificationCenter.default.post(name: .themeDidChange, object: nil)
            }
            
            // Save to user defaults
            saveCustomThemes()
            return true
        }
        return false
    }
    
    /// Delete a custom theme
    @discardableResult
    func deleteCustomTheme(id: String) -> Bool {
        // Make sure it's not a built-in theme
        guard let themeIndex = availableThemes.firstIndex(where: { $0.id == id }),
              !availableThemes[themeIndex].isBuiltIn else {
            return false
        }
        
        // If it's the current theme, switch to default
        if currentTheme.id == id {
            setTheme(id: "default")
        }
        
        // Remove the theme
        availableThemes.remove(at: themeIndex)
        
        // Save to user defaults
        saveCustomThemes()
        return true
    }
    
    // MARK: - Helper Methods
    
    /// Save custom themes to UserDefaults
    private func saveCustomThemes() {
        let customThemes = availableThemes.filter { !$0.isBuiltIn }
        
        if let encodedData = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(encodedData, forKey: customThemesKey)
        }
    }
    
    /// Load custom themes from UserDefaults
    private func loadCustomThemes() -> [Theme] {
        guard let encodedData = UserDefaults.standard.data(forKey: customThemesKey),
              let decodedThemes = try? JSONDecoder().decode([Theme].self, from: encodedData) else {
            return []
        }
        return decodedThemes
    }
    
    // MARK: - Methods for Spoiler Support
    func getSpoilerAttributes(fontSize: CGFloat = 14.0) -> [NSAttributedString.Key: Any] {
        return [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor { traitCollection in
                return self.currentTheme.spoilerTextColor.color(for: traitCollection)
            },
            .backgroundColor: UIColor { traitCollection in
                return self.currentTheme.spoilerBackgroundColor.color(for: traitCollection)
            }
        ]
    }
    
    /// Generate a unique ID for a new custom theme
    func generateUniqueThemeId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "custom_\(timestamp)"
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChangeNotification")
}
