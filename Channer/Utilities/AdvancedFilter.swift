import Foundation

// MARK: - Filter Types

/// Represents the different types of advanced filters available
enum FilterType: String, Codable, CaseIterable {
    case xtGeneral = "xt_general"
    case keyword = "keyword"
    case regex = "regex"
    case posterId = "poster_id"
    case imageName = "image_name"
    case fileType = "file_type"
    case countryFlag = "country_flag"
    case tripCode = "trip_code"
    case timeBased = "time_based"
    case subject = "subject"
    case email = "email"
    case capcode = "capcode"
    case passDate = "pass"
    case dimensions = "dimensions"
    case fileSize = "filesize"
    case md5 = "md5"

    var displayName: String {
        switch self {
        case .xtGeneral: return "XT General"
        case .keyword: return "Keyword"
        case .regex: return "Regex Pattern"
        case .posterId: return "Poster ID"
        case .imageName: return "Image Name"
        case .fileType: return "File Type"
        case .countryFlag: return "Country Flag"
        case .tripCode: return "Trip Code"
        case .timeBased: return "Time-Based"
        case .subject: return "Subject"
        case .email: return "Email"
        case .capcode: return "Capcode"
        case .passDate: return "Pass Date"
        case .dimensions: return "Image Dimensions"
        case .fileSize: return "Filesize"
        case .md5: return "Image MD5"
        }
    }

    var description: String {
        switch self {
        case .xtGeneral: return "Filter posts using XT's multi-field filter syntax"
        case .keyword: return "Filter posts containing specific text"
        case .regex: return "Filter posts matching a regex pattern"
        case .posterId: return "Filter posts from specific poster IDs"
        case .imageName: return "Filter posts with specific image names"
        case .fileType: return "Filter posts by attachment type"
        case .countryFlag: return "Filter posts by country flag"
        case .tripCode: return "Filter posts by trip code"
        case .timeBased: return "Filter posts older than specified time"
        case .subject: return "Filter posts by subject"
        case .email: return "Filter posts by email/options"
        case .capcode: return "Filter posts by capcode"
        case .passDate: return "Filter posts by 4chan Pass date"
        case .dimensions: return "Filter posts by image dimensions"
        case .fileSize: return "Filter posts by filesize"
        case .md5: return "Filter posts by image MD5"
        }
    }
}

// MARK: - XT Filter Language

enum XTFilterField: String, Codable, CaseIterable {
    case postID
    case name
    case uniqueID
    case tripcode
    case capcode
    case pass
    case email
    case subject
    case comment
    case flag
    case filename
    case dimensions
    case filesize
    case MD5
}

enum XTPostScope: String, Codable {
    case any
    case repliesOnly
    case opOnly
}

enum XTFileScope: String, Codable {
    case any
    case withFileOnly
    case withoutFileOnly
}

struct XTFilterOptions: Codable, Equatable {
    var boards: [String]?
    var excludedBoards: [String]?
    var postScope: XTPostScope
    var fileScope: XTFileScope
    var stub: Bool?
    var highlightClass: String?
    var pinToTop: Bool?
    var notify: Bool
    var samePoster: Bool
    var recursiveReplies: Bool
    var hide: Bool
    var reason: String?
    var generalFieldGroups: [[XTFilterField]]?

    init(
        boards: [String]? = nil,
        excludedBoards: [String]? = nil,
        postScope: XTPostScope = .any,
        fileScope: XTFileScope = .any,
        stub: Bool? = nil,
        highlightClass: String? = nil,
        pinToTop: Bool? = nil,
        notify: Bool = false,
        samePoster: Bool = false,
        recursiveReplies: Bool = false,
        hide: Bool = true,
        reason: String? = nil,
        generalFieldGroups: [[XTFilterField]]? = nil
    ) {
        self.boards = boards
        self.excludedBoards = excludedBoards
        self.postScope = postScope
        self.fileScope = fileScope
        self.stub = stub
        self.highlightClass = highlightClass
        self.pinToTop = pinToTop
        self.notify = notify
        self.samePoster = samePoster
        self.recursiveReplies = recursiveReplies
        self.hide = hide
        self.reason = reason
        self.generalFieldGroups = generalFieldGroups
    }
}

