import UIKit
import LinkPresentation

// MARK: - Link Preview Types
/// Represents different types of link previews that can be rendered
enum LinkPreviewType {
    case youtube(videoId: String)
    case twitter(tweetId: String, username: String?)
    case generic(url: URL, title: String?, description: String?, imageURL: URL?)

    var icon: UIImage? {
        switch self {
        case .youtube:
            return UIImage(systemName: "play.rectangle.fill")
        case .twitter:
            return UIImage(systemName: "text.bubble.fill")
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
        case .generic:
            return .systemBlue
        }
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

// MARK: - Link Preview Manager
/// Manages detection and display of inline link previews for YouTube, Twitter, and other external links
class LinkPreviewManager {

    // MARK: - Singleton
    static let shared = LinkPreviewManager()

    // MARK: - Patterns
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

    // MARK: - Cache
    private var previewCache: [URL: LPLinkMetadata] = [:]
    private let cacheQueue = DispatchQueue(label: "com.channer.linkpreview.cache")

    // MARK: - Initialization
    private init() {}

    // MARK: - Link Detection

    /// Extracts all links from the given text
    /// - Parameter text: The text to search for links
    /// - Returns: Array of LinkPreviewData containing detected links
    func extractLinks(from text: String) -> [LinkPreviewData] {
        var results: [LinkPreviewData] = []
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // First, find YouTube links
        for pattern in youtubePatterns {
            let matches = pattern.matches(in: text, options: [], range: fullRange)
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let videoIdRange = Range(match.range(at: 1), in: text) else { continue }

                let videoId = String(text[videoIdRange])
                let matchedURL = nsString.substring(with: match.range)

                // Build proper URL if needed
                var urlString = matchedURL
                if !urlString.hasPrefix("http") {
                    urlString = "https://\(urlString)"
                }

                guard let url = URL(string: urlString) else { continue }

                let preview = LinkPreviewData(
                    url: url,
                    type: .youtube(videoId: videoId),
                    displayText: "YouTube: \(videoId)",
                    range: match.range
                )
                results.append(preview)
            }
        }

        // Find Twitter/X links
        for pattern in twitterPatterns {
            let matches = pattern.matches(in: text, options: [], range: fullRange)
            for match in matches {
                guard match.numberOfRanges >= 3,
                      let usernameRange = Range(match.range(at: 1), in: text),
                      let tweetIdRange = Range(match.range(at: 2), in: text) else { continue }

                let username = String(text[usernameRange])
                let tweetId = String(text[tweetIdRange])
                let matchedURL = nsString.substring(with: match.range)

                var urlString = matchedURL
                if !urlString.hasPrefix("http") {
                    urlString = "https://\(urlString)"
                }

                guard let url = URL(string: urlString) else { continue }

                let preview = LinkPreviewData(
                    url: url,
                    type: .twitter(tweetId: tweetId, username: username),
                    displayText: "@\(username)'s post",
                    range: match.range
                )
                results.append(preview)
            }
        }

        // Find generic URLs (excluding already found YouTube/Twitter)
        if let genericPattern = genericURLPattern {
            let matches = genericPattern.matches(in: text, options: [], range: fullRange)
            for match in matches {
                // Skip if this range overlaps with an existing result
                let overlaps = results.contains { NSIntersectionRange($0.range, match.range).length > 0 }
                if overlaps { continue }

                let matchedURL = nsString.substring(with: match.range)
                guard let url = URL(string: matchedURL) else { continue }

                // Skip 4chan image URLs (these are handled separately)
                if url.host?.contains("4cdn.org") == true { continue }

                let displayText = url.host ?? url.absoluteString

                let preview = LinkPreviewData(
                    url: url,
                    type: .generic(url: url, title: nil, description: nil, imageURL: nil),
                    displayText: displayText,
                    range: match.range
                )
                results.append(preview)
            }
        }

        // Sort by range location
        return results.sorted { $0.range.location < $1.range.location }
    }

    // MARK: - Preview View Creation

    /// Creates a preview view for the given link data
    /// - Parameters:
    ///   - data: The link preview data
    ///   - width: Maximum width for the preview
    /// - Returns: A configured UIView for the link preview
    func createPreviewView(for data: LinkPreviewData, width: CGFloat) -> UIView {
        switch data.type {
        case .youtube(let videoId):
            return createYouTubePreview(videoId: videoId, url: data.url, width: width)
        case .twitter(let tweetId, let username):
            return createTwitterPreview(tweetId: tweetId, username: username, url: data.url, width: width)
        case .generic:
            return createGenericPreview(for: data, width: width)
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

    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
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
