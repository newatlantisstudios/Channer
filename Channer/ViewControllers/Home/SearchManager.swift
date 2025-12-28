import Foundation
import Alamofire
import SwiftyJSON
import UIKit

class SearchManager {
    
    // MARK: - Singleton Instance
    static let shared = SearchManager()
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let searchHistoryKey = "searchHistory"
    private let savedSearchesKey = "savedSearches"
    
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
        let createdAt: Date
        var updatedAt: Date
        
        init(name: String, query: String, boardAbv: String? = nil) {
            self.id = UUID().uuidString
            self.name = name
            self.query = query
            self.boardAbv = boardAbv
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    
    // MARK: - Properties
    private var searchHistory: [SearchItem] = []
    private var savedSearches: [SavedSearch] = []
    
    // MARK: - Initialization
    private init() {
        loadSearchHistory()
        loadSavedSearches()
    }
    
    // MARK: - iCloud Availability Check
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // MARK: - Search History Management
    func addToHistory(_ query: String, boardAbv: String? = nil) {
        let searchItem = SearchItem(query: query, boardAbv: boardAbv)
        
        // Remove duplicate if exists
        searchHistory.removeAll { $0.query.lowercased() == query.lowercased() && $0.boardAbv == boardAbv }
        
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
    func saveSearch(_ query: String, name: String? = nil, boardAbv: String? = nil) -> SavedSearch {
        let searchName = name ?? query
        let savedSearch = SavedSearch(name: searchName, query: query, boardAbv: boardAbv)
        
        // Remove duplicate if exists
        savedSearches.removeAll { $0.query.lowercased() == query.lowercased() && $0.boardAbv == boardAbv }
        
        savedSearches.insert(savedSearch, at: 0)
        saveSavedSearches()
        
        return savedSearch
    }
    
    func updateSavedSearch(_ search: SavedSearch) {
        if let index = savedSearches.firstIndex(where: { $0.id == search.id }) {
            var updatedSearch = search
            updatedSearch.updatedAt = Date()
            savedSearches[index] = updatedSearch
            saveSavedSearches()
        }
    }
    
    func deleteSavedSearch(_ id: String) {
        savedSearches.removeAll { $0.id == id }
        saveSavedSearches()
    }
    
    func getSavedSearches() -> [SavedSearch] {
        return savedSearches
    }
    
    func isSavedSearch(_ query: String, boardAbv: String? = nil) -> Bool {
        return savedSearches.contains { $0.query.lowercased() == query.lowercased() && $0.boardAbv == boardAbv }
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
    
    // MARK: - Search Execution
    func performSearch(query: String, boardAbv: String?, completion: @escaping ([ThreadData]) -> Void) {
        addToHistory(query, boardAbv: boardAbv)
        
        // If no board specified, we need to search all boards
        if let board = boardAbv {
            searchBoard(board: board, query: query, completion: completion)
        } else {
            // For now, just return empty results for all boards search
            // A full implementation would need to search across multiple boards
            completion([])
        }
    }
    
    func searchBoard(board: String, query: String, completion: @escaping ([ThreadData]) -> Void) {
        let catalogURL = "https://a.4cdn.org/\(board)/catalog.json"
        
        AF.request(catalogURL).responseData { response in
            switch response.result {
            case .success(let data):
                if let json = try? JSON(data: data) {
                    var matchingThreads: [ThreadData] = []
                    
                    // Parse catalog pages
                    for page in json.arrayValue {
                        for thread in page["threads"].arrayValue {
                            // Search in title and comment text
                            let title = thread["sub"].stringValue
                            let comment = thread["com"].stringValue
                            let searchText = "\(title) \(comment)".lowercased()
                            
                            if searchText.contains(query.lowercased()) {
                                let replies = thread["replies"].intValue
                                let images = thread["images"].intValue
                                let stats = "\(replies)/\(images)"
                                
                                var imageUrl = ""
                                if let tim = thread["tim"].int64,
                                   let ext = thread["ext"].string {
                                    imageUrl = "https://i.4cdn.org/\(board)/\(tim)\(ext)"
                                }
                                
                                let threadData = ThreadData(
                                    number: String(thread["no"].intValue),
                                    stats: stats,
                                    title: title.isEmpty ? "No title" : title,
                                    comment: comment,
                                    imageUrl: imageUrl,
                                    boardAbv: board,
                                    replies: replies,
                                    createdAt: thread["now"].stringValue
                                )
                                
                                matchingThreads.append(threadData)
                            }
                        }
                    }
                    
                    completion(matchingThreads)
                } else {
                    completion([])
                }
            case .failure:
                completion([])
            }
        }
    }
}