import Foundation

/// Manages content filtering settings and operations for Channer
/// Supports both legacy simple filters and advanced filters (regex, file type, country, trip code, time-based)
class ContentFilterManager {
    // MARK: - Singleton
    static let shared = ContentFilterManager()

    // MARK: - Constants (Legacy)
    private let keywordFiltersKey = "content_filters"
    private let posterFiltersKey = "poster_filters"
    private let imageFiltersKey = "image_filters"
    private let filterEnabledKey = "content_filter_enabled"

    // MARK: - Constants (Advanced)
    private let advancedFiltersKey = "advanced_content_filters"
    private let advancedFilterEnabledKey = "advanced_filter_enabled"

    // MARK: - Thread Safety
    private let queue = DispatchQueue(label: "com.channer.contentfilter", attributes: .concurrent)

    // MARK: - Cached Advanced Filters
    private var _advancedFilters: [AdvancedFilter] = []
    private var advancedFilters: [AdvancedFilter] {
        get {
            queue.sync { _advancedFilters }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?._advancedFilters = newValue
            }
        }
    }

    // MARK: - Initialization
    private init() {
        // Set default filter enabled state if it doesn't exist
        if UserDefaults.standard.object(forKey: filterEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: filterEnabledKey)
        }
        if UserDefaults.standard.object(forKey: advancedFilterEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: advancedFilterEnabledKey)
        }

        // Load advanced filters into cache
        loadAdvancedFilters()
    }

    // MARK: - Legacy Public Methods

    /// Checks if content filtering is enabled
    func isFilteringEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: filterEnabledKey)
    }

    /// Sets whether content filtering is enabled
    func setFilteringEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: filterEnabledKey)
    }

    /// Gets all active legacy filters
    func getAllFilters() -> (keywords: [String], posters: [String], images: [String]) {
        let keywords = UserDefaults.standard.stringArray(forKey: keywordFiltersKey) ?? []
        let posters = UserDefaults.standard.stringArray(forKey: posterFiltersKey) ?? []
        let images = UserDefaults.standard.stringArray(forKey: imageFiltersKey) ?? []
        return (keywords, posters, images)
    }

    // MARK: - Legacy Add/Remove Methods

    /// Adds a keyword filter
    @discardableResult
    func addKeywordFilter(_ text: String) -> Bool {
        var filters = UserDefaults.standard.stringArray(forKey: keywordFiltersKey) ?? []
        guard !filters.contains(text) else { return false }
        filters.append(text)
        UserDefaults.standard.set(filters, forKey: keywordFiltersKey)
        return true
    }

    /// Removes a keyword filter
    @discardableResult
    func removeKeywordFilter(_ text: String) -> Bool {
        var filters = UserDefaults.standard.stringArray(forKey: keywordFiltersKey) ?? []
        guard let index = filters.firstIndex(of: text) else { return false }
        filters.remove(at: index)
        UserDefaults.standard.set(filters, forKey: keywordFiltersKey)
        return true
    }

    /// Adds a poster ID filter
    @discardableResult
    func addPosterFilter(_ text: String) -> Bool {
        var filters = UserDefaults.standard.stringArray(forKey: posterFiltersKey) ?? []
        guard !filters.contains(text) else { return false }
        filters.append(text)
        UserDefaults.standard.set(filters, forKey: posterFiltersKey)
        return true
    }

    /// Removes a poster ID filter
    @discardableResult
    func removePosterFilter(_ text: String) -> Bool {
        var filters = UserDefaults.standard.stringArray(forKey: posterFiltersKey) ?? []
        guard let index = filters.firstIndex(of: text) else { return false }
        filters.remove(at: index)
        UserDefaults.standard.set(filters, forKey: posterFiltersKey)
        return true
    }

    /// Adds an image name filter
    @discardableResult
    func addImageFilter(_ text: String) -> Bool {
        var filters = UserDefaults.standard.stringArray(forKey: imageFiltersKey) ?? []
        guard !filters.contains(text) else { return false }
        filters.append(text)
        UserDefaults.standard.set(filters, forKey: imageFiltersKey)
        return true
    }

    /// Removes an image name filter
    @discardableResult
    func removeImageFilter(_ text: String) -> Bool {
        var filters = UserDefaults.standard.stringArray(forKey: imageFiltersKey) ?? []
        guard let index = filters.firstIndex(of: text) else { return false }
        filters.remove(at: index)
        UserDefaults.standard.set(filters, forKey: imageFiltersKey)
        return true
    }

    // MARK: - iCloud Sync Support (Legacy)

    func syncKeywordsFromICloud(_ keywords: [String]) {
        UserDefaults.standard.set(keywords, forKey: keywordFiltersKey)
    }

    func syncPostersFromICloud(_ posters: [String]) {
        UserDefaults.standard.set(posters, forKey: posterFiltersKey)
    }

    func syncImagesFromICloud(_ images: [String]) {
        UserDefaults.standard.set(images, forKey: imageFiltersKey)
    }

    // MARK: - Advanced Filtering Methods

    /// Checks if advanced filtering is enabled
    func isAdvancedFilteringEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: advancedFilterEnabledKey)
    }

    /// Sets whether advanced filtering is enabled
    func setAdvancedFilteringEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: advancedFilterEnabledKey)
    }

    /// Gets all advanced filters
    func getAdvancedFilters() -> [AdvancedFilter] {
        return advancedFilters
    }

    /// Gets advanced filters by type
    func getAdvancedFilters(ofType type: FilterType) -> [AdvancedFilter] {
        return advancedFilters.filter { $0.filterType == type }
    }

    /// Gets enabled advanced filters
    func getEnabledAdvancedFilters() -> [AdvancedFilter] {
        return advancedFilters.filter { $0.isEnabled }
    }

    /// Adds an advanced filter
    @discardableResult
    func addAdvancedFilter(_ filter: AdvancedFilter) -> Bool {
        // Check for duplicates based on type and value
        guard !advancedFilters.contains(where: {
            $0.filterType == filter.filterType && $0.value == filter.value
        }) else {
            return false
        }

        var filters = advancedFilters
        filters.append(filter)
        advancedFilters = filters
        saveAdvancedFilters()

        NotificationCenter.default.post(name: .advancedFiltersDidChange, object: nil)
        return true
    }

    /// Removes an advanced filter by ID
    @discardableResult
    func removeAdvancedFilter(id: UUID) -> Bool {
        var filters = advancedFilters
        guard let index = filters.firstIndex(where: { $0.id == id }) else {
            return false
        }
        filters.remove(at: index)
        advancedFilters = filters
        saveAdvancedFilters()

        NotificationCenter.default.post(name: .advancedFiltersDidChange, object: nil)
        return true
    }

    /// Updates an advanced filter
    @discardableResult
    func updateAdvancedFilter(_ filter: AdvancedFilter) -> Bool {
        var filters = advancedFilters
        guard let index = filters.firstIndex(where: { $0.id == filter.id }) else {
            return false
        }

        var updatedFilter = filter
        updatedFilter.modifiedAt = Date()
        filters[index] = updatedFilter
        advancedFilters = filters
        saveAdvancedFilters()

        NotificationCenter.default.post(name: .advancedFiltersDidChange, object: nil)
        return true
    }

    /// Toggles an advanced filter's enabled state
    @discardableResult
    func toggleAdvancedFilter(id: UUID) -> Bool {
        var filters = advancedFilters
        guard let index = filters.firstIndex(where: { $0.id == id }) else {
            return false
        }

        filters[index].isEnabled.toggle()
        filters[index].modifiedAt = Date()
        advancedFilters = filters
        saveAdvancedFilters()

        NotificationCenter.default.post(name: .advancedFiltersDidChange, object: nil)
        return true
    }

    /// Increments the hit count for a filter
    func recordFilterHit(id: UUID) {
        var filters = advancedFilters
        guard let index = filters.firstIndex(where: { $0.id == id }) else {
            return
        }

        filters[index].hitCount += 1
        advancedFilters = filters
        // Don't save immediately to avoid performance issues
        // Save periodically or on app background
    }

    // MARK: - Filter Application

    /// Checks if a post should be filtered based on all enabled filters
    /// - Parameter post: The post metadata to check
    /// - Returns: True if the post should be hidden
    func shouldFilter(post: PostMetadata) -> Bool {
        // Check legacy filters first
        if isFilteringEnabled() {
            let legacyFilters = getAllFilters()

            // Check keyword filters
            for keyword in legacyFilters.keywords {
                if post.comment.lowercased().contains(keyword.lowercased()) {
                    return true
                }
            }

            // Check poster filters
            if let posterId = post.posterId {
                for poster in legacyFilters.posters {
                    if posterId.lowercased().contains(poster.lowercased()) {
                        return true
                    }
                }
            }

            // Check image filters
            if let imageUrl = post.imageUrl {
                for image in legacyFilters.images {
                    if imageUrl.lowercased().contains(image.lowercased()) {
                        return true
                    }
                }
            }
        }

        // Check advanced filters
        if isAdvancedFilteringEnabled() {
            let enabledFilters = getEnabledAdvancedFilters()

            // Separate whitelist and blacklist filters
            let blacklistFilters = enabledFilters.filter { $0.filterMode == .blacklist }
            let whitelistFilters = enabledFilters.filter { $0.filterMode == .whitelist }

            // If there are whitelist filters, check if post matches any
            if !whitelistFilters.isEmpty {
                let matchesWhitelist = whitelistFilters.contains { $0.matches(post: post) }
                if !matchesWhitelist {
                    return true  // Hide if doesn't match whitelist
                }
            }

            // Check blacklist filters
            for filter in blacklistFilters {
                if filter.matches(post: post) {
                    recordFilterHit(id: filter.id)
                    return true
                }
            }
        }

        return false
    }

    /// Validates a regex pattern
    func isValidRegex(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return true
        } catch {
            return false
        }
    }

    /// Tests a filter against sample content
    func testFilter(_ filter: AdvancedFilter, against content: String) -> Bool {
        let testPost = PostMetadata(
            postNumber: "0",
            comment: content,
            posterId: nil,
            tripCode: nil,
            countryCode: nil,
            countryName: nil,
            timestamp: Int(Date().timeIntervalSince1970),
            imageUrl: nil,
            imageExtension: nil,
            imageName: nil
        )
        return filter.matches(post: testPost)
    }

    // MARK: - Persistence

    private func loadAdvancedFilters() {
        guard let data = UserDefaults.standard.data(forKey: advancedFiltersKey) else {
            _advancedFilters = []
            return
        }

        do {
            let filters = try JSONDecoder().decode([AdvancedFilter].self, from: data)
            _advancedFilters = filters
        } catch {
            print("Failed to decode advanced filters: \(error)")
            _advancedFilters = []
        }
    }

    private func saveAdvancedFilters() {
        do {
            let data = try JSONEncoder().encode(advancedFilters)
            UserDefaults.standard.set(data, forKey: advancedFiltersKey)
        } catch {
            print("Failed to encode advanced filters: \(error)")
        }
    }

    /// Force saves advanced filters (call on app background)
    func saveAdvancedFiltersIfNeeded() {
        saveAdvancedFilters()
    }

    // MARK: - Migration

    /// Migrates legacy filters to advanced filters
    func migrateLegacyFiltersToAdvanced() {
        let legacy = getAllFilters()

        // Migrate keyword filters
        for keyword in legacy.keywords {
            let filter = AdvancedFilter.keyword(keyword)
            addAdvancedFilter(filter)
        }

        // Migrate poster filters
        for poster in legacy.posters {
            let filter = AdvancedFilter.posterId(poster)
            addAdvancedFilter(filter)
        }

        // Migrate image filters
        for image in legacy.images {
            let filter = AdvancedFilter.imageName(image)
            addAdvancedFilter(filter)
        }
    }

    // MARK: - Statistics

    /// Returns filter statistics
    func getFilterStatistics() -> (total: Int, enabled: Int, byType: [FilterType: Int]) {
        let filters = advancedFilters
        var byType: [FilterType: Int] = [:]

        for type in FilterType.allCases {
            byType[type] = filters.filter { $0.filterType == type }.count
        }

        return (
            total: filters.count,
            enabled: filters.filter { $0.isEnabled }.count,
            byType: byType
        )
    }

    /// Returns the most effective filters by hit count
    func getMostEffectiveFilters(limit: Int = 10) -> [AdvancedFilter] {
        return advancedFilters
            .sorted { $0.hitCount > $1.hitCount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Import/Export

    /// Exports all advanced filters as JSON data
    func exportAdvancedFilters() -> Data? {
        do {
            return try JSONEncoder().encode(advancedFilters)
        } catch {
            print("Failed to export filters: \(error)")
            return nil
        }
    }

    /// Imports advanced filters from JSON data
    @discardableResult
    func importAdvancedFilters(from data: Data, replace: Bool = false) -> Int {
        do {
            let importedFilters = try JSONDecoder().decode([AdvancedFilter].self, from: data)

            if replace {
                advancedFilters = importedFilters
                saveAdvancedFilters()
                return importedFilters.count
            } else {
                var addedCount = 0
                for filter in importedFilters {
                    if addAdvancedFilter(filter) {
                        addedCount += 1
                    }
                }
                return addedCount
            }
        } catch {
            print("Failed to import filters: \(error)")
            return 0
        }
    }

    /// Clears all advanced filters
    func clearAllAdvancedFilters() {
        advancedFilters = []
        saveAdvancedFilters()
        NotificationCenter.default.post(name: .advancedFiltersDidChange, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let advancedFiltersDidChange = Notification.Name("advancedFiltersDidChange")
}
