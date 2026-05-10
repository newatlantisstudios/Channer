import UIKit
import LinkPresentation
import WebKit

// MARK: - Link Preview Types
/// Represents different types of link previews that can be rendered
enum LinkPreviewType {
    case youtube(videoId: String)
    case twitter(tweetId: String, username: String?)
    case service(RichLinkService)
    case media(RichLinkMedia)
    case generic(url: URL)

    var icon: UIImage? {
        switch self {
        case .youtube:
            return UIImage(systemName: "play.rectangle.fill")
        case .twitter:
            return UIImage(systemName: "text.bubble.fill")
        case .service(let service):
            return UIImage(systemName: service.iconName)
        case .media(let media):
            return UIImage(systemName: media.iconName)
        case .generic:
            return UIImage(systemName: "link")
        }
    }

    var accentColor: UIColor {
        switch self {
        case .youtube:
            return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // YouTube red
        case .twitter:
            return UIColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0) // Twitter blue
        case .service(let service):
            return service.accentColor
        case .media(let media):
            return media.accentColor
        case .generic:
            return .systemBlue
        }
    }

    var displayName: String {
        switch self {
        case .youtube:
            return "YouTube"
        case .twitter:
            return "X"
        case .service(let service):
            return service.name
        case .media(let media):
            return media.name
        case .generic(let url):
            return url.host ?? "Link"
        }
    }

    var embedURL: URL? {
        switch self {
        case .youtube(let videoId):
            return URL(string: "https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0")
        case .twitter(let tweetId, let username):
            guard let username = username else { return nil }
            return URL(string: "https://twitframe.com/show?url=https://twitter.com/\(username)/status/\(tweetId)")
        case .service(let service):
            return service.embedURL
        case .media(let media):
            return media.url
        case .generic:
            return nil
        }
    }

    var coverURL: URL? {
        switch self {
        case .youtube(let videoId):
            return URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")
        case .service(let service):
            return service.coverURL
        case .media(let media):
            return media.previewURL
        case .twitter, .generic:
            return nil
        }
    }

    var titleEndpoint: URL? {
        switch self {
        case .youtube(let videoId):
            return URL(string: "https://www.youtube.com/oembed?url=https%3A//www.youtube.com/watch%3Fv%3D\(videoId)&format=json")
        case .service(let service):
            return service.titleEndpoint
        case .twitter, .media, .generic:
            return nil
        }
    }

    var isEmbeddable: Bool {
        embedURL != nil
    }
}

// MARK: - Link Preview Data
/// Stores extracted link preview information
struct LinkPreviewData {
    let url: URL
    let type: LinkPreviewType
    let displayText: String
    let range: NSRange
}

// MARK: - Rich Link Metadata

struct RichLinkService {
    let name: String
    let identifier: String
    let embedURL: URL?
    let coverURL: URL?
    let titleEndpoint: URL?
    let accentColor: UIColor
    let iconName: String
}

struct RichLinkMedia {
    enum Kind {
        case image
        case video
        case audio
    }

    let kind: Kind
    let url: URL

    var name: String {
        switch kind {
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        }
    }

    var previewURL: URL? {
        switch kind {
        case .image:
            return url
        case .video, .audio:
            return nil
        }
    }

    var iconName: String {
        switch kind {
        case .image:
            return "photo"
        case .video:
            return "play.rectangle"
        case .audio:
            return "waveform"
        }
    }

    var accentColor: UIColor {
        switch kind {
        case .image:
            return .systemGreen
        case .video:
            return .systemPurple
        case .audio:
            return .systemOrange
        }
    }
}

struct RichLinkMetadata {
    let title: String?
    let subtitle: String?
    let imageURL: URL?
}

// MARK: - Link Preview Manager
/// Manages detection and display of inline link previews for YouTube, X, media, and other external links.
class LinkPreviewManager {

    // MARK: - Singleton
    static let shared = LinkPreviewManager()

