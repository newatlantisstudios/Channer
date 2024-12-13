import UIKit

class boardTVCell: UITableViewCell {

    // MARK: - IBOutlets
    /// Outlets connected to UI elements in Interface Builder.
    
    /// Label for topic text when title is present.
    let topicTextTitle: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .light)
            label.textAlignment = .left
            label.textColor = .black
            label.numberOfLines = 3
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
    
    /// Label for topic text when title is not present.
    let topicTextNoTitle: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .light)
            label.textAlignment = .left
            label.textColor = .black
            label.numberOfLines = 4
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
    
    /// Label displaying topic statistics.
    let topicStats: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 17, weight: .light)
            label.textAlignment = .center
            label.textColor = .black
            return label
        }()
    
    /// Label for the topic title.
    let topicTitle: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.textAlignment = .center
            label.textColor = .black
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            return label
        }()
    
    /// Image view for the topic image.
    let topicImage: UIImageView = {
            let imageView = UIImageView()
        imageView.layer.cornerRadius = 8
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            return imageView
        }()

    // MARK: - UI Components
    /// UI elements that are programmatically created.
    
    /// Custom background view for the cell.
    let customBackgroundView: UIView = {
            let view = UIView()
            view.backgroundColor = UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0)
            view.layer.cornerRadius = 12
            view.layer.borderWidth = 6.0
            view.layer.borderColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0).cgColor
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 2)
            view.layer.shadowOpacity = 0.2
            view.layer.shadowRadius = 3
            return view
        }()
    
    // MARK: - Lifecycle Methods
    /// Methods related to the cell's lifecycle.
    
    // MARK: - Initializers
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            setupCell()
            setupConstraints()
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
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
    }

    // MARK: - Setup Methods
    /// Methods for configuring UI components and constraints.
    
    /// Configures the cell's UI components.
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

                NSLayoutConstraint.activate([
                    // Custom Background View
                    customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 7),
                    customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
                    customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 1),
                    customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6), // Adjusted for 5px padding
                    customBackgroundView.heightAnchor.constraint(equalToConstant: 166), // Fixed height

                    // Topic Image
                    topicImage.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 2),
                    topicImage.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
                    topicImage.widthAnchor.constraint(equalToConstant: 120),
                    topicImage.heightAnchor.constraint(equalToConstant: 120),

                    // Topic Stats
                    topicStats.centerXAnchor.constraint(equalTo: topicImage.centerXAnchor, constant: 1),
                    topicStats.topAnchor.constraint(equalTo: topicImage.bottomAnchor),
                    topicStats.widthAnchor.constraint(equalToConstant: 120),
                    topicStats.heightAnchor.constraint(equalToConstant: 21),

                    // Topic Title (when visible)
                    topicTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
                    topicTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                    topicTitle.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
                    topicTitle.heightAnchor.constraint(greaterThanOrEqualToConstant: 17),

                    // Topic Text Title (when title is present)
                    topicTextTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
                    topicTextTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                    topicTextTitle.topAnchor.constraint(equalTo: topicTitle.bottomAnchor, constant: 8),
                    topicTextTitle.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -9),

                    // Topic Text No Title (when no title)
                    topicTextNoTitle.leadingAnchor.constraint(equalTo: topicImage.trailingAnchor, constant: 8),
                    topicTextNoTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                    topicTextNoTitle.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
                    topicTextNoTitle.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -9)
                ])
        }
    
    func configure(with thread: ThreadData, isHistoryView: Bool, isFavoritesView: Bool) {
            // Configure topicStats visibility and content
            if isHistoryView {
                topicStats.isHidden = true
            } else {
                topicStats.isHidden = false
                topicStats.text = thread.stats
            }

            // Configure background border for favorites
            if isFavoritesView, let currentReplies = thread.currentReplies, currentReplies > thread.replies {
                customBackgroundView.layer.borderColor = UIColor.red.cgColor
            } else {
                customBackgroundView.layer.borderColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0).cgColor
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
                topicImage.kf.setImage(with: url, placeholder: UIImage(named: "loadingBoardImage"))
            } else {
                topicImage.image = UIImage(named: "loadingBoardImage")
            }
    }
    
    private func formatText(_ text: String) -> NSAttributedString {
        // Formats text by applying styles and processing HTML tags.
        var formattedText = text
        
        // First handle all replacements except spoiler tags
        let replacements = [
            "<br>": "\n",
            "&#039;": "'",
            "&gt;": ">",
            "&quot;": "\"",
            "<wbr>": "",
            "&amp;": "&",
            "<a[^>]+>": "",
            "</a>": "",
            "<span[^>]+>": "",
            "</span>": ""
        ]
        
        for (key, value) in replacements {
            if key.contains("[^>]+") {
                if let regex = try? NSRegularExpression(pattern: key, options: []) {
                    formattedText = regex.stringByReplacingMatches(
                        in: formattedText,
                        options: [],
                        range: NSRange(location: 0, length: formattedText.count),
                        withTemplate: value
                    )
                }
            } else {
                formattedText = formattedText.replacingOccurrences(of: key, with: value)
            }
        }
        
        let attributedString = NSMutableAttributedString(string: "")
        
        // Split by spoiler tags and process each part
        let components = formattedText.components(separatedBy: "<s>")
        
        // Default text attributes with 14pt font
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        // Greentext attributes with 14pt font
        let greentextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
        ]
        
        // Spoiler attributes with 14pt font
        let spoilerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black,
            .backgroundColor: UIColor.black
        ]
        
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
