import Foundation
import Alamofire
import SwiftyJSON
import UIKit

class SearchManager {

    // MARK: - Search Progress
    enum SearchProgressPhase {
        case loadingBoards
        case searching
    }

    struct SearchProgress {
        let phase: SearchProgressPhase
        let completedBoards: Int
        let totalBoards: Int
        let currentBoard: String?
    }
    
    // MARK: - Singleton Instance
    static let shared = SearchManager()
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let searchHistoryKey = "searchHistory"
    private let savedSearchesKey = "savedSearches"
    private let savedSearchStatesKey = "savedSearchStates"
    
    // MARK: - Data Models
    struct SearchItem: Codable {
        let id: String
        let query: String
        let timestamp: Date
        let boardAbv: String?
        
        init(query: String, boardAbv: String? = nil) {
            self.id = UUID().uuidString
            self.query = query
            self.timestamp = Date()
            self.boardAbv = boardAbv
        }
    }
    
    struct SavedSearch: Codable {
        let id: String
        var name: String
        let query: String
        let boardAbv: String?
        var filters: SearchFilters?
        let createdAt: Date
        var updatedAt: Date
        
        init(name: String, query: String, boardAbv: String? = nil, filters: SearchFilters? = nil) {
            self.id = UUID().uuidString
            self.name = name
            self.query = query
            self.boardAbv = boardAbv
            self.filters = filters
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }

    struct SavedSearchAlert {
        let search: SavedSearch
        let newMatches: [ThreadData]
    }

    private struct SavedSearchState: Codable {
        var isPrimed: Bool
        var lastSeenThreadNumbersByBoard: [String: [String]]
        var lastCheckedAt: Date?

        init(isPrimed: Bool = false, lastSeenThreadNumbersByBoard: [String: [String]] = [:], lastCheckedAt: Date? = nil) {
            self.isPrimed = isPrimed
            self.lastSeenThreadNumbersByBoard = lastSeenThreadNumbersByBoard
            self.lastCheckedAt = lastCheckedAt
        }
    }
    
