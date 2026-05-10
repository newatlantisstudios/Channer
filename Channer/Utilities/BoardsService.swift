import Foundation
import SwiftyJSON

/// A supported imageboard target. 4chan XT treats 4chan/4channel/4cdn as a
/// single Yotsuba site and handles the other included domains as Tinyboard-like
/// roots; this mirrors that split for native board discovery.
struct ImageboardSite: Equatable {
    enum Software: String {
        case yotsuba
        case tinyboard
    }

    enum BoardListFormat {
        case yotsubaBoardsJSON
        case tinyboardIndexHTML
    }

    let id: String
    let displayName: String
    let software: Software
    let rootURL: URL
    let boardListURL: URL
    let boardListFormat: BoardListFormat
    let hostAliases: [String]

    static let fourChan = ImageboardSite(
        id: "4chan.org",
        displayName: "4chan",
        software: .yotsuba,
        rootURL: URL(string: "https://boards.4chan.org/")!,
        boardListURL: URL(string: "https://a.4cdn.org/boards.json")!,
        boardListFormat: .yotsubaBoardsJSON,
        hostAliases: ["4channel.org", "4cdn.org", "boards.4chan.org", "boards.4channel.org", "i.4cdn.org"]
    )

    static let supportedSites: [ImageboardSite] = [
        .fourChan,
        tinyboard(id: "erischan.org"),
        tinyboard(id: "fufufu.moe"),
        tinyboard(id: "kakashinenpo.com"),
        tinyboard(id: "kissu.moe", aliases: ["original.kissu.moe"]),
        tinyboard(id: "lainchan.org"),
        tinyboard(id: "merorin.com"),
        tinyboard(id: "ota-ch.com"),
        tinyboard(id: "ponyville.us"),
        tinyboard(id: "smuglo.li", aliases: ["notso.smuglo.li", "smugloli.net", "smug.nepu.moe"]),
        tinyboard(id: "sportschan.org"),
        tinyboard(id: "sushigirl.us"),
        tinyboard(id: "tvch.moe")
    ]

    static func site(for id: String?) -> ImageboardSite {
        guard let id = id else { return .fourChan }
        return supportedSites.first { $0.id == id || $0.hostAliases.contains(id) } ?? .fourChan
    }

    private static func tinyboard(id: String, aliases: [String] = []) -> ImageboardSite {
        let rootURL = URL(string: "https://\(id)/")!
        return ImageboardSite(
            id: id,
            displayName: id,
            software: .tinyboard,
            rootURL: rootURL,
            boardListURL: rootURL,
            boardListFormat: .tinyboardIndexHTML,
            hostAliases: aliases + ["www.\(id)"]
        )
    }
}

extension Notification.Name {
    static let imageboardSiteChanged = Notification.Name("imageboardSiteChanged")
}

/// Represents information about an imageboard board.
struct BoardInfo {
    /// The board's abbreviated code (e.g., "g", "pol", "b")
    let code: String
    /// The board's full display title
    let title: String
    /// The imageboard site this board belongs to.
    let siteID: String

    init(code: String, title: String, siteID: String = ImageboardSite.fourChan.id) {
        self.code = code
        self.title = title
        self.siteID = siteID
    }
}

