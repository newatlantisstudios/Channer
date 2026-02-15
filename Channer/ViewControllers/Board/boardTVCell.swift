import UIKit
import Kingfisher

class boardTVCell: UITableViewCell {

    // MARK: - IBOutlets
    /// Outlets connected to UI elements in Interface Builder.
    
    /// Label for topic text when title is present.
    let topicTextTitle: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .light)
            label.textAlignment = .left
            label.textColor = ThemeManager.shared.primaryTextColor
            label.numberOfLines = 3
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
    
    /// Label for topic text when title is not present.
    let topicTextNoTitle: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .light)
            label.textAlignment = .left
            label.textColor = ThemeManager.shared.primaryTextColor
            label.numberOfLines = 4
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
    
    /// Label displaying topic statistics.
    let topicStats: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 17, weight: .light)
            label.textAlignment = .center
            label.textColor = ThemeManager.shared.primaryTextColor
            return label
        }()
    
    /// Label for the topic title.
    let topicTitle: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.textAlignment = .center
            label.textColor = ThemeManager.shared.primaryTextColor
            label.numberOfLines = 2
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
    
    /// Image view for the topic image.
    let topicImage: UIImageView = {
            let imageView = UIImageView()
        // Use device corner radius for image
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        print("boardTVCell - Device corner radius: \(deviceCornerRadius)")
        imageView.layer.cornerRadius = deviceCornerRadius
        imageView.layer.cornerCurve = .continuous
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
        print("boardTVCell - Image frame: \(imageView.frame), bounds: \(imageView.bounds)")
        print("boardTVCell - Content mode: \(imageView.contentMode.rawValue), clips to bounds: \(imageView.clipsToBounds)")
            return imageView
        }()

    // MARK: - UI Components
    /// UI elements that are programmatically created.
    
    /// Custom background view for the cell.
    let customBackgroundView: UIView = {
            let view = UIView()
            view.backgroundColor = ThemeManager.shared.cellBackgroundColor

            // Use device corner radius
            let deviceCornerRadius: CGFloat
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
            } else {
                deviceCornerRadius = 39.0 // Default for modern iOS devices
            }

            view.layer.cornerRadius = deviceCornerRadius
            view.layer.cornerCurve = .continuous
            view.layer.borderWidth = 6.0
            view.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 4)
            view.layer.shadowOpacity = 0.15
            view.layer.shadowRadius = 6
            view.layer.masksToBounds = false
            // Performance: Enable rasterization for shadow rendering
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale
            return view
        }()
    
    // MARK: - Dynamic Thumbnail Constraints
    private var imageWidthConstraint: NSLayoutConstraint!
    private var imageHeightConstraint: NSLayoutConstraint!
    private var statsWidthConstraint: NSLayoutConstraint!
    private var bgHeightConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle Methods
    /// Methods related to the cell's lifecycle.

    // MARK: - Initializers
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            selectionStyle = .none
            setupCell()
            setupConstraints()
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            selectionStyle = .none
            setupCell()
            setupConstraints()
        }
    
    /// Prepares the cell for reuse by resetting its content.
    override func prepareForReuse() {
        super.prepareForReuse()
        topicImage.image = UIImage(named: "loadingBoardImage")
        topicStats.text = nil
        topicTextTitle.text = nil
        topicTextNoTitle.text = nil
        topicTitle.text = nil
        updateThumbnailSize()
    }

    func updateThumbnailSize() {
        let thumbSize = ThumbnailSizeManager.shared.thumbnailSize
        let cellHeight = ThumbnailSizeManager.shared.boardCellHeight
        imageWidthConstraint.constant = thumbSize
        imageHeightConstraint.constant = thumbSize
        statsWidthConstraint.constant = thumbSize
        bgHeightConstraint.constant = cellHeight
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Performance: Set shadowPath for efficient shadow rendering
        if customBackgroundView.layer.shadowPath == nil || customBackgroundView.bounds != CGRect(origin: .zero, size: customBackgroundView.bounds.size) {
            customBackgroundView.layer.shadowPath = UIBezierPath(
                roundedRect: customBackgroundView.bounds,
                cornerRadius: customBackgroundView.layer.cornerRadius
            ).cgPath
        }
    }

    // MARK: - Setup Methods
    /// Methods for configuring UI components and constraints.
    
    /// Configures the cell's UI components.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors when appearance changes
            customBackgroundView.backgroundColor = ThemeManager.shared.cellBackgroundColor
            customBackgroundView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
            
            topicTextTitle.textColor = ThemeManager.shared.primaryTextColor
            topicTextNoTitle.textColor = ThemeManager.shared.primaryTextColor
            topicStats.textColor = ThemeManager.shared.primaryTextColor
            topicTitle.textColor = ThemeManager.shared.primaryTextColor
            
            // When trait collection changes, we also need to update attributed text
            if let attributedText = topicTextTitle.attributedText {
                topicTextTitle.attributedText = updateAttributedTextColors(attributedText)
            }
            
            if let attributedText = topicTextNoTitle.attributedText {
                topicTextNoTitle.attributedText = updateAttributedTextColors(attributedText)
            }
        }
    }
    
    private func updateAttributedTextColors(_ attributedText: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: mutableString.length)

        mutableString.enumerateAttributes(in: fullRange) { (attributes, range, stop) in
            // Skip ranges with link attributes - preserve their color
            if attributes[.link] != nil {
                return
            }

            // Skip spoiler text - preserve its color
            if let isSpoiler = attributes[.isSpoiler] as? Bool, isSpoiler {
                return
            }

            // Check for greentext using the custom attribute marker
            if let isGreentext = attributes[.isGreentext] as? Bool, isGreentext {
                mutableString.addAttribute(.foregroundColor, value: ThemeManager.shared.greentextColor, range: range)
            } else if attributes[.foregroundColor] != nil {
                // Only update regular text colors
                mutableString.addAttribute(.foregroundColor, value: ThemeManager.shared.primaryTextColor, range: range)
            }
        }

        return mutableString
    }
    
    private func setupCell() {
            // **Add subviews to customBackgroundView**
            customBackgroundView.addSubview(topicImage)
            customBackgroundView.addSubview(topicStats)
            customBackgroundView.addSubview(topicTitle)
            customBackgroundView.addSubview(topicTextTitle)
            customBackgroundView.addSubview(topicTextNoTitle)

            // **Add customBackgroundView to contentView**
            contentView.addSubview(customBackgroundView)

            // **Set background colors**
            backgroundColor = .clear
            contentView.backgroundColor = .clear

            // **Set content compression resistance priorities**
            topicImage.setContentCompressionResistancePriority(.required, for: .vertical)
            topicImage.setContentCompressionResistancePriority(.required, for: .horizontal)

            topicTitle.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            topicTextTitle.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            topicTextNoTitle.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
    
    /// Sets up the Auto Layout constraints for the UI components.
    private func setupConstraints() {
            // Enable auto layout for all views
            [customBackgroundView, topicImage, topicStats, topicTitle, topicTextTitle, topicTextNoTitle].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

            // Border width + padding to keep content inside the border
            // Account for the large corner radius (39pt) - content near corners needs more inset
            let borderInset: CGFloat = 14
            let trailingInset: CGFloat = 20  // Extra inset on trailing edge for rounded corner

            let thumbSize = ThumbnailSizeManager.shared.thumbnailSize
            let cellHeight = ThumbnailSizeManager.shared.boardCellHeight

            imageWidthConstraint = topicImage.widthAnchor.constraint(equalToConstant: thumbSize)
            imageHeightConstraint = topicImage.heightAnchor.constraint(equalToConstant: thumbSize)
            statsWidthConstraint = topicStats.widthAnchor.constraint(equalToConstant: thumbSize)
            bgHeightConstraint = customBackgroundView.heightAnchor.constraint(equalToConstant: cellHeight)

                NSLayoutConstraint.activate([
                    // Custom Background View
                    customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 7),
                    customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
                    customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 1),
                    customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
                    bgHeightConstraint,

                    // Topic Image - constrained to customBackgroundView with border inset
                    topicImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: borderInset),
                    topicImage.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: borderInset),
                    imageWidthConstraint,
                    imageHeightConstraint,

                    // Topic Stats (positioned lower to avoid border)
                    topicStats.centerXAnchor.constraint(equalTo: topicImage.centerXAnchor),
                    topicStats.topAnchor.constraint(equalTo: topicImage.bottomAnchor, constant: 4),
                    statsWidthConstraint,
                    topicStats.heightAnchor.constraint(equalToConstant: 21),

                    // Topic Title (when visible) - constrained to customBackgroundView
                    topicTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
                    topicTitle.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -trailingInset),
                    topicTitle.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: borderInset),
                    topicTitle.heightAnchor.constraint(greaterThanOrEqualToConstant: 17),

                    // Topic Text Title (when title is present) - constrained to customBackgroundView
                    topicTextTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
                    topicTextTitle.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -trailingInset),
                    topicTextTitle.topAnchor.constraint(equalTo: topicTitle.bottomAnchor, constant: 4),
                    topicTextTitle.bottomAnchor.constraint(equalTo: customBackgroundView.bottomAnchor, constant: -borderInset),

                    // Topic Text No Title (when no title) - constrained to customBackgroundView
                    topicTextNoTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
                    topicTextNoTitle.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -trailingInset),
                    topicTextNoTitle.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: borderInset),
                    topicTextNoTitle.bottomAnchor.constraint(equalTo: customBackgroundView.bottomAnchor, constant: -borderInset)
                ])
        }
    
    // Filter badge to indicate filtered content
    private let filterBadge: UILabel = {
        let label = UILabel()
        label.text = "FILTERED"
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.systemRed
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()
    
    func configure(with thread: ThreadData, isHistoryView: Bool, isFavoritesView: Bool, isFiltered: Bool = false) {
            // Configure topicStats visibility and content
            topicStats.isHidden = false
            topicStats.text = thread.stats

            // Configure background border for favorites
            if isFavoritesView && thread.hasNewReplies {
                // Use alert color for threads with new replies
                customBackgroundView.layer.borderColor = ThemeManager.shared.alertColor.cgColor
                
                // Add notification badge to indicate unread content
                topicStats.text = (thread.stats) + " 🔴"
            } else {
                customBackgroundView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
            }

            // Handle filtered content
            if isFiltered {
                // Add filter badge if not already added
                if filterBadge.superview == nil {
                    customBackgroundView.addSubview(filterBadge)
                    filterBadge.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        filterBadge.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 8),
                        filterBadge.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -8),
                        filterBadge.widthAnchor.constraint(equalToConstant: 80),
                        filterBadge.heightAnchor.constraint(equalToConstant: 24)
                    ])
                }
                
                // Show filter badge
                filterBadge.isHidden = false
                
                // Dim the content to indicate it's filtered
                customBackgroundView.alpha = 0.7
            } else {
                // Hide filter badge
                filterBadge.isHidden = true
                
                // Normal opacity
                customBackgroundView.alpha = 1.0
            }

            // Configure text content
            let formattedComment = formatText(thread.comment)
            let formattedTitle = formatText(thread.title)

            if formattedTitle.string.trimmingCharacters(in: .whitespaces).isEmpty {
                topicTextTitle.isHidden = true
                topicTextNoTitle.isHidden = false
                topicTitle.isHidden = true
                topicTextNoTitle.attributedText = formattedComment
            } else {
                topicTextTitle.isHidden = false
                topicTextNoTitle.isHidden = true
                topicTitle.isHidden = false
                topicTextTitle.attributedText = formattedComment
                topicTitle.text = formattedTitle.string
            }

            // Configure the image
            if let url = URL(string: thread.imageUrl) {
                print("boardTVCell - Setting image from URL: \(thread.imageUrl)")
                print("boardTVCell - Image constraints - width: 120, height: 120")
                topicImage.kf.setImage(with: url, placeholder: UIImage(named: "loadingBoardImage"))
            } else {
                print("boardTVCell - Setting placeholder image")
                topicImage.image = UIImage(named: "loadingBoardImage")
            }
    }
    
    private func formatText(_ text: String) -> NSAttributedString {
        // Formats text by applying styles and processing HTML tags.
        var formattedText = text
        
        // First handle HTML tag replacements
        formattedText = formattedText
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<wbr>", with: "")

        // Remove HTML tags except spoiler tags (handled below)
        let tagPatterns = ["<a[^>]+>", "</a>", "<span[^>]+>", "</span>"]
        for pattern in tagPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                formattedText = regex.stringByReplacingMatches(
                    in: formattedText,
                    options: [],
                    range: NSRange(location: 0, length: formattedText.count),
                    withTemplate: ""
                )
            }
        }

        // Decode all HTML entities (named + numeric character references)
        formattedText = formattedText.decodingHTMLEntities()
        
        let attributedString = NSMutableAttributedString(string: "")
        
        // Split by spoiler tags and process each part
        let components = formattedText.components(separatedBy: "<s>")
        
        // Default text attributes with 14pt font
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: ThemeManager.shared.primaryTextColor
        ]
        
        // Greentext attributes with 14pt font
        let greentextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: ThemeManager.shared.greentextColor,
            .isGreentext: true
        ]
        
        // Spoiler attributes with 14pt font
        let spoilerAttributes = ThemeManager.shared.getSpoilerAttributes()
        
        for (index, component) in components.enumerated() {
            if index == 0 {
                // First component is never a spoiler
                let normalText = component.replacingOccurrences(of: "</s>", with: "")
                // Process greentext for non-spoiler text
                let lines = normalText.components(separatedBy: "\n")
                for line in lines {
                    if line.hasPrefix(">") {
                        attributedString.append(NSAttributedString(string: line + "\n", attributes: greentextAttributes))
                    } else {
                        attributedString.append(NSAttributedString(string: line + "\n", attributes: defaultAttributes))
                    }
                }
            } else {
                // For subsequent components, split by closing spoiler tag
                let spoilerParts = component.components(separatedBy: "</s>")
                if spoilerParts.count > 0 {
                    // Spoiler text
                    if let spoilerText = spoilerParts.first {
                        // Process greentext within spoiler
                        let lines = spoilerText.components(separatedBy: "\n")
                        for line in lines {
                            attributedString.append(NSAttributedString(string: line + "\n", attributes: spoilerAttributes))
                        }
                    }
                    
                    // Non-spoiler text (after closing tag)
                    if spoilerParts.count > 1 {
                        let normalText = spoilerParts[1]
                        // Process greentext for text after spoiler
                        let lines = normalText.components(separatedBy: "\n")
                        for line in lines {
                            if line.hasPrefix(">") {
                                attributedString.append(NSAttributedString(string: line + "\n", attributes: greentextAttributes))
                            } else {
                                attributedString.append(NSAttributedString(string: line + "\n", attributes: defaultAttributes))
                            }
                        }
                    }
                }
            }
        }
        
        // Remove any extra newlines that might have been added
        let finalString = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAttributedString = NSMutableAttributedString(string: finalString)
        
        // Copy attributes from the original string, ensuring font size is preserved
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { (attrs, range, _) in
            let intersectingRange = NSIntersectionRange(range, NSRange(location: 0, length: finalString.count))
            if intersectingRange.length > 0 {
                var newAttributes = attrs
                // Ensure font size is 14pt
                if attrs[.font] is UIFont {
                    newAttributes[.font] = UIFont.systemFont(ofSize: 14)
                }
                for (key, value) in newAttributes {
                    finalAttributedString.addAttribute(key, value: value, range: intersectingRange)
                }
            }
        }
        
        return finalAttributedString
    }
    
}
