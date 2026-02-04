import Foundation

/// Represents different types of notifications
enum NotificationType: String, Codable {
    case threadUpdate       // New posts in favorited threads
    case watchedPostReply   // Reply to a watched post
    case myPostReply        // Reply to user's own post
    case savedSearchAlert   // New matches for a saved search
    case watchRuleMatch     // New matches for watch rules
}

/// Represents a reply notification with tracking metadata
struct ReplyNotification: Codable, Identifiable {
    let id: String
    let boardAbv: String
    let threadNo: String
    let replyNo: String
    let replyToNo: String  // The post number being replied to
    let replyText: String
    let timestamp: Date
    var isRead: Bool
    let notificationType: NotificationType
    let threadTitle: String?
    let newReplyCount: Int?
    let searchId: String?
    let watchRuleId: String?

    /// Full initializer with all fields
    init(boardAbv: String, threadNo: String, replyNo: String, replyToNo: String, replyText: String,
         notificationType: NotificationType = .watchedPostReply, threadTitle: String? = nil, newReplyCount: Int? = nil, searchId: String? = nil, watchRuleId: String? = nil) {
        self.id = UUID().uuidString
        self.boardAbv = boardAbv
        self.threadNo = threadNo
        self.replyNo = replyNo
        self.replyToNo = replyToNo
        self.replyText = replyText
        self.timestamp = Date()
        self.isRead = false
        self.notificationType = notificationType
        self.threadTitle = threadTitle
        self.newReplyCount = newReplyCount
        self.searchId = searchId
        self.watchRuleId = watchRuleId
    }

    /// Backward-compatible decoding with defaults for missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        boardAbv = try container.decode(String.self, forKey: .boardAbv)
        threadNo = try container.decode(String.self, forKey: .threadNo)
        replyNo = try container.decode(String.self, forKey: .replyNo)
        replyToNo = try container.decode(String.self, forKey: .replyToNo)
        replyText = try container.decode(String.self, forKey: .replyText)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        // Defaults for backward compatibility
        notificationType = try container.decodeIfPresent(NotificationType.self, forKey: .notificationType) ?? .watchedPostReply
        threadTitle = try container.decodeIfPresent(String.self, forKey: .threadTitle)
        newReplyCount = try container.decodeIfPresent(Int.self, forKey: .newReplyCount)
        searchId = try container.decodeIfPresent(String.self, forKey: .searchId)
        watchRuleId = try container.decodeIfPresent(String.self, forKey: .watchRuleId)
    }
}

/// Manages reply notifications for the app
/// Provides functionality to track, store, and manage reply notifications with thread-safe operations
class NotificationManager {
    static let shared = NotificationManager()
    
    private let notificationsKey = "channer_reply_notifications"
    private let unreadCountKey = "channer_unread_notifications_count"
    
