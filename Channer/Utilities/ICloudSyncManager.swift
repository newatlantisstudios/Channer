import Foundation

/// Manages iCloud synchronization for the app
class ICloudSyncManager {
    
    static let shared = ICloudSyncManager()
    
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let syncQueue = DispatchQueue(label: "com.channer.icloud.sync", qos: .background)
    
    // Key for sync enabled state
    private let iCloudSyncEnabledKey = "channer_icloud_sync_enabled"
    
    // Keys for settings sync
    private let settingsKeys = [
        "defaultBoard",
        "channer_selected_theme_id",
        "channer_custom_themes",
        "channer_faceID_authentication_enabled",
        "channer_notifications_enabled",
        "channer_offline_reading_enabled",
        "channer_launch_with_startup_board",
        "channer_boards_auto_refresh_interval",
        "channer_threads_auto_refresh_interval",
        "channer_hidden_boards"
    ]

    // Keys for complex data sync (Codable objects)
    private let statisticsKey = "channer_user_statistics"
    private let passCredentialsKey = "channer_pass_credentials"
    
    // Last sync date tracking
    private(set) var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "channer_icloud_last_sync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "channer_icloud_last_sync") }
    }
    
    // Notification names for sync events
    static let iCloudSyncStartedNotification = Notification.Name("iCloudSyncStarted")
    static let iCloudSyncCompletedNotification = Notification.Name("iCloudSyncCompleted")
    static let iCloudSyncFailedNotification = Notification.Name("iCloudSyncFailed")
    static let iCloudSyncStatusChangedNotification = Notification.Name("iCloudSyncStatusChanged")
    
    private init() {
        setupiCloudNotifications()
        // Perform initial sync if available and enabled
        if isICloudAvailable && isSyncEnabled {
            syncFromiCloud()
        }
    }
    
    // MARK: - iCloud Availability
    
    /// Checks if iCloud is available for the current user
    var isICloudAvailable: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    /// Checks if iCloud sync is enabled in settings
    var isSyncEnabled: Bool {
        return UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
    }
    
    /// Gets the current iCloud account identifier
    var iCloudAccountIdentifier: String? {
        guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
        return "\(token)"
    }
    
    /// Gets the current sync status
    var syncStatus: String {
        if !isSyncEnabled {
            return "Disabled"
        } else if !isICloudAvailable {
            return "Not Available"
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Never synced"
        }
    }
    
    // MARK: - Sync Management
    
    /// Sets up observers for iCloud sync notifications
    private func setupiCloudNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        // Listen for UserDefaults changes to sync to iCloud
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    /// Handles external changes to iCloud data
    @objc private func iCloudStoreDidChangeExternally(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            print("iCloud data changed from another device")
            syncFromiCloud()
            
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("iCloud quota exceeded")
            NotificationCenter.default.post(name: Self.iCloudSyncFailedNotification, object: nil)
            
        case NSUbiquitousKeyValueStoreAccountChange:
            print("iCloud account changed")
            syncFromiCloud()
            
        default:
            break
        }
    }
    
    /// Handles changes to UserDefaults
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        guard isSyncEnabled else { return }
        
        syncQueue.async {
            self.syncToiCloud()
        }
    }
    
    // MARK: - Data Operations
    
    /// Saves data to iCloud
    func save<T: Codable>(_ object: T, forKey key: String) -> Bool {
        guard isICloudAvailable && isSyncEnabled else {
            print("iCloud not available or disabled, saving to UserDefaults")
            return saveLocally(object, forKey: key)
        }
        
        do {
            let encoded = try JSONEncoder().encode(object)
            iCloudStore.set(encoded, forKey: key)
            iCloudStore.synchronize()
            return true
        } catch {
            print("Failed to encode data for iCloud: \(error)")
            return false
        }
    }
    
    /// Loads data from iCloud
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        if isICloudAvailable && isSyncEnabled {
            guard let data = iCloudStore.data(forKey: key) else { 
                // Try local storage as fallback
                return loadLocally(type, forKey: key)
            }
            
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                print("Failed to decode data from iCloud: \(error)")
                // Try local storage as fallback
                return loadLocally(type, forKey: key)
            }
        } else {
            // Fallback to local storage
            return loadLocally(type, forKey: key)
        }
    }
    
    /// Saves data locally (fallback when iCloud is not available)
    private func saveLocally<T: Codable>(_ object: T, forKey key: String) -> Bool {
        do {
            let encoded = try JSONEncoder().encode(object)
            UserDefaults.standard.set(encoded, forKey: key)
            return true
        } catch {
            print("Failed to encode data for local storage: \(error)")
            return false
        }
    }
    
    /// Loads data locally (fallback when iCloud is not available)
    private func loadLocally<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode data from local storage: \(error)")
            return nil
        }
    }
    
    // MARK: - Sync Status
    
    /// Forces a sync with iCloud
    func forceSync() {
        guard isICloudAvailable && isSyncEnabled else { return }
        
        NotificationCenter.default.post(name: Self.iCloudSyncStartedNotification, object: nil)
        
        syncQueue.async {
            self.syncToiCloud()
            self.lastSyncDate = Date()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.iCloudSyncCompletedNotification, object: nil)
                NotificationCenter.default.post(name: Self.iCloudSyncStatusChangedNotification, object: nil)
            }
        }
    }
    
    /// Syncs settings from iCloud to local
    private func syncFromiCloud() {
        guard isICloudAvailable && isSyncEnabled else { return }
        
        syncQueue.async {
            self.iCloudStore.synchronize()
            
            for key in self.settingsKeys {
                if let iCloudValue = self.iCloudStore.object(forKey: key) {
                    // Special handling for theme data
                    if key == "channer_custom_themes" {
                        // Only sync if the iCloud data is newer or local doesn't exist
                        if UserDefaults.standard.object(forKey: key) == nil {
                            UserDefaults.standard.set(iCloudValue, forKey: key)
                        }
                    } else {
                        UserDefaults.standard.set(iCloudValue, forKey: key)
                    }
                }
            }
            
            self.lastSyncDate = Date()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.iCloudSyncCompletedNotification, object: nil)
                NotificationCenter.default.post(name: Self.iCloudSyncStatusChangedNotification, object: nil)
                
                // Notify theme manager if theme changed
                if self.iCloudStore.object(forKey: "channer_selected_theme_id") != nil {
                    NotificationCenter.default.post(name: .themeDidChange, object: nil)
                }
            }
        }
    }
    
    /// Syncs settings from local to iCloud
    private func syncToiCloud() {
        guard isICloudAvailable && isSyncEnabled else { return }
        
        for key in settingsKeys {
            if let localValue = UserDefaults.standard.object(forKey: key) {
                iCloudStore.set(localValue, forKey: key)
            }
        }
        
        iCloudStore.synchronize()
    }
    
    // MARK: - Data Migration
    
    /// Migrates local data to iCloud if needed
    func migrateLocalDataToiCloud() {
        guard isICloudAvailable && isSyncEnabled else { return }

        // Check if we've already migrated
        let hasMigrated = UserDefaults.standard.bool(forKey: "HasMigratedToiCloud")
        if hasMigrated { return }

        // Migrate favorites
        if let localFavoritesData = UserDefaults.standard.data(forKey: "favorites"),
           iCloudStore.data(forKey: "favorites") == nil {
            iCloudStore.set(localFavoritesData, forKey: "favorites")
        }

        // Migrate history
        if let localHistoryData = UserDefaults.standard.data(forKey: "threadHistory"),
           iCloudStore.data(forKey: "threadHistory") == nil {
            iCloudStore.set(localHistoryData, forKey: "threadHistory")
        }

        // Migrate categories
        if let localCategoriesData = UserDefaults.standard.data(forKey: "bookmarkCategories"),
           iCloudStore.data(forKey: "bookmarkCategories") == nil {
            iCloudStore.set(localCategoriesData, forKey: "bookmarkCategories")
        }

        // Migrate statistics
        if let localStatisticsData = UserDefaults.standard.data(forKey: statisticsKey),
           iCloudStore.data(forKey: statisticsKey) == nil {
            iCloudStore.set(localStatisticsData, forKey: statisticsKey)
        }

        // Migrate hidden boards
        if let localHiddenBoards = UserDefaults.standard.array(forKey: "channer_hidden_boards"),
           iCloudStore.array(forKey: "channer_hidden_boards") == nil {
            iCloudStore.set(localHiddenBoards, forKey: "channer_hidden_boards")
        }

        // Migrate pass credentials (pass_id cookie)
        if let localPassId = UserDefaults.standard.string(forKey: "channer_pass_id_cookie"),
           iCloudStore.string(forKey: passCredentialsKey) == nil {
            iCloudStore.set(localPassId, forKey: passCredentialsKey)
        }

        // Mark as migrated
        UserDefaults.standard.set(true, forKey: "HasMigratedToiCloud")
        iCloudStore.synchronize()
    }
    
    // MARK: - Statistics Sync

    /// Saves statistics to iCloud
    func saveStatistics(_ data: Data) {
        guard isICloudAvailable && isSyncEnabled else {
            UserDefaults.standard.set(data, forKey: statisticsKey)
            return
        }
        iCloudStore.set(data, forKey: statisticsKey)
        UserDefaults.standard.set(data, forKey: statisticsKey)
        iCloudStore.synchronize()
    }

    /// Loads statistics from iCloud (or local fallback)
    func loadStatistics() -> Data? {
        if isICloudAvailable && isSyncEnabled {
            if let cloudData = iCloudStore.data(forKey: statisticsKey) {
                return cloudData
            }
        }
        return UserDefaults.standard.data(forKey: statisticsKey)
    }

    // MARK: - Pass Credentials Sync

    /// Saves pass_id cookie to iCloud for sync across devices
    func savePassCredentials(passId: String) {
        guard isICloudAvailable && isSyncEnabled else { return }
        iCloudStore.set(passId, forKey: passCredentialsKey)
        iCloudStore.synchronize()
    }

    /// Loads pass_id cookie from iCloud
    func loadPassCredentials() -> String? {
        guard isICloudAvailable && isSyncEnabled else { return nil }
        return iCloudStore.string(forKey: passCredentialsKey)
    }

    /// Clears pass credentials from iCloud
    func clearPassCredentials() {
        guard isICloudAvailable && isSyncEnabled else { return }
        iCloudStore.removeObject(forKey: passCredentialsKey)
        iCloudStore.synchronize()
    }

    // MARK: - Conflict Resolution

    /// Merges local and iCloud data for favorites
    func mergeFavorites(local: [ThreadData], cloud: [ThreadData]) -> [ThreadData] {
        var merged = cloud
        
        // Add local favorites that aren't in cloud
        for localFavorite in local {
            if !merged.contains(where: { $0.number == localFavorite.number && $0.boardAbv == localFavorite.boardAbv }) {
                merged.append(localFavorite)
            }
        }
        
        return merged
    }
    
    /// Merges local and iCloud data for history
    func mergeHistory(local: [ThreadData], cloud: [ThreadData]) -> [ThreadData] {
        var merged = cloud
        
        // Add local history that isn't in cloud
        for localHistory in local {
            if !merged.contains(where: { $0.number == localHistory.number && $0.boardAbv == localHistory.boardAbv }) {
                merged.append(localHistory)
            }
        }
        
        // Sort by creation date (assuming newer entries are added to the end)
        return merged
    }
}