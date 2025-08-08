import Foundation
import SwiftyJSON

struct BoardInfo {
    let code: String
    let title: String
}

class BoardsService {
    static let shared = BoardsService()
    private init() {
        loadFromCache()
    }
    
    private let boardsURL = URL(string: "https://a.4cdn.org/boards.json")!
    private let cachedBoardsKey = "channer_cached_boards_list"
    private let cachedBoardsDateKey = "channer_cached_boards_list_date"
    
    private(set) var boards: [BoardInfo] = []
    
    var boardNames: [String] { boards.map { $0.title } }
    var boardAbv: [String] { boards.map { $0.code } }
    
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
                    UserDefaults.standard.synchronize()
                    completion?()
                }
            } catch {
                print("BoardsService parse error: \(error)")
                DispatchQueue.main.async { completion?() }
            }
        }
        task.resume()
    }
    
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

