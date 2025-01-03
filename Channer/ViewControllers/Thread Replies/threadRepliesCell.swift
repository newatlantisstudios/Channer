import UIKit

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
        label.textColor = .black
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
        view.backgroundColor = UIColor(red: 255/255, green: 236/255, blue: 219/255, alpha: 1.0)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 6.0
        view.layer.borderColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0).cgColor
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
            customBackgroundView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),

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
            replyText.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 18),
            replyText.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -16),
            replyText.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -16)
        ]

        // Constraints for replyText without image
        replyTextNoImageConstraints = [
            replyTextNoImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 12),
            replyTextNoImage.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 18),
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
