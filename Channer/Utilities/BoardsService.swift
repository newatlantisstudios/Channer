import Foundation
import CryptoKit
import SwiftyJSON

/// A supported imageboard target. 4chan XT treats 4chan/4channel/4cdn as a
/// single Yotsuba site and handles the other included domains as Tinyboard-like
/// roots; this mirrors that split for native board discovery.
struct ImageboardSite: Equatable {
    enum Software: String {
        case yotsuba
        case vichan
        case lynxchan
        case makaba
        case htmlScrape
    }

    enum BoardListFormat {
        case yotsubaBoardsJSON
        case vichanIndexHTML
        case lynxchanBoardsHTML
        case makabaMobileBoards
        case htmlIndex
    }

    let id: String
    let displayName: String
    let software: Software
    let rootURL: URL
    let boardListURL: URL
    let fallbackRootURLs: [URL]
    let boardListFormat: BoardListFormat
    let hostAliases: [String]

    static let fourChan = ImageboardSite(
        id: "4chan.org",
        displayName: "4chan",
        software: .yotsuba,
        rootURL: URL(string: "https://boards.4chan.org/")!,
        boardListURL: URL(string: "https://a.4cdn.org/boards.json")!,
        fallbackRootURLs: [],
        boardListFormat: .yotsubaBoardsJSON,
        hostAliases: ["4channel.org", "4cdn.org", "boards.4chan.org", "boards.4channel.org", "i.4cdn.org"]
    )

    static let supportedSites: [ImageboardSite] = [
        vichan(id: "28chan.org", rootPath: "board"),
        makaba(id: "2ch.org", aliases: ["2ch.hk", "2ch.su"]),
        vichan(id: "39chan.moe"),
        .fourChan,
        lynxchan(id: "8chan.moe", aliases: ["8chan.se", "redchannit.com", "redchannit.net"]),
        vichan(id: "9ch.site", aliases: ["9-chan.eu", "9ch.moe", "9ch.fun"], fallbackHosts: ["9ch.moe", "9ch.fun"]),
        htmlScrape(id: "crystal.cafe"),
        lynxchan(id: "endchan.net", aliases: ["endchan.org"]),
        vichan(id: "fufufu.moe"),
        vichan(id: "kakashinenpo.com"),
        vichan(id: "kissu.moe", aliases: ["original.kissu.moe"]),
        vichan(id: "lainchan.org"),
        vichan(id: "merorin.com"),
        vichan(id: "nukechan.net", displayName: "Nukechan", aliases: ["erischan.org", "www.erischan.org"]),
        vichan(id: "ponyville.us"),
        vichan(id: "smuglo.li", aliases: ["notso.smuglo.li", "smugloli.net", "smug.nepu.moe"]),
        vichan(id: "sportschan.org"),
        vichan(id: "sushigirl.us", aliases: ["sushigirl.cafe", "www.sushigirl.cafe"]),
        vichan(id: "tvch.moe")
    ]

    static func site(for id: String?) -> ImageboardSite {
        guard let id = id else { return .fourChan }
        return supportedSites.first { $0.id == id || $0.hostAliases.contains(id) } ?? .fourChan
    }

    var supportsPosting: Bool {
        id == Self.fourChan.id
    }

    private static func vichan(id: String, displayName: String? = nil, rootPath: String? = nil, aliases: [String] = [], fallbackHosts: [String] = []) -> ImageboardSite {
        let rootURL = siteURL(host: id, rootPath: rootPath)
        return ImageboardSite(
            id: id,
            displayName: displayName ?? id,
            software: .vichan,
            rootURL: rootURL,
            boardListURL: rootURL,
            fallbackRootURLs: fallbackHosts.map { siteURL(host: $0, rootPath: rootPath) },
            boardListFormat: .vichanIndexHTML,
            hostAliases: aliases + ["www.\(id)"]
        )
    }

    private static func lynxchan(id: String, displayName: String? = nil, aliases: [String] = []) -> ImageboardSite {
        let rootURL = siteURL(host: id)
        return ImageboardSite(
            id: id,
            displayName: displayName ?? id,
            software: .lynxchan,
            rootURL: rootURL,
            boardListURL: rootURL.appendingPathComponent("boards.js"),
            fallbackRootURLs: [],
            boardListFormat: .lynxchanBoardsHTML,
            hostAliases: aliases + ["www.\(id)"]
        )
    }

    private static func makaba(id: String, displayName: String? = nil, aliases: [String] = []) -> ImageboardSite {
        let rootURL = siteURL(host: id)
        return ImageboardSite(
            id: id,
            displayName: displayName ?? id,
            software: .makaba,
            rootURL: rootURL,
            boardListURL: rootURL,
            fallbackRootURLs: [],
            boardListFormat: .makabaMobileBoards,
            hostAliases: aliases + ["www.\(id)"]
        )
    }

    private static func htmlScrape(id: String, displayName: String? = nil, boardListPath: String? = nil, aliases: [String] = []) -> ImageboardSite {
        let rootURL = siteURL(host: id)
        let boardListURL = boardListPath.map { rootURL.appendingPathComponent($0) } ?? rootURL
        return ImageboardSite(
            id: id,
            displayName: displayName ?? id,
            software: .htmlScrape,
            rootURL: rootURL,
            boardListURL: boardListURL,
            fallbackRootURLs: [],
            boardListFormat: .htmlIndex,
            hostAliases: aliases + ["www.\(id)"]
        )
    }

