import Foundation
import Alamofire
import SwiftyJSON
import UIKit

// Inline BookmarkCategory definition until files are added to project
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

class FavoritesManager {
    
    // MARK: - Singleton Instance
    static let shared = FavoritesManager()
    private let favoritesKey = "favorites"
    private let categoriesKey = "bookmarkCategories"
    
    // MARK: - Category Properties
    private var categories: [BookmarkCategory] = []
    
    init() {
        loadCategories()
        setupiCloudObserver()
        // Migrate local data to iCloud if needed and sync is enabled
        if UserDefaults.standard.bool(forKey: "channer_icloud_sync_enabled") {
            ICloudSyncManager.shared.migrateLocalDataToiCloud()
        }
    }
    
    // MARK: - iCloud Observer
    private func setupiCloudObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataChanged),
            name: ICloudSyncManager.iCloudSyncCompletedNotification,
            object: nil
        )
    }
    
    @objc private func iCloudDataChanged() {
        // Reload data when iCloud sync completes
        loadCategories()
        NotificationCenter.default.post(name: Notification.Name("FavoritesUpdated"), object: nil)
    }
    
    // MARK: - Persistence Methods
    func loadFavorites() -> [ThreadData] {
        print("=== loadFavorites called ===")
        
        // Load from iCloud/local storage using the sync manager
        let cloudFavorites = ICloudSyncManager.shared.load([ThreadData].self, forKey: favoritesKey) ?? []
        
        print("Loaded \(cloudFavorites.count) favorites")
        for (index, favorite) in cloudFavorites.enumerated() {
            print("Favorite \(index): Thread \(favorite.number) - Category: \(favorite.categoryId ?? "nil")")
        }
        
        return cloudFavorites
    }

    func saveFavorites(_ favorites: [ThreadData]) {
        print("=== saveFavorites called ===")
        print("Saving \(favorites.count) favorites")
        
        for (index, favorite) in favorites.enumerated() {
            print("Favorite \(index): Thread \(favorite.number) - Category: \(favorite.categoryId ?? "nil")")
        }
        
        // Save using the sync manager
        let success = ICloudSyncManager.shared.save(favorites, forKey: favoritesKey)
        
        if success {
            print("Favorites successfully saved.")
        } else {
            print("Failed to save favorites.")
            showICloudFallbackWarning()
        }
    }


    // MARK: - Warn User About iCloud Fallback
    private func showICloudFallbackWarning() {
        let hasShownWarning = UserDefaults.standard.bool(forKey: "iCloudFallbackWarningShown")
        if !hasShownWarning {
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "iCloud Sync Unavailable",
                    message: "You're not signed into iCloud. Favorites are being saved locally. Sign in to iCloud to enable syncing across devices.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let rootViewController = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    rootViewController.present(alert, animated: true, completion: nil)
                }
            }
            UserDefaults.standard.set(true, forKey: "iCloudFallbackWarningShown")
        }
    }
    
    // MARK: - Favorite Management
    func addFavorite(_ favorite: ThreadData) {
        addFavorite(favorite, to: nil)
    }
    
    func removeFavorite(threadNumber: String) {
        var favorites = loadFavorites()
        
        // Find the favorite to get its board info before removing
        if let favorite = favorites.first(where: { $0.number == threadNumber }) {
            // Remove from offline cache
            ThreadCacheManager.shared.removeFromCache(
                boardAbv: favorite.boardAbv,
                threadNumber: threadNumber
            )
        }
        
        favorites.removeAll { $0.number == threadNumber }
        saveFavorites(favorites)
    }
    
    func isFavorited(threadNumber: String) -> Bool {
        return loadFavorites().contains { $0.number == threadNumber }
    }
    
    func updateFavorite(thread: ThreadData) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == thread.number }) {
            favorites[index] = thread
            saveFavorites(favorites)
        }
    }
    
    func markThreadHasNewReplies(threadNumber: String) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == threadNumber }) {
            var updatedThread = favorites[index]
            updatedThread.hasNewReplies = true
            favorites[index] = updatedThread
            saveFavorites(favorites)
        }
    }
    
    func clearNewRepliesFlag(threadNumber: String) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == threadNumber }) {
            var updatedThread = favorites[index]
            updatedThread.hasNewReplies = false
            favorites[index] = updatedThread
            saveFavorites(favorites)
        }
    }
    
    // MARK: - Verification Methods
    func verifyAndRemoveInvalidFavorites(completion: @escaping ([ThreadData]) -> Void) {
        let favorites = loadFavorites()
        let dispatchGroup = DispatchGroup()
        var validFavorites: [ThreadData] = []

        for favorite in favorites {
            dispatchGroup.enter()
            let url = "https://a.4cdn.org/\(favorite.boardAbv)/thread/\(favorite.number).json"
            
            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }
                switch response.result {
                case .success(let data):
                    if let json = try? JSON(data: data),
                       let firstPost = json["posts"].array?.first {
                        var threadData = favorite
                        threadData.currentReplies = firstPost["replies"].intValue
                        threadData.stats = "\(firstPost["replies"].intValue)/\(firstPost["images"].intValue)"
                        validFavorites.append(threadData)
                    } else {
                        self.removeFavorite(threadNumber: favorite.number)
                    }
                case .failure:
                    self.removeFavorite(threadNumber: favorite.number)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(validFavorites)
        }
    }
    
    func updateCurrentReplies(completion: @escaping () -> Void) {
        var favorites = loadFavorites()
        
        for (index, favorite) in favorites.enumerated() {
            fetchLatestReplyCount(for: favorite.number, boardAbv: favorite.boardAbv) { latestCount in
                favorites[index].currentReplies = latestCount
                
                if index == favorites.count - 1 {
                    self.saveFavorites(favorites)
                    completion()
                }
            }
        }
    }
    
    private func fetchLatestReplyCount(for threadID: String, boardAbv: String, completion: @escaping (Int) -> Void) {
        let url = "https://a.4cdn.org/\(boardAbv)/thread/\(threadID).json"
        
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                if let json = try? JSON(data: data),
                   let firstPost = json["posts"].array?.first {
                    let latestReplies = firstPost["replies"].intValue
                    completion(latestReplies)
                } else {
                    completion(0)
                }
            case .failure:
                completion(0)
            }
        }
    }
    
    // MARK: - Additional Methods
    func markThreadAsSeen(threadID: String) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == threadID }) {
            if let currentReplies = favorites[index].currentReplies {
                favorites[index].replies = currentReplies
                saveFavorites(favorites)
            } else {
                print("Error: currentReplies is nil for thread \(threadID).")
            }
        }
    }
    
    // MARK: - iCloud Sync Support
    func getAllFavoritesForSync() -> [(boardAbv: String, threadNumber: String, dateAdded: Date)] {
        let favorites = loadFavorites()
        return favorites.map { (boardAbv: $0.boardAbv, threadNumber: $0.number, dateAdded: Date()) }
    }
    
    func syncFavoriteFromICloud(boardAbv: String, threadNumber: String) {
        // Check if favorite already exists locally
        if !isFavorited(threadNumber: threadNumber) {
            // Create a basic ThreadData object for the synced favorite
            let thread = ThreadData(
                number: threadNumber,
                stats: "0/0",
                title: "",
                comment: "",
                imageUrl: "",
                boardAbv: boardAbv,
                replies: 0,
                createdAt: "",
                categoryId: categories.first?.id
            )
            addFavorite(thread)
        }
    }
    
    
    // MARK: - Category Management
    func loadCategories() {
        // Load categories using the sync manager
        if let loadedCategories = ICloudSyncManager.shared.load([BookmarkCategory].self, forKey: categoriesKey) {
            categories = loadedCategories
            print("Loaded \(categories.count) categories")
        }
        
        // Ensure at least one default category exists
        if categories.isEmpty {
            createDefaultCategories()
        }
        
        // Migrate existing favorites to default category if they don't have one
        migrateExistingFavorites()
    }
    
    func saveCategories() {
        let success = ICloudSyncManager.shared.save(categories, forKey: categoriesKey)
        if success {
            print("Categories successfully saved.")
        } else {
            print("Failed to save categories.")
        }
    }
    
    func createDefaultCategories() {
        let defaultCategories = [
            BookmarkCategory(name: "General", color: "#007AFF", icon: "folder"),
            BookmarkCategory(name: "To Read", color: "#34C759", icon: "bookmark"),
            BookmarkCategory(name: "Important", color: "#FF3B30", icon: "exclamationmark.circle"),
            BookmarkCategory(name: "Archives", color: "#8E8E93", icon: "archivebox")
        ]
        categories = defaultCategories
        saveCategories()
    }
    
    func createCategory(name: String, color: String, icon: String) -> BookmarkCategory {
        let category = BookmarkCategory(name: name, color: color, icon: icon)
        categories.append(category)
        saveCategories()
        return category
    }
    
    func updateCategory(_ category: BookmarkCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }
    
    func deleteCategory(id: String) {
        // Move all threads from this category to the default category
        var favorites = loadFavorites()
        for i in 0..<favorites.count {
            if favorites[i].categoryId == id {
                favorites[i].categoryId = categories.first?.id
            }
        }
        saveFavorites(favorites)
        
        // Remove the category
        categories.removeAll { $0.id == id }
        saveCategories()
    }
    
    func getCategories() -> [BookmarkCategory] {
        return categories
    }
    
    func getCategory(by id: String) -> BookmarkCategory? {
        return categories.first { $0.id == id }
    }
    
    // MARK: - Enhanced Favorite Management
    func addFavorite(_ favorite: ThreadData, to categoryId: String? = nil) {
        print("=== addFavorite called ===")
        print("Thread number: \(favorite.number)")
        print("Board: \(favorite.boardAbv)")
        print("Target category ID: \(categoryId ?? "nil")")
        
        var favorites = loadFavorites()
        var newFavorite = favorite
        newFavorite.categoryId = categoryId ?? categories.first?.id
        
        print("Actual category ID assigned: \(newFavorite.categoryId ?? "nil")")
        
        favorites.append(newFavorite)
        saveFavorites(favorites)
        
        // Automatically cache the thread for offline reading
        ThreadCacheManager.shared.cacheThread(
            boardAbv: newFavorite.boardAbv,
            threadNumber: newFavorite.number,
            categoryId: newFavorite.categoryId
        ) { success in
            if success {
                print("Thread automatically cached for offline reading")
            } else {
                print("Failed to cache thread for offline reading")
            }
        }
        
        print("Added favorite with category: \(newFavorite.categoryId ?? "nil")")
        print("Total favorites after add: \(favorites.count)")
    }
    
    func getFavorites(for categoryId: String? = nil) -> [ThreadData] {
        let allFavorites = loadFavorites()
        print("All favorites count: \(allFavorites.count)")
        if let categoryId = categoryId {
            let filtered = allFavorites.filter { $0.categoryId == categoryId }
            print("Filtering for category ID \(categoryId): found \(filtered.count) matches")
            for favorite in allFavorites {
                print("Thread \(favorite.number) has category: \(favorite.categoryId ?? "nil")")
            }
            return filtered
        }
        return allFavorites
    }
    
    func changeFavoriteCategory(threadNumber: String, to categoryId: String) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == threadNumber }) {
            let favorite = favorites[index]
            favorites[index].categoryId = categoryId
            saveFavorites(favorites)
            
            // Update cached thread category if it exists
            ThreadCacheManager.shared.updateCachedThreadCategory(
                boardAbv: favorite.boardAbv,
                threadNumber: threadNumber,
                categoryId: categoryId
            )
        }
    }
    
    private func migrateExistingFavorites() {
        var favorites = loadFavorites()
        var needsSave = false
        
        print("Migrating favorites. Found \(favorites.count) favorites")
        print("First category ID: \(categories.first?.id ?? "none")")
        
        for i in 0..<favorites.count {
            let currentCategoryId = favorites[i].categoryId
            print("Thread \(favorites[i].number) current category: \(currentCategoryId ?? "nil")")
            
            if currentCategoryId == nil || currentCategoryId!.isEmpty {
                favorites[i].categoryId = categories.first?.id
                needsSave = true
                print("Migrated thread \(favorites[i].number) to category \(favorites[i].categoryId ?? "nil")")
            } else {
                print("Thread \(favorites[i].number) already has category \(currentCategoryId ?? "nil")")
            }
        }
        
        if needsSave {
            saveFavorites(favorites)
            print("Migration complete - saved favorites")
        } else {
            print("No migration needed")
        }
    }
    
    // MARK: - Offline Caching Methods
    
    /// Caches all existing favorites for offline reading
    func cacheAllFavorites(completion: @escaping (Int, Int) -> Void) {
        let favorites = loadFavorites()
        var successCount = 0
        var failureCount = 0
        let dispatchGroup = DispatchGroup()
        
        for favorite in favorites {
            dispatchGroup.enter()
            
            ThreadCacheManager.shared.cacheThread(
                boardAbv: favorite.boardAbv,
                threadNumber: favorite.number,
                categoryId: favorite.categoryId
            ) { success in
                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(successCount, failureCount)
        }
    }
    
    /// Checks if all favorites are cached for offline reading
    func checkFavoritesCacheStatus(completion: @escaping (Int, Int) -> Void) {
        let favorites = loadFavorites()
        var cachedCount = 0
        var uncachedCount = 0
        
        for favorite in favorites {
            if ThreadCacheManager.shared.isCached(boardAbv: favorite.boardAbv, threadNumber: favorite.number) {
                cachedCount += 1
            } else {
                uncachedCount += 1
            }
        }
        
        completion(cachedCount, uncachedCount)
    }
    
}
