import UIKit

// MARK: - Theme Manager
/// A singleton class that manages the theme colors for the app.
class ThemeManager {
    // MARK: - Singleton Instance
    static let shared = ThemeManager()
    
    // MARK: - Color Properties
    // These colors automatically adapt to light/dark mode
    
    // Background Colors
    var backgroundColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : 
                UIColor.systemBackground
        }
    }
    
    var secondaryBackgroundColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0) : 
                UIColor.secondarySystemBackground
        }
    }
    
    // Cell Background Colors
    var cellBackgroundColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0) : 
                UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0)
        }
    }
    
    var cellBorderColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor(red: 0.25, green: 0.52, blue: 0.28, alpha: 1.0) : 
                UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0)
        }
    }
    
    // Text Colors
    var primaryTextColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor.white : 
                UIColor.black
        }
    }
    
    var secondaryTextColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor.lightGray : 
                UIColor.darkGray
        }
    }
    
    // Special Text Colors
    var greentextColor: UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? 
                UIColor(red: 140/255, green: 183/255, blue: 54/255, alpha: 1.0) : 
                UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
        }
    }
    
    var alertColor: UIColor {
        return UIColor.systemRed
    }
    
    // MARK: - Initializer
    private init() {
        // Private initializer to enforce singleton pattern
    }
    
    // MARK: - Methods for Spoiler Support
    func getSpoilerAttributes(fontSize: CGFloat = 14.0) -> [NSAttributedString.Key: Any] {
        return [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? 
                    UIColor.white : 
                    UIColor.black
            },
            .backgroundColor: UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? 
                    UIColor.darkGray : 
                    UIColor.black
            }
        ]
    }
}