    private static func siteURL(host: String, rootPath: String? = nil) -> URL {
        var url = URL(string: "https://\(host)/")!
        if let rootPath = rootPath, !rootPath.isEmpty {
            url = url.appendingPathComponent(rootPath).appendingPathComponent("")
        }
        return url
    }
}

private extension URL {
    func appendingQueryItem(name: String, value: String) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: name, value: value))
        components.queryItems = queryItems
        return components.url ?? self
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
    
    func setSelectedSite(_ site: ImageboardSite, completion: (() -> Void)? = nil) {
        guard site != selectedSite else {
            print("BoardsService selected site unchanged: \(site.displayName); refreshing boards.")
            fetchBoards(completion: completion)
            return
        }
        print("BoardsService switching site from \(selectedSite.displayName) to \(site.displayName); fetching boards.")
        selectedSite = site
        UserDefaults.standard.set(site.id, forKey: selectedSiteKey)
        boards = []
        loadFromCache()
        fetchBoards { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            NotificationCenter.default.post(name: .imageboardSiteChanged, object: self)
            completion?()
        }
    }

    func setSelectedSite(id: String) {
        setSelectedSite(ImageboardSite.site(for: id))
    }

    #if DEBUG
    func setSelectedSiteForTesting(_ site: ImageboardSite) {
        selectedSite = site
        boards = []
    }
    #endif

    func threadListURLs(for board: String, totalPages: Int) -> [URL] {
        switch selectedSite.boardListFormat {
        case .yotsubaBoardsJSON:
            return (1...totalPages).compactMap {
                URL(string: "https://a.4cdn.org/\(board)/\($0).json")
            }
        case .vichanIndexHTML, .lynxchanBoardsHTML, .makabaMobileBoards:
            return [tinyboardURL(board: board, pathComponents: ["catalog.json"])]
        case .htmlIndex:
            return [htmlCatalogURL(board: board)]
        }
    }

    func threadJSONURL(board: String, threadNumber: String) -> URL {
        switch selectedSite.boardListFormat {
        case .yotsubaBoardsJSON:
            return URL(string: "https://a.4cdn.org/\(board)/thread/\(threadNumber).json")!
        case .vichanIndexHTML:
            if selectedSite.id == "sportschan.org" || selectedSite.id == "nukechan.net" {
                return tinyboardURL(board: board, pathComponents: ["thread", "\(threadNumber).json"])
            }
            return tinyboardURL(board: board, pathComponents: ["res", "\(threadNumber).json"])
        case .lynxchanBoardsHTML, .makabaMobileBoards:
            return tinyboardURL(board: board, pathComponents: ["res", "\(threadNumber).json"])
        case .htmlIndex:
            return htmlThreadURL(board: board, threadNumber: threadNumber)
        }
    }

    func webThreadURL(board: String, threadNumber: String) -> URL {
        switch selectedSite.boardListFormat {
        case .yotsubaBoardsJSON:
            return URL(string: "https://boards.4chan.org/\(board)/thread/\(threadNumber)")!
        case .vichanIndexHTML:
            if selectedSite.id == "sportschan.org" || selectedSite.id == "nukechan.net" {
                return tinyboardURL(board: board, pathComponents: ["thread", "\(threadNumber).html"])
            }
            return tinyboardURL(board: board, pathComponents: ["res", "\(threadNumber).html"])
        case .lynxchanBoardsHTML, .makabaMobileBoards:
            return tinyboardURL(board: board, pathComponents: ["res", "\(threadNumber).html"])
        case .htmlIndex:
            return htmlThreadURL(board: board, threadNumber: threadNumber)
        }
    }

    func imageURL(board: String, timestamp: String, extension ext: String) -> String {
        let cleanedTimestamp = timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTimestamp.isEmpty else { return "" }

        switch selectedSite.boardListFormat {
        case .yotsubaBoardsJSON:
            return "https://i.4cdn.org/\(board)/\(cleanedTimestamp)\(ext)"
        case .vichanIndexHTML, .lynxchanBoardsHTML, .makabaMobileBoards, .htmlIndex:
            if cleanedTimestamp.hasPrefix("http://") || cleanedTimestamp.hasPrefix("https://") {
                return cleanedTimestamp
            }
            if cleanedTimestamp.hasPrefix("/") {
                return URL(string: cleanedTimestamp, relativeTo: selectedSite.rootURL)?.absoluteURL.absoluteString ?? cleanedTimestamp
            }
            if selectedSite.id == "sportschan.org" || selectedSite.id == "nukechan.net" {
                let filename = cleanedTimestamp.hasSuffix(ext) || ext.isEmpty ? cleanedTimestamp : "\(cleanedTimestamp)\(ext)"
                return selectedSite.rootURL
                    .appendingPathComponent("file")
                    .appendingPathComponent(filename)
                    .absoluteString
            }

            let filename: String
            if cleanedTimestamp.contains("/") {
                filename = cleanedTimestamp.hasSuffix(ext) ? cleanedTimestamp : "\(cleanedTimestamp)\(ext)"
            } else {
                filename = "src/\(cleanedTimestamp)\(ext)"
            }
            return tinyboardURL(board: board, pathComponents: filename.split(separator: "/").map(String.init)).absoluteString
        }
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
        print("BoardsService fetching boards for \(site.displayName) from \(site.boardListURL.absoluteString)")
        fetchBoards(for: site, urls: boardListURLs(for: site), completion: completion)
    }

    struct FetchDataResponse {
        let data: Data
        let response: HTTPURLResponse?
    }

    func fetchData(from url: URL, completion: @escaping (Result<FetchDataResponse, Error>) -> Void) {
        fetchData(from: url, site: selectedSite, hasRetriedAfterChallenge: false, completion: completion)
    }

    private func fetchData(from url: URL, site: ImageboardSite, hasRetriedAfterChallenge: Bool, completion: @escaping (Result<FetchDataResponse, Error>) -> Void) {
        let debugID = String(UUID().uuidString.prefix(8))
        let startedAt = Date()
        print("[ChannerThreadLoadDebug][BoardsService][\(debugID)] start url=\(url.absoluteString) site=\(site.id) retry=\(hasRetriedAfterChallenge)")

        let completeOnMain: (Result<FetchDataResponse, Error>) -> Void = { result in
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startedAt))
            switch result {
            case .success(let dataResponse):
                let statusCode = dataResponse.response?.statusCode ?? -1
                let mimeType = dataResponse.response?.mimeType ?? "nil"
                let finalURL = dataResponse.response?.url?.absoluteString ?? "nil"
                let cacheHeaders = Self.debugCacheHeaderSummary(dataResponse.response)
                let payloadSummary = Self.debugPayloadSummary(dataResponse.data, originalURL: url)
                print("[ChannerThreadLoadDebug][BoardsService][\(debugID)] success status=\(statusCode) bytes=\(dataResponse.data.count) mime=\(mimeType) elapsed=\(elapsed)s mainThread=\(Thread.isMainThread) finalURL=\(finalURL) \(cacheHeaders) \(payloadSummary)")
            case .failure(let error):
                print("[ChannerThreadLoadDebug][BoardsService][\(debugID)] failure error=\(error.localizedDescription) elapsed=\(elapsed)s mainThread=\(Thread.isMainThread)")
            }

            if Thread.isMainThread {
                completion(result)
            } else {
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }

        let requestURL = Self.cacheBypassedURL(for: url)
        var request = URLRequest(url: requestURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        print("[ChannerThreadLoadDebug][BoardsService][\(debugID)] request url=\(requestURL.absoluteString) originalUrl=\(url.absoluteString) cachePolicy=\(request.cachePolicy.rawValue) timeout=\(request.timeoutInterval)s")
        if site.id == "8chan.moe" {
            EightChanMoePOWBlock.applyStoredCookies(to: &request)
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completeOnMain(.failure(error))
                return
            }

            let httpResponse = response as? HTTPURLResponse
            if site.id == "8chan.moe",
               let httpResponse = httpResponse,
               Self.requiresEightChanPOWBlockSolve(httpResponse),
               !hasRetriedAfterChallenge {
                print("[ChannerThreadLoadDebug][BoardsService][\(debugID)] 8chan POW challenge status=\(httpResponse.statusCode); solving")
                EightChanMoePOWBlock.shared.solve { result in
                    switch result {
                    case .success:
                        self.fetchData(from: url, site: site, hasRetriedAfterChallenge: true, completion: completion)
                    case .failure(let error):
                        completeOnMain(.failure(error))
                    }
                }
                return
            }

            guard let data = data else {
                completeOnMain(.failure(URLError(.zeroByteResource)))
                return
            }

            completeOnMain(.success(FetchDataResponse(data: data, response: httpResponse)))
        }
        task.resume()
    }

    static func cacheBypassedURL(for url: URL) -> URL {
        guard let host = url.host,
              ["a.4cdn.org", "boards.4chan.org"].contains(host),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "_" || $0.name == "channer_ts" }
        queryItems.append(URLQueryItem(name: "channer_ts", value: "\(Int(Date().timeIntervalSince1970 * 1000))"))
        components.queryItems = queryItems

        return components.url ?? url
    }

    private static func debugCacheHeaderSummary(_ response: HTTPURLResponse?) -> String {
        guard let response else { return "headers=nil" }

        let headers = response.allHeaderFields
        let interestingHeaders = ["Date", "Age", "Cache-Control", "ETag", "Last-Modified", "Expires", "CF-Cache-Status"]
            .map { name -> String in
                let value = headers.first { key, _ in
                    String(describing: key).caseInsensitiveCompare(name) == .orderedSame
                }?.value
                return "\(name)=\(value.map { String(describing: $0) } ?? "nil")"
            }
            .joined(separator: " ")

        return "headers{\(interestingHeaders)}"
    }

    private static func debugPayloadSummary(_ data: Data, originalURL: URL) -> String {
        let hash = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        guard originalURL.path.contains("/thread/") else {
            return "payload{sha256_8=\(hash)}"
        }

        let json: JSON?
        if originalURL.host == "a.4cdn.org" {
            json = try? JSON(data: data)
        } else if originalURL.host == "boards.4chan.org" {
            json = try? ThreadData.parseThreadResponse(from: data, boardAbv: originalURL.path.split(separator: "/").first.map(String.init) ?? "")
        } else {
            json = nil
        }

        guard let posts = json?["posts"].array else {
            return "payload{sha256_8=\(hash)}"
        }

        let firstNo = posts.first?["no"].stringValue.nonEmptyDebugValue ?? "nil"
        let lastNo = posts.last?["no"].stringValue.nonEmptyDebugValue ?? "nil"
        let opReplies = posts.first?["replies"].int.map(String.init) ?? "nil"
        let lastModified = posts.first?["last_modified"].int.map(String.init) ?? "nil"
        return "payload{sha256_8=\(hash) posts=\(posts.count) first=\(firstNo) last=\(lastNo) opReplies=\(opReplies) last_modified=\(lastModified)}"
    }

    private func fetchBoards(for site: ImageboardSite, urls: [URL], completion: (() -> Void)?) {
        guard let url = urls.first else {
            DispatchQueue.main.async {
                self.ensureBundledBoardsAvailable(for: site)
                self.logFetchedBoards(self.boards, site: site, source: "fallback after no board endpoints")
                completion?()
            }
            return
        }

        fetchData(from: url, site: site, hasRetriedAfterChallenge: false) { [weak self] result in
            guard let self = self else { completion?(); return }
            switch result {
            case .failure(let error):
                if Self.isCertificateTrustError(error) {
                    print("BoardsService TLS trust error for \(url.host ?? "boards endpoint"); using cached or bundled boards.")
                } else {
                    print("BoardsService fetch error: \(error.localizedDescription)")
                }
                if urls.count > 1 {
                    self.fetchBoards(for: site, urls: Array(urls.dropFirst()), completion: completion)
                    return
                }
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        print("BoardsService ignored fetched boards fallback for \(site.displayName) because selected site changed to \(self.selectedSite.displayName).")
                        completion?()
                        return
                    }
                    self.ensureBundledBoardsAvailable(for: site)
                    self.logFetchedBoards(self.boards, site: site, source: "fallback after fetch error")
                    completion?()
                }
                return

            case .success(let dataResponse):
                if let httpResponse = dataResponse.response {
                if !Self.isSuccessfulHTTPStatus(httpResponse.statusCode) || Self.isChallengeResponse(httpResponse) {
                    print("BoardsService board endpoint blocked or unavailable for \(site.displayName): HTTP \(httpResponse.statusCode) from \(url.absoluteString)")
                    if urls.count > 1 {
                        self.fetchBoards(for: site, urls: Array(urls.dropFirst()), completion: completion)
                        return
                    }
                    DispatchQueue.main.async {
                        guard self.selectedSite == site else {
                            print("BoardsService ignored HTTP fallback for \(site.displayName) because selected site changed to \(self.selectedSite.displayName).")
                            completion?()
                            return
                        }
                        self.ensureBundledBoardsAvailable(for: site)
                        self.logFetchedBoards(self.boards, site: site, source: "fallback after blocked or unavailable HTTP response")
                        completion?()
                    }
                    return
                }
            }
            do {
                let items = try Self.parseBoards(from: dataResponse.data, for: site)
                let sorted = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                if sorted.isEmpty, urls.count > 1 {
                    self.fetchBoards(for: site, urls: Array(urls.dropFirst()), completion: completion)
                    return
                }
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        print("BoardsService ignored fetched boards for \(site.displayName) because selected site changed to \(self.selectedSite.displayName).")
                        completion?()
                        return
                    }
                    if sorted.isEmpty {
                        self.ensureBundledBoardsAvailable(for: site)
                        self.logFetchedBoards(self.boards, site: site, source: "fallback after empty parsed response")
                    } else {
                        self.boards = sorted
                        let cachePayload = sorted.map { ["board": $0.code, "title": $0.title, "siteID": $0.siteID] }
                        UserDefaults.standard.set(cachePayload, forKey: self.cacheKey(for: site))
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.cacheDateKey(for: site))
                        self.logFetchedBoards(sorted, site: site, source: "network")
                    }
                    completion?()
                }
            } catch {
                print("BoardsService parse error: \(error)")
                if urls.count > 1 {
                    self.fetchBoards(for: site, urls: Array(urls.dropFirst()), completion: completion)
                    return
                }
                DispatchQueue.main.async {
                    guard self.selectedSite == site else {
                        print("BoardsService ignored parsed boards fallback for \(site.displayName) because selected site changed to \(self.selectedSite.displayName).")
                        completion?()
                        return
                    }
                    self.ensureBundledBoardsAvailable(for: site)
                    self.logFetchedBoards(self.boards, site: site, source: "fallback after parse error")
                    completion?()
                }
            }
            }
        }
    }
    
    // MARK: - Utility Methods

    private func cacheKey(for site: ImageboardSite) -> String {
        site.id == ImageboardSite.fourChan.id ? cachedBoardsKey : "\(cachedBoardsKey)_\(site.id)"
    }

    private func cacheDateKey(for site: ImageboardSite) -> String {
        site.id == ImageboardSite.fourChan.id ? cachedBoardsDateKey : "\(cachedBoardsDateKey)_\(site.id)"
    }

    private func boardListURLs(for site: ImageboardSite) -> [URL] {
        [site.boardListURL] + site.fallbackRootURLs.map { rootURL in
            switch site.boardListFormat {
            case .yotsubaBoardsJSON:
                return site.boardListURL
            case .vichanIndexHTML, .htmlIndex:
                return rootURL
            case .lynxchanBoardsHTML:
                return rootURL.appendingPathComponent("boards.js")
            case .makabaMobileBoards:
                return rootURL
            }
        }
    }

    private func tinyboardURL(board: String, pathComponents: [String]) -> URL {
        var url = selectedSite.rootURL
            .appendingPathComponent(board)
        for pathComponent in pathComponents {
            url = url.appendingPathComponent(pathComponent)
        }
        return url
    }

    private func htmlCatalogURL(board: String) -> URL {
        switch selectedSite.id {
        case "crystal.cafe":
            return selectedSite.rootURL.appendingPathComponent(board).appendingPathComponent("catalog")
        default:
            return selectedSite.rootURL.appendingPathComponent(board).appendingPathComponent("catalog.html")
        }
    }

    private func htmlThreadURL(board: String, threadNumber: String) -> URL {
        switch selectedSite.id {
        default:
            return selectedSite.rootURL.appendingPathComponent(board).appendingPathComponent("res").appendingPathComponent("\(threadNumber).html")
        }
    }

    static func parseBoards(from data: Data, for site: ImageboardSite) throws -> [BoardInfo] {
        switch site.boardListFormat {
        case .yotsubaBoardsJSON:
            return try parseYotsubaBoardsJSON(data, siteID: site.id)
        case .vichanIndexHTML, .htmlIndex:
            return parseTinyboardIndexHTML(data, site: site)
        case .lynxchanBoardsHTML:
            return parseLynxchanBoardsHTML(data, site: site)
        case .makabaMobileBoards:
            return try parseMakabaBoards(data, site: site)
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

    private static func parseMakabaBoards(_ data: Data, site: ImageboardSite) throws -> [BoardInfo] {
        guard let json = try? JSON(data: data), json.error == nil else {
            return parseTinyboardIndexHTML(data, site: site)
        }
        let candidates: [JSON]
        if let boards = json["boards"].array {
            candidates = boards
        } else if let boards = json.array {
            candidates = boards
        } else {
            candidates = json.dictionaryValue.values.flatMap { value -> [JSON] in
                if let boards = value.array { return boards }
                if let boards = value["boards"].array { return boards }
                return []
            }
        }

        var seenCodes = Set<String>()
        var items: [BoardInfo] = []
        for entry in candidates {
            let code = firstString(in: entry, keys: ["id", "board", "board_id", "name"])
            let title = firstString(in: entry, keys: ["name", "title", "boardName", "info"])
            let lowercasedCode = code.lowercased()
            guard
                !code.isEmpty,
                lowercasedCode.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil,
                !seenCodes.contains(lowercasedCode)
            else {
                continue
            }

            seenCodes.insert(lowercasedCode)
            items.append(BoardInfo(code: code, title: normalizeBoardTitle(title, code: code), siteID: site.id))
        }
        return items
    }

    private static func parseLynxchanBoardsHTML(_ data: Data, site: ImageboardSite) -> [BoardInfo] {
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"<a\b([^>]*)>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return parseTinyboardIndexHTML(data, site: site)
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seenCodes = Set<String>()
        var items: [BoardInfo] = []

        for match in regex.matches(in: html, options: [], range: range) {
            guard
                let attributesRange = Range(match.range(at: 1), in: html),
                let titleRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }

            let attributes = String(html[attributesRange])
            guard
                attributeValue(named: "class", in: attributes)?.range(of: #"(^|\s)linkBoard(\s|$)"#, options: [.regularExpression, .caseInsensitive]) != nil,
                let href = attributeValue(named: "href", in: attributes),
                let code = boardCode(from: href)
            else {
                continue
            }

            let lowercasedCode = code.lowercased()
            guard
                !code.isEmpty,
                lowercasedCode.range(of: #"^[a-z0-9_\-]+$"#, options: .regularExpression) != nil,
                !seenCodes.contains(lowercasedCode)
            else {
                continue
            }

            seenCodes.insert(lowercasedCode)
            let title = normalizeBoardTitle(String(html[titleRange]), code: code)
            items.append(BoardInfo(code: code, title: title, siteID: site.id))
        }

        return items.isEmpty ? parseTinyboardIndexHTML(data, site: site) : items
    }

    private static func parseTinyboardIndexHTML(_ data: Data, site: ImageboardSite) -> [BoardInfo] {
        let html = String(decoding: data, as: UTF8.self)
        if let embeddedBoards = parseTinyboardEmbeddedSiteJSON(html, site: site), !embeddedBoards.isEmpty {
            return embeddedBoards
        }

        let pattern = #"<a\b([^>]*)>(.*?)</a>"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let invalidCodes = Set([
            ".", "..", "api", "catalog", "css", "data", "favicon.ico", "images", "img",
            "js", "res", "src", "static", "stylesheets", "thumb", "all", "about",
            "account", "banners", "chat", "faq", "home", "i2p", "legal", "news",
            "recent", "rules", "rss", "search", "tagged", "tor"
        ]).union(siteSpecificInvalidBoardCodes(for: site))
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seenCodes = Set<String>()
        var items: [BoardInfo] = []

        for match in regex.matches(in: html, options: [], range: range) {
            guard
                let attributesRange = Range(match.range(at: 1), in: html),
                let titleRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }

            let attributes = String(html[attributesRange])
            guard
                let href = attributeValue(named: "href", in: attributes),
                isBoardHref(href, for: site),
                let code = boardCode(from: href)
            else {
                continue
            }

            let lowercasedCode = code.lowercased()
            guard
                !code.isEmpty,
                !invalidCodes.contains(lowercasedCode),
                lowercasedCode.range(of: #"^[a-z0-9_\-]+$"#, options: .regularExpression) != nil,
                !seenCodes.contains(lowercasedCode)
            else {
                continue
            }

            seenCodes.insert(lowercasedCode)
            let title = boardTitle(from: String(html[titleRange]), attributes: attributes, code: code)
            items.append(BoardInfo(code: code, title: title, siteID: site.id))
        }

        return items
    }

    private static func isBoardHref(_ href: String, for site: ImageboardSite) -> Bool {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("javascript:") else {
            return false
        }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            guard
                let url = URL(string: trimmed),
                let host = url.host?.lowercased()
            else {
                return false
            }
            let allowedHosts = ([site.rootURL.host] + site.hostAliases).compactMap { $0?.lowercased() }
            guard allowedHosts.contains(host) else {
                return false
            }
        }

        return boardCode(from: trimmed) != nil
    }

    private static func boardCode(from href: String) -> String? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        let path: String
        if let url = URL(string: trimmed), url.scheme != nil {
            path = url.path
        } else {
            path = trimmed
        }

        let cleanPath = path
            .components(separatedBy: "#").first?
            .components(separatedBy: "?").first?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        var segments = cleanPath
            .split(separator: "/")
            .map(String.init)

        guard !segments.isEmpty else { return nil }
        if segments.first?.lowercased() == "boards" {
            segments.removeFirst()
        }
        guard segments.count == 1 || (segments.count == 2 && segments[1].lowercased() == "index.html") else {
            return nil
        }

        let rawCode = segments[0].removingPercentEncoding ?? segments[0]
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.range(of: #"^[a-z0-9_\-]+$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return code
    }

    private static func boardTitle(from anchorHTML: String, attributes: String, code: String) -> String {
        if let title = attributeValue(named: "title", in: attributes), !title.isEmpty {
            return normalizeBoardTitle(title, code: code)
        }
        if let nestedTitle = firstMatch(in: anchorHTML, pattern: #"<[^>]*\bclass\s*=\s*["'][^"']*\bboard-title\b[^"']*["'][^>]*>(.*?)</[^>]+>"#) {
            return normalizeBoardTitle(nestedTitle, code: code)
        }
        return normalizeBoardTitle(anchorHTML, code: code)
    }

    private static func attributeValue(named name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        return firstMatch(in: attributes, pattern: #"\b\#(escapedName)\s*=\s*(['"])(.*?)\1"#, captureGroup: 2)
    }

    private static func firstMatch(in text: String, pattern: String, captureGroup: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > captureGroup,
            let matchRange = Range(match.range(at: captureGroup), in: text)
        else {
            return nil
        }
        return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseTinyboardEmbeddedSiteJSON(_ html: String, site: ImageboardSite) -> [BoardInfo]? {
        guard let markerRange = html.range(of: "window.site_json=") else {
            return nil
        }

        var start = markerRange.upperBound
        while start < html.endIndex, html[start].isWhitespace {
            html.formIndex(after: &start)
        }
        guard start < html.endIndex, html[start] == "{" else {
            return nil
        }

        guard let end = endOfJavaScriptObject(in: html, from: start) else {
            return nil
        }

        let jsonLiteral = String(html[start..<end])
        guard let jsonData = jsonLiteral.data(using: .utf8),
              let json = try? JSON(data: jsonData),
              let boards = json["boards"].array else {
            return nil
        }

        var seenCodes = Set<String>()
        var items: [BoardInfo] = []
        items.reserveCapacity(boards.count)

        for board in boards {
            let code = (board["name"].string ?? board["uri"].string ?? board["board"].string ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedCode = code.lowercased()
            let rawTitle = (board["title"].string ?? board["subtitle"].string ?? board["topic"].string ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard
                !code.isEmpty,
                lowercasedCode.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil,
                !seenCodes.contains(lowercasedCode)
            else {
                continue
            }

            seenCodes.insert(lowercasedCode)
            let title = normalizeBoardTitle(rawTitle, code: code)
            items.append(BoardInfo(code: code, title: title, siteID: site.id))
        }

        return items
    }

    private static func endOfJavaScriptObject(in text: String, from start: String.Index) -> String.Index? {
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return text.index(after: index)
                    }
                }
            }

            text.formIndex(after: &index)
        }

        return nil
    }

    private static func siteSpecificInvalidBoardCodes(for site: ImageboardSite) -> Set<String> {
        switch site.id {
        case "sushigirl.us":
            return ["chat", "faq", "kaitensushi"]
        case "39chan.moe":
            return ["all", "frames", "radio", "rules", "faq", "static", "stylesheets"]
        case "28chan.org":
            return ["all", "rules", "news", "contact", "about", "donate", "banners"]
        default:
            return []
        }
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

    private static func firstString(in json: JSON, keys: [String]) -> String {
        for key in keys {
            let value = json[key].stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private func ensureBundledBoardsAvailable(for site: ImageboardSite? = nil) {
        let fallbackSite = site ?? selectedSite
        if fallbackSite == ImageboardSite.fourChan, boards.isEmpty {
            boards = Self.bundledBoards
        }
    }

    private func logFetchedBoards(_ boards: [BoardInfo], site: ImageboardSite, source: String) {
        let boardList = boards
            .map { "/\($0.code)/ - \($0.title)" }
            .joined(separator: ", ")
        print("BoardsService fetched \(boards.count) boards for \(site.displayName) (\(source)): \(boardList)")
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

    private static func isSuccessfulHTTPStatus(_ statusCode: Int) -> Bool {
        (200...299).contains(statusCode)
    }

    private static func isChallengeResponse(_ response: HTTPURLResponse) -> Bool {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            guard let key = item.key as? String else { return }
            result[key.lowercased()] = "\(item.value)".lowercased()
        }
        if headers["cf-mitigated"] == "challenge" {
            return true
        }
        if headers["x-powblock-status"] == "required" {
            return true
        }
        return false
    }

    static func isPOWBlockRequired(_ response: HTTPURLResponse) -> Bool {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            guard let key = item.key as? String else { return }
            result[key.lowercased()] = "\(item.value)".lowercased()
        }
        return headers["x-powblock-status"] == "required"
    }

    static func requiresEightChanPOWBlockSolve(_ response: HTTPURLResponse) -> Bool {
        isPOWBlockRequired(response) || response.statusCode == 403
    }
}

private extension String {
    var nonEmptyDebugValue: String? {
        isEmpty ? nil : self
    }
}

enum EightChanMoePOWBlock {
    enum POWBlockError: LocalizedError {
        case missingChallenge
        case noSolution
        case badSubmitResponse(Int)
        case missingCookies
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .missingChallenge:
                return "8chan.moe POWBlock challenge was missing required fields."
            case .noSolution:
                return "Could not solve the 8chan.moe POWBlock challenge."
            case .badSubmitResponse(let statusCode):
                return "8chan.moe POWBlock rejected the solution with HTTP \(statusCode)."
            case .missingCookies:
                return "8chan.moe POWBlock did not return the required cookies."
            case .network(let error):
                return error.localizedDescription
            }
        }
    }

    struct Challenge: Equatable {
        let token: String
        let difficulty: Int
        let algorithm: Int
    }

    static let shared = Solver()
    private static let rootURL = URL(string: "https://8chan.moe/")!
    private static let powTokenKey = "channer_8chan_moe_pow_token"
    private static let powIDKey = "channer_8chan_moe_pow_id"
    private static let tosCookie = "TOS20250418=1"

    static func applyStoredCookies(to request: inout URLRequest) {
        request.setValue(rootURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
    }

    static func parseChallenge(from data: Data) -> Challenge? {
        let html = String(decoding: data, as: UTF8.self)
        guard
            let token = firstMatch(in: html, pattern: #"<pre\b[^>]*\bid\s*=\s*["']?c["']?(?=[\s>])[^>]*>(.*?)</pre>"#),
            let difficultyText = firstMatch(in: html, pattern: #"<pre\b[^>]*\bid\s*=\s*["']?d["']?(?=[\s>])[^>]*>(.*?)</pre>"#),
            let difficulty = Int(difficultyText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }

        let algorithmText = firstMatch(in: html, pattern: #"<pre\b[^>]*\bid\s*=\s*["']?h["']?(?=[\s>])[^>]*>(.*?)</pre>"#)
        let algorithm = algorithmText
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 256

        return Challenge(
            token: decodeHTML(token),
            difficulty: difficulty,
            algorithm: algorithm == 512 ? 512 : 256
        )
    }

    static func solve(challenge: Challenge, maxIterations: Int = 5_000_000) -> Int? {
        guard challenge.difficulty >= 0 else { return nil }
        if challenge.difficulty == 0 { return 0 }

        for nonce in 0...maxIterations {
            let message = "\(challenge.token)\(nonce)"
            let digest: [UInt8]
            if challenge.algorithm == 512 {
                digest = Array(SHA512.hash(data: Data(message.utf8)))
            } else {
                digest = Array(SHA256.hash(data: Data(message.utf8)))
            }

            if leadingZeroBits(in: digest) >= challenge.difficulty {
                return nonce
            }
        }

        return nil
    }

    private static func cookieHeader() -> String {
        var cookies = [tosCookie]
        let defaults = UserDefaults.standard
        if let token = defaults.string(forKey: powTokenKey), !token.isEmpty,
           let id = defaults.string(forKey: powIDKey), !id.isEmpty {
            cookies.insert("POW_ID=\(id)", at: 0)
            cookies.insert("POW_TOKEN=\(token)", at: 0)
        }
        return cookies.joined(separator: "; ")
    }

    private static func storeCookies(from response: HTTPURLResponse) -> Bool {
        let rawCookies = response.allHeaderFields
            .filter { key, _ in (key as? String)?.lowercased() == "set-cookie" }
            .flatMap { _, value -> [String] in
                if let values = value as? [String] { return values }
                return ["\(value)"]
            }

        let token = rawCookies.compactMap { cookieValue(named: "POW_TOKEN", from: $0) }.first
        let id = rawCookies.compactMap { cookieValue(named: "POW_ID", from: $0) }.first

        guard let token = token, let id = id else {
            return false
        }

        let defaults = UserDefaults.standard
        defaults.set(token, forKey: powTokenKey)
        defaults.set(id, forKey: powIDKey)
        return true
    }

    private static func storeCookies(from cookies: [HTTPCookie]) -> Bool {
        let token = cookies.first { $0.name == "POW_TOKEN" }?.value
        let id = cookies.first { $0.name == "POW_ID" }?.value

        guard let token = token, !token.isEmpty, let id = id, !id.isEmpty else {
            return false
        }

        let defaults = UserDefaults.standard
        defaults.set(token, forKey: powTokenKey)
        defaults.set(id, forKey: powIDKey)
        return true
    }

    private static func cookieValue(named name: String, from rawCookie: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        return firstMatch(in: rawCookie, pattern: #"(^|[;,]\s*)\#(escapedName)=([^;,]+)"#, captureGroup: 2)
    }

    static func submitURL(solution: Int, token: String) -> URL? {
        URL(string: "\(rootURL.absoluteString)?pow=\(solution)&t=\(token)")
    }

    private static func leadingZeroBits(in bytes: [UInt8]) -> Int {
        var count = 0
        for byte in bytes {
            if byte == 0 {
                count += 8
                continue
            }

            for bit in (0...7).reversed() {
                if (byte & UInt8(1 << bit)) == 0 {
                    count += 1
                } else {
                    return count
                }
            }
        }
        return count
    }

    private static func firstMatch(in text: String, pattern: String, captureGroup: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > captureGroup,
            let matchRange = Range(match.range(at: captureGroup), in: text)
        else {
            return nil
        }
        return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
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

    final class Solver {
        private let workQueue = DispatchQueue(label: "com.channer.8chanMoePOWBlock", qos: .userInitiated)
        private let stateQueue = DispatchQueue(label: "com.channer.8chanMoePOWBlock.state")
        private var isSolving = false
        private var waiters: [(Result<Void, Error>) -> Void] = []

        func solve(completion: @escaping (Result<Void, Error>) -> Void) {
            stateQueue.async {
                self.waiters.append(completion)
                guard !self.isSolving else { return }
                self.isSolving = true

                self.workQueue.async {
                    let result = Result { try self.solveBlocking() }
                    self.stateQueue.async {
                        let waiters = self.waiters
                        self.waiters = []
                        self.isSolving = false
                        waiters.forEach { $0(result) }
                    }
                }
            }
        }

        private func solveBlocking() throws {
            var initialRequest = URLRequest(url: EightChanMoePOWBlock.rootURL)
            EightChanMoePOWBlock.applyStoredCookies(to: &initialRequest)

            let initial = try perform(initialRequest, session: .shared)
            guard let initialResponse = initial.response else {
                throw POWBlockError.missingChallenge
            }

            if !BoardsService.isPOWBlockRequired(initialResponse) {
                return
            }

            guard let challenge = EightChanMoePOWBlock.parseChallenge(from: initial.data) else {
                throw POWBlockError.missingChallenge
            }

            UserDefaults.standard.removeObject(forKey: EightChanMoePOWBlock.powTokenKey)
            UserDefaults.standard.removeObject(forKey: EightChanMoePOWBlock.powIDKey)

            guard let solution = EightChanMoePOWBlock.solve(challenge: challenge),
                  let submitURL = EightChanMoePOWBlock.submitURL(solution: solution, token: challenge.token)
            else {
                throw POWBlockError.noSolution
            }

            var submitRequest = URLRequest(url: submitURL)
            submitRequest.setValue(EightChanMoePOWBlock.rootURL.absoluteString, forHTTPHeaderField: "Referer")
            submitRequest.setValue(EightChanMoePOWBlock.tosCookie, forHTTPHeaderField: "Cookie")

            let sessionConfiguration = URLSessionConfiguration.ephemeral
            let cookieStorage = HTTPCookieStorage()
            sessionConfiguration.httpCookieStorage = cookieStorage
            sessionConfiguration.httpCookieAcceptPolicy = .always

            let noRedirectDelegate = NoRedirectDelegate()
            let noRedirectSession = URLSession(configuration: sessionConfiguration, delegate: noRedirectDelegate, delegateQueue: nil)
            let submit = try perform(submitRequest, session: noRedirectSession)

            guard let submitResponse = submit.response else {
                noRedirectSession.finishTasksAndInvalidate()
                throw POWBlockError.missingCookies
            }

            let storedCookies = EightChanMoePOWBlock.storeCookies(from: submitResponse)
                || EightChanMoePOWBlock.storeCookies(from: cookieStorage.cookies(for: EightChanMoePOWBlock.rootURL) ?? [])
            noRedirectSession.finishTasksAndInvalidate()

            let status = submitResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
                guard let key = item.key as? String else { return }
                result[key.lowercased()] = "\(item.value)".lowercased()
            }["x-powblock-status"]

            let responseIndicatesCompletion = status == "completed" || (200...399).contains(submitResponse.statusCode)
            guard responseIndicatesCompletion, !BoardsService.isPOWBlockRequired(submitResponse) else {
                throw POWBlockError.badSubmitResponse(submitResponse.statusCode)
            }
            guard storedCookies else {
                throw POWBlockError.missingCookies
            }
        }

        private func perform(_ request: URLRequest, session: URLSession) throws -> (data: Data, response: HTTPURLResponse?) {
            let semaphore = DispatchSemaphore(value: 0)
            var outputData: Data?
            var outputResponse: HTTPURLResponse?
            var outputError: Error?

            let task = session.dataTask(with: request) { data, response, error in
                outputData = data
                outputResponse = response as? HTTPURLResponse
                outputError = error
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()

            if let outputError = outputError {
                throw POWBlockError.network(outputError)
            }

            return (outputData ?? Data(), outputResponse)
        }
    }

    private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }
}