/// Manages fetching and caching of imageboard board information
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
    
    /// UserDefaults key for the active imageboard site.
    private let selectedSiteKey = "channer_selected_imageboard_site_id"
    /// UserDefaults key for caching board data
    private let cachedBoardsKey = "channer_cached_boards_list"
    /// UserDefaults key for caching board fetch date
    private let cachedBoardsDateKey = "channer_cached_boards_list_date"
    /// Active imageboard target. Defaults to 4chan for existing installs.
    private(set) var selectedSite = ImageboardSite.site(for: UserDefaults.standard.string(forKey: "channer_selected_imageboard_site_id"))
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
    /// Imageboard sites supported by the native board loader.
    var supportedSites: [ImageboardSite] { ImageboardSite.supportedSites }
    
    func setSelectedSite(_ site: ImageboardSite) {
        guard site != selectedSite else { return }
        selectedSite = site
        UserDefaults.standard.set(site.id, forKey: selectedSiteKey)
        boards = []
        loadFromCache()
        ensureBundledBoardsAvailable()
        NotificationCenter.default.post(name: .imageboardSiteChanged, object: self)
    }

    func setSelectedSite(id: String) {
        setSelectedSite(ImageboardSite.site(for: id))
    }
    
    // MARK: - Cache Management
    
    /// Loads board information from UserDefaults cache
    /// Called during initialization to restore previously fetched board data
    func loadFromCache() {
        let defaults = UserDefaults.standard
        if let cached = defaults.array(forKey: cacheKey(for: selectedSite)) as? [[String: String]], !cached.isEmpty {
            var items: [BoardInfo] = []
            items.reserveCapacity(cached.count)
            for item in cached {
                if let code = item["board"], let title = item["title"], !code.isEmpty, !title.isEmpty {
                    let siteID = item["siteID"] ?? selectedSite.id
                    items.append(BoardInfo(code: code, title: title, siteID: siteID))
                }
            }
            if !items.isEmpty {
                self.boards = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            }
        }
    }
    
    // MARK: - Network Operations
    
    /// Fetches the latest board list from the selected imageboard site
    /// Updates the local boards array and caches the result
    /// - Parameter completion: Optional closure called when the fetch operation completes (success or failure)
    func fetchBoards(completion: (() -> Void)? = nil) {
        let site = selectedSite
        let task = URLSession.shared.dataTask(with: site.boardListURL) { [weak self] data, response, error in
            guard let self = self else { completion?(); return }
            if let error = error {
                if Self.isCertificateTrustError(error) {
                    print("BoardsService TLS trust error for \(site.boardListURL.host ?? "boards endpoint"); using cached or bundled boards.")
                } else {
                    print("BoardsService fetch error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        completion?()
                        return
                    }
                    self.ensureBundledBoardsAvailable()
                    completion?()
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        completion?()
                        return
                    }
                    self.ensureBundledBoardsAvailable()
                    completion?()
                }
                return
            }
            do {
                let items = try Self.parseBoards(from: data, for: site)
                let sorted = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        completion?()
                        return
                    }
                    if sorted.isEmpty {
                        self.ensureBundledBoardsAvailable()
                    } else {
                        self.boards = sorted
                        let cachePayload = sorted.map { ["board": $0.code, "title": $0.title, "siteID": $0.siteID] }
                        UserDefaults.standard.set(cachePayload, forKey: self.cacheKey(for: site))
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.cacheDateKey(for: site))
                    }
                    completion?()
                }
            } catch {
                print("BoardsService parse error: \(error)")
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        completion?()
                        return
                    }
                    self.ensureBundledBoardsAvailable()
                    completion?()
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Utility Methods

    private func cacheKey(for site: ImageboardSite) -> String {
        site.id == ImageboardSite.fourChan.id ? cachedBoardsKey : "\(cachedBoardsKey)_\(site.id)"
    }

    private func cacheDateKey(for site: ImageboardSite) -> String {
        site.id == ImageboardSite.fourChan.id ? cachedBoardsDateKey : "\(cachedBoardsDateKey)_\(site.id)"
    }

    private static func parseBoards(from data: Data, for site: ImageboardSite) throws -> [BoardInfo] {
        switch site.boardListFormat {
        case .yotsubaBoardsJSON:
            return try parseYotsubaBoardsJSON(data, siteID: site.id)
        case .tinyboardIndexHTML:
            return parseTinyboardIndexHTML(data, site: site)
        }
    }

    private static func parseYotsubaBoardsJSON(_ data: Data, siteID: String) throws -> [BoardInfo] {
        let json = try JSON(data: data)
        let boardsArray = json["boards"].arrayValue
        var items: [BoardInfo] = []
        items.reserveCapacity(boardsArray.count)

        for entry in boardsArray {
            let code = entry["board"].stringValue
            let titleRaw = entry["title"].stringValue
            let title = decodeHTML(titleRaw)
            if !code.isEmpty && !title.isEmpty {
                items.append(BoardInfo(code: code, title: title, siteID: siteID))
            }
        }

        return items
    }

    private static func parseTinyboardIndexHTML(_ data: Data, site: ImageboardSite) -> [BoardInfo] {
        let html = String(decoding: data, as: UTF8.self)
        let hosts = ([site.rootURL.host] + site.hostAliases)
            .compactMap { $0 }
            .map { NSRegularExpression.escapedPattern(for: $0) }
        let hostPattern = hosts.joined(separator: "|")
        let pattern = #"<a\b[^>]*\bhref\s*=\s*["'](?:(?:https?://(?:\#(hostPattern)))?/|/)([^/"'?#]+)/(?:index\.html)?["'][^>]*>(.*?)</a>"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let invalidCodes: Set<String> = [
            ".", "..", "api", "catalog", "css", "data", "favicon.ico", "images", "img",
            "js", "res", "src", "static", "stylesheets", "thumb"
        ]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seenCodes = Set<String>()
        var items: [BoardInfo] = []

        for match in regex.matches(in: html, options: [], range: range) {
            guard
                let codeRange = Range(match.range(at: 1), in: html),
                let titleRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }

            let rawCode = String(html[codeRange]).removingPercentEncoding ?? String(html[codeRange])
            let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedCode = code.lowercased()
            guard
                !code.isEmpty,
                !invalidCodes.contains(lowercasedCode),
                lowercasedCode.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil,
                !seenCodes.contains(lowercasedCode)
            else {
                continue
            }

            seenCodes.insert(lowercasedCode)
            let title = normalizeBoardTitle(String(html[titleRange]), code: code)
            items.append(BoardInfo(code: code, title: title, siteID: site.id))
        }

        return items
    }

    private static func normalizeBoardTitle(_ rawTitle: String, code: String) -> String {
        let withoutTags = rawTitle.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        var title = decodeHTML(withoutTags)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let slashCode = "/\(code)/"
        if title.hasPrefix(slashCode) {
            title.removeFirst(slashCode.count)
        }
        if let delimiter = title.range(of: " - ") {
            title = String(title[delimiter.upperBound...])
        }
        title = title
            .replacingOccurrences(of: slashCode, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? code : title
    }
    
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
        if selectedSite == ImageboardSite.fourChan, boards.isEmpty {
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
