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
        print("[ChannerThreadLoadDebug][HistoryManager] addThreadToHistory start board=/\(thread.boardAbv)/ thread=\(thread.number) currentCount=\(history.count)")
        if !history.contains(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
            print("[ChannerThreadLoadDebug][HistoryManager] addThreadToHistory appending and saving board=/\(thread.boardAbv)/ thread=\(thread.number)")
            history.append(thread)
            saveHistory()
            print("[ChannerThreadLoadDebug][HistoryManager] addThreadToHistory saved board=/\(thread.boardAbv)/ thread=\(thread.number) newCount=\(history.count)")
        } else {
            print("[ChannerThreadLoadDebug][HistoryManager] addThreadToHistory skipped duplicate board=/\(thread.boardAbv)/ thread=\(thread.number)")
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

struct ThreadScrollPosition: Codable, Equatable {
    let boardAbv: String
    let threadNumber: String
    let postNumber: String?
    let itemIndex: Int
    let offsetWithinItem: Double
    let contentOffsetY: Double
    let updatedAt: Date
}

class ThreadScrollPositionManager {
    static let shared = ThreadScrollPositionManager()

    private let positionsKey = "threadScrollPositions"
    private let maxStoredPositions = 250
    private let defaults: UserDefaults
    private var positions: [String: ThreadScrollPosition] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadPositions()
    }

    func savePosition(
        boardAbv: String,
        threadNumber: String,
        postNumber: String?,
        itemIndex: Int,
        offsetWithinItem: CGFloat,
        contentOffsetY: CGFloat
    ) {
        guard !boardAbv.isEmpty, !threadNumber.isEmpty else { return }

        let position = ThreadScrollPosition(
            boardAbv: boardAbv,
            threadNumber: threadNumber,
            postNumber: postNumber,
            itemIndex: max(0, itemIndex),
            offsetWithinItem: Double(max(0, offsetWithinItem)),
            contentOffsetY: Double(contentOffsetY),
            updatedAt: Date()
        )

        positions[key(boardAbv: boardAbv, threadNumber: threadNumber)] = position
        pruneOldPositionsIfNeeded()
        persistPositions()
    }

    func position(boardAbv: String, threadNumber: String) -> ThreadScrollPosition? {
        guard !boardAbv.isEmpty, !threadNumber.isEmpty else { return nil }
        return positions[key(boardAbv: boardAbv, threadNumber: threadNumber)]
    }

    func removePosition(boardAbv: String, threadNumber: String) {
        positions.removeValue(forKey: key(boardAbv: boardAbv, threadNumber: threadNumber))
        persistPositions()
    }

    func removeAllPositions() {
        positions.removeAll()
        persistPositions()
    }

    private func key(boardAbv: String, threadNumber: String) -> String {
        "\(boardAbv)/\(threadNumber)"
    }

    private func loadPositions() {
        guard let data = defaults.data(forKey: positionsKey),
              let savedPositions = try? JSONDecoder().decode([String: ThreadScrollPosition].self, from: data) else {
            positions = [:]
            return
        }

        positions = savedPositions
    }

    private func persistPositions() {
        guard let data = try? JSONEncoder().encode(positions) else { return }
        defaults.set(data, forKey: positionsKey)
    }

    private func pruneOldPositionsIfNeeded() {
        guard positions.count > maxStoredPositions else { return }

        let keysToRemove = positions
            .sorted { $0.value.updatedAt < $1.value.updatedAt }
            .prefix(positions.count - maxStoredPositions)
            .map(\.key)

        for key in keysToRemove {
            positions.removeValue(forKey: key)
        }
    }
}

struct ThreadReadState: Codable, Equatable {
    let boardAbv: String
    let threadNumber: String
    var knownPostNumbers: [String]
    var unreadPostNumbers: Set<String>
    var lastReadPostNumber: String?
    var boardPage: Int?
    var purgePosition: Int?
    var replyCount: Int?
    var imageCount: Int?
    var prunedPostNumbers: Set<String>
    var updatedAt: Date
}

class ThreadReadStateManager {
    static let shared = ThreadReadStateManager()
    static let unreadCountDidChangeNotification = Notification.Name("ThreadReadStateUnreadCountDidChange")

    private let statesKey = "threadReadStates"
    private let maxStoredStates = 500
    private let defaults: UserDefaults
    private var states: [String: ThreadReadState] = [:]
    private let lock = NSLock()
    private let persistenceQueue = DispatchQueue(label: "com.channer.threadReadState.persistence", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadStates()
    }

