import Foundation

/// A struct representing a filter with keyword/phrase and filter options
struct ContentFilter: Codable, Equatable {
    let id: UUID
    let keyword: String
    let isRegex: Bool
    let isCaseSensitive: Bool
    let isEnabled: Bool
    
    init(keyword: String, isRegex: Bool = false, isCaseSensitive: Bool = false, isEnabled: Bool = true) {
        self.id = UUID()
        self.keyword = keyword
        self.isRegex = isRegex
        self.isCaseSensitive = isCaseSensitive
        self.isEnabled = isEnabled
    }
    
    static func == (lhs: ContentFilter, rhs: ContentFilter) -> Bool {
        return lhs.id == rhs.id
    }
}

class FilterManager {
    
    // MARK: - Singleton Instance
    static let shared = FilterManager()
    
    // MARK: - Properties
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let filtersKey = "content_filters"
    private let iCloudFallbackWarningKey = "iCloudFilterFallbackWarningShown"
    
    /// Array to store active content filters
    private(set) var filters: [ContentFilter] = []
    
    // MARK: - Initialization
    private init() {
        loadFilters()
    }
    
    // MARK: - iCloud Availability Check
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // MARK: - Filter Management Methods
    /// Adds a new content filter
    /// - Parameter filter: The ContentFilter to add
    func addFilter(_ filter: ContentFilter) {
        if !filters.contains(where: { $0.id == filter.id }) {
            filters.append(filter)
            saveFilters()
        }
    }
    
    /// Removes a content filter by ID
    /// - Parameter id: The UUID of the filter to remove
    func removeFilter(id: UUID) {
        filters.removeAll { $0.id == id }
        saveFilters()
    }
    
    /// Updates an existing filter
    /// - Parameter filter: The updated filter (must have existing ID)
    func updateFilter(_ filter: ContentFilter) {
        if let index = filters.firstIndex(where: { $0.id == filter.id }) {
            filters[index] = filter
            saveFilters()
        }
    }
    
    /// Checks if content should be filtered based on active filters
    /// - Parameter content: The string to check against filters
    /// - Returns: Boolean indicating if content should be filtered
    func shouldFilter(content: String) -> Bool {
        // Only check enabled filters
        let enabledFilters = filters.filter { $0.isEnabled }
        
        for filter in enabledFilters {
            if filter.isRegex {
                // Try to create a regex from the filter keyword
                do {
                    let options: NSRegularExpression.Options = filter.isCaseSensitive ? [] : .caseInsensitive
                    let regex = try NSRegularExpression(pattern: filter.keyword, options: options)
                    let range = NSRange(location: 0, length: content.utf16.count)
                    if regex.firstMatch(in: content, options: [], range: range) != nil {
                        return true
                    }
                } catch {
                    print("Invalid regex pattern: \(filter.keyword)")
                    continue
                }
            } else {
                // Simple string containment check
                if filter.isCaseSensitive {
                    if content.contains(filter.keyword) {
                        return true
                    }
                } else {
                    if content.lowercased().contains(filter.keyword.lowercased()) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Returns all available filters
    /// - Returns: Array of ContentFilter objects
    func getAllFilters() -> [ContentFilter] {
        return filters
    }
    
    // MARK: - Persistence Methods
    /// Saves the current filters to iCloud or local storage
    private func saveFilters() {
        if let encodedData = try? JSONEncoder().encode(filters) {
            if isICloudAvailable() {
                print("Saving filters to iCloud.")
                iCloudStore.set(encodedData, forKey: filtersKey)
                iCloudStore.synchronize()
            } else {
                print("Saving filters to local storage.")
                UserDefaults.standard.set(encodedData, forKey: filtersKey)
                showICloudFallbackWarning()
            }
        } else {
            print("Failed to encode filters.")
        }
    }
    
    /// Loads filters from iCloud or local storage
    private func loadFilters() {
        if isICloudAvailable() {
            print("Loading filters from iCloud.")
            if let data = iCloudStore.data(forKey: filtersKey),
               let savedFilters = try? JSONDecoder().decode([ContentFilter].self, from: data) {
                filters = savedFilters
            } else {
                print("No filters found in iCloud.")
            }
        } else {
            print("Loading filters from local storage.")
            if let data = UserDefaults.standard.data(forKey: filtersKey),
               let savedFilters = try? JSONDecoder().decode([ContentFilter].self, from: data) {
                filters = savedFilters
            } else {
                print("No filters found locally.")
            }
        }
    }
    
    // MARK: - iCloud Fallback Warning
    /// Warns the user only once if iCloud is unavailable and the app falls back to local storage
    private func showICloudFallbackWarning() {
        let hasShownWarning = UserDefaults.standard.bool(forKey: iCloudFallbackWarningKey)
        if !hasShownWarning {
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "iCloud Sync Unavailable",
                    message: "You're not signed into iCloud. Filters are being saved locally. Sign in to iCloud to enable syncing across devices.",
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
    
    // MARK: - Filter Testing
    /// Tests a filter against sample content for validation
    /// - Parameters:
    ///   - filter: The filter to test
    ///   - content: The sample content to test against
    /// - Returns: Boolean indicating if the filter would match the content
    func testFilter(_ filter: ContentFilter, against content: String) -> Bool {
        if filter.isRegex {
            do {
                let options: NSRegularExpression.Options = filter.isCaseSensitive ? [] : .caseInsensitive
                let regex = try NSRegularExpression(pattern: filter.keyword, options: options)
                let range = NSRange(location: 0, length: content.utf16.count)
                return regex.firstMatch(in: content, options: [], range: range) != nil
            } catch {
                print("Invalid regex pattern: \(filter.keyword)")
                return false
            }
        } else {
            if filter.isCaseSensitive {
                return content.contains(filter.keyword)
            } else {
                return content.lowercased().contains(filter.keyword.lowercased())
            }
        }
    }
}