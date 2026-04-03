import UIKit
import Kingfisher

class threadCatalogCell: UICollectionViewCell {
    private let containerView = UIView()
    private let thumbnailImageView = UIImageView()
    private let statsLabel = UILabel()
    private let titleLabel = UILabel()
    private let commentLabel = UILabel()
    private var displayedImageURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
        updateColors()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.kf.cancelDownloadTask()
        statsLabel.text = nil
        titleLabel.text = nil
        commentLabel.text = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCommentLineLimit()
    }

    func configure(with thread: ThreadData) {
        statsLabel.text = thread.stats

        let titleText = thread.title.decodingHTMLEntities().trimmingCharacters(in: .whitespacesAndNewlines)
        let commentText = plainText(from: thread.comment)

        if titleText.isEmpty {
            titleLabel.text = commentText.isEmpty ? "No Subject" : commentText
            commentLabel.text = nil
        } else {
            titleLabel.text = titleText
            commentLabel.text = commentText.isEmpty ? nil : commentText
        }

        if let url = thumbnailURL(from: thread.imageUrl) {
            if displayedImageURL == url, thumbnailImageView.image != nil {
                return
            }

            let placeholderImage: UIImage?
            if displayedImageURL == url {
                placeholderImage = thumbnailImageView.image ?? UIImage(named: "loadingBoardImage")
            } else {
                placeholderImage = UIImage(named: "loadingBoardImage")
            }

            thumbnailImageView.kf.setImage(
                with: url,
                placeholder: placeholderImage,
                options: [.loadDiskFileSynchronously]
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.displayedImageURL = url
                case .failure:
                    self?.displayedImageURL = nil
                }
            }
        } else {
            displayedImageURL = nil
            thumbnailImageView.image = UIImage(named: "loadingBoardImage")
        }
    }

    private func setupViews() {
        containerView.layer.cornerRadius = 16
        containerView.layer.cornerCurve = .continuous
        containerView.layer.borderWidth = 4
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 3)
        containerView.layer.shadowOpacity = 0.12
        containerView.layer.shadowRadius = 6
        containerView.layer.masksToBounds = false

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 12
        thumbnailImageView.layer.cornerCurve = .continuous

        statsLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statsLabel.textAlignment = .center

        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        commentLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        commentLabel.textAlignment = .left
        commentLabel.numberOfLines = 1
        commentLabel.lineBreakMode = .byTruncatingTail

        contentView.addSubview(containerView)
        containerView.addSubview(thumbnailImageView)
        containerView.addSubview(statsLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(commentLabel)
    }

    private func setupConstraints() {
        [containerView, thumbnailImageView, statsLabel, titleLabel, commentLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            thumbnailImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor),

            statsLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 6),
            statsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            statsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),

            commentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            commentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            commentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            commentLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
    }

    private func updateColors() {
        containerView.backgroundColor = ThemeManager.shared.cellBackgroundColor
        containerView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        statsLabel.textColor = ThemeManager.shared.secondaryTextColor
        titleLabel.textColor = ThemeManager.shared.primaryTextColor
        commentLabel.textColor = ThemeManager.shared.secondaryTextColor
    }

    private func updateCommentLineLimit() {
        let availableHeight = containerView.bounds.maxY - 8 - commentLabel.frame.minY
        let maxLines = Int(floor(availableHeight / commentLabel.font.lineHeight))
        let computedLineLimit = max(1, maxLines)

        if commentLabel.numberOfLines != computedLineLimit {
            commentLabel.numberOfLines = computedLineLimit
        }
    }

    private func thumbnailURL(from urlString: String) -> URL? {
        guard !urlString.isEmpty else { return nil }

        var finalUrl = urlString
        if urlString.hasSuffix(".webm") || urlString.hasSuffix(".mp4") {
            let components = urlString.components(separatedBy: "/")
            if let last = components.last {
                let fileExtension = urlString.hasSuffix(".webm") ? ".webm" : ".mp4"
                let base = last.replacingOccurrences(of: fileExtension, with: "")
                finalUrl = urlString.replacingOccurrences(of: last, with: "\(base)s.jpg")
            }
        }

        return URL(string: finalUrl)
    }

    private func plainText(from htmlText: String) -> String {
        var cleanedText = htmlText
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<wbr>", with: "")

        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            cleanedText = regex.stringByReplacingMatches(
                in: cleanedText,
                options: [],
                range: NSRange(location: 0, length: cleanedText.count),
                withTemplate: ""
            )
        }

        return cleanedText.decodingHTMLEntities().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
