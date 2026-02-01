import Foundation

// MARK: - Filter Types

/// Represents the different types of advanced filters available
enum FilterType: String, Codable, CaseIterable {
    case keyword = "keyword"
    case regex = "regex"
    case posterId = "poster_id"
    case imageName = "image_name"
    case fileType = "file_type"
    case countryFlag = "country_flag"
    case tripCode = "trip_code"
    case timeBased = "time_based"

    var displayName: String {
        switch self {
        case .keyword: return "Keyword"
        case .regex: return "Regex Pattern"
        case .posterId: return "Poster ID"
        case .imageName: return "Image Name"
        case .fileType: return "File Type"
        case .countryFlag: return "Country Flag"
        case .tripCode: return "Trip Code"
        case .timeBased: return "Time-Based"
        }
    }

    var description: String {
        switch self {
        case .keyword: return "Filter posts containing specific text"
        case .regex: return "Filter posts matching a regex pattern"
        case .posterId: return "Filter posts from specific poster IDs"
        case .imageName: return "Filter posts with specific image names"
        case .fileType: return "Filter posts by attachment type"
        case .countryFlag: return "Filter posts by country flag"
        case .tripCode: return "Filter posts by trip code"
        case .timeBased: return "Filter posts older than specified time"
        }
    }
}

/// Represents file type filter options
enum FileTypeFilter: String, Codable, CaseIterable {
    case hideVideos = "hide_videos"
    case hideImages = "hide_images"
    case hideGifs = "hide_gifs"
    case showImagesOnly = "show_images_only"
    case showVideosOnly = "show_videos_only"

    var displayName: String {
        switch self {
        case .hideVideos: return "Hide Videos"
        case .hideImages: return "Hide Images"
        case .hideGifs: return "Hide GIFs"
        case .showImagesOnly: return "Show Images Only"
        case .showVideosOnly: return "Show Videos Only"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .hideVideos: return [".webm", ".mp4"]
        case .hideImages: return [".jpg", ".jpeg", ".png"]
        case .hideGifs: return [".gif"]
        case .showImagesOnly: return [".jpg", ".jpeg", ".png", ".gif"]
        case .showVideosOnly: return [".webm", ".mp4"]
        }
    }
}

/// Time unit for time-based filters
enum TimeUnit: String, Codable, CaseIterable {
    case minutes = "minutes"
    case hours = "hours"
    case days = "days"
    case weeks = "weeks"

    var displayName: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        case .days: return "Days"
        case .weeks: return "Weeks"
        }
    }

    func toSeconds(_ value: Int) -> TimeInterval {
        switch self {
        case .minutes: return TimeInterval(value * 60)
        case .hours: return TimeInterval(value * 3600)
        case .days: return TimeInterval(value * 86400)
        case .weeks: return TimeInterval(value * 604800)
        }
    }
}

/// Filter mode for whitelist/blacklist behavior
enum FilterMode: String, Codable {
    case blacklist = "blacklist"  // Hide matching posts
    case whitelist = "whitelist"  // Only show matching posts

    var displayName: String {
        switch self {
        case .blacklist: return "Hide Matching"
        case .whitelist: return "Show Only Matching"
        }
    }
}

// MARK: - Advanced Filter Model

/// A comprehensive filter model supporting all advanced filter types
struct AdvancedFilter: Codable, Equatable, Identifiable {
    let id: UUID
    var filterType: FilterType
    var value: String
    var isEnabled: Bool
    var isCaseSensitive: Bool
    var filterMode: FilterMode

    // File type specific
    var fileTypeFilter: FileTypeFilter?

    // Time-based specific
    var timeValue: Int?
    var timeUnit: TimeUnit?

    // Metadata
    var createdAt: Date
    var modifiedAt: Date
    var hitCount: Int

    init(
        filterType: FilterType,
        value: String,
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false,
        filterMode: FilterMode = .blacklist,
        fileTypeFilter: FileTypeFilter? = nil,
        timeValue: Int? = nil,
        timeUnit: TimeUnit? = nil
    ) {
        self.id = UUID()
        self.filterType = filterType
        self.value = value
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
        self.filterMode = filterMode
        self.fileTypeFilter = fileTypeFilter
        self.timeValue = timeValue
        self.timeUnit = timeUnit
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.hitCount = 0
    }

    static func == (lhs: AdvancedFilter, rhs: AdvancedFilter) -> Bool {
        return lhs.id == rhs.id
    }

