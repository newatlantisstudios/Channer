import Foundation
import SwiftyJSON

/// Represents information about a 4chan board
struct BoardInfo {
    /// The board's abbreviated code (e.g., "g", "pol", "b")
    let code: String
    /// The board's full display title
    let title: String
}

/// Manages fetching and caching of 4chan board information
/// Provides a centralized service for retrieving board lists and handles caching for offline access
class BoardsService {
    /// Shared singleton instance
    static let shared = BoardsService()
    
    /// Private initializer to ensure singleton pattern
    private init() {
        loadFromCache()
    }
    
    // MARK: - Properties
    
    /// URL endpoint for fetching board data from 4chan API
    private let boardsURL = URL(string: "https://a.4cdn.org/boards.json")!
    /// UserDefaults key for caching board data
    private let cachedBoardsKey = "channer_cached_boards_list"
    /// UserDefaults key for caching board fetch date
    private let cachedBoardsDateKey = "channer_cached_boards_list_date"
    
    /// Array of all available boards
    private(set) var boards: [BoardInfo] = []
    
    /// Array of board display names
    var boardNames: [String] { boards.map { $0.title } }
    /// Array of board abbreviations/codes
    var boardAbv: [String] { boards.map { $0.code } }
    
    // MARK: - Cache Management
    
    /// Loads board information from UserDefaults cache
    /// Called during initialization to restore previously fetched board data
    func loadFromCache() {
        let defaults = UserDefaults.standard
        if let cached = defaults.array(forKey: cachedBoardsKey) as? [[String: String]], !cached.isEmpty {
            var items: [BoardInfo] = []
            items.reserveCapacity(cached.count)
            for item in cached {
                if let code = item["board"], let title = item["title"], !code.isEmpty, !title.isEmpty {
                    items.append(BoardInfo(code: code, title: title))
                }
            }
            if !items.isEmpty {
                self.boards = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            }
        }
    }
    
    // MARK: - Network Operations
    
    /// Fetches the latest board list from 4chan API
    /// Updates the local boards array and caches the result
    /// - Parameter completion: Optional closure called when the fetch operation completes (success or failure)
    func fetchBoards(completion: (() -> Void)? = nil) {
        let task = URLSession.shared.dataTask(with: boardsURL) { [weak self] data, response, error in
            guard let self = self else { completion?(); return }
            if let error = error {
                print("BoardsService fetch error: \(error)")
                DispatchQueue.main.async { completion?() }
                return
            }
            guard let data = data else { DispatchQueue.main.async { completion?() }; return }
            do {
                let json = try JSON(data: data)
                let boardsArray = json["boards"].arrayValue
                var items: [BoardInfo] = []
                var cachePayload: [[String: String]] = []
                items.reserveCapacity(boardsArray.count)
                cachePayload.reserveCapacity(boardsArray.count)
                for entry in boardsArray {
                    let code = entry["board"].stringValue
                    let titleRaw = entry["title"].stringValue
                    let title = Self.decodeHTML(titleRaw)
                    if !code.isEmpty && !title.isEmpty {
                        items.append(BoardInfo(code: code, title: title))
                        cachePayload.append(["board": code, "title": title])
                    }
                }
                let sorted = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                DispatchQueue.main.async {
                    self.boards = sorted
                    // cache
                    UserDefaults.standard.set(cachePayload, forKey: self.cachedBoardsKey)
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.cachedBoardsDateKey)
                    completion?()
                }
            } catch {
                print("BoardsService parse error: \(error)")
                DispatchQueue.main.async { completion?() }
            }
        }
        task.resume()
    }
    
    // MARK: - Utility Methods
    
    /// Decodes HTML entities in board titles
    /// - Parameter string: HTML-encoded string
    /// - Returns: Decoded string with HTML entities resolved
    private static func decodeHTML(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attributed.string
        }
        return string
    }
}

