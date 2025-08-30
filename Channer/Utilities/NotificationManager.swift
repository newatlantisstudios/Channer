import Foundation

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
    
    init(boardAbv: String, threadNo: String, replyNo: String, replyToNo: String, replyText: String) {
        self.id = UUID().uuidString
        self.boardAbv = boardAbv
        self.threadNo = threadNo
        self.replyNo = replyNo
        self.replyToNo = replyToNo
        self.replyText = replyText
        self.timestamp = Date()
        self.isRead = false
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