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
        ensureBundledBoardsAvailable()
    }
    
    // MARK: - Properties
    
    /// URL endpoint for fetching board data from 4chan API
    private let boardsURL = URL(string: "https://a.4cdn.org/boards.json")!
    /// UserDefaults key for caching board data
    private let cachedBoardsKey = "channer_cached_boards_list"
    /// UserDefaults key for caching board fetch date
    private let cachedBoardsDateKey = "channer_cached_boards_list_date"
    /// Board metadata used when the live API is unavailable or TLS trust fails.
    private static let bundledBoards: [BoardInfo] = [
        BoardInfo(code: "3", title: "3DCG"),
        BoardInfo(code: "a", title: "Anime & Manga"),
        BoardInfo(code: "aco", title: "Adult Cartoons"),
        BoardInfo(code: "adv", title: "Advice"),
        BoardInfo(code: "an", title: "Animals & Nature"),
        BoardInfo(code: "b", title: "Random"),
        BoardInfo(code: "bant", title: "International/Random"),
        BoardInfo(code: "biz", title: "Business & Finance"),
        BoardInfo(code: "c", title: "Anime/Cute"),
        BoardInfo(code: "cgl", title: "Cosplay & EGL"),
        BoardInfo(code: "ck", title: "Food & Cooking"),
        BoardInfo(code: "cm", title: "Cute/Male"),
        BoardInfo(code: "co", title: "Comics & Cartoons"),
        BoardInfo(code: "diy", title: "Do-It-Yourself"),
        BoardInfo(code: "e", title: "Ecchi"),
        BoardInfo(code: "f", title: "Flash"),
        BoardInfo(code: "fa", title: "Fashion"),
        BoardInfo(code: "fit", title: "Fitness"),
        BoardInfo(code: "g", title: "Technology"),
        BoardInfo(code: "gd", title: "Graphic Design"),
        BoardInfo(code: "gif", title: "Adult GIF"),
        BoardInfo(code: "h", title: "Hentai"),
        BoardInfo(code: "hc", title: "Hardcore"),
        BoardInfo(code: "his", title: "History & Humanities"),
        BoardInfo(code: "hm", title: "Handsome Men"),
        BoardInfo(code: "hr", title: "High Resolution"),
        BoardInfo(code: "i", title: "Oekaki"),
        BoardInfo(code: "ic", title: "Artwork/Critique"),
        BoardInfo(code: "int", title: "International"),
        BoardInfo(code: "jp", title: "Otaku Culture"),
        BoardInfo(code: "k", title: "Weapons"),
        BoardInfo(code: "lgbt", title: "LGBT"),
        BoardInfo(code: "lit", title: "Literature"),
        BoardInfo(code: "m", title: "Mecha"),
        BoardInfo(code: "mlp", title: "Pony"),
        BoardInfo(code: "mu", title: "Music"),
        BoardInfo(code: "n", title: "Transportation"),
        BoardInfo(code: "news", title: "Current News"),
        BoardInfo(code: "o", title: "Auto"),
        BoardInfo(code: "out", title: "Outdoors"),
        BoardInfo(code: "p", title: "Photography"),
        BoardInfo(code: "po", title: "Papercraft & Origami"),
        BoardInfo(code: "pol", title: "Politically Incorrect"),
        BoardInfo(code: "pw", title: "Professional Wrestling"),
        BoardInfo(code: "qa", title: "Question & Answer"),
        BoardInfo(code: "qst", title: "Quests"),
        BoardInfo(code: "r", title: "Request"),
        BoardInfo(code: "r9k", title: "ROBOT9001"),
        BoardInfo(code: "s", title: "Sexy Beautiful Women"),
        BoardInfo(code: "sci", title: "Science & Math"),
        BoardInfo(code: "soc", title: "Cams & Meetups"),
        BoardInfo(code: "sp", title: "Sports"),
        BoardInfo(code: "t", title: "Torrents"),
        BoardInfo(code: "tg", title: "Traditional Games"),
        BoardInfo(code: "toy", title: "Toys"),
        BoardInfo(code: "trash", title: "Off-topic"),
        BoardInfo(code: "trv", title: "Travel"),
        BoardInfo(code: "tv", title: "Television & Film"),
        BoardInfo(code: "u", title: "Yuri"),
        BoardInfo(code: "v", title: "Video Games"),
        BoardInfo(code: "vg", title: "Video Game Generals"),
        BoardInfo(code: "vip", title: "Very Important Posts"),
        BoardInfo(code: "vm", title: "Video Games/Multiplayer"),
        BoardInfo(code: "vmg", title: "Video Games/Mobile"),
        BoardInfo(code: "vp", title: "Pokemon"),
        BoardInfo(code: "vr", title: "Retro Games"),
        BoardInfo(code: "vrpg", title: "Video Games/RPG"),
        BoardInfo(code: "vst", title: "Video Games/Strategy"),
        BoardInfo(code: "w", title: "Anime/Wallpapers"),
        BoardInfo(code: "wg", title: "Wallpapers/General"),
        BoardInfo(code: "wsg", title: "Worksafe GIF"),
        BoardInfo(code: "x", title: "Paranormal"),
        BoardInfo(code: "xs", title: "Extreme Sports"),
        BoardInfo(code: "y", title: "Yaoi")
    ].sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    
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
                if Self.isCertificateTrustError(error) {
                    print("BoardsService TLS trust error for \(self.boardsURL.host ?? "boards endpoint"); using cached or bundled boards.")
                } else {
                    print("BoardsService fetch error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self.ensureBundledBoardsAvailable()
                    completion?()
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.ensureBundledBoardsAvailable()
                    completion?()
                }
                return
            }
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
                    if sorted.isEmpty {
                        self.ensureBundledBoardsAvailable()
                    } else {
                        self.boards = sorted
                        // cache
                        UserDefaults.standard.set(cachePayload, forKey: self.cachedBoardsKey)
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.cachedBoardsDateKey)
                    }
                    completion?()
                }
            } catch {
                print("BoardsService parse error: \(error)")
                DispatchQueue.main.async {
                    self.ensureBundledBoardsAvailable()
                    completion?()
                }
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

    private func ensureBundledBoardsAvailable() {
        if boards.isEmpty {
            boards = Self.bundledBoards
        }
    }

    private static func isCertificateTrustError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let code = URLError.Code(rawValue: nsError.code)
        return code == .serverCertificateUntrusted
            || code == .serverCertificateHasBadDate
            || code == .serverCertificateHasUnknownRoot
            || code == .serverCertificateNotYetValid
            || code == .clientCertificateRejected
            || code == .clientCertificateRequired
    }
}
