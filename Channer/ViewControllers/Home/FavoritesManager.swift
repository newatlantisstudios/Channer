import Foundation
import Alamofire
import SwiftyJSON

// FavoritesManager handles saving/loading operations
class FavoritesManager {
    
    // MARK: - Singleton Instance
    /// Shared instance of FavoritesManager for global access
    static let shared = FavoritesManager()
    
    // MARK: - Persistence Methods
    /// Loads the list of favorite threads from UserDefaults
    func loadFavorites() -> [ThreadData] {
        guard let data = UserDefaults.standard.data(forKey: "favorites"),
              let favorites = try? JSONDecoder().decode([ThreadData].self, from: data) else {
            print("No favorites found.")
            return []
        }
        return favorites
    }
    
    /// Saves the list of favorite threads to UserDefaults
    func saveFavorites(_ favorites: [ThreadData]) {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "favorites")
            print("Favorites successfully saved to UserDefaults.")
        } else {
            print("Failed to encode favorites.")
        }
    }
    
    // MARK: - Favorite Management
    /// Adds a thread to the favorites list
    func addFavorite(_ favorite: ThreadData) {
        //print("Adding favorite: \(favorite)")
        var favorites = loadFavorites()
        favorites.append(favorite)
        saveFavorites(favorites)
        //print("Favorites after adding: \(favorites)")
    }
    
    /// Removes a thread from the favorites list by its number
    func removeFavorite(threadNumber: String) {
        print("FavoritesManager - removeFavorite")
        var favorites = loadFavorites()
        favorites.removeAll { $0.number == threadNumber }
        saveFavorites(favorites)
    }
    
    /// Checks if a thread is in the favorites list
    func isFavorited(threadNumber: String) -> Bool {
        return loadFavorites().contains { $0.number == threadNumber }
    }
    
    // MARK: - Verification Methods
    /// Verifies all favorite threads by checking if they still exist and removes invalid ones
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
    
    /// Updates the latest reply counts for all favorite threads by fetching the current data from the server.
    /// This ensures that each thread's `currentReplies` reflects the most up-to-date count.
    /// The updated reply counts can be used to indicate whether there are new replies since the thread was last viewed.
    func updateCurrentReplies(completion: @escaping () -> Void) {
        var favorites = loadFavorites()
        
        for (index, favorite) in favorites.enumerated() {
            fetchLatestReplyCount(for: favorite.number, boardAbv: favorite.boardAbv) { latestCount in
                favorites[index].currentReplies = latestCount
                
                // Save the updated favorites after all threads are processed
                if index == favorites.count - 1 {
                    self.saveFavorites(favorites)
                    completion()
                }
            }
        }
    }
        
    /// Fetches the latest reply count for a given thread from the server.
    /// - Parameters:
    ///   - threadID: The unique identifier of the thread.
    ///   - boardAbv: The abbreviation of the board where the thread resides.
    ///   - completion: A closure that receives the latest reply count as an integer.
    /// If the fetch or parsing fails, the closure returns a default value of 0.
    private func fetchLatestReplyCount(for threadID: String, boardAbv: String, completion: @escaping (Int) -> Void) {
        let url = "https://a.4cdn.org/\(boardAbv)/thread/\(threadID).json"
        
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                if let json = try? JSON(data: data),
                   let firstPost = json["posts"].array?.first {
                    let latestReplies = firstPost["replies"].intValue // Extract latest replies count
                    completion(latestReplies)
                } else {
                    print("Error: Unable to parse reply count for thread \(threadID).")
                    completion(0) // Default to 0 if parsing fails
                }
            case .failure(let error):
                print("Error fetching reply count for thread \(threadID): \(error.localizedDescription)")
                completion(0) // Default to 0 on failure
            }
        }
    }
    
    // MARK: - Favorite Management (continued)
    /// Updates a favorite thread's data in the list
    func updateFavorite(thread: ThreadData) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == thread.number }) {
            favorites[index] = thread
            saveFavorites(favorites)
        }
    }
    
    func markThreadAsSeen(threadID: String) {
        var favorites = loadFavorites() // Load the list of favorites
        if let index = favorites.firstIndex(where: { $0.number == threadID }) {
            if let currentReplies = favorites[index].currentReplies {
                favorites[index].replies = currentReplies // Update replies to match currentReplies
                saveFavorites(favorites) // Persist changes to UserDefaults
            } else {
                print("Error: currentReplies is nil for thread \(threadID).")
            }
        }
    }
    
}
