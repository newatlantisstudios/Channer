import Foundation

/// Represents different types of notifications
enum NotificationType: String, Codable {
    case threadUpdate       // New posts in favorited threads
    case watchedPostReply   // Reply to a watched post
    case myPostReply        // Reply to user's own post
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

    /// Full initializer with all fields
    init(boardAbv: String, threadNo: String, replyNo: String, replyToNo: String, replyText: String,
         notificationType: NotificationType = .watchedPostReply, threadTitle: String? = nil, newReplyCount: Int? = nil) {
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
    }
}

/// Manages reply notifications for the app
/// Provides functionality to track, store, and manage reply notifications with thread-safe operations
class NotificationManager {
    static let shared = NotificationManager()
    
    private let notificationsKey = "channer_reply_notifications"
    private let unreadCountKey = "channer_unread_notifications_count"
    
    private init() {
        // Subscribe to UserDefaults changes to sync iCloud
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
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
        let defaults = UserDefaults.standard
        defaults.synchronize()
        
        if let data = defaults.data(forKey: notificationsKey),
           let notifications = try? JSONDecoder().decode([ReplyNotification].self, from: data) {
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

        for type in [NotificationType.myPostReply, .threadUpdate, .watchedPostReply] {
            let filtered = allNotifications.filter { $0.notificationType == type }
            if !filtered.isEmpty {
                grouped[type] = filtered
            }
        }

        return grouped
    }

    // MARK: - Convenience Methods

    /// Adds a thread update notification
    /// - Parameters:
    ///   - boardAbv: Board abbreviation
    ///   - threadNo: Thread number
    ///   - threadTitle: Optional thread title/subject
    ///   - newReplyCount: Number of new replies
    ///   - replyPreview: Preview text of the latest reply
    func addThreadUpdateNotification(boardAbv: String, threadNo: String, threadTitle: String?, newReplyCount: Int, replyPreview: String) {
        let notification = ReplyNotification(
            boardAbv: boardAbv,
            threadNo: threadNo,
            replyNo: "",
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

    // MARK: - Private Methods
    
    private func saveNotifications(_ notifications: [ReplyNotification]) {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(notifications) {
            defaults.set(encoded, forKey: notificationsKey)
            defaults.synchronize()
        }
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
        UserDefaults.standard.synchronize()
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
}

// MARK: - Notification Names

extension Notification.Name {
    static let notificationAdded = Notification.Name("channer.notificationAdded")
    static let notificationRead = Notification.Name("channer.notificationRead")
    static let notificationRemoved = Notification.Name("channer.notificationRemoved")
    static let notificationDataChanged = Notification.Name("channer.notificationDataChanged")
}