    // MARK: - Patterns
    private let candidateURLPattern: NSRegularExpression? = {
        let serviceHosts = [
            "youtu\\.be", "youtube\\.com", "youtube-nocookie\\.com",
            "twitter\\.com", "x\\.com", "fxtwitter\\.com", "vxtwitter\\.com", "fixupx\\.com", "fixvx\\.com", "nitter\\.[^/\\s]+",
            "vimeo\\.com", "dailymotion\\.com", "dai\\.ly", "soundcloud\\.com", "snd\\.sc",
            "streamable\\.com", "twitch\\.tv", "clips\\.twitch\\.tv", "clyp\\.it",
            "vocaroo\\.com", "voca\\.ro", "pastebin\\.com", "gist\\.github\\.com"
        ].joined(separator: "|")

        let pattern = #"(?:(?:https?://)?(?:www\.|m\.|mobile\.)?(?:"# + serviceHosts + #")[^\s<>"']*|https?://[^\s<>"']+)"#
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    private let youtubePatterns: [NSRegularExpression] = {
        let patterns = [
            // youtube.com/watch?v=VIDEO_ID
            "(?:https?://)?(?:www\\.)?youtube\\.com/watch\\?v=([a-zA-Z0-9_-]{11})",
            // youtu.be/VIDEO_ID
            "(?:https?://)?youtu\\.be/([a-zA-Z0-9_-]{11})",
            // youtube.com/embed/VIDEO_ID
            "(?:https?://)?(?:www\\.)?youtube\\.com/embed/([a-zA-Z0-9_-]{11})",
            // youtube.com/shorts/VIDEO_ID
            "(?:https?://)?(?:www\\.)?youtube\\.com/shorts/([a-zA-Z0-9_-]{11})"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private let twitterPatterns: [NSRegularExpression] = {
        let patterns = [
            // twitter.com/username/status/TWEET_ID
            "(?:https?://)?(?:www\\.)?twitter\\.com/([a-zA-Z0-9_]+)/status/(\\d+)",
            // x.com/username/status/TWEET_ID
            "(?:https?://)?(?:www\\.)?x\\.com/([a-zA-Z0-9_]+)/status/(\\d+)"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private let genericURLPattern: NSRegularExpression? = {
        // Match HTTP/HTTPS URLs
        return try? NSRegularExpression(
            pattern: "https?://[a-zA-Z0-9\\-._~:/?#\\[\\]@!$&'()*+,;=%]+",
            options: .caseInsensitive
        )
    }()

    // MARK: - Initialization
    private init() {}

    // MARK: - Metadata Cache

    private let metadataQueue = DispatchQueue(label: "com.channer.rich-links.metadata", attributes: .concurrent)
    private var metadataCache: [URL: RichLinkMetadata] = [:]
    private var inFlightMetadata: [URL: [(RichLinkMetadata) -> Void]] = [:]

    // MARK: - Link Detection

    /// Extracts all links from the given text
    /// - Parameter text: The text to search for links
    /// - Returns: Array of LinkPreviewData containing detected links
    func extractLinks(from text: String) -> [LinkPreviewData] {
        var results: [LinkPreviewData] = []
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        if let candidateURLPattern = candidateURLPattern {
            let matches = candidateURLPattern.matches(in: text, options: [], range: fullRange)
            for match in matches {
                let normalized = normalizedCandidate(nsString.substring(with: match.range), range: match.range)
                guard let url = normalized.url else { continue }

                // Skip 4chan image URLs (these are handled separately)
                if url.host?.contains("4cdn.org") == true { continue }

                results.append(LinkPreviewData(
                    url: url,
                    type: classify(url: url),
                    displayText: url.host ?? url.absoluteString,
                    range: normalized.range
                ))
            }
        } else if let genericPattern = genericURLPattern {
            let matches = genericPattern.matches(in: text, options: [], range: fullRange)
            for match in matches {
                let normalized = normalizedCandidate(nsString.substring(with: match.range), range: match.range)
                guard let url = normalized.url else { continue }
                if url.host?.contains("4cdn.org") == true { continue }

                results.append(LinkPreviewData(
                    url: url,
                    type: classify(url: url),
                    displayText: url.host ?? url.absoluteString,
                    range: normalized.range
                ))
            }
        }

        // Sort by range location
        return dedupeOverlaps(results.sorted { $0.range.location < $1.range.location })
    }

    private func normalizedCandidate(_ candidate: String, range: NSRange) -> (url: URL?, range: NSRange) {
        var urlString = candidate
        var adjustedRange = range

        while let last = urlString.last, ".,!?:;)]}".contains(last) {
            urlString.removeLast()
            adjustedRange.length -= 1
        }

        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        return (URL(string: urlString), adjustedRange)
    }

    private func dedupeOverlaps(_ links: [LinkPreviewData]) -> [LinkPreviewData] {
        var accepted: [LinkPreviewData] = []
        for link in links {
            if accepted.contains(where: { NSIntersectionRange($0.range, link.range).length > 0 }) {
                continue
            }
            accepted.append(link)
        }
        return accepted
    }

    private func classify(url: URL) -> LinkPreviewType {
        let lowerHost = (url.host ?? "").lowercased()
        let lowerPath = url.path.lowercased()
        let ext = url.pathExtension.isEmpty
            ? (lowerPath.components(separatedBy: ".").last ?? "")
            : url.pathExtension.lowercased()

        if ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext) {
            return .media(RichLinkMedia(kind: .image, url: url))
        }

        if ["ogv", "ogg", "webm", "mp4", "mov", "m4v"].contains(ext) {
            return .media(RichLinkMedia(kind: .video, url: url))
        }

        if ["mp3", "m4a", "oga", "wav", "flac"].contains(ext) {
            return .media(RichLinkMedia(kind: .audio, url: url))
        }

        if let youtubeId = youtubeVideoId(from: url) {
            return .youtube(videoId: youtubeId)
        }

        if let tweet = tweetIdentifier(from: url) {
            return .twitter(tweetId: tweet.id, username: tweet.username)
        }

        if lowerHost.contains("vimeo.com"),
           let id = url.pathComponents.dropFirst().first,
           id.allSatisfy({ $0.isNumber }) {
            return .service(RichLinkService(
                name: "Vimeo",
                identifier: id,
                embedURL: URL(string: "https://player.vimeo.com/video/\(id)?playsinline=1"),
                coverURL: nil,
                titleEndpoint: URL(string: "https://vimeo.com/api/oembed.json?url=https://vimeo.com/\(id)"),
                accentColor: .systemIndigo,
                iconName: "play.rectangle"
            ))
        }

        if lowerHost.contains("dailymotion.com") || lowerHost == "dai.ly",
           let id = dailymotionId(from: url) {
            return .service(RichLinkService(
                name: "Dailymotion",
                identifier: id,
                embedURL: URL(string: "https://www.dailymotion.com/embed/video/\(id)"),
                coverURL: URL(string: "https://www.dailymotion.com/thumbnail/video/\(id)"),
                titleEndpoint: URL(string: "https://api.dailymotion.com/video/\(id)"),
                accentColor: .systemBlue,
                iconName: "play.tv"
            ))
        }

        if lowerHost.contains("soundcloud.com") || lowerHost == "snd.sc" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !path.isEmpty,
               let encodedURL = "https://soundcloud.com/\(path)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                return .service(RichLinkService(
                    name: "SoundCloud",
                    identifier: path,
                    embedURL: URL(string: "https://w.soundcloud.com/player/?visual=true&show_comments=false&url=\(encodedURL)"),
                    coverURL: nil,
                    titleEndpoint: URL(string: "https://soundcloud.com/oembed?format=json&url=\(encodedURL)"),
                    accentColor: .systemOrange,
                    iconName: "waveform"
                ))
            }
        }

        if lowerHost.contains("streamable.com"),
           let id = url.pathComponents.dropFirst().first {
            return .service(RichLinkService(
                name: "Streamable",
                identifier: id,
                embedURL: URL(string: "https://streamable.com/o/\(id)"),
                coverURL: nil,
                titleEndpoint: URL(string: "https://api.streamable.com/oembed?url=https://streamable.com/\(id)"),
                accentColor: .systemTeal,
                iconName: "play.rectangle"
            ))
        }

        if lowerHost.contains("twitch.tv"),
           let service = twitchService(from: url) {
            return .service(service)
        }

        if lowerHost.contains("clyp.it"),
           let id = url.pathComponents.dropFirst().first {
            return .service(RichLinkService(
                name: "Clyp",
                identifier: id,
                embedURL: URL(string: "https://clyp.it/\(id)/widget"),
                coverURL: nil,
                titleEndpoint: URL(string: "https://api.clyp.it/oembed?url=https://clyp.it/\(id)"),
                accentColor: .systemPink,
                iconName: "waveform"
            ))
        }

        if lowerHost.contains("vocaroo.com") || lowerHost == "voca.ro",
           let id = url.pathComponents.dropFirst().last {
            return .service(RichLinkService(
                name: "Vocaroo",
                identifier: id,
                embedURL: URL(string: "https://vocaroo.com/embed/\(id.replacingOccurrences(of: "i/", with: ""))?autoplay=0"),
                coverURL: nil,
                titleEndpoint: nil,
                accentColor: .systemMint,
                iconName: "waveform"
            ))
        }

        if lowerHost.contains("pastebin.com"),
           let id = url.pathComponents.dropFirst().last,
           id != "u" {
            return .service(RichLinkService(
                name: "Pastebin",
                identifier: id,
                embedURL: URL(string: "https://pastebin.com/embed_iframe/\(id)"),
                coverURL: nil,
                titleEndpoint: nil,
                accentColor: .systemGreen,
                iconName: "doc.text"
            ))
        }

        if lowerHost == "gist.github.com",
           let id = url.pathComponents.dropFirst().last {
            return .service(RichLinkService(
                name: "GitHub Gist",
                identifier: id,
                embedURL: url,
                coverURL: nil,
                titleEndpoint: URL(string: "https://api.github.com/gists/\(id)"),
                accentColor: .label,
                iconName: "curlybraces"
            ))
        }

        return .generic(url: url)
    }

