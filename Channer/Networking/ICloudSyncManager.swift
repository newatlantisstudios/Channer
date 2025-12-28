import Foundation
import UIKit

class ICloudSyncManager {
    static let shared = ICloudSyncManager()
    
    // Notification names
    static let iCloudSyncCompletedNotification = Notification.Name("ICloudSyncCompleted")
    static let iCloudSyncStatusChangedNotification = Notification.Name("ICloudSyncStatusChanged")
    
    // Properties
    private(set) var isICloudAvailable: Bool = false
    private(set) var syncStatus: String = "Not Available"
    private let iCloudEnabledKey = "channer_icloud_sync_enabled"
    
    // NSUbiquitousKeyValueStore for simple key-value syncing
    private let keyValueStore = NSUbiquitousKeyValueStore.default
    
    // Sync management
    private var syncTimer: Timer?
    private var isSyncing = false
    private var lastSyncDate: Date?
    
    private init() {
        checkICloudAvailability()
        setupAutoSync()
        setupNotificationObservers()
    }
    
    // MARK: - iCloud Availability
    
    private func checkICloudAvailability() {
        if let identity = FileManager.default.ubiquityIdentityToken {
            isICloudAvailable = true
            updateSyncStatus("Ready to sync")
        } else {
            isICloudAvailable = false
            updateSyncStatus("Not signed in to iCloud")
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyValueStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: keyValueStore
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudAccountDidChange(_:)),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
    }
    
    @objc private func keyValueStoreDidChange(_ notification: Notification) {
        // Handle changes from iCloud
        updateSyncStatus("Syncing...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.completeSync()
        }
    }
    
    @objc private func iCloudAccountDidChange(_ notification: Notification) {
        checkICloudAvailability()
    }
    
    // MARK: - Sync Status
    
    private func updateSyncStatus(_ status: String) {
        syncStatus = status
        NotificationCenter.default.post(name: ICloudSyncManager.iCloudSyncStatusChangedNotification, object: nil)
    }
    
    // MARK: - Auto Sync
    
    private func setupAutoSync() {
        // Cancel any existing timer
        syncTimer?.invalidate()
        
        // Only setup timer if iCloud sync is enabled
        if UserDefaults.standard.bool(forKey: iCloudEnabledKey) {
            // Sync every 5 minutes
            syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                self?.performSync()
            }
        }
    }
    
    // MARK: - Manual Sync
    
    func forceSync() {
        guard isICloudAvailable else {
            updateSyncStatus("iCloud not available")
            return
        }
        
        guard UserDefaults.standard.bool(forKey: iCloudEnabledKey) else {
            updateSyncStatus("Sync disabled")
            return
        }
        
        performSync()
    }
    
    // MARK: - Core Sync Logic
    
    private func performSync() {
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }
        
        isSyncing = true
        updateSyncStatus("Syncing...")

        // Complete sync after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.completeSync()
        }
    }
    
    private func completeSync() {
        lastSyncDate = Date()
        isSyncing = false
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        updateSyncStatus("Last synced: \(formatter.string(from: lastSyncDate!))")
        
        NotificationCenter.default.post(name: ICloudSyncManager.iCloudSyncCompletedNotification, object: nil)
    }
    
    // MARK: - Data Persistence Methods (Matching FavoritesManager expectations)
    
    func save<T: Codable>(_ object: T, forKey key: String) -> Bool {
        guard isICloudAvailable && UserDefaults.standard.bool(forKey: iCloudEnabledKey) else {
            // Fallback to UserDefaults
            return saveToUserDefaults(object, forKey: key)
        }
        
        do {
            let data = try JSONEncoder().encode(object)
            keyValueStore.set(data, forKey: key)
            
            // Also save to UserDefaults as backup
            saveToUserDefaults(object, forKey: key)
            
            return true
        } catch {
            print("Failed to encode data for iCloud: \(error)")
            return saveToUserDefaults(object, forKey: key)
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // First try to load from iCloud if available and enabled
        if isICloudAvailable && UserDefaults.standard.bool(forKey: iCloudEnabledKey) {
            if let data = keyValueStore.data(forKey: key) {
                do {
                    return try JSONDecoder().decode(type, from: data)
                } catch {
                    print("Failed to decode data from iCloud: \(error)")
                }
            }
        }
        
        // Fallback to UserDefaults
        return loadFromUserDefaults(type, forKey: key)
    }
    
    // MARK: - UserDefaults Fallback
    
    private func saveToUserDefaults<T: Codable>(_ object: T, forKey key: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(object)
            UserDefaults.standard.set(data, forKey: key)
            return true
        } catch {
            print("Failed to save to UserDefaults: \(error)")
            return false
        }
    }
    
    private func loadFromUserDefaults<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode from UserDefaults: \(error)")
            return nil
        }
    }
    
    // MARK: - Migration
    
    func migrateLocalDataToiCloud() {
        guard isICloudAvailable && UserDefaults.standard.bool(forKey: iCloudEnabledKey) else { return }
        
        // List of keys to migrate
        let keysToMigrate = ["favorites", "bookmarkCategories", "contentFilters", "themeSettings"]
        
        for key in keysToMigrate {
            if let data = UserDefaults.standard.data(forKey: key),
               keyValueStore.data(forKey: key) == nil {
                // Only migrate if not already in iCloud
                keyValueStore.set(data, forKey: key)
                print("Migrated \(key) to iCloud")
            }
        }
    }
    
    // MARK: - Enable/Disable Sync
    
    func enableSync() {
        UserDefaults.standard.set(true, forKey: iCloudEnabledKey)
        setupAutoSync()
        forceSync()
    }
    
    func disableSync() {
        UserDefaults.standard.set(false, forKey: iCloudEnabledKey)
        syncTimer?.invalidate()
        syncTimer = nil
        updateSyncStatus("Sync disabled")
    }
}