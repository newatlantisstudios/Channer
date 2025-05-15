import Foundation
import Alamofire
import SwiftyJSON

class FavoritesManager {
    
    // MARK: - Singleton Instance
    static let shared = FavoritesManager()
    let iCloudStore = NSUbiquitousKeyValueStore.default
    private let favoritesKey = "favorites"
    
    // MARK: - Persistence Methods
    func loadFavorites() -> [ThreadData] {
        // Check if iCloud is available
        if isICloudAvailable() {
            print("Loading favorites from iCloud.")
            printICloudStoreContents()
            guard let data = iCloudStore.data(forKey: favoritesKey),
                  let favorites = try? JSONDecoder().decode([ThreadData].self, from: data) else {
                print("No favorites found in iCloud.")
                return []
            }
            return favorites
        } else {
            print("Loading favorites from local storage.")
            guard let data = UserDefaults.standard.data(forKey: favoritesKey),
                  let favorites = try? JSONDecoder().decode([ThreadData].self, from: data) else {
                print("No favorites found locally.")
                return []
            }
            return favorites
        }
    }

    func saveFavorites(_ favorites: [ThreadData]) {
        if let encoded = try? JSONEncoder().encode(favorites) {
            if isICloudAvailable() {
                print("Saving favorites to iCloud.")
                printICloudStoreContents()
                iCloudStore.set(encoded, forKey: favoritesKey)
                iCloudStore.synchronize()
            } else {
                print("Saving favorites to local storage.")
                UserDefaults.standard.set(encoded, forKey: favoritesKey)
                showICloudFallbackWarning() // Warn the user once
            }
            print("Favorites successfully saved.")
        } else {
            print("Failed to encode favorites.")
        }
    }

    // MARK: - iCloud Availability Check
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
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
        var favorites = loadFavorites()
        favorites.append(favorite)
        saveFavorites(favorites)
    }
    
    func removeFavorite(threadNumber: String) {
        var favorites = loadFavorites()
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
    
    func printICloudStoreContents() {
        print("NSUbiquitousKeyValueStore contents:")

        // Print all key-value pairs in the iCloud store
        for (key, value) in iCloudStore.dictionaryRepresentation {
            print("\(key): \(value)")
        }

        // Attempt to decode favorites if the key exists
        if let data = iCloudStore.data(forKey: favoritesKey) {
            do {
                let favorites = try JSONDecoder().decode([ThreadData].self, from: data)
                print("Favorites in iCloud:")
                for favorite in favorites {
                    print("Board: \(favorite.boardAbv), Thread Number: \(favorite.number), Replies: \(favorite.currentReplies ?? 0)")
                }
            } catch {
                print("Failed to decode favorites from iCloud: \(error)")
            }
        } else {
            print("No favorites found in iCloud.")
        }
    }
    
}
