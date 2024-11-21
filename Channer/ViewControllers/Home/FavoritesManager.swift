import Foundation
import Alamofire
import SwiftyJSON

// FavoritesManager handles saving/loading operations
class FavoritesManager {
    static let shared = FavoritesManager()

    func loadFavorites() -> [ThreadData] {
        guard let data = UserDefaults.standard.data(forKey: "favorites"),
              let favorites = try? JSONDecoder().decode([ThreadData].self, from: data) else {
            print("No favorites found.")
            return []
        }
        return favorites
    }

    func saveFavorites(_ favorites: [ThreadData]) {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "favorites")
            print("Favorites successfully saved to UserDefaults.")
        } else {
            print("Failed to encode favorites.")
        }
    }
    
    func addFavorite(_ favorite: ThreadData) {
        //print("Adding favorite: \(favorite)")
        var favorites = loadFavorites()
        favorites.append(favorite)
        saveFavorites(favorites)
        //print("Favorites after adding: \(favorites)")
    }

    func removeFavorite(threadNumber: String) {
        print("FavoritesManager - removeFavorite")
        var favorites = loadFavorites()
        favorites.removeAll { $0.number == threadNumber }
        saveFavorites(favorites)
    }

    func isFavorited(threadNumber: String) -> Bool {
        return loadFavorites().contains { $0.number == threadNumber }
    }
    
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
    
    func updateFavorite(thread: ThreadData) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(where: { $0.number == thread.number }) {
            favorites[index] = thread
            saveFavorites(favorites)
        }
    }
    
}
