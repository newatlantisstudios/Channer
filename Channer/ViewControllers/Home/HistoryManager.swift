import Foundation
import Alamofire
import SwiftyJSON
import UIKit

class HistoryManager {
    
    // MARK: - Singleton Instance
    /// Shared instance of `HistoryManager` for global access.
    static let shared = HistoryManager()
    
    // MARK: - Properties
    /// Key used for saving and retrieving history from storage.
    private let historyKey = "threadHistory"
    private let iCloudFallbackWarningKey = "iCloudFallbackWarningShown"
    
    /// Array to store the history of threads.
    private(set) var history: [ThreadData] = []
    
    // MARK: - Initialization
    /// Private initializer to enforce singleton pattern and load history upon creation.
    private init() {
        loadHistory()
        setupiCloudObserver()
        // Migrate local data to iCloud if needed
        ICloudSyncManager.shared.migrateLocalDataToiCloud()
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
        loadHistory()
        NotificationCenter.default.post(name: Notification.Name("HistoryUpdated"), object: nil)
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
        let success = ICloudSyncManager.shared.save(history, forKey: historyKey)
        
        if success {
            print("History successfully saved.")
        } else {
            print("Failed to save history.")
            showICloudFallbackWarning()
        }
    }
    
    /// Loads the history from iCloud or local storage.
    private func loadHistory() {
        // Load from iCloud/local storage using the sync manager
        let loadedHistory = ICloudSyncManager.shared.load([ThreadData].self, forKey: historyKey) ?? []
        history = loadedHistory
        
        print("Loaded \(history.count) history items")
    }
    
    // MARK: - Validation Methods
    /// Verifies each thread in the history, updates stats with fresh data, and removes invalid ones.
    /// - Parameter completion: Closure called with the array of valid `ThreadData` objects with updated stats.
    func verifyAndRemoveInvalidHistory(completion: @escaping ([ThreadData]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var updatedHistory: [ThreadData] = []
        let serialQueue = DispatchQueue(label: "com.channer.historyValidation")

        for thread in history {
            dispatchGroup.enter()
            let url = "https://a.4cdn.org/\(thread.boardAbv)/thread/\(thread.number).json"

            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }
                switch response.result {
                case .success(let data):
                    if let json = try? JSON(data: data), let firstPost = json["posts"].array?.first {
                        // Update thread with fresh stats from API
                        let freshReplies = firstPost["replies"].intValue
                        let freshImages = firstPost["images"].intValue
                        let freshStats = "\(freshReplies)/\(freshImages)"

                        var updatedThread = thread
                        updatedThread.stats = freshStats

                        serialQueue.sync {
                            updatedHistory.append(updatedThread)
                        }
                    } else {
                        // Keep thread in history even if it no longer exists
                        serialQueue.sync {
                            updatedHistory.append(thread)
                        }
                    }
                case .failure:
                    // Keep thread in history even if the API request fails
                    serialQueue.sync {
                        updatedHistory.append(thread)
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            // Update stored history with fresh stats where available
            self.history = updatedHistory
            self.saveHistory()
            completion(updatedHistory)
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
    
    // MARK: - iCloud Sync Support
    func getAllHistoryForSync() -> [(boardAbv: String, threadNumber: String, visitDate: Date)] {
        return history.map { (boardAbv: $0.boardAbv, threadNumber: $0.number, visitDate: Date()) }
    }
    
    func syncHistoryFromICloud(boardAbv: String, threadNumber: String, visitDate: Date) {
        // Check if history item already exists locally
        if !history.contains(where: { $0.number == threadNumber && $0.boardAbv == boardAbv }) {
            // Create a basic ThreadData object for the synced history item
            let thread = ThreadData(
                number: threadNumber,
                stats: "0/0",
                title: "",
                comment: "",
                imageUrl: "",
                boardAbv: boardAbv,
                replies: 0,
                createdAt: ""
            )
            history.append(thread)
            saveHistory()
        }
    }
}