    private func youtubeVideoId(from url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if host.contains("youtu.be") {
            return pathComponents.first.flatMap(validYouTubeId)
        }

        guard host.contains("youtube") else { return nil }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let id = components.queryItems?.first(where: { $0.name == "v" })?.value.flatMap(validYouTubeId) {
            return id
        }

        for marker in ["embed", "v", "shorts", "live", "watch"] {
            if let index = pathComponents.firstIndex(of: marker),
               pathComponents.indices.contains(index + 1),
               let id = validYouTubeId(pathComponents[index + 1]) {
                return id
            }
        }

        return nil
    }

    private func validYouTubeId(_ value: String) -> String? {
        let cleaned = value.components(separatedBy: CharacterSet(charactersIn: "?&#")).first ?? value
        guard cleaned.count == 11,
              cleaned.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return cleaned
    }

    private func tweetIdentifier(from url: URL) -> (username: String?, id: String)? {
        let host = (url.host ?? "").lowercased()
        guard host.contains("twitter.com") ||
              host.contains("x.com") ||
              host.contains("nitter.") ||
              host.contains("twittpr.com") ||
              host.contains("xcancel.com") else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard let statusIndex = components.firstIndex(of: "status"),
              components.indices.contains(statusIndex + 1) else {
            return nil
        }
        let username = statusIndex > 0 ? components[statusIndex - 1] : nil
        return (username, components[statusIndex + 1])
    }

