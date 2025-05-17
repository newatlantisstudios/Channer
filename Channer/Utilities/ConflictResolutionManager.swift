import Foundation

/// Manages conflict resolution for iCloud syncing
class ConflictResolutionManager {
    
    static let shared = ConflictResolutionManager()
    
    // MARK: - Conflict Types
    
    enum ConflictType {
        case favorites
        case history
        case categories
        case themes
        case settings
    }
    
    enum ConflictResolution {
        case merge
        case takeLocal
        case takeRemote
        case askUser
    }
    
    struct SyncConflict {
        let type: ConflictType
        let localData: Any
        let remoteData: Any
        let localTimestamp: Date
        let remoteTimestamp: Date
        var resolution: ConflictResolution?
    }
    
    // MARK: - Properties
    
    private var pendingConflicts: [SyncConflict] = []
    private let timestampKey = "_lastModified"
    
    // Delegate for UI interaction
    weak var delegate: ConflictResolutionDelegate?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Conflict Detection
    
    /// Detects conflicts between local and remote data
    func detectConflicts(for type: ConflictType, localData: Any, remoteData: Any) -> SyncConflict? {
        let localTimestamp = getTimestamp(for: type, isLocal: true)
        let remoteTimestamp = getTimestamp(for: type, isLocal: false)
        
        switch type {
        case .favorites, .history:
            // Check for actual differences in content
            if let localThreads = localData as? [ThreadData],
               let remoteThreads = remoteData as? [ThreadData] {
                if hasConflictingChanges(local: localThreads, remote: remoteThreads) {
                    return SyncConflict(type: type,
                                      localData: localData,
                                      remoteData: remoteData,
                                      localTimestamp: localTimestamp,
                                      remoteTimestamp: remoteTimestamp)
                }
            }
            
        case .categories:
            if let localCategories = localData as? [BookmarkCategory],
               let remoteCategories = remoteData as? [BookmarkCategory] {
                if hasCategoryConflicts(local: localCategories, remote: remoteCategories) {
                    return SyncConflict(type: type,
                                      localData: localData,
                                      remoteData: remoteData,
                                      localTimestamp: localTimestamp,
                                      remoteTimestamp: remoteTimestamp)
                }
            }
            
        case .themes:
            if let localThemes = localData as? [Theme],
               let remoteThemes = remoteData as? [Theme] {
                if hasThemeConflicts(local: localThemes, remote: remoteThemes) {
                    return SyncConflict(type: type,
                                      localData: localData,
                                      remoteData: remoteData,
                                      localTimestamp: localTimestamp,
                                      remoteTimestamp: remoteTimestamp)
                }
            }
            
        case .settings:
            // Settings typically use last-write-wins
            return nil
        }
        
        return nil
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts based on type and strategy
    func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) -> Any? {
        switch conflict.type {
        case .favorites, .history:
            return resolveThreadDataConflict(conflict, resolution: resolution)
            
        case .categories:
            return resolveCategoryConflict(conflict, resolution: resolution)
            
        case .themes:
            return resolveThemeConflict(conflict, resolution: resolution)
            
        case .settings:
            // Settings use the specified resolution strategy
            switch resolution {
            case .takeLocal:
                return conflict.localData
            case .takeRemote:
                return conflict.remoteData
            case .merge, .askUser:
                // For settings, default to remote (last-write-wins)
                return conflict.remoteData
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func hasConflictingChanges(local: [ThreadData], remote: [ThreadData]) -> Bool {
        // Check if there are threads that exist in both but with different data
        for localThread in local {
            if let remoteThread = remote.first(where: { $0.number == localThread.number && $0.boardAbv == localThread.boardAbv }) {
                // Check for differences in mutable properties
                if localThread.stats != remoteThread.stats ||
                   localThread.currentReplies != remoteThread.currentReplies ||
                   localThread.hasNewReplies != remoteThread.hasNewReplies ||
                   localThread.categoryId != remoteThread.categoryId {
                    return true
                }
            }
        }
        return false
    }
    
    private func hasCategoryConflicts(local: [BookmarkCategory], remote: [BookmarkCategory]) -> Bool {
        // Check for categories with same ID but different properties
        for localCategory in local {
            if let remoteCategory = remote.first(where: { $0.id == localCategory.id }) {
                if localCategory.name != remoteCategory.name ||
                   localCategory.icon != remoteCategory.icon ||
                   localCategory.color != remoteCategory.color {
                    return true
                }
            }
        }
        return false
    }
    
    private func hasThemeConflicts(local: [Theme], remote: [Theme]) -> Bool {
        // Check for themes with same ID but different properties
        for localTheme in local {
            if let remoteTheme = remote.first(where: { $0.id == localTheme.id }) {
                if localTheme.name != remoteTheme.name ||
                   !areThemePropertiesEqual(localTheme, remoteTheme) {
                    return true
                }
            }
        }
        return false
    }
    
    private func areThemePropertiesEqual(_ theme1: Theme, _ theme2: Theme) -> Bool {
        // Compare theme properties (colors, fonts, etc.)
        // This is a simplified comparison - expand based on actual Theme properties
        return theme1.name == theme2.name 
    }
    
    private func resolveThreadDataConflict(_ conflict: SyncConflict, resolution: ConflictResolution) -> [ThreadData]? {
        guard let localThreads = conflict.localData as? [ThreadData],
              let remoteThreads = conflict.remoteData as? [ThreadData] else { return nil }
        
        switch resolution {
        case .takeLocal:
            return localThreads
            
        case .takeRemote:
            return remoteThreads
            
        case .merge:
            // Intelligent merge: combine both sets, preferring newer data for duplicates
            var merged: [ThreadData] = []
            var processed: Set<String> = []
            
            // Process all threads, combining local and remote
            let allThreads = localThreads + remoteThreads
            
            for thread in allThreads {
                let identifier = "\(thread.boardAbv)-\(thread.number)"
                if !processed.contains(identifier) {
                    processed.insert(identifier)
                    
                    // Find if this thread exists in both sets
                    let localVersion = localThreads.first { $0.boardAbv == thread.boardAbv && $0.number == thread.number }
                    let remoteVersion = remoteThreads.first { $0.boardAbv == thread.boardAbv && $0.number == thread.number }
                    
                    if let local = localVersion, let remote = remoteVersion {
                        // Merge the two versions, preferring the one with more recent activity
                        var mergedThread = remote // Start with remote as base
                        
                        // Keep local category if set
                        if local.categoryId != nil {
                            mergedThread.categoryId = local.categoryId
                        }
                        
                        // Keep higher reply count
                        if let localReplies = local.currentReplies,
                           let remoteReplies = remote.currentReplies {
                            mergedThread.currentReplies = max(localReplies, remoteReplies)
                        }
                        
                        merged.append(mergedThread)
                    } else {
                        // Thread only exists in one set
                        merged.append(thread)
                    }
                }
            }
            
            return merged
            
        case .askUser:
            // This would trigger a UI dialog - implementation depends on delegate
            return nil
        }
    }
    
    private func resolveCategoryConflict(_ conflict: SyncConflict, resolution: ConflictResolution) -> [BookmarkCategory]? {
        guard let localCategories = conflict.localData as? [BookmarkCategory],
              let remoteCategories = conflict.remoteData as? [BookmarkCategory] else { return nil }
        
        switch resolution {
        case .takeLocal:
            return localCategories
            
        case .takeRemote:
            return remoteCategories
            
        case .merge:
            // Merge categories: union of both sets, preferring newer versions for duplicates
            var merged: [BookmarkCategory] = []
            var processedIds: Set<String> = []
            
            // Process all categories
            let allCategories = localCategories + remoteCategories
            
            for category in allCategories {
                if !processedIds.contains(category.id) {
                    processedIds.insert(category.id)
                    
                    let localVersion = localCategories.first { $0.id == category.id }
                    let remoteVersion = remoteCategories.first { $0.id == category.id }
                    
                    if localVersion != nil && remoteVersion != nil {
                        // Both exist - prefer the one with more recent timestamp
                        merged.append(conflict.localTimestamp > conflict.remoteTimestamp ? localVersion! : remoteVersion!)
                    } else {
                        // Only exists in one set
                        merged.append(category)
                    }
                }
            }
            
            return merged
            
        case .askUser:
            return nil
        }
    }
    
    private func resolveThemeConflict(_ conflict: SyncConflict, resolution: ConflictResolution) -> [Theme]? {
        guard let localThemes = conflict.localData as? [Theme],
              let remoteThemes = conflict.remoteData as? [Theme] else { return nil }
        
        switch resolution {
        case .takeLocal:
            return localThemes
            
        case .takeRemote:
            return remoteThemes
            
        case .merge:
            // Merge themes: keep both versions but rename duplicates
            var merged: [Theme] = remoteThemes
            
            for localTheme in localThemes {
                if let existingIndex = merged.firstIndex(where: { $0.id == localTheme.id }) {
                    // Conflict: same ID but different content
                    var renamedTheme = localTheme
                    renamedTheme.name = "\(localTheme.name) (Local)"
                    renamedTheme.id = UUID().uuidString // Generate new ID
                    merged.append(renamedTheme)
                } else {
                    // No conflict: add local theme
                    merged.append(localTheme)
                }
            }
            
            return merged
            
        case .askUser:
            return nil
        }
    }
    
    private func getTimestamp(for type: ConflictType, isLocal: Bool) -> Date {
        let key = "\(type).\(timestampKey)"
        
        if isLocal {
            return UserDefaults.standard.object(forKey: key) as? Date ?? Date()
        } else {
            return ICloudSyncManager.shared.load(Date.self, forKey: key) ?? Date()
        }
    }
    
    func updateTimestamp(for type: ConflictType, isLocal: Bool) {
        let key = "\(type).\(timestampKey)"
        let now = Date()
        
        if isLocal {
            UserDefaults.standard.set(now, forKey: key)
        } else {
            _ = ICloudSyncManager.shared.save(now, forKey: key)
        }
    }
}

// MARK: - Delegate Protocol

protocol ConflictResolutionDelegate: AnyObject {
    func conflictResolutionManager(_ manager: ConflictResolutionManager, 
                                 didDetectConflict conflict: ConflictResolutionManager.SyncConflict,
                                 completion: @escaping (ConflictResolutionManager.ConflictResolution) -> Void)
}

// MARK: - Supporting Types
// Note: Theme struct is defined in ThemeManager.swift
// BookmarkCategory struct is defined in BookmarkCategory.swift