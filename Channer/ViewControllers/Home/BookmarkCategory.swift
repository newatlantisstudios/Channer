import Foundation

/// Represents a category for organizing bookmarked threads
struct BookmarkCategory: Codable {
    let id: String
    var name: String
    var color: String  // Hex color string
    var icon: String   // SF Symbol name
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, color: String = "#007AFF", icon: String = "folder") {
        self.id = UUID().uuidString
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

