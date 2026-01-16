import Foundation
import Alamofire
import SwiftyJSON
import UIKit

// Inline BookmarkCategory definition until files are added to project
struct BookmarkCategory: Codable, Equatable {
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

    // MARK: - Thread Safety
    private let syncQueue = DispatchQueue(label: "com.channer.favoritesmanager.sync", attributes: .concurrent)

    // MARK: - Category Properties
    private var categories: [BookmarkCategory] = []

    // MARK: - Performance: In-memory cache for favorites
    private var favoritesCache: [ThreadData]?
    private var favoriteNumbersCache: Set<String>?

    init() {
        loadCategories()
        setupiCloudObserver()
        // Pre-load favorites cache
        _ = loadFavorites()
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
        // Invalidate cache and reload data when iCloud sync completes
        invalidateCache()
        loadCategories()
        NotificationCenter.default.post(name: Notification.Name("FavoritesUpdated"), object: nil)
    }

    /// Invalidates the in-memory cache, forcing next load to read from storage
    private func invalidateCache() {
        favoritesCache = nil
        favoriteNumbersCache = nil
    }
    
    // MARK: - Persistence Methods
    func loadFavorites() -> [ThreadData] {
        // Performance: Return cached favorites if available
        if let cached = favoritesCache {
            return cached
        }

        print("=== loadFavorites called (cache miss) ===")

        // Load from iCloud/local storage using the sync manager
        let cloudFavorites = ICloudSyncManager.shared.load([ThreadData].self, forKey: favoritesKey) ?? []

        print("Loaded \(cloudFavorites.count) favorites")

        // Update cache
        favoritesCache = cloudFavorites
        favoriteNumbersCache = Set(cloudFavorites.map { $0.number })

        return cloudFavorites
    }

    func saveFavorites(_ favorites: [ThreadData]) {
        print("=== saveFavorites called ===")
        print("Saving \(favorites.count) favorites")

        // Update cache immediately for fast reads
        favoritesCache = favorites
        favoriteNumbersCache = Set(favorites.map { $0.number })

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

    private func matchesFavorite(_ favorite: ThreadData, threadNumber: String, boardAbv: String?) -> Bool {
        guard let boardAbv = boardAbv else {
            return favorite.number == threadNumber
        }
        return favorite.number == threadNumber && favorite.boardAbv == boardAbv
    }
    
    func removeFavorite(threadNumber: String, boardAbv: String? = nil) {
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            let favoritesToRemove = favorites.filter { self.matchesFavorite($0, threadNumber: threadNumber, boardAbv: boardAbv) }
            guard !favoritesToRemove.isEmpty else { return }

            for favorite in favoritesToRemove {
                ThreadCacheManager.shared.removeFromCache(
                    boardAbv: favorite.boardAbv,
                    threadNumber: favorite.number
                )
            }

            favorites.removeAll { self.matchesFavorite($0, threadNumber: threadNumber, boardAbv: boardAbv) }
            self.saveFavorites(favorites)
        }
    }
    
    func isFavorited(threadNumber: String, boardAbv: String? = nil) -> Bool {
        if let boardAbv = boardAbv {
            if let cached = favoritesCache {
                return cached.contains { $0.number == threadNumber && $0.boardAbv == boardAbv }
            }
            return loadFavorites().contains { $0.number == threadNumber && $0.boardAbv == boardAbv }
        }

        // Performance: Use Set cache for O(1) lookup
        if let cachedNumbers = favoriteNumbersCache {
            return cachedNumbers.contains(threadNumber)
        }
        // Fallback: load and check (will populate cache)
        return loadFavorites().contains { $0.number == threadNumber }
    }
    