    private init() {
        migrateLocalNotificationsIfNeeded()

        // Subscribe to UserDefaults changes to sync iCloud
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Listen for iCloud sync completion to refresh notification data
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudSyncCompleted),
            name: ICloudSyncManager.iCloudSyncCompletedNotification,
            object: nil
        )

        // Listen for direct iCloud key-value store changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Management
    
    /// Gets all notifications sorted by timestamp (newest first)
    /// Thread-safe method that ensures UserDefaults access on main thread
    /// - Returns: Array of all notifications sorted by timestamp
    func getNotifications() -> [ReplyNotification] {
        // Ensure we're on the main thread when accessing UserDefaults
        if !Thread.isMainThread {
            var result: [ReplyNotification] = []
            DispatchQueue.main.sync {
                result = self.fetchNotificationsFromDefaults()
            }
            return result
        }
        return fetchNotificationsFromDefaults()
    }
    
    /// Helper method to fetch notifications from UserDefaults
    private func fetchNotificationsFromDefaults() -> [ReplyNotification] {
        if let notifications = ICloudSyncManager.shared.load([ReplyNotification].self, forKey: notificationsKey) {
            return notifications.sorted { $0.timestamp > $1.timestamp }
        }
        return []
    }
    
    /// Adds a new notification and updates unread count
    /// - Parameter notification: The notification to add
    func addNotification(_ notification: ReplyNotification) {
        var notifications = getNotifications()
        notifications.append(notification)
        saveNotifications(notifications)
        
        // Update unread count
        updateUnreadCount()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .notificationAdded, object: nil)
    }
    
    /// Marks a specific notification as read by ID
    /// - Parameter notificationId: Unique identifier of the notification
    func markAsRead(_ notificationId: String) {
        var notifications = getNotifications()
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
            saveNotifications(notifications)
            updateUnreadCount()
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: .notificationRead, object: nil)
        }
    }
    
    /// Marks all notifications as read
    func markAllAsRead() {
        var notifications = getNotifications()
        for i in 0..<notifications.count {
            notifications[i].isRead = true
        }
        saveNotifications(notifications)
        updateUnreadCount()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .notificationRead, object: nil)
    }
    
    /// Removes a notification by ID
    /// - Parameter notificationId: Unique identifier of the notification to remove
    func removeNotification(_ notificationId: String) {
        var notifications = getNotifications()
        notifications.removeAll { $0.id == notificationId }
        saveNotifications(notifications)
        updateUnreadCount()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .notificationRemoved, object: nil)
    }
    
    /// Clears all notifications
    func clearAllNotifications() {
        saveNotifications([])
        updateUnreadCount()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .notificationRemoved, object: nil)
    }
    
    /// Gets the count of unread notifications
    /// Thread-safe method that ensures UserDefaults access on main thread
    /// - Returns: Number of unread notifications
    func getUnreadCount() -> Int {
        // Ensure we're on the main thread when accessing UserDefaults
        if !Thread.isMainThread {
            var count = 0
            DispatchQueue.main.sync {
                count = getNotifications().filter { !$0.isRead }.count
            }
            return count
        }
        return getNotifications().filter { !$0.isRead }.count
    }

    // MARK: - Filtering & Grouping

    /// Gets notifications filtered by type
    /// - Parameter type: The notification type to filter by
    /// - Returns: Array of notifications of the specified type
    func getNotifications(ofType type: NotificationType) -> [ReplyNotification] {
        return getNotifications().filter { $0.notificationType == type }
    }

    /// Gets notifications grouped by type for sectioned display
    /// - Returns: Dictionary with notification type as key and array of notifications as value
    func getNotificationsGroupedByType() -> [NotificationType: [ReplyNotification]] {
        let allNotifications = getNotifications()
        var grouped: [NotificationType: [ReplyNotification]] = [:]

        for type in [NotificationType.myPostReply, .threadUpdate, .savedSearchAlert, .watchedPostReply, .watchRuleMatch] {
            let filtered = allNotifications.filter { $0.notificationType == type }
            if !filtered.isEmpty {
                grouped[type] = filtered
            }
        }

        return grouped
    }

    // MARK: - Convenience Methods

    /// Adds a thread update notification
    /// If an unread notification for the same thread already exists, it will be updated instead of creating a duplicate
    /// - Parameters:
    ///   - boardAbv: Board abbreviation
    ///   - threadNo: Thread number
    ///   - threadTitle: Optional thread title/subject
    ///   - newReplyCount: Number of new replies
    ///   - replyPreview: Preview text of the latest reply
    ///   - latestReplyNo: Optional post number of the latest reply (for navigation)
    func addThreadUpdateNotification(boardAbv: String, threadNo: String, threadTitle: String?, newReplyCount: Int, replyPreview: String, latestReplyNo: String? = nil) {
        var notifications = getNotifications()

        // Check for existing unread notification for the same thread
        if let existingIndex = notifications.firstIndex(where: {
            $0.boardAbv == boardAbv &&
            $0.threadNo == threadNo &&
            $0.notificationType == .threadUpdate &&
            !$0.isRead
        }) {
            // Update existing notification by removing old and adding new
            notifications.remove(at: existingIndex)
            saveNotifications(notifications)
        }

        let notification = ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: latestReplyNo ?? "",
            replyToNo: "",
            replyText: replyPreview,
            notificationType: .threadUpdate,
            threadTitle: threadTitle,
            newReplyCount: newReplyCount
        )
        addNotification(notification)
    }

    /// Adds a notification for a reply to the user's own post
    /// - Parameters:
    ///   - boardAbv: Board abbreviation
    ///   - threadNo: Thread number
    ///   - replyNo: The post number of the reply
    ///   - replyToNo: The user's post number being replied to
    ///   - replyText: Preview of the reply text
    ///   - threadTitle: Optional thread title/subject
    func addMyPostReplyNotification(boardAbv: String, threadNo: String, replyNo: String, replyToNo: String, replyText: String, threadTitle: String? = nil) {
        let notification = ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: replyNo,
            replyToNo: replyToNo,
            replyText: replyText,
            notificationType: .myPostReply,
            threadTitle: threadTitle
        )
        addNotification(notification)
    }

    /// Adds a saved search alert notification
    /// If an unread notification for the same saved search already exists, it will be updated instead of duplicated
    func addSavedSearchNotification(
        searchId: String,
        searchName: String,
        boardAbv: String,
        threadNo: String,
        previewText: String,
        matchCount: Int
    ) {
        var notifications = getNotifications()

        if let existingIndex = notifications.firstIndex(where: {
            $0.notificationType == .savedSearchAlert &&
            $0.searchId == searchId &&
            !$0.isRead
        }) {
            notifications.remove(at: existingIndex)
            saveNotifications(notifications)
        }

        let notification = ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: threadNo,
            replyToNo: "",
            replyText: previewText,
            notificationType: .savedSearchAlert,
            threadTitle: searchName,
            newReplyCount: matchCount,
            searchId: searchId
        )
        addNotification(notification)
    }

    /// Adds a watch rule match notification
    /// If an unread notification for the same rule already exists, it will be updated instead of duplicated
    func addWatchRuleNotification(
        rule: WatchRule,
        boardAbv: String,
        threadNo: String,
        postNo: String,
        previewText: String,
        matchCount: Int
    ) {
        var notifications = getNotifications()

        if let existingIndex = notifications.firstIndex(where: {
            $0.notificationType == .watchRuleMatch &&
            $0.watchRuleId == rule.id &&
            !$0.isRead
        }) {
            notifications.remove(at: existingIndex)
            saveNotifications(notifications)
        }

        let notification = ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: postNo,
            replyToNo: "",
            replyText: previewText,
            notificationType: .watchRuleMatch,
            threadTitle: rule.displayName,
            newReplyCount: matchCount,
            watchRuleId: rule.id
        )

        addNotification(notification)
    }

    // MARK: - Private Methods
    
    private func saveNotifications(_ notifications: [ReplyNotification]) {
        _ = ICloudSyncManager.shared.save(notifications, forKey: notificationsKey)
    }
    
    private func updateUnreadCount() {
        // Ensure we're on the main thread when updating UserDefaults
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateUnreadCountOnMainThread()
            }
            return
        }
        updateUnreadCountOnMainThread()
    }
    
    private func updateUnreadCountOnMainThread() {
        let count = getUnreadCount()
        UserDefaults.standard.set(count, forKey: unreadCountKey)
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // Ensure we're on the main thread when posting notifications
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.userDefaultsDidChange(notification)
            }
            return
        }
        
        // Notify UI that data might have changed
        NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
    }

    @objc private func iCloudSyncCompleted(_ notification: Notification) {
        NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
    }

    @objc private func iCloudStoreDidChangeExternally(_ notification: Notification) {
        NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
    }

    private func migrateLocalNotificationsIfNeeded() {
        guard ICloudSyncManager.shared.isICloudAvailable,
              ICloudSyncManager.shared.isSyncEnabled else { return }

        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()

        // Only migrate if iCloud doesn't already have notifications
        guard store.data(forKey: notificationsKey) == nil else { return }
        guard let localData = UserDefaults.standard.data(forKey: notificationsKey) else { return }

        store.set(localData, forKey: notificationsKey)
        store.synchronize()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let notificationAdded = Notification.Name("channer.notificationAdded")
    static let notificationRead = Notification.Name("channer.notificationRead")
    static let notificationRemoved = Notification.Name("channer.notificationRemoved")
    static let notificationDataChanged = Notification.Name("channer.notificationDataChanged")
}
