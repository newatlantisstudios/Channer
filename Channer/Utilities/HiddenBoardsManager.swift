import Foundation

/// Manages hidden boards that should not be displayed on the Home Screen
/// Uses UserDefaults for persistence with iCloud sync support
class HiddenBoardsManager {

    // MARK: - Singleton
    static let shared = HiddenBoardsManager()

    // MARK: - Constants
    private let hiddenBoardsKey = "channer_hidden_boards"

    // MARK: - Notification
    static let hiddenBoardsChangedNotification = Notification.Name("HiddenBoardsChangedNotification")

    // MARK: - Properties
    private var hiddenBoardCodes: Set<String> = []
    private let queue = DispatchQueue(label: "com.channer.hiddenboards", attributes: .concurrent)

    // MARK: - Initialization
    private init() {
        loadHiddenBoards()

        // Register for iCloud sync changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Returns an array of hidden board codes
    var hiddenBoards: [String] {
        return queue.sync {
            Array(hiddenBoardCodes)
        }
    }

    /// Returns the count of hidden boards
    var hiddenBoardsCount: Int {
        return queue.sync {
            hiddenBoardCodes.count
        }
    }

    /// Checks if a board is hidden
    /// - Parameter boardCode: The board code to check (e.g., "g", "pol")
    /// - Returns: True if the board is hidden
    func isBoardHidden(_ boardCode: String) -> Bool {
        return queue.sync {
            hiddenBoardCodes.contains(boardCode)
        }
    }

    /// Hides a board from the Home Screen
    /// - Parameter boardCode: The board code to hide
    func hideBoard(_ boardCode: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.hiddenBoardCodes.insert(boardCode)
            self.saveHiddenBoards()

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HiddenBoardsManager.hiddenBoardsChangedNotification, object: nil)
            }
        }
    }

    /// Shows a previously hidden board on the Home Screen
    /// - Parameter boardCode: The board code to show
    func showBoard(_ boardCode: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.hiddenBoardCodes.remove(boardCode)
            self.saveHiddenBoards()

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HiddenBoardsManager.hiddenBoardsChangedNotification, object: nil)
            }
        }
    }

    /// Toggles the hidden state of a board
    /// - Parameter boardCode: The board code to toggle
    func toggleBoard(_ boardCode: String) {
        if isBoardHidden(boardCode) {
            showBoard(boardCode)
        } else {
            hideBoard(boardCode)
        }
    }

    /// Shows all hidden boards (clears the hidden list)
    func showAllBoards() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.hiddenBoardCodes.removeAll()
            self.saveHiddenBoards()

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: HiddenBoardsManager.hiddenBoardsChangedNotification, object: nil)
            }
        }
    }

    /// Filters board arrays to exclude hidden boards
    /// - Parameters:
    ///   - boardNames: Array of board names
    ///   - boardCodes: Array of board codes (abbreviations)
    /// - Returns: Tuple of filtered (names, codes) arrays
    func filterHiddenBoards(boardNames: [String], boardCodes: [String]) -> (names: [String], codes: [String]) {
        return queue.sync {
            var filteredNames: [String] = []
            var filteredCodes: [String] = []

            for (index, code) in boardCodes.enumerated() {
                if !hiddenBoardCodes.contains(code) {
                    if index < boardNames.count {
                        filteredNames.append(boardNames[index])
                        filteredCodes.append(code)
                    }
                }
            }

            return (filteredNames, filteredCodes)
        }
    }

    // MARK: - Private Methods

    private func loadHiddenBoards() {
        if let savedBoards = UserDefaults.standard.array(forKey: hiddenBoardsKey) as? [String] {
            hiddenBoardCodes = Set(savedBoards)
        }
    }

    private func saveHiddenBoards() {
        let boardsArray = Array(hiddenBoardCodes)
        UserDefaults.standard.set(boardsArray, forKey: hiddenBoardsKey)

        // Also sync to iCloud if available
        if ICloudSyncManager.shared.isICloudAvailable {
            NSUbiquitousKeyValueStore.default.set(boardsArray, forKey: hiddenBoardsKey)
        }
    }

    @objc private func iCloudDataDidChange(_ notification: Notification) {
        // Check if our key was changed
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              changedKeys.contains(hiddenBoardsKey) else {
            return
        }

        // Reload from iCloud
        if let cloudBoards = NSUbiquitousKeyValueStore.default.array(forKey: hiddenBoardsKey) as? [String] {
            queue.async(flags: .barrier) { [weak self] in
                self?.hiddenBoardCodes = Set(cloudBoards)

                // Also update local storage
                UserDefaults.standard.set(cloudBoards, forKey: self?.hiddenBoardsKey ?? "")

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: HiddenBoardsManager.hiddenBoardsChangedNotification, object: nil)
                }
            }
        }
    }
}