    private func dailymotionId(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        if (url.host ?? "").lowercased() == "dai.ly" {
            return components.first
        }
        if let videoIndex = components.firstIndex(of: "video"),
           components.indices.contains(videoIndex + 1) {
            return components[videoIndex + 1]
        }
        return components.last
    }

    private func twitchService(from url: URL) -> RichLinkService? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first, !first.isEmpty else { return nil }

        let embedURL: URL?
        if (url.host ?? "").lowercased().contains("clips.twitch.tv") {
            embedURL = URL(string: "https://clips.twitch.tv/embed?clip=\(first)&parent=localhost")
        } else if first == "videos" || first == "v",
                  components.indices.contains(1) {
            embedURL = URL(string: "https://player.twitch.tv/?video=v\(components[1])&autoplay=false&parent=localhost")
        } else if first == "clip",
                  components.indices.contains(1) {
            embedURL = URL(string: "https://clips.twitch.tv/embed?clip=\(components[1])&parent=localhost")
        } else {
            embedURL = URL(string: "https://player.twitch.tv/?channel=\(first)&autoplay=false&parent=localhost")
        }

        return RichLinkService(
            name: "Twitch",
            identifier: components.joined(separator: "/"),
            embedURL: embedURL,
            coverURL: nil,
            titleEndpoint: nil,
            accentColor: .systemPurple,
            iconName: "play.tv"
        )
    }

    // MARK: - Preview View Creation

    /// Creates a preview view for the given link data
    /// - Parameters:
    ///   - data: The link preview data
    ///   - width: Maximum width for the preview
    /// - Returns: A configured UIView for the link preview
    func createPreviewView(for data: LinkPreviewData, width: CGFloat) -> UIView {
        let view = RichLinkPreviewCardView()
        view.configure(with: data, width: width)
        return view
    }

    // MARK: - Metadata Fetching

    func fetchMetadata(for data: LinkPreviewData, completion: @escaping (RichLinkMetadata) -> Void) {
        let key = data.url

        if let cached = metadataQueue.sync(execute: { metadataCache[key] }) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        var shouldStartFetch = false
        metadataQueue.async(flags: .barrier) {
            if let cached = self.metadataCache[key] {
                DispatchQueue.main.async { completion(cached) }
                return
            }

            if self.inFlightMetadata[key] != nil {
                self.inFlightMetadata[key]?.append(completion)
            } else {
                self.inFlightMetadata[key] = [completion]
                shouldStartFetch = true
            }

            if shouldStartFetch {
                self.performMetadataFetch(for: data)
            }
        }
    }

    private func performMetadataFetch(for data: LinkPreviewData) {
        if let endpoint = data.type.titleEndpoint {
            URLSession.shared.dataTask(with: endpoint) { [weak self] responseData, _, _ in
                let metadata = self?.metadataFromJSON(responseData, fallback: data) ?? self?.fallbackMetadata(for: data) ?? RichLinkMetadata(title: nil, subtitle: nil, imageURL: nil)
                self?.completeMetadata(metadata, for: data.url)
            }.resume()
            return
        }

        switch data.type {
        case .generic, .twitter:
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: data.url) { [weak self] lpMetadata, _ in
                let metadata = RichLinkMetadata(
                    title: lpMetadata?.title,
                    subtitle: data.url.host,
                    imageURL: data.type.coverURL
                )
                self?.completeMetadata(metadata, for: data.url)
            }
        default:
            completeMetadata(fallbackMetadata(for: data), for: data.url)
        }
    }

    private func metadataFromJSON(_ data: Data?, fallback: LinkPreviewData) -> RichLinkMetadata? {
        guard let data = data,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        let title = object["title"] as? String ??
            object["description"] as? String ??
            (object["files"] as? [String: Any])?.keys.sorted().first

        let imageURLString = object["thumbnail_url"] as? String ??
            object["thumbnail"] as? String

        return RichLinkMetadata(
            title: title,
            subtitle: fallback.type.displayName,
            imageURL: imageURLString.flatMap(URL.init(string:)) ?? fallback.type.coverURL
        )
    }

    private func fallbackMetadata(for data: LinkPreviewData) -> RichLinkMetadata {
        let title: String
        switch data.type {
        case .youtube(let videoId):
            title = "YouTube video \(videoId)"
        case .twitter(_, let username):
            title = username.map { "@\($0)'s post" } ?? "X post"
        case .service(let service):
            title = service.name
        case .media(let media):
            title = data.url.lastPathComponent.isEmpty ? media.name : data.url.lastPathComponent
        case .generic:
            title = data.url.host ?? data.url.absoluteString
        }

        return RichLinkMetadata(
            title: title,
            subtitle: data.url.host,
            imageURL: data.type.coverURL
        )
    }

    private func completeMetadata(_ metadata: RichLinkMetadata, for url: URL) {
        metadataQueue.async(flags: .barrier) {
            self.metadataCache[url] = metadata
            let completions = self.inFlightMetadata.removeValue(forKey: url) ?? []
            DispatchQueue.main.async {
                completions.forEach { $0(metadata) }
            }
        }
    }

    // MARK: - YouTube Preview

    private func createYouTubePreview(videoId: String, url: URL, width: CGFloat) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        // Thumbnail image view
        let thumbnailView = UIImageView()
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.backgroundColor = .black
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false

        // Load YouTube thumbnail
        let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg")
        if let thumbURL = thumbnailURL {
            loadImage(from: thumbURL) { image in
                DispatchQueue.main.async {
                    thumbnailView.image = image
                }
            }
        }

        // Play button overlay
        let playButton = UIImageView()
        playButton.image = UIImage(systemName: "play.circle.fill")
        playButton.tintColor = .white
        playButton.contentMode = .scaleAspectFit
        playButton.translatesAutoresizingMaskIntoConstraints = false

        // YouTube branding
        let brandLabel = UILabel()
        brandLabel.text = "YouTube"
        brandLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        brandLabel.textColor = .white
        brandLabel.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.9)
        brandLabel.textAlignment = .center
        brandLabel.layer.cornerRadius = 4
        brandLabel.layer.masksToBounds = true
        brandLabel.translatesAutoresizingMaskIntoConstraints = false

        // Video ID label
        let idLabel = UILabel()
        idLabel.text = videoId
        idLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        idLabel.textColor = .secondaryLabel
        idLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(thumbnailView)
        container.addSubview(playButton)
        container.addSubview(brandLabel)
        container.addSubview(idLabel)

        let aspectRatio: CGFloat = 9.0 / 16.0
        let thumbnailHeight = (width - 16) * aspectRatio

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalToConstant: thumbnailHeight),

            playButton.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 50),
            playButton.heightAnchor.constraint(equalToConstant: 50),

            brandLabel.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: 8),
            brandLabel.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: 8),
            brandLabel.widthAnchor.constraint(equalToConstant: 60),
            brandLabel.heightAnchor.constraint(equalToConstant: 20),

            idLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 8),
            idLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            idLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            idLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        // Store URL for tap handling
        container.accessibilityValue = url.absoluteString

        return container
    }

    // MARK: - Twitter Preview

    private func createTwitterPreview(tweetId: String, username: String?, url: URL, width: CGFloat) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.separator.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        // X/Twitter icon
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "text.bubble.fill")
        iconView.tintColor = UIColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Username label
        let usernameLabel = UILabel()
        usernameLabel.text = username != nil ? "@\(username!)" : "Post"
        usernameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        usernameLabel.textColor = .label
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Platform label
        let platformLabel = UILabel()
        platformLabel.text = "X (Twitter)"
        platformLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        platformLabel.textColor = .secondaryLabel
        platformLabel.translatesAutoresizingMaskIntoConstraints = false

        // Tap to view label
        let tapLabel = UILabel()
        tapLabel.text = "Tap to view post"
        tapLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        tapLabel.textColor = .tertiaryLabel
        tapLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(usernameLabel)
        container.addSubview(platformLabel)
        container.addSubview(tapLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),

            usernameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            usernameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            usernameLabel.trailingAnchor.constraint(lessThanOrEqualTo: platformLabel.leadingAnchor, constant: -8),

            platformLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            platformLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            tapLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 4),
            tapLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            tapLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        container.accessibilityValue = url.absoluteString

        return container
    }

    // MARK: - Generic Link Preview

    private func createGenericPreview(for data: LinkPreviewData, width: CGFloat) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.separator.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        // Link icon
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "link")
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Domain label
        let domainLabel = UILabel()
        domainLabel.text = data.url.host ?? data.displayText
        domainLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        domainLabel.textColor = .systemBlue
        domainLabel.lineBreakMode = .byTruncatingMiddle
        domainLabel.translatesAutoresizingMaskIntoConstraints = false

        // Arrow indicator
        let arrowView = UIImageView()
        arrowView.image = UIImage(systemName: "arrow.up.right")
        arrowView.tintColor = .tertiaryLabel
        arrowView.contentMode = .scaleAspectFit
        arrowView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(domainLabel)
        container.addSubview(arrowView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            domainLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            domainLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            domainLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowView.leadingAnchor, constant: -8),

            arrowView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            arrowView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 14),
            arrowView.heightAnchor.constraint(equalToConstant: 14),

            container.heightAnchor.constraint(equalToConstant: 36)
        ])

        container.accessibilityValue = data.url.absoluteString

        return container
    }

    // MARK: - Image Loading Helper

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }

    // MARK: - Attributed String Integration

    /// Creates attributed string with link styling for detected URLs
    /// - Parameters:
    ///   - text: Original text
    ///   - links: Detected links
    ///   - baseAttributes: Base text attributes
    /// - Returns: Attributed string with styled links
    func applyLinkStyling(
        to text: String,
        links: [LinkPreviewData],
        baseAttributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text, attributes: baseAttributes)

        // Apply styling to each link (in reverse order to maintain range validity)
        for link in links.reversed() {
            var linkAttributes = baseAttributes
            linkAttributes[.foregroundColor] = link.type.accentColor
            linkAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            linkAttributes[.link] = link.url

            // Add a custom attribute to identify the link type
            linkAttributes[.init("linkPreviewType")] = link.type

            attributedString.addAttributes(linkAttributes, range: link.range)
        }

        return attributedString
    }

    // MARK: - Preview Expansion State

    /// Tracks which links have been expanded for preview
    private var expandedPreviews: Set<URL> = []

    func isPreviewExpanded(for url: URL) -> Bool {
        return expandedPreviews.contains(url)
    }

    func togglePreview(for url: URL) {
        if expandedPreviews.contains(url) {
            expandedPreviews.remove(url)
        } else {
            expandedPreviews.insert(url)
        }
    }

    func collapseAllPreviews() {
        expandedPreviews.removeAll()
    }

    // MARK: - Floating Embeds

    func presentFloatingEmbed(for data: LinkPreviewData) {
        guard let embedURL = data.type.embedURL,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            UIApplication.shared.open(data.url)
            return
        }

        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = .systemBackground
        panel.layer.cornerRadius = 12
        panel.layer.masksToBounds = true

        let header = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        header.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.text = data.type.displayName

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label

        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = true
        webView.load(URLRequest(url: embedURL))

        window.addSubview(overlay)
        overlay.addSubview(panel)
        panel.addSubview(webView)
        panel.addSubview(header)
        header.contentView.addSubview(titleLabel)
        header.contentView.addSubview(closeButton)

        let maxWidth = min(window.bounds.width - 32, 720)
        let panelHeight = min(window.bounds.height - 96, max(260, maxWidth * 9 / 16 + 44))

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: maxWidth),
            panel.heightAnchor.constraint(equalToConstant: panelHeight),

            header.topAnchor.constraint(equalTo: panel.topAnchor),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: header.contentView.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: header.contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            closeButton.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: header.contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            webView.topAnchor.constraint(equalTo: header.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])

        closeButton.addAction(UIAction { _ in
            overlay.removeFromSuperview()
        }, for: .touchUpInside)

        overlay.alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
            overlay.alpha = 1
            panel.transform = .identity
        }
    }
}

