import Foundation

/// Manages content filtering settings and operations for Channer
class ContentFilterManager {
    // MARK: - Singleton
    static let shared = ContentFilterManager()
    
    // MARK: - Constants
    private let keywordFiltersKey = "content_filters"
    private let posterFiltersKey = "poster_filters"
    private let imageFiltersKey = "image_filters"
    private let filterEnabledKey = "content_filter_enabled"
    
    // MARK: - Initialization
    private init() {
        // Set default filter enabled state if it doesn't exist
        if UserDefaults.standard.object(forKey: filterEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: filterEnabledKey)
        }
    }
    
    // MARK: - Public Methods
    
    /// Checks if content filtering is enabled
    func isFilteringEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: filterEnabledKey)
    }
    
    /// Sets whether content filtering is enabled
    func setFilteringEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: filterEnabledKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Gets all active filters
    func getAllFilters() -> (keywords: [String], posters: [String], images: [String]) {
        let keywords = UserDefaults.standard.stringArray(forKey: keywordFiltersKey) ?? []
        let posters = UserDefaults.standard.stringArray(forKey: posterFiltersKey) ?? []
        let images = UserDefaults.standard.stringArray(forKey: imageFiltersKey) ?? []
        return (keywords, posters, images)
    }
    
    // MARK: - iCloud Sync Support
    
    func syncKeywordsFromICloud(_ keywords: [String]) {
        UserDefaults.standard.set(keywords, forKey: keywordFiltersKey)
        UserDefaults.standard.synchronize()
    }
    
    func syncPostersFromICloud(_ posters: [String]) {
        UserDefaults.standard.set(posters, forKey: posterFiltersKey)
        UserDefaults.standard.synchronize()
    }
    
    func syncImagesFromICloud(_ images: [String]) {
        UserDefaults.standard.set(images, forKey: imageFiltersKey)
        UserDefaults.standard.synchronize()
    }
}