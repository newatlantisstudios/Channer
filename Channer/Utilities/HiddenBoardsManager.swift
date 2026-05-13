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

/// Manages boards pinned to the top of the Home Screen board list.
/// Pins are scoped by imageboard site so common board codes like /b/ do not
/// affect other sites.
class PinnedBoardsManager {

    // MARK: - Singleton
    static let shared = PinnedBoardsManager()

    // MARK: - Constants
    private let pinnedBoardsKey = "channer_pinned_boards"

    // MARK: - Notification
    static let pinnedBoardsChangedNotification = Notification.Name("PinnedBoardsChangedNotification")

    // MARK: - Properties
    private var pinnedBoardIDs: Set<String> = []
    private let queue = DispatchQueue(label: "com.channer.pinnedboards", attributes: .concurrent)

    // MARK: - Initialization
    private init() {
        loadPinnedBoards()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudSyncCompleted),
            name: ICloudSyncManager.iCloudSyncCompletedNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    func isBoardPinned(_ boardCode: String, siteID: String = BoardsService.shared.selectedSite.id) -> Bool {
        let id = pinnedID(siteID: siteID, boardCode: boardCode)
        return queue.sync {
            pinnedBoardIDs.contains(id)
        }
    }

    func toggleBoard(_ boardCode: String, siteID: String = BoardsService.shared.selectedSite.id) {
        let id = pinnedID(siteID: siteID, boardCode: boardCode)
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.pinnedBoardIDs.contains(id) {
                self.pinnedBoardIDs.remove(id)
            } else {
                self.pinnedBoardIDs.insert(id)
            }
            self.savePinnedBoards()
            self.postPinnedBoardsChanged()
        }
    }

    func orderBoards(boardNames: [String], boardCodes: [String], siteID: String = BoardsService.shared.selectedSite.id) -> (names: [String], codes: [String]) {
        return queue.sync {
            let combinedBoards = zip(boardNames, boardCodes).map { (name: $0.0, code: $0.1) }

            let sortedBoards = combinedBoards.sorted { lhs, rhs in
                let lhsPinned = pinnedBoardIDs.contains(pinnedID(siteID: siteID, boardCode: lhs.code))
                let rhsPinned = pinnedBoardIDs.contains(pinnedID(siteID: siteID, boardCode: rhs.code))

                if lhsPinned != rhsPinned {
                    return lhsPinned
                }

                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                return lhs.code.localizedCaseInsensitiveCompare(rhs.code) == .orderedAscending
            }

            return (sortedBoards.map { $0.name }, sortedBoards.map { $0.code })
        }
    }

    // MARK: - Private Methods

    private func pinnedID(siteID: String, boardCode: String) -> String {
        return "\(siteID.lowercased())|\(boardCode.lowercased())"
    }

    private func loadPinnedBoards() {
        if let savedBoards = UserDefaults.standard.array(forKey: pinnedBoardsKey) as? [String] {
            pinnedBoardIDs = Set(savedBoards)
        }
    }

    private func savePinnedBoards() {
        let boardsArray = Array(pinnedBoardIDs)
        UserDefaults.standard.set(boardsArray, forKey: pinnedBoardsKey)

        if ICloudSyncManager.shared.isICloudAvailable {
            NSUbiquitousKeyValueStore.default.set(boardsArray, forKey: pinnedBoardsKey)
        }
    }

    private func postPinnedBoardsChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: PinnedBoardsManager.pinnedBoardsChangedNotification, object: nil)
        }
    }

    @objc private func iCloudDataDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              changedKeys.contains(pinnedBoardsKey) else {
            return
        }

        if let cloudBoards = NSUbiquitousKeyValueStore.default.array(forKey: pinnedBoardsKey) as? [String] {
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.pinnedBoardIDs = Set(cloudBoards)
                UserDefaults.standard.set(cloudBoards, forKey: self.pinnedBoardsKey)
                self.postPinnedBoardsChanged()
            }
        }
    }

    @objc private func iCloudSyncCompleted(_ notification: Notification) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.loadPinnedBoards()
            self.postPinnedBoardsChanged()
        }
    }
}