    /// Creates a keyword filter
    static func keyword(_ text: String, caseSensitive: Bool = false) -> AdvancedFilter {
        return AdvancedFilter(filterType: .keyword, value: text, isCaseSensitive: caseSensitive)
    }

    /// Creates a regex filter
    static func regex(_ pattern: String, caseSensitive: Bool = false) -> AdvancedFilter {
        return AdvancedFilter(filterType: .regex, value: pattern, isCaseSensitive: caseSensitive)
    }

    /// Creates a poster ID filter
    static func posterId(_ id: String) -> AdvancedFilter {
        return AdvancedFilter(filterType: .posterId, value: id)
    }

    /// Creates an image name filter
    static func imageName(_ name: String) -> AdvancedFilter {
        return AdvancedFilter(filterType: .imageName, value: name)
    }

    /// Creates a file type filter
    static func fileType(_ filter: FileTypeFilter) -> AdvancedFilter {
        return AdvancedFilter(filterType: .fileType, value: filter.rawValue, fileTypeFilter: filter)
    }

    /// Creates a country flag filter
    static func countryFlag(_ countryCode: String, mode: FilterMode = .blacklist) -> AdvancedFilter {
        return AdvancedFilter(filterType: .countryFlag, value: countryCode.uppercased(), filterMode: mode)
    }

    /// Creates a trip code filter
    static func tripCode(_ tripCode: String, mode: FilterMode = .blacklist) -> AdvancedFilter {
        return AdvancedFilter(filterType: .tripCode, value: tripCode, filterMode: mode)
    }

    /// Creates a time-based filter
    static func timeBased(value: Int, unit: TimeUnit) -> AdvancedFilter {
        return AdvancedFilter(
            filterType: .timeBased,
            value: "\(value) \(unit.displayName.lowercased())",
            timeValue: value,
            timeUnit: unit
        )
    }

    /// Display name for the filter
    var displayName: String {
        switch filterType {
        case .keyword, .regex, .posterId, .imageName:
            return value
        case .fileType:
            return fileTypeFilter?.displayName ?? value
        case .countryFlag:
            return "\(filterMode.displayName): \(value)"
        case .tripCode:
            return "\(filterMode.displayName): \(value)"
        case .timeBased:
            if let tv = timeValue, let tu = timeUnit {
                return "Posts older than \(tv) \(tu.displayName.lowercased())"
            }
            return value
        }
    }
}

// MARK: - Post Metadata for Filtering

/// Stores metadata about a post for filtering purposes
struct PostMetadata: Codable {
    let postNumber: String
    let comment: String
    let posterId: String?
    let tripCode: String?
    let countryCode: String?
    let countryName: String?
    let timestamp: Int?  // Unix timestamp
    let imageUrl: String?
    let imageExtension: String?
    let imageName: String?
    let fileHash: String?

    /// Checks if post has an attachment
    var hasAttachment: Bool {
        return imageUrl != nil && !imageUrl!.isEmpty && imageExtension != nil && !imageExtension!.isEmpty
    }

    /// Checks if attachment is a video
    var isVideo: Bool {
        guard let ext = imageExtension?.lowercased() else { return false }
        return ext == ".webm" || ext == ".mp4"
    }

    /// Checks if attachment is an image
    var isImage: Bool {
        guard let ext = imageExtension?.lowercased() else { return false }
        return ext == ".jpg" || ext == ".jpeg" || ext == ".png"
    }

    /// Checks if attachment is a GIF
    var isGif: Bool {
        guard let ext = imageExtension?.lowercased() else { return false }
        return ext == ".gif"
    }

    /// Returns the post's age in seconds
    var ageInSeconds: TimeInterval? {
        guard let ts = timestamp else { return nil }
        return Date().timeIntervalSince1970 - TimeInterval(ts)
    }
}

// MARK: - Filter Matching Logic

extension AdvancedFilter {

    /// Checks if a post should be filtered based on this filter
    /// - Parameter post: The post metadata to check
    /// - Returns: True if the post should be hidden (for blacklist) or shown (for whitelist)
    func matches(post: PostMetadata) -> Bool {
        guard isEnabled else { return false }

        switch filterType {
        case .keyword:
            return matchesKeyword(post.comment)

        case .regex:
            return matchesRegex(post.comment)

        case .posterId:
            guard let posterId = post.posterId else { return false }
            return matchesExact(posterId, against: value)

        case .imageName:
            guard let imageName = post.imageName else { return false }
            return matchesContains(imageName, against: value)

        case .fileType:
            return matchesFileType(post)

        case .countryFlag:
            guard let countryCode = post.countryCode else { return false }
            return matchesExact(countryCode.uppercased(), against: value.uppercased())

        case .tripCode:
            guard let tripCode = post.tripCode else { return false }
            return matchesExact(tripCode, against: value)

        case .timeBased:
            return matchesTimeBased(post)
        }
    }