    // MARK: - Properties
    private var searchHistory: [SearchItem] = []
    private var savedSearches: [SavedSearch] = []
    private var savedSearchStates: [String: SavedSearchState] = [:]
    private let allBoardsMaxConcurrentRequests = 4
    private let allBoardsThrottleInterval: TimeInterval = 0.15
    private let parsingQueue = DispatchQueue(label: "com.channer.searchManager.catalogParsing", qos: .userInitiated)
    private let catalogThrottleQueue = DispatchQueue(label: "com.channer.searchManager.catalogThrottle")
    private var nextCatalogRequestTime = Date.distantPast
    private let htmlStripRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: [])
    private let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: [])
    
    // MARK: - Initialization
    private init() {
        loadSearchHistory()
        loadSavedSearches()
        loadSavedSearchStates()
        pruneSavedSearchStates()
    }
    
    // MARK: - iCloud Availability Check
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // MARK: - Search History Management
    func addToHistory(_ query: String, boardAbv: String? = nil) {
        let cleanedQuery = sanitizedQuery(query)
        let normalizedBoard = normalizedBoardAbv(boardAbv)
        guard !cleanedQuery.isEmpty else { return }
        let searchItem = SearchItem(query: cleanedQuery, boardAbv: normalizedBoard)
        let queryKey = normalizedQuery(cleanedQuery)
        
        // Remove duplicate if exists
        searchHistory.removeAll {
            normalizedQuery($0.query) == queryKey && normalizedBoardAbv($0.boardAbv) == normalizedBoard
        }
        
        // Add new search at the beginning
        searchHistory.insert(searchItem, at: 0)
        
        // Limit history to 100 items
        if searchHistory.count > 100 {
            searchHistory = Array(searchHistory.prefix(100))
        }
        
        saveSearchHistory()
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    func getSearchHistory() -> [SearchItem] {
        return searchHistory
    }
    
    func removeFromHistory(_ id: String) {
        searchHistory.removeAll { $0.id == id }
        saveSearchHistory()
    }
    
    // MARK: - Saved Searches Management
    func saveSearch(_ query: String, name: String? = nil, boardAbv: String? = nil, filters: SearchFilters? = nil) -> SavedSearch {
        let cleanedQuery = sanitizedQuery(query)
        let normalizedBoard = normalizedBoardAbv(boardAbv)
        let normalizedFilters = filters?.normalized()
        let searchName = name ?? cleanedQuery
        let savedSearch = SavedSearch(name: searchName, query: cleanedQuery, boardAbv: normalizedBoard, filters: normalizedFilters)
        let queryKey = normalizedQuery(cleanedQuery)
        
        // Remove duplicate if exists
        let duplicates = savedSearches.filter {
            normalizedQuery($0.query) == queryKey && normalizedBoardAbv($0.boardAbv) == normalizedBoard
        }
        savedSearches.removeAll {
            normalizedQuery($0.query) == queryKey && normalizedBoardAbv($0.boardAbv) == normalizedBoard
        }
        if let existing = duplicates.first,
           let existingState = savedSearchStates[existing.id],
           existing.filters == savedSearch.filters {
            savedSearchStates[savedSearch.id] = existingState
        } else {
            savedSearchStates[savedSearch.id] = SavedSearchState()
        }
        for duplicate in duplicates {
            savedSearchStates.removeValue(forKey: duplicate.id)
        }
        
        savedSearches.insert(savedSearch, at: 0)
        saveSavedSearches()
        saveSavedSearchStates()
        
        return savedSearch
    }
    
    func updateSavedSearch(_ search: SavedSearch) {
        if let index = savedSearches.firstIndex(where: { $0.id == search.id }) {
            let existing = savedSearches[index]
            var updatedSearch = search
            updatedSearch.updatedAt = Date()
            savedSearches[index] = updatedSearch
            if normalizedQuery(existing.query) != normalizedQuery(search.query)
                || normalizedBoardAbv(existing.boardAbv) != normalizedBoardAbv(search.boardAbv)
                || existing.filters != search.filters {
                savedSearchStates[search.id] = SavedSearchState()
            }
            saveSavedSearches()
            saveSavedSearchStates()
        }
    }
    
    func deleteSavedSearch(_ id: String) {
        savedSearches.removeAll { $0.id == id }
        savedSearchStates.removeValue(forKey: id)
        saveSavedSearches()
        saveSavedSearchStates()
    }
    
    func getSavedSearches() -> [SavedSearch] {
        return savedSearches
    }
    
    func isSavedSearch(_ query: String, boardAbv: String? = nil) -> Bool {
        let queryKey = normalizedQuery(query)
        let normalizedBoard = normalizedBoardAbv(boardAbv)
        return savedSearches.contains {
            normalizedQuery($0.query) == queryKey && normalizedBoardAbv($0.boardAbv) == normalizedBoard
        }
    }
    
    // MARK: - Persistence Methods
    private func saveSearchHistory() {
        if let encoded = try? JSONEncoder().encode(searchHistory) {
            if isICloudAvailable() {
                iCloudStore.set(encoded, forKey: searchHistoryKey)
            } else {
                UserDefaults.standard.set(encoded, forKey: searchHistoryKey)
            }
        }
    }
    
    private func loadSearchHistory() {
        if isICloudAvailable() {
            if let data = iCloudStore.data(forKey: searchHistoryKey),
               let history = try? JSONDecoder().decode([SearchItem].self, from: data) {
                searchHistory = history
            }
        } else {
            if let data = UserDefaults.standard.data(forKey: searchHistoryKey),
               let history = try? JSONDecoder().decode([SearchItem].self, from: data) {
                searchHistory = history
            }
        }
    }
    
    private func saveSavedSearches() {
        if let encoded = try? JSONEncoder().encode(savedSearches) {
            if isICloudAvailable() {
                iCloudStore.set(encoded, forKey: savedSearchesKey)
            } else {
                UserDefaults.standard.set(encoded, forKey: savedSearchesKey)
            }
        }
    }
    
    private func loadSavedSearches() {
        if isICloudAvailable() {
            if let data = iCloudStore.data(forKey: savedSearchesKey),
               let searches = try? JSONDecoder().decode([SavedSearch].self, from: data) {
                savedSearches = searches
            }
        } else {
            if let data = UserDefaults.standard.data(forKey: savedSearchesKey),
               let searches = try? JSONDecoder().decode([SavedSearch].self, from: data) {
                savedSearches = searches
            }
        }
    }

    private func saveSavedSearchStates() {
        if let encoded = try? JSONEncoder().encode(savedSearchStates) {
            if isICloudAvailable() {
                iCloudStore.set(encoded, forKey: savedSearchStatesKey)
            } else {
                UserDefaults.standard.set(encoded, forKey: savedSearchStatesKey)
            }
        }
    }

    private func loadSavedSearchStates() {
        if isICloudAvailable() {
            if let data = iCloudStore.data(forKey: savedSearchStatesKey),
               let states = try? JSONDecoder().decode([String: SavedSearchState].self, from: data) {
                savedSearchStates = states
            }
        } else {
            if let data = UserDefaults.standard.data(forKey: savedSearchStatesKey),
               let states = try? JSONDecoder().decode([String: SavedSearchState].self, from: data) {
                savedSearchStates = states
            }
        }
    }

    private func pruneSavedSearchStates() {
        let validIds = Set(savedSearches.map { $0.id })
        savedSearchStates = savedSearchStates.filter { validIds.contains($0.key) }
    }
    
    // MARK: - Search Execution
    func performSearch(
        query: String,
        boardAbv: String?,
        filters: SearchFilters? = nil,
        recordHistory: Bool = true,
        progress: ((SearchProgress) -> Void)? = nil,
        completion: @escaping ([ThreadData]) -> Void
    ) {
        let cleanedQuery = sanitizedQuery(query)
        let normalizedBoard = normalizedBoardAbv(boardAbv)
        let normalizedFilters = filters?.normalized()
        guard !cleanedQuery.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        if recordHistory {
            addToHistory(cleanedQuery, boardAbv: normalizedBoard)
        }
        
        // If no board specified, we need to search all boards
        if let board = normalizedBoard {
            searchBoard(board: board, query: cleanedQuery, filters: normalizedFilters) { results in
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        } else {
            searchAllBoards(query: cleanedQuery, filters: normalizedFilters, progress: progress, completion: completion)
        }
    }

    // MARK: - Saved Search Alerts
    func checkSavedSearchesForAlerts(
        progress: ((SearchProgress) -> Void)? = nil,
        completion: @escaping ([SavedSearchAlert]) -> Void
    ) {
        let searches = savedSearches
        guard !searches.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let needsAllBoards = searches.contains { normalizedBoardAbv($0.boardAbv) == nil }

        if needsAllBoards {
            DispatchQueue.main.async {
                progress?(SearchProgress(phase: .loadingBoards, completedBoards: 0, totalBoards: 0, currentBoard: nil))
            }
            ensureBoardsLoaded { [weak self] boards in
                guard let self = self else { return }
                self.fetchCatalogs(for: boards, progress: progress) { catalogsByBoard in
                    let alerts = self.buildSavedSearchAlerts(searches: searches, catalogsByBoard: catalogsByBoard)
                    self.saveSavedSearchStates()
                    DispatchQueue.main.async { completion(alerts) }
                }
            }
        } else {
            let boards = Array(Set(searches.compactMap { normalizedBoardAbv($0.boardAbv) }))
            fetchCatalogs(for: boards, progress: progress) { [weak self] catalogsByBoard in
                guard let self = self else { return }
                let alerts = self.buildSavedSearchAlerts(searches: searches, catalogsByBoard: catalogsByBoard)
                self.saveSavedSearchStates()
                DispatchQueue.main.async { completion(alerts) }
            }
        }
    }

    private func searchAllBoards(
        query: String,
        filters: SearchFilters?,
        progress: ((SearchProgress) -> Void)?,
        completion: @escaping ([ThreadData]) -> Void
    ) {
        let queryKey = normalizedQuery(query)
        guard !queryKey.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        DispatchQueue.main.async {
            progress?(SearchProgress(phase: .loadingBoards, completedBoards: 0, totalBoards: 0, currentBoard: nil))
        }

        ensureBoardsLoaded { [weak self] boards in
            guard let self = self else { return }
            guard !boards.isEmpty else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            self.fetchCatalogs(for: boards, progress: progress) { catalogsByBoard in
                var allResults: [ThreadData] = []
                allResults.reserveCapacity(128)

                for threads in catalogsByBoard.values {
                    allResults.append(contentsOf: self.filterThreads(threads, normalizedQuery: queryKey, filters: filters))
                }

                DispatchQueue.main.async {
                    completion(allResults)
                }
            }
        }
    }

    private func fetchCatalogs(
        for boards: [String],
        progress: ((SearchProgress) -> Void)?,
        completion: @escaping ([String: [ThreadData]]) -> Void
    ) {
        var seenBoards = Set<String>()
        let orderedBoards = boards.filter { seenBoards.insert($0).inserted }
        let totalBoards = orderedBoards.count
        guard totalBoards > 0 else {
            completion([:])
            return
        }

        DispatchQueue.main.async {
            progress?(SearchProgress(phase: .searching, completedBoards: 0, totalBoards: totalBoards, currentBoard: nil))
        }

        let semaphore = DispatchSemaphore(value: allBoardsMaxConcurrentRequests)
        let group = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "com.channer.searchManager.catalogResults")
        var catalogsByBoard: [String: [ThreadData]] = [:]
        var completedBoards = 0

        DispatchQueue.global(qos: .userInitiated).async {
            for board in orderedBoards {
                group.enter()
                semaphore.wait()
                self.enqueueThrottledCatalogRequest { [weak self] in
                    guard let self = self else {
                        semaphore.signal()
                        group.leave()
                        return
                    }
                    self.fetchCatalog(for: board) { threads in
                        resultsQueue.async {
                            catalogsByBoard[board] = threads
                            completedBoards += 1
                            let progressPayload = SearchProgress(
                                phase: .searching,
                                completedBoards: completedBoards,
                                totalBoards: totalBoards,
                                currentBoard: board
                            )
                            DispatchQueue.main.async {
                                progress?(progressPayload)
                            }
                            semaphore.signal()
                            group.leave()
                        }
                    }
                }
            }

            group.notify(queue: self.parsingQueue) {
                completion(catalogsByBoard)
            }
        }
    }

    private func enqueueThrottledCatalogRequest(_ work: @escaping () -> Void) {
        catalogThrottleQueue.async {
            let now = Date()
            let scheduledStart = max(now, self.nextCatalogRequestTime)
            let delay = scheduledStart.timeIntervalSince(now)
            self.nextCatalogRequestTime = scheduledStart.addingTimeInterval(self.allBoardsThrottleInterval)
            if delay > 0 {
                self.catalogThrottleQueue.asyncAfter(deadline: .now() + delay) {
                    work()
                }
            } else {
                work()
            }
        }
    }

    private func fetchCatalog(for board: String, completion: @escaping ([ThreadData]) -> Void) {
        let catalogURL = "https://a.4cdn.org/\(board)/catalog.json"

        AF.request(catalogURL).responseData(queue: parsingQueue) { response in
            switch response.result {
            case .success(let data):
                completion(self.parseCatalogData(data, board: board))
            case .failure:
                completion([])
            }
        }
    }

    private func parseCatalogData(_ data: Data, board: String) -> [ThreadData] {
        guard let json = try? JSON(data: data) else { return [] }
        var threads: [ThreadData] = []
        threads.reserveCapacity(128)
        var bumpIndex = 0

        for page in json.arrayValue {
            for thread in page["threads"].arrayValue {
                let replies = thread["replies"].intValue
                let images = thread["images"].intValue
                let stats = "\(replies)/\(images)"
                let title = thread["sub"].stringValue
                let comment = thread["com"].stringValue
                let createdAt = thread["now"].stringValue
                let lastReplyTime = thread["last_modified"].int

                var imageUrl = ""
                if let tim = thread["tim"].int64,
                   let ext = thread["ext"].string {
                    imageUrl = "https://i.4cdn.org/\(board)/\(tim)\(ext)"
                }

                let threadData = ThreadData(
                    number: String(thread["no"].intValue),
                    stats: stats,
                    title: title,
                    comment: comment,
                    imageUrl: imageUrl,
                    boardAbv: board,
                    replies: replies,
                    currentReplies: nil,
                    createdAt: createdAt,
                    hasNewReplies: false,
                    categoryId: nil,
                    lastReplyTime: lastReplyTime,
                    bumpIndex: bumpIndex
                )
                threads.append(threadData)
                bumpIndex += 1
            }
        }
        return threads
    }

    private func filterThreads(_ threads: [ThreadData], normalizedQuery: String, filters: SearchFilters?) -> [ThreadData] {
        guard !normalizedQuery.isEmpty else { return [] }
        let activeFilters = filters?.normalized()
        return threads.filter { thread in
            let searchText = normalizedSearchText(title: thread.title, comment: thread.comment)
            guard searchText.contains(normalizedQuery) else { return false }
            if let activeFilters = activeFilters, activeFilters.isActive {
                return activeFilters.matches(thread: thread)
            }
            return true
        }
    }

    private func normalizedSearchText(title: String, comment: String) -> String {
        let raw = "\(title) \(comment)"
        let stripped: String
        if let regex = htmlStripRegex {
            let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            stripped = regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: " ")
        } else {
            stripped = raw
        }

        let decoded = stripped
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return decoded.lowercased()
    }

    private func buildSavedSearchAlerts(
        searches: [SavedSearch],
        catalogsByBoard: [String: [ThreadData]]
    ) -> [SavedSearchAlert] {
        var alerts: [SavedSearchAlert] = []
        alerts.reserveCapacity(searches.count)

        for search in searches {
            let queryKey = normalizedQuery(search.query)
            let boards: [String]
            if let board = normalizedBoardAbv(search.boardAbv) {
                boards = [board]
            } else {
                boards = Array(catalogsByBoard.keys)
            }

            var state = savedSearchStates[search.id] ?? SavedSearchState()
            var lastSeen = state.lastSeenThreadNumbersByBoard
            var newMatches: [ThreadData] = []

            for board in boards {
                guard let threads = catalogsByBoard[board] else { continue }
                let matches = filterThreads(threads, normalizedQuery: queryKey, filters: search.filters)

                if state.isPrimed {
                    let previous = Set(lastSeen[board] ?? [])
                    newMatches.append(contentsOf: matches.filter { !previous.contains($0.number) })
                }

                lastSeen[board] = threads.map { $0.number }
            }

            state.isPrimed = true
            state.lastSeenThreadNumbersByBoard = lastSeen
            state.lastCheckedAt = Date()
            savedSearchStates[search.id] = state

            if !newMatches.isEmpty {
                alerts.append(SavedSearchAlert(search: search, newMatches: newMatches))
            }
        }

        return alerts
    }

    private func ensureBoardsLoaded(completion: @escaping ([String]) -> Void) {
        let existing = BoardsService.shared.boardAbv
        if !existing.isEmpty {
            completion(existing)
            return
        }

        BoardsService.shared.fetchBoards {
            completion(BoardsService.shared.boardAbv)
        }
    }
    
    func searchBoard(board: String, query: String, filters: SearchFilters? = nil, completion: @escaping ([ThreadData]) -> Void) {
        let queryKey = normalizedQuery(query)
        let normalizedBoard = normalizedBoardAbv(board) ?? board
        guard !queryKey.isEmpty else {
            completion([])
            return
        }

        let catalogURL = "https://a.4cdn.org/\(normalizedBoard)/catalog.json"

        AF.request(catalogURL).responseData(queue: parsingQueue) { response in
            switch response.result {
            case .success(let data):
                let threads = self.parseCatalogData(data, board: normalizedBoard)
                completion(self.filterThreads(threads, normalizedQuery: queryKey, filters: filters))
            case .failure:
                completion([])
            }
        }
    }

    private func normalizedBoardAbv(_ boardAbv: String?) -> String? {
        guard let trimmed = boardAbv?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func sanitizedQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = whitespaceRegex else { return trimmed }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: " ")
    }

    private func normalizedQuery(_ query: String) -> String {
        return sanitizedQuery(query).lowercased()
    }
}