// MARK: - Link Preview View
/// A reusable view component for displaying link previews inline
class LinkPreviewView: UIView {

    private let containerStackView = UIStackView()
    private var linkData: LinkPreviewData?
    private var onTap: ((URL) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        containerStackView.axis = .vertical
        containerStackView.spacing = 8
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerStackView)

        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }

    func configure(with data: LinkPreviewData, width: CGFloat, onTap: @escaping (URL) -> Void) {
        self.linkData = data
        self.onTap = onTap

        // Clear existing views
        containerStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Create and add preview view
        let previewView = LinkPreviewManager.shared.createPreviewView(for: data, width: width)
        containerStackView.addArrangedSubview(previewView)
    }

    @objc private func handleTap() {
        guard let url = linkData?.url else { return }
        onTap?(url)
    }
}

// MARK: - Rich Link Preview Card

private final class RichLinkPreviewCardView: UIView {
    private let container = UIView()
    private let thumbnailView = UIImageView()
    private let iconView = UIImageView()
    private let serviceLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let embedButton = UIButton(type: .system)
    private let floatButton = UIButton(type: .system)
    private var webView: WKWebView?
    private var webHeightConstraint: NSLayoutConstraint?
    private var linkData: LinkPreviewData?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.separator.cgColor
        addSubview(container)

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.backgroundColor = .tertiarySystemBackground

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        serviceLabel.translatesAutoresizingMaskIntoConstraints = false
        serviceLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        serviceLabel.textColor = .secondaryLabel

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.lineBreakMode = .byTruncatingMiddle