struct AdvancedFilterEffect: Equatable {
    let filterID: UUID
    let shouldHide: Bool
    let showStub: Bool?
    let reason: String?
    let highlightClass: String?
    let pinToTop: Bool
    let notify: Bool
    let samePoster: Bool
    let recursiveReplies: Bool
}

enum XTFilterParseError: Error, LocalizedError {
    case missingPattern
    case unknownField(String)

    var errorDescription: String? {
        switch self {
        case .missingPattern:
            return "XT filters must start with a /pattern/ expression."
        case .unknownField(let field):
            return "Unknown XT filter field: \(field)"
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

    // XT filter language specific
    var xtOptions: XTFilterOptions?
    var xtRegexFlags: String?

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
        timeUnit: TimeUnit? = nil,
        xtOptions: XTFilterOptions? = nil,
        xtRegexFlags: String? = nil
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
        self.xtOptions = xtOptions
        self.xtRegexFlags = xtRegexFlags
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

    /// Creates an exact MD5 filter, matching XT's MD5 filter behavior.
    static func md5(_ hash: String) -> AdvancedFilter {
        return AdvancedFilter(filterType: .md5, value: hash)
    }

    /// Creates a filter from an XT line such as "/pattern/i;boards:g;op:only;reason:Bait".
    static func xt(_ line: String, type: FilterType = .xtGeneral) throws -> AdvancedFilter {
        let parsed = try XTFilterLineParser.parse(line, defaultType: type)
        return AdvancedFilter(
            filterType: parsed.type,
            value: parsed.pattern,
            isCaseSensitive: !parsed.flags.contains("i"),
            filterMode: .blacklist,
            xtOptions: parsed.options,
            xtRegexFlags: parsed.flags
        )
    }

    /// Display name for the filter
    var displayName: String {
        switch filterType {
        case .keyword, .regex, .posterId, .imageName, .xtGeneral, .subject, .email, .capcode, .passDate, .dimensions, .fileSize, .md5:
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
    var posterId: String? = nil
    var tripCode: String? = nil
    var countryCode: String? = nil
    var countryName: String? = nil
    var timestamp: Int? = nil  // Unix timestamp
    var imageUrl: String? = nil
    var imageExtension: String? = nil
    var imageName: String? = nil
    var fileHash: String? = nil
    var isSpoiler: Bool = false
    var boardAbv: String? = nil
    var threadNumber: String? = nil
    var subject: String? = nil
    var name: String? = nil
    var email: String? = nil
    var capcode: String? = nil
    var passDate: String? = nil
    var imageDimensions: String? = nil
    var imageFileSize: String? = nil
    var isOP: Bool = false
    var isTopThread: Bool = false

    enum CodingKeys: String, CodingKey {
        case postNumber, comment, posterId, tripCode, countryCode, countryName, timestamp, imageUrl, imageExtension, imageName, fileHash, isSpoiler
        case boardAbv, threadNumber, subject, name, email, capcode, passDate, imageDimensions, imageFileSize, isOP, isTopThread
    }

    init(
        postNumber: String,
        comment: String,
        posterId: String? = nil,
        tripCode: String? = nil,
        countryCode: String? = nil,
        countryName: String? = nil,
        timestamp: Int? = nil,
        imageUrl: String? = nil,
        imageExtension: String? = nil,
        imageName: String? = nil,
        fileHash: String? = nil,
        isSpoiler: Bool = false,
        boardAbv: String? = nil,
        threadNumber: String? = nil,
        subject: String? = nil,
        name: String? = nil,
        email: String? = nil,
        capcode: String? = nil,
        passDate: String? = nil,
        imageDimensions: String? = nil,
        imageFileSize: String? = nil,
        isOP: Bool = false,
        isTopThread: Bool = false
    ) {
        self.postNumber = postNumber
        self.comment = comment
        self.posterId = posterId
        self.tripCode = tripCode
        self.countryCode = countryCode
        self.countryName = countryName
        self.timestamp = timestamp
        self.imageUrl = imageUrl
        self.imageExtension = imageExtension
        self.imageName = imageName
        self.fileHash = fileHash
        self.isSpoiler = isSpoiler
        self.boardAbv = boardAbv
        self.threadNumber = threadNumber
        self.subject = subject
        self.name = name
        self.email = email
        self.capcode = capcode
        self.passDate = passDate
        self.imageDimensions = imageDimensions
        self.imageFileSize = imageFileSize
        self.isOP = isOP
        self.isTopThread = isTopThread
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postNumber = try container.decode(String.self, forKey: .postNumber)
        comment = try container.decode(String.self, forKey: .comment)
        posterId = try container.decodeIfPresent(String.self, forKey: .posterId)
        tripCode = try container.decodeIfPresent(String.self, forKey: .tripCode)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        countryName = try container.decodeIfPresent(String.self, forKey: .countryName)
        timestamp = try container.decodeIfPresent(Int.self, forKey: .timestamp)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        imageExtension = try container.decodeIfPresent(String.self, forKey: .imageExtension)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        fileHash = try container.decodeIfPresent(String.self, forKey: .fileHash)
        isSpoiler = try container.decodeIfPresent(Bool.self, forKey: .isSpoiler) ?? false
        boardAbv = try container.decodeIfPresent(String.self, forKey: .boardAbv)
        threadNumber = try container.decodeIfPresent(String.self, forKey: .threadNumber)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        capcode = try container.decodeIfPresent(String.self, forKey: .capcode)
        passDate = try container.decodeIfPresent(String.self, forKey: .passDate)
        imageDimensions = try container.decodeIfPresent(String.self, forKey: .imageDimensions)
        imageFileSize = try container.decodeIfPresent(String.self, forKey: .imageFileSize)
        isOP = try container.decodeIfPresent(Bool.self, forKey: .isOP) ?? false
        isTopThread = try container.decodeIfPresent(Bool.self, forKey: .isTopThread) ?? false
    }

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

    var quotedPostNumbers: [String] {
        let pattern = ">>([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(comment.startIndex..<comment.endIndex, in: comment)
        return regex.matches(in: comment, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: comment) else { return nil }
            return String(comment[range])
        }
    }
}

// MARK: - Filter Matching Logic

extension AdvancedFilter {

    /// Checks if a post should be filtered based on this filter
    /// - Parameter post: The post metadata to check
    /// - Returns: True if the post should be hidden (for blacklist) or shown (for whitelist)
    func matches(post: PostMetadata) -> Bool {
        guard isEnabled, appliesToPostContext(post) else { return false }
        return rawMatches(post: post)
    }

    func matchEffect(post: PostMetadata, defaultShowStub: Bool) -> AdvancedFilterEffect? {
        guard matches(post: post) else { return nil }
        let options = xtOptions
        let shouldHide = options?.hide ?? (filterMode == .blacklist)
        return AdvancedFilterEffect(
            filterID: id,
            shouldHide: shouldHide,
            showStub: options?.stub ?? defaultShowStub,
            reason: options?.reason ?? defaultReason,
            highlightClass: options?.highlightClass,
            pinToTop: options?.pinToTop ?? false,
            notify: options?.notify ?? false,
            samePoster: options?.samePoster ?? false,
            recursiveReplies: options?.recursiveReplies ?? false
        )
    }

    private func rawMatches(post: PostMetadata) -> Bool {
        switch filterType {
        case .xtGeneral:
            return matchesXTGeneral(post)

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

        case .subject:
            return post.subject.map { matchesRegexOrContains($0) } ?? false

        case .email:
            return post.email.map { matchesRegexOrContains($0) } ?? false

        case .capcode:
            return post.capcode.map { matchesRegexOrContains($0) } ?? false

        case .passDate:
            return post.passDate.map { matchesRegexOrContains($0) } ?? false

        case .dimensions:
            return post.imageDimensions.map { matchesRegexOrContains($0) } ?? false

        case .fileSize:
            return post.imageFileSize.map { matchesRegexOrContains($0) } ?? false

        case .md5:
            return post.fileHash.map { matchesExact($0, against: value) } ?? false
        }
    }

    private var defaultReason: String {
        switch filterType {
        case .xtGeneral:
            let fields = xtOptions?.generalFieldGroups?.map { group in
                group.map(\.rawValue).joined(separator: "+")
            }.joined(separator: ",") ?? "general"
            return "Filtered \(fields) /\(value)/"
        case .md5:
            return "Filtered MD5 \(value)"
        default:
            return "Filtered \(filterType.displayName) \(value)"
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
            var options: NSRegularExpression.Options = isCaseSensitive ? [] : .caseInsensitive
            if xtRegexFlags?.contains("m") == true {
                options.insert(.anchorsMatchLines)
            }
            if xtRegexFlags?.contains("s") == true {
                options.insert(.dotMatchesLineSeparators)
            }
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

    private func matchesRegexOrContains(_ content: String) -> Bool {
        if xtOptions != nil || xtRegexFlags != nil {
            return matchesRegex(content)
        }
        return matchesContains(content, against: value)
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

    private func appliesToPostContext(_ post: PostMetadata) -> Bool {
        guard let options = xtOptions else { return true }

        let board = post.boardAbv?.lowercased()
        if let boards = options.boards, !boards.isEmpty {
            guard let board = board, boards.contains("*") || boards.contains(board) else { return false }
        }
        if let excludedBoards = options.excludedBoards, let board = board {
            if excludedBoards.contains("*") || excludedBoards.contains(board) {
                return false
            }
        }

        switch options.postScope {
        case .any:
            break
        case .repliesOnly:
            if post.isOP { return false }
        case .opOnly:
            if !post.isOP { return false }
        }

        switch options.fileScope {
        case .any:
            break
        case .withFileOnly:
            if !post.hasAttachment { return false }
        case .withoutFileOnly:
            if post.hasAttachment { return false }
        }

        return true
    }

    private func matchesXTGeneral(_ post: PostMetadata) -> Bool {
        let groups = xtOptions?.generalFieldGroups ?? [[.subject], [.name], [.filename], [.comment]]
        for group in groups {
            let joined = group.map { values(for: $0, post: post).joined(separator: "\n") }.joined(separator: "\n")
            if matchesRegex(joined) {
                return true
            }
        }
        return false
    }

    private func values(for field: XTFilterField, post: PostMetadata) -> [String] {
        switch field {
        case .postID:
            return [post.postNumber]
        case .name:
            return [post.name].compactMap { $0 }
        case .uniqueID:
            return [post.posterId].compactMap { $0 }
        case .tripcode:
            return [post.tripCode].compactMap { $0 }
        case .capcode:
            return [post.capcode].compactMap { $0 }
        case .pass:
            return [post.passDate].compactMap { $0 }
        case .email:
            return [post.email].compactMap { $0 }
        case .subject:
            return [post.subject ?? (post.isOP ? "" : nil)].compactMap { $0 }
        case .comment:
            return [post.comment]
        case .flag:
            return [post.countryCode].compactMap { $0 }
        case .filename:
            return [post.imageName].compactMap { $0 }
        case .dimensions:
            return [post.imageDimensions].compactMap { $0 }
        case .filesize:
            return [post.imageFileSize].compactMap { $0 }
        case .MD5:
            return [post.fileHash].compactMap { $0 }
        }
    }
}

private struct XTParsedFilterLine {
    let pattern: String
    let flags: String
    let type: FilterType
    let options: XTFilterOptions
}

private enum XTFilterLineParser {
    static func parse(_ line: String, defaultType: FilterType) throws -> XTParsedFilterLine {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), trimmed.first == "/" else {
            throw XTFilterParseError.missingPattern
        }

        guard let closingSlash = lastUnescapedSlash(in: trimmed) else {
            throw XTFilterParseError.missingPattern
        }

        let patternStart = trimmed.index(after: trimmed.startIndex)
        let pattern = String(trimmed[patternStart..<closingSlash])
        let afterSlash = trimmed.index(after: closingSlash)
        let remainder = String(trimmed[afterSlash...])
        let flagEnd = remainder.firstIndex(of: ";") ?? remainder.endIndex
        let flags = String(remainder[..<flagEnd])
        let optionsText = flagEnd == remainder.endIndex ? "" : String(remainder[flagEnd...])
        let parsedOptions = try parseOptions(optionsText)
        return XTParsedFilterLine(pattern: pattern, flags: flags, type: defaultType, options: parsedOptions)
    }

    private static func lastUnescapedSlash(in line: String) -> String.Index? {
        var index = line.index(before: line.endIndex)
        while index > line.startIndex {
            if line[index] == "/" {
                let before = line.index(before: index)
                if line[before] != "\\" {
                    return index
                }
            }
            index = line.index(before: index)
        }
        return nil
    }

    private static func parseOptions(_ text: String) throws -> XTFilterOptions {
        var options = XTFilterOptions()
        let parts = text.split(separator: ";", omittingEmptySubsequences: true)
        for rawPart in parts {
            let part = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.hasPrefix("boards:") {
                options.boards = parseBoards(String(part.dropFirst("boards:".count)))
            } else if part.hasPrefix("exclude:") {
                options.excludedBoards = parseBoards(String(part.dropFirst("exclude:".count)))
            } else if part == "op:no" {
                options.postScope = .repliesOnly
            } else if part == "op:only" {
                options.postScope = .opOnly
            } else if part == "file:no" {
                options.fileScope = .withoutFileOnly
            } else if part == "file:only" {
                options.fileScope = .withFileOnly
            } else if part == "stub:yes" {
                options.stub = true
            } else if part == "stub:no" {
                options.stub = false
            } else if part == "highlight" {
                options.highlightClass = "filter-highlight"
                options.pinToTop = true
                options.hide = false
            } else if part.hasPrefix("highlight:") {
                let value = String(part.dropFirst("highlight:".count))
                options.highlightClass = value.isEmpty ? "filter-highlight" : value
                options.pinToTop = true
                options.hide = false
            } else if part == "top:yes" {
                options.pinToTop = true
            } else if part == "top:no" {
                options.pinToTop = false
            } else if part == "notify" {
                options.notify = true
                options.hide = false
            } else if part == "poster" {
                options.samePoster = true
            } else if part == "replies" {
                options.recursiveReplies = true
            } else if part == "hide" {
                options.hide = true
            } else if part.hasPrefix("reason:") {
                options.reason = String(part.dropFirst("reason:".count))
            } else if part.hasPrefix("type:") {
                options.generalFieldGroups = try parseFieldGroups(String(part.dropFirst("type:".count)))
            }
        }
        return options
    }

    private static func parseBoards(_ raw: String) -> [String] {
        return raw.split(separator: ",").map { part in
            let board = part.split(separator: ":").last.map(String.init) ?? String(part)
            return board.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "/", with: "")
        }.filter { !$0.isEmpty }
    }

    private static func parseFieldGroups(_ raw: String) throws -> [[XTFilterField]] {
        try raw.split(separator: ",").map { group in
            try group.split(separator: "+").map { rawField in
                let name = String(rawField).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let field = XTFilterField(rawValue: name) else {
                    throw XTFilterParseError.unknownField(name)
                }
                return field
            }
        }.filter { !$0.isEmpty }
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