    private func matchesKeyword(_ content: String) -> Bool {
        if isCaseSensitive {
            return content.contains(value)
        } else {
            return content.lowercased().contains(value.lowercased())
        }
    }

    private func matchesRegex(_ content: String) -> Bool {
        do {
            let options: NSRegularExpression.Options = isCaseSensitive ? [] : .caseInsensitive
            let regex = try NSRegularExpression(pattern: value, options: options)
            let range = NSRange(location: 0, length: content.utf16.count)
            return regex.firstMatch(in: content, options: [], range: range) != nil
        } catch {
            print("Invalid regex pattern: \(value)")
            return false
        }
    }

    private func matchesExact(_ content: String, against filter: String) -> Bool {
        if isCaseSensitive {
            return content == filter
        } else {
            return content.lowercased() == filter.lowercased()
        }
    }

    private func matchesContains(_ content: String, against filter: String) -> Bool {
        if isCaseSensitive {
            return content.contains(filter)
        } else {
            return content.lowercased().contains(filter.lowercased())
        }
    }

    private func matchesFileType(_ post: PostMetadata) -> Bool {
        guard let filter = fileTypeFilter, post.hasAttachment else { return false }

        switch filter {
        case .hideVideos:
            return post.isVideo
        case .hideImages:
            return post.isImage
        case .hideGifs:
            return post.isGif
        case .showImagesOnly:
            // For "show only" filters, return true for non-matching (to hide them)
            return !post.isImage && !post.isGif
        case .showVideosOnly:
            return !post.isVideo
        }
    }

    private func matchesTimeBased(_ post: PostMetadata) -> Bool {
        guard let tv = timeValue, let tu = timeUnit, let age = post.ageInSeconds else {
            return false
        }
        let thresholdSeconds = tu.toSeconds(tv)
        return age > thresholdSeconds
    }
}

// MARK: - Country Code Helpers

/// Common country codes used in 4chan boards with country flags
struct CountryCodes {
    static let common: [(code: String, name: String)] = [
        ("US", "United States"),
        ("GB", "United Kingdom"),
        ("CA", "Canada"),
        ("AU", "Australia"),
        ("DE", "Germany"),
        ("FR", "France"),
        ("NL", "Netherlands"),
        ("SE", "Sweden"),
        ("FI", "Finland"),
        ("NO", "Norway"),
        ("DK", "Denmark"),
        ("PL", "Poland"),
        ("RU", "Russia"),
        ("JP", "Japan"),
        ("BR", "Brazil"),
        ("MX", "Mexico"),
        ("AR", "Argentina"),
        ("IT", "Italy"),
        ("ES", "Spain"),
        ("PT", "Portugal"),
        ("IE", "Ireland"),
        ("NZ", "New Zealand"),
        ("IN", "India"),
        ("KR", "South Korea"),
        ("CN", "China"),
        ("TW", "Taiwan"),
        ("HK", "Hong Kong"),
        ("SG", "Singapore"),
        ("MY", "Malaysia"),
        ("PH", "Philippines"),
        ("TH", "Thailand"),
        ("ID", "Indonesia"),
        ("VN", "Vietnam"),
        ("ZA", "South Africa"),
        ("IL", "Israel"),
        ("TR", "Turkey"),
        ("GR", "Greece"),
        ("CH", "Switzerland"),
        ("AT", "Austria"),
        ("BE", "Belgium"),
        ("CZ", "Czech Republic"),
        ("HU", "Hungary"),
        ("RO", "Romania"),
        ("UA", "Ukraine"),
        ("BG", "Bulgaria"),
        ("HR", "Croatia"),
        ("RS", "Serbia"),
        ("SK", "Slovakia"),
        ("SI", "Slovenia"),
        ("EE", "Estonia"),
        ("LV", "Latvia"),
        ("LT", "Lithuania")
    ]

    /// Returns the country name for a given code
    static func name(for code: String) -> String? {
        return common.first { $0.code == code.uppercased() }?.name
    }

    /// Returns emoji flag for a country code
    static func flag(for code: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in code.uppercased().unicodeScalars {
            emoji.append(String(UnicodeScalar(base + scalar.value)!))
        }
        return emoji
    }
}