        configureButton(openButton, systemImage: "arrow.up.right")
        configureButton(embedButton, systemImage: "play.rectangle")
        configureButton(floatButton, systemImage: "rectangle.on.rectangle")

        container.addSubview(thumbnailView)
        container.addSubview(iconView)
        container.addSubview(serviceLabel)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(openButton)
        container.addSubview(embedButton)
        container.addSubview(floatButton)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            thumbnailView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 96),
            thumbnailView.heightAnchor.constraint(equalToConstant: 74),

            iconView.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 10),
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            serviceLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 5),
            serviceLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            serviceLabel.trailingAnchor.constraint(lessThanOrEqualTo: openButton.leadingAnchor, constant: -8),

            openButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            openButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            openButton.widthAnchor.constraint(equalToConstant: 34),
            openButton.heightAnchor.constraint(equalToConstant: 34),

            floatButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            floatButton.trailingAnchor.constraint(equalTo: openButton.leadingAnchor, constant: -2),
            floatButton.widthAnchor.constraint(equalToConstant: 34),
            floatButton.heightAnchor.constraint(equalToConstant: 34),

            embedButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            embedButton.trailingAnchor.constraint(equalTo: floatButton.leadingAnchor, constant: -2),
            embedButton.widthAnchor.constraint(equalToConstant: 34),
            embedButton.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -10),

            thumbnailView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])

        openButton.addAction(UIAction { [weak self] _ in
            guard let url = self?.linkData?.url else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        embedButton.addAction(UIAction { [weak self] _ in
            self?.toggleInlineEmbed()
        }, for: .touchUpInside)

        floatButton.addAction(UIAction { [weak self] _ in
            guard let data = self?.linkData else { return }
            LinkPreviewManager.shared.presentFloatingEmbed(for: data)
        }, for: .touchUpInside)
    }

    private func configureButton(_ button: UIButton, systemImage: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = .secondaryLabel
        button.backgroundColor = UIColor.tertiarySystemBackground.withAlphaComponent(0.7)
        button.layer.cornerRadius = 8
    }

    func configure(with data: LinkPreviewData, width: CGFloat) {
        linkData = data

        iconView.image = data.type.icon
        iconView.tintColor = data.type.accentColor
        serviceLabel.text = data.type.displayName.uppercased()
        titleLabel.text = data.displayText
        subtitleLabel.text = data.url.absoluteString
        thumbnailView.image = nil
        thumbnailView.backgroundColor = data.type.accentColor.withAlphaComponent(0.14)

        embedButton.isHidden = !data.type.isEmbeddable
        floatButton.isHidden = !data.type.isEmbeddable

        if let coverURL = data.type.coverURL {
            LinkPreviewManager.shared.loadImage(from: coverURL) { [weak self] image in
                DispatchQueue.main.async {
                    guard self?.linkData?.url == data.url else { return }
                    self?.thumbnailView.image = image
                }
            }
        } else {
            thumbnailView.image = data.type.icon
            thumbnailView.tintColor = data.type.accentColor
            thumbnailView.contentMode = .center
        }

        LinkPreviewManager.shared.fetchMetadata(for: data) { [weak self] metadata in
            guard self?.linkData?.url == data.url else { return }
            self?.titleLabel.text = metadata.title ?? data.displayText
            self?.subtitleLabel.text = metadata.subtitle ?? data.url.host ?? data.url.absoluteString
            if let imageURL = metadata.imageURL {
                LinkPreviewManager.shared.loadImage(from: imageURL) { image in
                    DispatchQueue.main.async {
                        guard self?.linkData?.url == data.url, let image = image else { return }
                        self?.thumbnailView.contentMode = .scaleAspectFill
                        self?.thumbnailView.image = image
                    }
                }
            }
        }
    }

    private func toggleInlineEmbed() {
        guard let data = linkData,
              let embedURL = data.type.embedURL else {
            return
        }

        if let webView = webView {
            webView.removeFromSuperview()
            self.webView = nil
            webHeightConstraint = nil
            embedButton.tintColor = .secondaryLabel
            return
        }

        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = false
        webView.layer.borderColor = UIColor.separator.cgColor
        webView.layer.borderWidth = 0.5
        webView.load(URLRequest(url: embedURL))
        container.addSubview(webView)

        let height = min(max(bounds.width * 9 / 16, 180), 300)
        let heightConstraint = webView.heightAnchor.constraint(equalToConstant: height)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            heightConstraint
        ])

        self.webView = webView
        webHeightConstraint = heightConstraint
        embedButton.tintColor = data.type.accentColor
    }
}
