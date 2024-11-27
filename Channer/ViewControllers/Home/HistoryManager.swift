import Foundation
import Alamofire
import SwiftyJSON

class HistoryManager {
    
    // MARK: - Singleton Instance
    /// Shared instance of `HistoryManager` for global access.
    static let shared = HistoryManager()
    
    // MARK: - Properties
    /// Key used for saving and retrieving history from `UserDefaults`.
    private let historyKey = "threadHistory"
    
    /// Array to store the history of threads.
    private(set) var history: [ThreadData] = []
    
    // MARK: - Initialization
    /// Private initializer to enforce singleton pattern and load history upon creation.
    private init() {
        loadHistory()
    }
    
    // MARK: - History Management Methods
    /// Adds a thread to the history if it doesn't already exist.
    /// - Parameter thread: The `ThreadData` object to be added.
    func addThreadToHistory(_ thread: ThreadData) {
        // Avoid duplicates
        if !history.contains(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
            history.append(thread)
            saveHistory()
        }
    }
    
    /// Removes a thread from the history.
    /// - Parameter thread: The `ThreadData` object to be removed.
    func removeThreadFromHistory(_ thread: ThreadData) {
        history.removeAll { $0.number == thread.number && $0.boardAbv == thread.boardAbv }
        saveHistory()
    }
    
    /// Clears all threads from the history.
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    /// Retrieves all threads from the history.
    /// - Returns: An array of `ThreadData` objects.
    func getHistoryThreads() -> [ThreadData] {
        return history
    }
    
    // MARK: - Persistence Methods
    /// Saves the current history to `UserDefaults`.
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    /// Loads the history from `UserDefaults`.
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let savedHistory = try? JSONDecoder().decode([ThreadData].self, from: data) {
            history = savedHistory
        }
    }
    
    // MARK: - Validation Methods
    /// Verifies each thread in the history and removes invalid ones.
    /// - Parameter completion: Closure called with the array of valid `ThreadData` objects.
    func verifyAndRemoveInvalidHistory(completion: @escaping ([ThreadData]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var validHistory: [ThreadData] = []

        for thread in history {
            dispatchGroup.enter()
            let url = "https://a.4cdn.org/\(thread.boardAbv)/thread/\(thread.number).json"
            
            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }
                switch response.result {
                case .success(let data):
                    if let json = try? JSON(data: data), let _ = json["posts"].array?.first {
                        validHistory.append(thread)
                    } else {
                        self.removeThreadFromHistory(thread)
                    }
                case .failure:
                    self.removeThreadFromHistory(thread)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(validHistory)
        }
    }
}