    func updateFavorite(thread: ThreadData) {
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            if let index = favorites.firstIndex(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
                favorites[index] = thread
                self.saveFavorites(favorites)
            }
        }
    }
    
    func markThreadHasNewReplies(threadNumber: String) {
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            if let index = favorites.firstIndex(where: { $0.number == threadNumber }) {
                var updatedThread = favorites[index]
                updatedThread.hasNewReplies = true
                favorites[index] = updatedThread
                self.saveFavorites(favorites)
            }
        }
    }
    
    func clearNewRepliesFlag(threadNumber: String) {
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            if let index = favorites.firstIndex(where: { $0.number == threadNumber }) {
                var updatedThread = favorites[index]
                updatedThread.hasNewReplies = false
                favorites[index] = updatedThread
                self.saveFavorites(favorites)
            }
        }
    }
    
    // MARK: - Verification Methods
    func verifyAndRemoveInvalidFavorites(completion: @escaping ([ThreadData]) -> Void) {
        let favorites = loadFavorites()
        DispatchQueue.main.async {
            completion(favorites)
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
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            if let index = favorites.firstIndex(where: { $0.number == threadID }) {
                if let currentReplies = favorites[index].currentReplies {
                    favorites[index].replies = currentReplies
                    self.saveFavorites(favorites)
                } else {
                    print("Error: currentReplies is nil for thread \(threadID).")
                }
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
        if !isFavorited(threadNumber: threadNumber, boardAbv: boardAbv) {
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
        syncQueue.sync(flags: .barrier) {
            // Move all threads from this category to the default category
            var favorites = self.loadFavorites()
            for i in 0..<favorites.count {
                if favorites[i].categoryId == id {
                    favorites[i].categoryId = self.categories.first?.id
                }
            }
            self.saveFavorites(favorites)

            // Remove the category
            self.categories.removeAll { $0.id == id }
            self.saveCategories()
        }
    }
    
    func getCategories() -> [BookmarkCategory] {
        return categories
    }
    
    func getCategory(by id: String) -> BookmarkCategory? {
        return categories.first { $0.id == id }
    }

    func setDefaultCategory(id: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }), index > 0 else {
            return // Already default or not found
        }
        let category = categories.remove(at: index)
        categories.insert(category, at: 0)
        saveCategories()
    }
    
    // MARK: - Enhanced Favorite Management
    func addFavorite(_ favorite: ThreadData, to categoryId: String? = nil) {
        syncQueue.sync(flags: .barrier) {
            print("=== addFavorite called ===")
            print("Thread number: \(favorite.number)")
            print("Board: \(favorite.boardAbv)")
            print("Target category ID: \(categoryId ?? "nil")")
            print("Thread: \(Thread.current)")

            var favorites = self.loadFavorites()
            print("Current favorites count before add: \(favorites.count)")

            var newFavorite = favorite
            newFavorite.categoryId = categoryId ?? self.categories.first?.id

            print("Actual category ID assigned: \(newFavorite.categoryId ?? "nil")")

            favorites.append(newFavorite)
            print("Favorites count after append: \(favorites.count)")

            self.saveFavorites(favorites)
            print("Saved favorites. Final count: \(favorites.count)")

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
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            if let index = favorites.firstIndex(where: { $0.number == threadNumber }) {
                let favorite = favorites[index]
                favorites[index].categoryId = categoryId
                self.saveFavorites(favorites)

                // Update cached thread category if it exists
                ThreadCacheManager.shared.updateCachedThreadCategory(
                    boardAbv: favorite.boardAbv,
                    threadNumber: threadNumber,
                    categoryId: categoryId
                )
            }
        }
    }
    
    private func migrateExistingFavorites() {
        syncQueue.sync(flags: .barrier) {
            var favorites = self.loadFavorites()
            var needsSave = false

            print("Migrating favorites. Found \(favorites.count) favorites")
            print("First category ID: \(self.categories.first?.id ?? "none")")

            for i in 0..<favorites.count {
                let currentCategoryId = favorites[i].categoryId
                print("Thread \(favorites[i].number) current category: \(currentCategoryId ?? "nil")")

                if currentCategoryId == nil || currentCategoryId!.isEmpty {
                    favorites[i].categoryId = self.categories.first?.id
                    needsSave = true
                    print("Migrated thread \(favorites[i].number) to category \(favorites[i].categoryId ?? "nil")")
                } else {
                    print("Thread \(favorites[i].number) already has category \(currentCategoryId ?? "nil")")
                }
            }

            if needsSave {
                self.saveFavorites(favorites)
                print("Migration complete - saved favorites")
            } else {
                print("No migration needed")
            }
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
