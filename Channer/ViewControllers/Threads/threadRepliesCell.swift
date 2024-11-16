import UIKit

class threadRepliesCell: UITableViewCell {
    // MARK: - Outlets
    @IBOutlet weak var threadImage: UIButton!
    @IBOutlet weak var replyText: UITextView!
    @IBOutlet weak var replyTextNoImage: UITextView!
    @IBOutlet weak var boardReplyCount: UILabel!
    @IBOutlet weak var thread: UIButton!
    
    weak var replyTextDelegate: UITextViewDelegate? {
        didSet {
            replyText.delegate = replyTextDelegate
            replyTextNoImage.delegate = replyTextDelegate
        }
    }

    private let customBackgroundView: UIView = {
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
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Set font size for replyText and replyTextNoImage
        replyText.font = UIFont.systemFont(ofSize: 14)
        replyTextNoImage.font = UIFont.systemFont(ofSize: 14)
        
        // Enable link detection for text views
        replyText.dataDetectorTypes = [.link]
        replyTextNoImage.dataDetectorTypes = [.link]
        
        // Disable scrolling in the text views to allow them to expand
        replyText.isScrollEnabled = false
        replyTextNoImage.isScrollEnabled = false

        // Set text views to be non-editable but selectable for link interaction
        replyText.isEditable = false
        replyTextNoImage.isEditable = false
        replyText.isSelectable = true
        replyTextNoImage.isSelectable = true

        // Set corner radius for threadImage
        threadImage.layer.cornerRadius = 8
        threadImage.clipsToBounds = true
        
        // Set content hugging and compression resistance priorities
        replyText.setContentHuggingPriority(.required, for: .vertical)
        replyText.setContentCompressionResistancePriority(.required, for: .vertical)
        
        replyTextNoImage.setContentHuggingPriority(.required, for: .vertical)
        replyTextNoImage.setContentCompressionResistancePriority(.required, for: .vertical)
        
        setupSubviews()
        setupConstraints()
    }

    // MARK: - Setup Subviews
    private func setupSubviews() {
        // Add subviews to contentView
        contentView.addSubview(customBackgroundView)
        contentView.addSubview(threadImage)
        contentView.addSubview(replyText)
        contentView.addSubview(replyTextNoImage)
        contentView.addSubview(boardReplyCount)
        contentView.addSubview(thread)

        // Configure the text views to be non-scrollable for dynamic height
        replyText.isScrollEnabled = false
        replyTextNoImage.isScrollEnabled = false
        replyText.backgroundColor = .clear
        replyTextNoImage.backgroundColor = .clear
        replyText.isEditable = false
        replyTextNoImage.isEditable = false
    }

    // MARK: - Setup Constraints
    private func setupConstraints() {
        [customBackgroundView, threadImage, replyText, replyTextNoImage, boardReplyCount, thread].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Custom background view constraints
            customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Minimum height constraint for the contentView to ensure cell height of at least 172 points
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 172),
            
            // Thread Image constraints
            threadImage.widthAnchor.constraint(equalToConstant: 120),
            threadImage.heightAnchor.constraint(equalToConstant: 120),
            threadImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 12),
            threadImage.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 24),
            
            // Board Reply Count constraints
            boardReplyCount.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 16),
            boardReplyCount.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 8),
            
            // Reply Text constraints (with image)
            replyText.leadingAnchor.constraint(equalTo: threadImage.trailingAnchor, constant: 2),
            replyText.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 16),
            replyText.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -16),
            replyText.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -16),
            
            // Reply Text No Image constraints
            replyTextNoImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: 12),
            replyTextNoImage.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 16),
            replyTextNoImage.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -16),
            replyTextNoImage.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -16),
            
            // Thread Button constraints (bottom-right corner)
            thread.widthAnchor.constraint(equalToConstant: 20),
            thread.heightAnchor.constraint(equalToConstant: 20),
            thread.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -8),
            thread.bottomAnchor.constraint(equalTo: customBackgroundView.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Configure Cell
    func configure(withImage: Bool, text: NSAttributedString, boardNumber: String) {
                // Set visibility based on image availability
                threadImage.isHidden = !withImage
                replyText.isHidden = !withImage
                replyTextNoImage.isHidden = withImage

                // Adjust the font size of the attributed text to 14
                let updatedText = NSMutableAttributedString(attributedString: text)
                updatedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: updatedText.length))
                
                // Set attributed text for the appropriate text view
                if withImage {
                    replyText.attributedText = updatedText
                } else {
                    replyTextNoImage.attributedText = updatedText
                }

                // Set board reply count label
                boardReplyCount.text = boardNumber

                // Update layout to reflect changes
                setNeedsLayout()
                layoutIfNeeded()
        }

}