    @discardableResult
    func updateThread(
        boardAbv: String,
        threadNumber: String,
        postNumbers: [String],
        boardPage: Int? = nil,
        purgePosition: Int? = nil,
        replyCount: Int? = nil,
        imageCount: Int? = nil
    ) -> ThreadReadState {
        let debugPrefix = "[ChannerThreadLoadDebug][ThreadReadStateManager board=/\(boardAbv)/ thread=\(threadNumber)]"
        print("\(debugPrefix) updateThread start posts=\(postNumbers.count)")

        let state: ThreadReadState
        let statesSnapshot: [String: ThreadReadState]
        lock.lock()
        print("\(debugPrefix) updateThread acquired lock")

        let stateKey = key(boardAbv: boardAbv, threadNumber: threadNumber)
        var updatedState = states[stateKey] ?? ThreadReadState(
            boardAbv: boardAbv,
            threadNumber: threadNumber,
            knownPostNumbers: [],
            unreadPostNumbers: [],
            lastReadPostNumber: nil,
            boardPage: nil,
            purgePosition: nil,
            replyCount: nil,
            imageCount: nil,
            prunedPostNumbers: [],
            updatedAt: Date()
        )

        let known = Set(updatedState.knownPostNumbers)
        let newPosts = postNumbers.filter { !known.contains($0) }
        if !updatedState.knownPostNumbers.isEmpty {
            updatedState.unreadPostNumbers.formUnion(newPosts)
        }

        let currentPosts = Set(postNumbers)
        updatedState.unreadPostNumbers = updatedState.unreadPostNumbers.intersection(currentPosts)
        updatedState.prunedPostNumbers = updatedState.prunedPostNumbers.intersection(currentPosts)
        updatedState.knownPostNumbers = postNumbers
        updatedState.boardPage = boardPage ?? updatedState.boardPage
        updatedState.purgePosition = purgePosition ?? updatedState.purgePosition
        updatedState.replyCount = replyCount ?? updatedState.replyCount
        updatedState.imageCount = imageCount ?? updatedState.imageCount
        updatedState.updatedAt = Date()

        states[stateKey] = updatedState
        pruneOldStatesIfNeeded()
        state = updatedState
        statesSnapshot = states
        lock.unlock()

        print("\(debugPrefix) updateThread released lock unread=\(state.unreadPostNumbers.count) known=\(state.knownPostNumbers.count); scheduling persist")
        persistStatesAsync(statesSnapshot, context: "updateThread \(boardAbv)/\(threadNumber)")
        postUnreadCountDidChange()
        print("\(debugPrefix) updateThread returning")
        return state
    }

    func state(boardAbv: String, threadNumber: String) -> ThreadReadState? {
        lock.lock()
        defer { lock.unlock() }
        return states[key(boardAbv: boardAbv, threadNumber: threadNumber)]
    }

    func markReadThrough(boardAbv: String, threadNumber: String, postNumber: String) {
        lock.lock()
        defer { lock.unlock() }

        let stateKey = key(boardAbv: boardAbv, threadNumber: threadNumber)
        guard var state = states[stateKey] else { return }

        if let index = state.knownPostNumbers.firstIndex(of: postNumber) {
            let readPosts = Set(state.knownPostNumbers.prefix(through: index))
            state.unreadPostNumbers.subtract(readPosts)
        } else {
            state.unreadPostNumbers.remove(postNumber)
        }

        state.lastReadPostNumber = postNumber
        state.updatedAt = Date()
        states[stateKey] = state
        persistStates()
        postUnreadCountDidChange()
    }

    func markUnread(boardAbv: String, threadNumber: String, postNumbers: [String]) {
        guard !postNumbers.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        let stateKey = key(boardAbv: boardAbv, threadNumber: threadNumber)
        guard var state = states[stateKey] else { return }
        state.unreadPostNumbers.formUnion(postNumbers)
        state.unreadPostNumbers = state.unreadPostNumbers.intersection(Set(state.knownPostNumbers))
        state.updatedAt = Date()
        states[stateKey] = state
        persistStates()
        postUnreadCountDidChange()
    }

    func setPrunedPostNumbers(_ postNumbers: Set<String>, boardAbv: String, threadNumber: String) {
        lock.lock()
        defer { lock.unlock() }

        let stateKey = key(boardAbv: boardAbv, threadNumber: threadNumber)
        guard var state = states[stateKey] else { return }
        state.prunedPostNumbers = postNumbers.intersection(Set(state.knownPostNumbers))
        state.updatedAt = Date()
        states[stateKey] = state
        persistStates()
    }

    func unreadCount(boardAbv: String, threadNumber: String) -> Int {
        state(boardAbv: boardAbv, threadNumber: threadNumber)?.unreadPostNumbers.count ?? 0
    }

    func totalUnreadCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return states.values.reduce(0) { $0 + $1.unreadPostNumbers.count }
    }

    private func key(boardAbv: String, threadNumber: String) -> String {
        "\(boardAbv)/\(threadNumber)"
    }

    private func loadStates() {
        guard let data = defaults.data(forKey: statesKey),
              let savedStates = try? JSONDecoder().decode([String: ThreadReadState].self, from: data) else {
            states = [:]
            return
        }
        states = savedStates
    }

    private func persistStates() {
        guard let data = try? JSONEncoder().encode(states) else { return }
        defaults.set(data, forKey: statesKey)
    }

    private func persistStatesAsync(_ statesSnapshot: [String: ThreadReadState], context: String) {
        persistenceQueue.async { [defaults, statesKey] in
            let startedAt = Date()
            guard let data = try? JSONEncoder().encode(statesSnapshot) else {
                print("[ChannerThreadLoadDebug][ThreadReadStateManager] persist failed context=\(context)")
                return
            }
            defaults.set(data, forKey: statesKey)
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startedAt))
            print("[ChannerThreadLoadDebug][ThreadReadStateManager] persist complete context=\(context) states=\(statesSnapshot.count) bytes=\(data.count) elapsed=\(elapsed)s")
        }
    }

    private func pruneOldStatesIfNeeded() {
        guard states.count > maxStoredStates else { return }

        let keysToRemove = states
            .sorted { $0.value.updatedAt < $1.value.updatedAt }
            .prefix(states.count - maxStoredStates)
            .map(\.key)

        for key in keysToRemove {
            states.removeValue(forKey: key)
        }
    }

    private func postUnreadCountDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.unreadCountDidChangeNotification, object: nil)
        }
    }
}
