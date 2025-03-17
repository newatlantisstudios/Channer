import UIKit
import Kingfisher

class threadRepliesCell: UITableViewCell {

    // MARK: - UI Components
    let threadImage: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.imageView?.contentMode = .scaleAspectFill
        button.imageView?.clipsToBounds = true
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let replyText: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }()

    let replyTextNoImage: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }()

    let boardReplyCount: UILabel = {
        let label = UILabel()
        label.text = "#000000000000"
        label.textColor = ThemeManager.shared.primaryTextColor
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let thread: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "thread"), for: .normal)
        return button
    }()

    let customBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeManager.shared.cellBackgroundColor
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 6.0
        view.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties
    weak var replyTextDelegate: UITextViewDelegate? {
        didSet {
            replyText.delegate = replyTextDelegate
            replyTextNoImage.delegate = replyTextDelegate
        }
    }

    private var replyTextWithImageConstraints: [NSLayoutConstraint] = []
    private var replyTextNoImageConstraints: [NSLayoutConstraint] = []
    private var minHeightConstraint: NSLayoutConstraint?

    // MARK: - Initializer
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Update UI when trait collection changes (light/dark mode)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors when appearance changes
            customBackgroundView.backgroundColor = ThemeManager.shared.cellBackgroundColor
            customBackgroundView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
            boardReplyCount.textColor = ThemeManager.shared.primaryTextColor
            
            // When trait collection changes, we also need to update attributed text
            if let attributedText = replyText.attributedText {
                replyText.attributedText = updateAttributedTextColors(attributedText)
            }
            
            if let attributedText = replyTextNoImage.attributedText {
                replyTextNoImage.attributedText = updateAttributedTextColors(attributedText)
            }
        }
    }
    
    private func updateAttributedTextColors(_ attributedText: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        
        mutableString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutableString.length)) { (value, range, stop) in
            if value != nil {
                // If this is greentext (checking the color)
                if let color = value as? UIColor, self.isColorGreenish(color) {
                    mutableString.addAttribute(.foregroundColor, value: ThemeManager.shared.greentextColor, range: range)
                } else {
                    mutableString.addAttribute(.foregroundColor, value: ThemeManager.shared.primaryTextColor, range: range)
                }
            }
        }
        
        return mutableString
    }
    
    private func isColorGreenish(_ color: UIColor) -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Check if green component is dominant
        return green > red * 1.5 && green > blue * 1.5
    }

    // MARK: - Setup Methods
    private func setupSubviews() {
        contentView.addSubview(customBackgroundView)
        contentView.addSubview(threadImage)
        contentView.addSubview(replyText)
        contentView.addSubview(replyTextNoImage)
        contentView.addSubview(boardReplyCount)
        contentView.addSubview(thread)
    }

    private func setupConstraints() {
        // Common constraints
        NSLayoutConstraint.activate([
            customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            threadImage.widthAnchor.constraint(equalToConstant: 120),
            threadImage.heightAnchor.constraint(equalToConstant: 120),
            threadImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 12),
            threadImage.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 28),

            boardReplyCount.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 16),
            boardReplyCount.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 8),

            thread.widthAnchor.constraint(equalToConstant: 20),
            thread.heightAnchor.constraint(equalToConstant: 20),
            thread.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -8),
            thread.bottomAnchor.constraint(equalTo: customBackgroundView.bottomAnchor, constant: -8)
        ])

        // Minimum height constraint with lower priority
        minHeightConstraint = customBackgroundView.heightAnchor.constraint(greaterThanOrEqualToConstant: 172)
        if let minHeightConstraint = minHeightConstraint {
            minHeightConstraint.priority = .defaultHigh
            minHeightConstraint.isActive = true
        }

        // Constraints for replyText with image
        replyTextWithImageConstraints = [
            replyText.leadingAnchor.constraint(equalTo: threadImage.trailingAnchor, constant: 8),
            replyText.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4),
            replyText.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -16),
            replyText.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -16)
        ]

        // Constraints for replyText without image
        replyTextNoImageConstraints = [
            replyTextNoImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 12),
            replyTextNoImage.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4),
            replyTextNoImage.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -16),
            replyTextNoImage.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -16)
        ]
    }

    // MARK: - Configuration Method
    func configure(withImage: Bool, text: NSAttributedString, boardNumber: String) {
        threadImage.isHidden = !withImage
        replyText.isHidden = !withImage
        replyTextNoImage.isHidden = withImage

        NSLayoutConstraint.deactivate(replyTextWithImageConstraints)
        NSLayoutConstraint.deactivate(replyTextNoImageConstraints)

        if withImage {
            NSLayoutConstraint.activate(replyTextWithImageConstraints)
            replyText.attributedText = text
        } else {
            NSLayoutConstraint.activate(replyTextNoImageConstraints)
            replyTextNoImage.attributedText = text
        }

        boardReplyCount.text = boardNumber

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layoutIfNeeded()
    }
}
