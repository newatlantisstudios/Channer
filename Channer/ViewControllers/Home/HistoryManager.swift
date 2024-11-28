import Foundation
import Alamofire
import SwiftyJSON

class HistoryManager {
    
    // MARK: - Singleton Instance
    /// Shared instance of `HistoryManager` for global access.
    static let shared = HistoryManager()
    
    // MARK: - Properties
    /// Key used for saving and retrieving history from `NSUbiquitousKeyValueStore` or `UserDefaults`.
    private let historyKey = "threadHistory"
    private let iCloudFallbackWarningKey = "iCloudFallbackWarningShown"
    
    /// Array to store the history of threads.
    private(set) var history: [ThreadData] = []
    
    /// iCloud Key-Value Store
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    
    // MARK: - Initialization
    /// Private initializer to enforce singleton pattern and load history upon creation.
    private init() {
        loadHistory()
    }
    
    // MARK: - iCloud Availability Check
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // MARK: - History Management Methods
    /// Adds a thread to the history if it doesn't already exist.
    /// - Parameter thread: The `ThreadData` object to be added.
    func addThreadToHistory(_ thread: ThreadData) {
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
    /// Saves the current history to iCloud or local storage.
    private func saveHistory() {
        if let encodedData = try? JSONEncoder().encode(history) {
            if isICloudAvailable() {
                print("Saving history to iCloud.")
                iCloudStore.set(encodedData, forKey: historyKey)
                iCloudStore.synchronize()
            } else {
                print("Saving history to local storage.")
                UserDefaults.standard.set(encodedData, forKey: historyKey)
                showICloudFallbackWarning()
            }
        } else {
            print("Failed to encode history.")
        }
    }
    
    /// Loads the history from iCloud or local storage.
    private func loadHistory() {
        if isICloudAvailable() {
            print("Loading history from iCloud.")
            if let data = iCloudStore.data(forKey: historyKey),
               let savedHistory = try? JSONDecoder().decode([ThreadData].self, from: data) {
                history = savedHistory
            } else {
                print("No history found in iCloud.")
            }
        } else {
            print("Loading history from local storage.")
            if let data = UserDefaults.standard.data(forKey: historyKey),
               let savedHistory = try? JSONDecoder().decode([ThreadData].self, from: data) {
                history = savedHistory
            } else {
                print("No history found locally.")
            }
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
    
    // MARK: - iCloud Fallback Warning
    /// Warns the user only once if iCloud is unavailable and the app falls back to local storage.
    private func showICloudFallbackWarning() {
        let hasShownWarning = UserDefaults.standard.bool(forKey: iCloudFallbackWarningKey)
        if !hasShownWarning {
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "iCloud Sync Unavailable",
                    message: "You're not signed into iCloud. History is being saved locally. Sign in to iCloud to enable syncing across devices.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let rootViewController = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    rootViewController.present(alert, animated: true, completion: nil)
                }
            }
            UserDefaults.standard.set(true, forKey: iCloudFallbackWarningKey)
        }
    }
}
