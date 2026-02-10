import UIKit
import Kingfisher
import WebKit
import VLCKit

class threadRepliesCell: UITableViewCell, VLCMediaPlayerDelegate {
    // Variables for hover functionality
    private var imageURL: String?
    private var hoveredPreviewView: UIView?
    private var hoverOverlayView: UIView?
    private var pointerInteraction: UIPointerInteraction?
    private var hoverProgressTimer: Timer?
    private var hoverVLCPlayer: VLCMediaPlayer?

    // MARK: - Spoiler Handling
    /// The post number for this cell (used for spoiler state tracking)
    var postNumber: String = ""
    /// Delegate for handling spoiler tap events
    weak var spoilerDelegate: SpoilerTapHandler?
    /// Tap gesture for spoiler reveal
    private var spoilerTapGesture: UITapGestureRecognizer?

    // MARK: - Quote Link Hover Preview
    weak var quoteLinkHoverDelegate: QuoteLinkHoverDelegate?
    private var quoteLinkPreviewView: UIView?
    private var quoteLinkOverlayView: UIView?
    private var currentlyHoveredPostNumber: String?

    // MARK: - UI Components
    let threadImage: UIButton = {
        let button = UIButton()
        // Use device corner radius to match board thread thumbnails
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        print("threadRepliesCell - Device corner radius: \(deviceCornerRadius)")
        button.layer.cornerRadius = deviceCornerRadius
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.imageView?.contentMode = .scaleAspectFill
        button.imageView?.clipsToBounds = true
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        print("threadRepliesCell - Button frame: \(button.frame), bounds: \(button.bounds)")
        print("threadRepliesCell - ImageView content mode: \(button.imageView?.contentMode.rawValue ?? -1), clips to bounds: \(button.imageView?.clipsToBounds ?? false)")
        print("threadRepliesCell - Button clips to bounds: \(button.clipsToBounds), masksToBounds: \(button.layer.masksToBounds)")
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

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(named: "thread")
            config.baseForegroundColor = .systemBlue
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            config.background.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            config.background.cornerRadius = 15
            button.configuration = config
        } else {
            button.setImage(UIImage(named: "thread"), for: .normal)

            // Make button more visually appealing
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            button.layer.cornerRadius = 15
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            button.tintColor = .systemBlue // Make the icon blue
        }
        
        // Add shadow for depth
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 3
        return button
    }()

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
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Filter badge to indicate filtered content
    let subjectLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = ThemeManager.shared.primaryTextColor
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let filterBadge: UILabel = {
        let label = UILabel()
        label.text = "FILTERED"
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.systemRed
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Reply count label to show how many replies this post has received
    let replyCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.systemBlue
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
    private var replyTextNoImageWithSubjectConstraints: [NSLayoutConstraint] = []
    private var minHeightConstraint: NSLayoutConstraint?
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    private var imageTopToSubject: NSLayoutConstraint?
    private var imageTopToBoardReply: NSLayoutConstraint?

    // MARK: - Initializer
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupSubviews()
        setupConstraints()
        setupPointerInteraction()
        setupSpoilerTapGesture()
        setupQuoteLinkHoverGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Prepare for reuse to clean up resources
    override func prepareForReuse() {
        super.prepareForReuse()
        removeHoverPreview()
        removeQuoteLinkPreview()
        // Cancel any in-flight image downloads to prevent race conditions
        threadImage.kf.cancelImageDownloadTask()
        threadImage.setImage(nil, for: .normal)
        imageURL = nil
        postNumber = ""
        spoilerDelegate = nil
        quoteLinkHoverDelegate = nil
        replyCountLabel.isHidden = true
        replyCountLabel.text = nil
        subjectLabel.isHidden = true
        subjectLabel.text = nil
        updateThumbnailSize()
    }

    func updateThumbnailSize() {
        let thumbSize = ThumbnailSizeManager.shared.thumbnailSize
        imageWidthConstraint?.constant = thumbSize
        imageHeightConstraint?.constant = thumbSize
        minHeightConstraint?.constant = ThumbnailSizeManager.shared.replyCellMinHeight
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentView.alpha = 1.0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        contentView.alpha = 1.0
    }

    // MARK: - Spoiler Tap Gesture Setup
    private func setupSpoilerTapGesture() {
        // Add tap gesture for replyText
        let tapGesture1 = UITapGestureRecognizer(target: self, action: #selector(handleSpoilerTap(_:)))
        tapGesture1.delegate = self
        replyText.addGestureRecognizer(tapGesture1)

        // Add tap gesture for replyTextNoImage
        let tapGesture2 = UITapGestureRecognizer(target: self, action: #selector(handleSpoilerTap(_:)))
        tapGesture2.delegate = self
        replyTextNoImage.addGestureRecognizer(tapGesture2)
    }

    @objc private func handleSpoilerTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let attributedText = textView.attributedText else { return }

        let location = gesture.location(in: textView)
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer

        // Get character index at tap location
        var fraction: CGFloat = 0
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )

        guard characterIndex < attributedText.length else { return }

        // Check if tapped on a spoiler
        if let isSpoiler = attributedText.attribute(.isSpoiler, at: characterIndex, effectiveRange: nil) as? Bool,
           isSpoiler,
           let spoilerIndex = attributedText.attribute(.spoilerIndex, at: characterIndex, effectiveRange: nil) as? Int {
            // Notify delegate about spoiler tap
            spoilerDelegate?.didTapSpoiler(at: spoilerIndex, in: postNumber)
        }
    }
    
    // Update UI when trait collection changes (light/dark mode)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors when appearance changes
            customBackgroundView.backgroundColor = ThemeManager.shared.cellBackgroundColor
            customBackgroundView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
            boardReplyCount.textColor = ThemeManager.shared.primaryTextColor
            subjectLabel.textColor = ThemeManager.shared.primaryTextColor

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
        contentView.addSubview(subjectLabel)
        // Reply bubble button removed - feature moved to long press menu
        contentView.addSubview(filterBadge)
        contentView.addSubview(replyCountLabel)
    }

    private func setupConstraints() {
        // Border width + padding to keep content inside the border
        // Account for the large corner radius (39pt) - content near corners needs more inset
        let cornerInset: CGFloat = 18  // Inset for corners (top-left, top-right, bottom corners)
        let sideInset: CGFloat = 14    // Inset for sides (where corner doesn't affect as much)

        let thumbSize = ThumbnailSizeManager.shared.thumbnailSize

        imageWidthConstraint = threadImage.widthAnchor.constraint(equalToConstant: thumbSize)
        imageHeightConstraint = threadImage.heightAnchor.constraint(equalToConstant: thumbSize)

        // Common constraints
        NSLayoutConstraint.activate([
            customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            imageWidthConstraint!,
            imageHeightConstraint!,
            threadImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: sideInset),
            threadImage.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -sideInset),

            boardReplyCount.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: cornerInset),
            boardReplyCount.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: cornerInset),

            // Subject label constraints
            subjectLabel.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: cornerInset),
            subjectLabel.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            subjectLabel.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4),

            // Filter badge constraints
            filterBadge.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: cornerInset),
            filterBadge.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            filterBadge.widthAnchor.constraint(equalToConstant: 80),
            filterBadge.heightAnchor.constraint(equalToConstant: 24),

            // Reply count label constraints - positioned at top right
            replyCountLabel.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: cornerInset),
            replyCountLabel.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            replyCountLabel.heightAnchor.constraint(equalToConstant: 20),
            replyCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])

        // Minimum height constraint with lower priority
        minHeightConstraint = customBackgroundView.heightAnchor.constraint(greaterThanOrEqualToConstant: ThumbnailSizeManager.shared.replyCellMinHeight)
        if let minHeightConstraint = minHeightConstraint {
            minHeightConstraint.priority = .defaultHigh
            minHeightConstraint.isActive = true
        }

        // Image top constraints (switched based on subject visibility)
        imageTopToSubject = threadImage.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 8)
        imageTopToBoardReply = threadImage.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 8)
        imageTopToBoardReply?.isActive = true

        // Constraints for replyText with image
        replyTextWithImageConstraints = [
            replyText.leadingAnchor.constraint(equalTo: threadImage.trailingAnchor, constant: 8),
            replyText.topAnchor.constraint(equalTo: threadImage.topAnchor),
            replyText.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            replyText.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -sideInset)
        ]

        // Constraints for replyText without image (top anchored to same as image)
        replyTextNoImageWithSubjectConstraints = [
            replyTextNoImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: cornerInset),
            replyTextNoImage.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 4),
            replyTextNoImage.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            replyTextNoImage.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -sideInset)
        ]

        replyTextNoImageConstraints = [
            replyTextNoImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: cornerInset),
            replyTextNoImage.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4),
            replyTextNoImage.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            replyTextNoImage.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -sideInset)
        ]
    }

    // MARK: - Configuration Method
    func configure(withImage: Bool, text: NSAttributedString, boardNumber: String, isFiltered: Bool = false, replyCount: Int = 0, subject: String? = nil) {
        print("threadRepliesCell - Configure called with withImage: \(withImage)")
        threadImage.isHidden = !withImage
        replyText.isHidden = !withImage
        replyTextNoImage.isHidden = withImage

        if withImage {
            print("threadRepliesCell - Image constraints - width: 120, height: 120")
            print("threadRepliesCell - Final image frame after constraints: \(threadImage.frame)")
        }

        // Configure subject label
        let hasSubject = subject != nil && !subject!.isEmpty
        subjectLabel.isHidden = !hasSubject
        subjectLabel.text = subject
        subjectLabel.textColor = ThemeManager.shared.primaryTextColor

        // Switch image top constraint based on subject visibility
        imageTopToSubject?.isActive = hasSubject
        imageTopToBoardReply?.isActive = !hasSubject

        NSLayoutConstraint.deactivate(replyTextWithImageConstraints)
        NSLayoutConstraint.deactivate(replyTextNoImageConstraints)
        NSLayoutConstraint.deactivate(replyTextNoImageWithSubjectConstraints)

        if withImage {
            NSLayoutConstraint.activate(replyTextWithImageConstraints)
            replyText.attributedText = text
        } else if hasSubject {
            NSLayoutConstraint.activate(replyTextNoImageWithSubjectConstraints)
            replyTextNoImage.attributedText = text
        } else {
            NSLayoutConstraint.activate(replyTextNoImageConstraints)
            replyTextNoImage.attributedText = text
        }

        boardReplyCount.text = boardNumber

        // Handle filtered content
        if isFiltered {
            filterBadge.isHidden = false
            customBackgroundView.alpha = 0.7 // Dim filtered content
        } else {
            filterBadge.isHidden = true
            customBackgroundView.alpha = 1.0 // Normal opacity
        }

        // Handle reply count display
        if replyCount > 0 {
            replyCountLabel.text = " \(replyCount) "
            replyCountLabel.isHidden = false
            // If filter badge is also visible, offset the reply count label
            if !filterBadge.isHidden {
                // Move reply count to the left of filter badge
                for constraint in replyCountLabel.constraints where constraint.firstAttribute == .trailing {
                    constraint.isActive = false
                }
                replyCountLabel.trailingAnchor.constraint(equalTo: filterBadge.leadingAnchor, constant: -8).isActive = true
            }
        } else {
            replyCountLabel.isHidden = true
        }

        // Update hover interaction
        updatePointerInteractionIfNeeded()

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layoutIfNeeded()
        // Provide a shadowPath to avoid offscreen rendering cost per frame
        // Use device corner radius
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        customBackgroundView.layer.shadowPath = UIBezierPath(roundedRect: customBackgroundView.bounds, cornerRadius: deviceCornerRadius).cgPath
        // Rasterize the static background for smoother scrolling
        customBackgroundView.layer.shouldRasterize = true
        customBackgroundView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    // MARK: - Pointer Interaction for Apple Pencil Hover
    
    private func setupPointerInteraction() {
        // Remove any existing interaction
        if let existingInteraction = pointerInteraction {
            threadImage.removeInteraction(existingInteraction)
        }
        
        // Create new interaction
        pointerInteraction = UIPointerInteraction(delegate: self)
        if let interaction = pointerInteraction {
            threadImage.addInteraction(interaction)
            
            // Remove any border
            threadImage.layer.borderWidth = 0.0
        }
    }
    
    private func updatePointerInteractionIfNeeded() {
        // Make sure we only set up interaction for visible images
        if !threadImage.isHidden {
            setupPointerInteraction()
        }
    }

    func setupHoverGestureRecognizer() {
        updatePointerInteractionIfNeeded()
    }

    // Show preview for Apple Pencil hover
    private func showHoverPreview(at location: CGPoint) {
        // Avoid recreating the preview if it is already visible
        if hoveredPreviewView != nil {
            return
        }

        if let overlayView = hoverOverlayView {
            overlayView.removeFromSuperview()
            hoverOverlayView = nil
        }

        guard let thumbnailImage = threadImage.imageView?.image else { return }

        // Create overlay view for the entire screen
        let overlayView = UIView()

        // Determine if this is a video thumbnail (low quality, keep smaller)
        let isVideo: Bool
        if let urlString = imageURL {
            isVideo = urlString.hasSuffix(".webm") || urlString.hasSuffix(".mp4")
        } else {
            isVideo = false
        }

        // Bigger preview for images, smaller for video thumbnails
        let previewSize: CGFloat = isVideo ? HoverPreviewManager.shared.videoPreviewSize : HoverPreviewManager.shared.imagePreviewSize
        // Use device corner radius for preview
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }

        let previewView: UIView
        if isVideo, let urlString = imageURL, let url = URL(string: urlString) {
            print("[HoverVideo] Starting video hover preview for URL: \(urlString)")
            // Container holds VLC video view + native poster/progress overlays
            let container = UIView(frame: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
            container.backgroundColor = .black
            container.layer.cornerRadius = deviceCornerRadius
            container.layer.cornerCurve = .continuous
            container.clipsToBounds = true
            container.isUserInteractionEnabled = false
            container.layer.borderColor = UIColor.label.cgColor
            container.layer.borderWidth = 1.0

            // VLC video view
            let vlcVideoView = UIView(frame: container.bounds)
            vlcVideoView.backgroundColor = .black
            container.addSubview(vlcVideoView)

            // Create VLC player
            let player = VLCMediaPlayer()
            print("[HoverVLC] Created new VLCMediaPlayer \(Unmanaged.passUnretained(player).toOpaque()) on thread: \(Thread.isMainThread ? "main" : "bg") for URL: \(urlString)")
            player.drawable = vlcVideoView
            let hoverSoundEnabled = HoverPreviewManager.shared.videoSoundEnabled
            let media = VLCMedia(url: url)
            media?.addOption(":input-repeat=65535")
            if !hoverSoundEnabled {
                media?.addOption(":no-audio")
            }
            player.media = media
            if let oldPlayer = hoverVLCPlayer {
                print("[HoverVLC] WARNING: replacing existing hoverVLCPlayer \(Unmanaged.passUnretained(oldPlayer).toOpaque()) without cleanup!")
            }
            player.delegate = self
            hoverVLCPlayer = player

            // Native poster overlay (shows thumbnail immediately while VLC loads)
            let posterView = UIImageView(frame: container.bounds)
            posterView.image = thumbnailImage
            posterView.contentMode = .scaleAspectFit
            posterView.backgroundColor = .black
            container.addSubview(posterView)

            // Gradient background behind progress bar
            let gradientHeight: CGFloat = 48
            let gradientView = UIView(frame: CGRect(x: 0, y: previewSize - gradientHeight, width: previewSize, height: gradientHeight))
            let gradient = CAGradientLayer()
            gradient.frame = gradientView.bounds
            gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
            gradientView.layer.addSublayer(gradient)
            container.addSubview(gradientView)

            // Progress bar track
            let trackInset: CGFloat = 24
            let trackHeight: CGFloat = 3
            let trackY = previewSize - 20
            let trackWidth = previewSize - (trackInset * 2)
            let progressTrack = UIView(frame: CGRect(x: trackInset, y: trackY, width: trackWidth, height: trackHeight))
            progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            progressTrack.layer.cornerRadius = trackHeight / 2
            progressTrack.clipsToBounds = true
            container.addSubview(progressTrack)

            // Progress fill
            let progressFill = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: trackHeight))
            progressFill.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            progressFill.layer.cornerRadius = trackHeight / 2
            progressTrack.addSubview(progressFill)

            // Shimmer for indeterminate loading state
            let shimmerWidth = trackWidth * 0.3
            let shimmerView = UIView(frame: CGRect(x: -shimmerWidth, y: 0, width: shimmerWidth, height: trackHeight))
            shimmerView.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            progressTrack.addSubview(shimmerView)

            // Start shimmer animation
            UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .curveEaseInOut]) {
                shimmerView.frame.origin.x = trackWidth
            }

            // Start VLC playback
            player.play()
            // Enforce mute right after play() — audio subsystem may now be available
            player.audio?.isMuted = !hoverSoundEnabled
            player.audio?.volume = hoverSoundEnabled ? 100 : 0
            print("[HoverVideo] VLC player.play() called, hoverSoundEnabled=\(hoverSoundEnabled) audio=\(player.audio != nil ? "available" : "nil")")

            // Poll VLC player state to update native progress overlay
            hoverProgressTimer?.invalidate()
            hoverProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak player, weak posterView, weak progressFill, weak shimmerView, weak gradientView, weak progressTrack] _ in
                guard let player = player else {
                    self?.hoverProgressTimer?.invalidate()
                    self?.hoverProgressTimer = nil
                    return
                }

                // Enforce mute setting on every poll tick until audio subsystem is ready
                if !hoverSoundEnabled {
                    if let audio = player.audio, !audio.isMuted {
                        audio.isMuted = true
                        audio.volume = 0
                        print("[HoverVideo] Enforced mute on poll tick (audio was unexpectedly unmuted)")
                    }
                }

                let isPlaying = player.isPlaying
                let position = player.position
                let timeMs = player.time.intValue

                print("[HoverVideo] Poll: isPlaying=\(isPlaying) position=\(position) time=\(timeMs)ms state=\(player.state.rawValue)")

                // Update progress bar with playback position
                if isPlaying && position > 0 {
                    let pct = CGFloat(min(max(position, 0), 1))
                    let tw = progressTrack?.bounds.width ?? 0
                    UIView.animate(withDuration: 0.2) {
                        progressFill?.frame.size.width = tw * pct
                    }
                    shimmerView?.layer.removeAllAnimations()
                    shimmerView?.isHidden = true
                }

                // Fade out poster once VLC is actually rendering frames
                if isPlaying && timeMs > 0 {
                    print("[HoverVideo] Video ready! Fading out poster overlay.")
                    self?.hoverProgressTimer?.invalidate()
                    self?.hoverProgressTimer = nil
                    UIView.animate(withDuration: 0.3) {
                        posterView?.alpha = 0
                        gradientView?.alpha = 0
                        progressTrack?.alpha = 0
                    }
                }
            }

            previewView = container
        } else {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
            imageView.contentMode = .scaleAspectFit
            imageView.layer.cornerRadius = deviceCornerRadius
            imageView.layer.cornerCurve = .continuous
            imageView.clipsToBounds = true
            imageView.isUserInteractionEnabled = false
            imageView.backgroundColor = UIColor.systemBackground
            imageView.layer.borderColor = UIColor.label.cgColor
            imageView.layer.borderWidth = 1.0
            imageView.layer.shadowColor = UIColor.black.cgColor
            imageView.layer.shadowOffset = CGSize(width: 0, height: 5)
            imageView.layer.shadowOpacity = 0.5
            imageView.layer.shadowRadius = 12
            imageView.image = thumbnailImage

            // Load the full-resolution image for non-video files
            if let urlString = imageURL, let url = URL(string: urlString) {
                imageView.kf.setImage(
                    with: url,
                    placeholder: thumbnailImage,
                    options: [
                        .scaleFactor(UIScreen.main.scale),
                        .transition(.fade(0.2)),
                        .backgroundDecode
                    ]
                )
            }
            previewView = imageView
        }

        // Position the image in the center of the screen
        // Add to window safely
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {

            // Configure overlay to cover the entire screen with a semi-transparent background
            overlayView.frame = window.bounds
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)

            // Keep hover interactions active by avoiding hit-testing on the overlay
            overlayView.isUserInteractionEnabled = false

            // Center the preview in the window
            let centerX = window.bounds.width / 2
            let centerY = window.bounds.height / 2

            // Position relative to center
            previewView.frame.origin = CGPoint(
                x: centerX - (previewSize / 2),
                y: centerY - (previewSize / 2)
            )

            // Add the overlay first, then the image on top
            window.addSubview(overlayView)
            window.addSubview(previewView)

            // Store references to both views
            hoverOverlayView = overlayView
            hoveredPreviewView = previewView

            // Add appear animation - faster for better responsiveness
            previewView.alpha = 0
            previewView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                previewView.alpha = 1
                previewView.transform = .identity
            }
        }
    }
    
    // Update position of hover preview
    private func updateHoverPreviewPosition(to location: CGPoint) {
        guard let previewView = hoveredPreviewView else { return }
        
        let previewSize = previewView.frame.size.width
        let positionY = location.y - previewSize - 20
        let positionX = location.x - (previewSize / 2)
        
        // Use window bounds to keep preview on screen
        if let window = previewView.window {
            let minX: CGFloat = 20
            let maxX = window.bounds.width - previewSize - 20
            let finalX = max(minX, min(positionX, maxX))
            
            previewView.frame.origin = CGPoint(x: finalX, y: positionY)
        } else {
            previewView.frame.origin = CGPoint(x: positionX, y: positionY)
        }
    }
    
    // MARK: - VLCMediaPlayerDelegate (hover video looping)
    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        guard newState == .stopped, let player = hoverVLCPlayer else { return }
        player.position = 0
        player.play()
    }

    // Remove hover preview
    private func removeHoverPreview() {
        hoverProgressTimer?.invalidate()
        hoverProgressTimer = nil

        let previewView = hoveredPreviewView
        let overlayView = hoverOverlayView

        guard previewView != nil || overlayView != nil else { return }

        // Cancel any in-flight full-res image download
        (previewView as? UIImageView)?.kf.cancelDownloadTask()

        // Detach VLC player from this cell immediately, then tear down on a
        // background queue so the blocking stop()/media-nil calls don't freeze
        // the main thread (beach-ball on macOS Catalyst).  Final dealloc is
        // bounced back to main to avoid the VLC timer-lock assertion.
        if let player = hoverVLCPlayer {
            let playerPtr = Unmanaged.passUnretained(player).toOpaque()
            print("[HoverVLC] removeHoverPreview: detaching player \(playerPtr) state=\(player.state.rawValue) isPlaying=\(player.isPlaying)")
            hoverVLCPlayer = nil
            player.drawable = nil

            DispatchQueue.global(qos: .userInitiated).async {
                player.stop()
                print("[HoverVLC] removeHoverPreview: stop() returned for \(playerPtr)")
                // Keep player alive so dealloc happens on main thread
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    _ = player
                }
            }
        }

        // Animate out
        UIView.animate(withDuration: 0.15, animations: {
            previewView?.alpha = 0
            previewView?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            overlayView?.alpha = 0
        }, completion: { _ in
            previewView?.removeFromSuperview()
            overlayView?.removeFromSuperview()

            if let previewView = previewView, self.hoveredPreviewView === previewView {
                self.hoveredPreviewView = nil
            }

            if let overlayView = overlayView, self.hoverOverlayView === overlayView {
                self.hoverOverlayView = nil
            }
        })
    }
    
    deinit {
        hoverProgressTimer?.invalidate()
        if let player = hoverVLCPlayer {
            print("[HoverVLC] deinit: stopping player \(Unmanaged.passUnretained(player).toOpaque())")
            hoverVLCPlayer = nil
            player.drawable = nil
            DispatchQueue.global(qos: .userInitiated).async {
                player.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    _ = player
                }
            }
        }

        // Ensure we clean up any previews when cell is deallocated
        if let previewView = hoveredPreviewView {
            previewView.removeFromSuperview()
        }

        if let overlayView = hoverOverlayView {
            overlayView.removeFromSuperview()
        }

        quoteLinkPreviewView?.removeFromSuperview()
        quoteLinkOverlayView?.removeFromSuperview()
    }

    // MARK: - Quote Link Hover Preview

    private func setupQuoteLinkHoverGestures() {
        let hover1 = UIHoverGestureRecognizer(target: self, action: #selector(handleQuoteLinkHover(_:)))
        replyText.addGestureRecognizer(hover1)

        let hover2 = UIHoverGestureRecognizer(target: self, action: #selector(handleQuoteLinkHover(_:)))
        replyTextNoImage.addGestureRecognizer(hover2)
    }

    @objc private func handleQuoteLinkHover(_ gesture: UIHoverGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let attributedText = textView.attributedText else { return }

        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: textView)
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer

            var fraction: CGFloat = 0
            let characterIndex = layoutManager.characterIndex(
                for: location,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: &fraction
            )

            guard characterIndex < attributedText.length else {
                removeQuoteLinkPreview()
                return
            }

            // Check for a .link attribute with post:// scheme
            if let link = attributedText.attribute(.link, at: characterIndex, effectiveRange: nil),
               let url = (link as? URL) ?? (link as? String).flatMap({ URL(string: $0) }),
               url.scheme == "post",
               let postNum = url.host, !postNum.isEmpty {
                // Avoid re-showing for the same post
                if currentlyHoveredPostNumber == postNum { return }
                removeQuoteLinkPreview()
                showQuoteLinkPreview(for: postNum)
            } else {
                removeQuoteLinkPreview()
            }

        case .ended, .cancelled:
            removeQuoteLinkPreview()

        default:
            break
        }
    }

    private func showQuoteLinkPreview(for postNum: String) {
        guard let delegate = quoteLinkHoverDelegate,
              let content = delegate.attributedTextForPost(number: postNum) else { return }

        currentlyHoveredPostNumber = postNum
        let thumbnailURL = delegate.thumbnailURLForPost(number: postNum)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Overlay
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.isUserInteractionEnabled = false

        // Card dimensions
        let maxWidth = min(window.bounds.width - 40, 500)
        let maxHeight = window.bounds.height * 0.7
        let deviceCornerRadius: CGFloat
        if window.layer.cornerRadius > 0 {
            deviceCornerRadius = window.layer.cornerRadius
        } else {
            deviceCornerRadius = 39.0
        }
        let thumbnailSize = ThumbnailSizeManager.shared.thumbnailSize
        let padding: CGFloat = 16

        // Calculate text height to size the card properly
        let textInset: CGFloat = 8
        let textWidth = (thumbnailURL != nil)
            ? maxWidth - thumbnailSize - padding - (textInset * 2) - padding
            : maxWidth - (textInset * 2)
        let boundingRect = content.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // Header ~30, top/bottom padding, text insets
        let headerHeight: CGFloat = 30
        let contentHeight = ceil(boundingRect.height) + textInset * 2
        let minContentHeight = (thumbnailURL != nil) ? thumbnailSize + padding : 40
        let totalHeight = min(headerHeight + padding + max(contentHeight, minContentHeight) + padding, maxHeight)

        // Build card with frame-based layout for reliable sizing
        let cardWidth = maxWidth
        let card = UIView(frame: CGRect(
            x: (window.bounds.width - cardWidth) / 2,
            y: (window.bounds.height - totalHeight) / 2,
            width: cardWidth,
            height: totalHeight
        ))
        card.backgroundColor = ThemeManager.shared.cellBackgroundColor
        card.layer.cornerRadius = deviceCornerRadius
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.isUserInteractionEnabled = false

        // Header
        let header = UILabel(frame: CGRect(x: padding, y: 12, width: cardWidth - padding * 2, height: 20))
        header.text = ">>\(postNum)"
        header.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        header.textColor = .systemBlue
        card.addSubview(header)

        // Content area starts below header
        let contentY = header.frame.maxY + 4

        // Thumbnail
        var textX: CGFloat = 0
        var textAvailableWidth = cardWidth
        if let thumbURL = thumbnailURL {
            let thumbView = UIImageView(frame: CGRect(
                x: padding,
                y: contentY,
                width: thumbnailSize,
                height: thumbnailSize
            ))
            thumbView.contentMode = .scaleAspectFill
            thumbView.clipsToBounds = true
            thumbView.layer.cornerRadius = 8
            thumbView.backgroundColor = UIColor.secondarySystemBackground
            thumbView.kf.setImage(with: thumbURL)
            card.addSubview(thumbView)

            textX = padding + thumbnailSize + padding
            textAvailableWidth = cardWidth - textX
        }

        // Text content
        let textViewHeight = totalHeight - contentY
        let textView = UITextView(frame: CGRect(
            x: textX,
            y: contentY,
            width: textAvailableWidth,
            height: textViewHeight
        ))
        textView.attributedText = content
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = contentHeight > textViewHeight
        textView.backgroundColor = .clear
        textView.isUserInteractionEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: textInset, bottom: 8, right: textInset)
        card.addSubview(textView)

        window.addSubview(overlay)
        window.addSubview(card)

        quoteLinkOverlayView = overlay
        quoteLinkPreviewView = card

        // Animate in
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            card.alpha = 1
            card.transform = .identity
        }
    }

    private func removeQuoteLinkPreview() {
        currentlyHoveredPostNumber = nil

        let preview = quoteLinkPreviewView
        let overlay = quoteLinkOverlayView

        guard preview != nil || overlay != nil else { return }

        UIView.animate(withDuration: 0.15, animations: {
            preview?.alpha = 0
            preview?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            overlay?.alpha = 0
        }, completion: { _ in
            preview?.removeFromSuperview()
            overlay?.removeFromSuperview()

            if let preview = preview, self.quoteLinkPreviewView === preview {
                self.quoteLinkPreviewView = nil
            }
            if let overlay = overlay, self.quoteLinkOverlayView === overlay {
                self.quoteLinkOverlayView = nil
            }
        })
    }

    func setImageURL(_ url: String?) {
        // Only store the URL for later use (tap actions, hover preview)
        // Image loading is handled by configureImage in threadRepliesTV
        self.imageURL = url
    }
    
    // Handle tap on the preview overlay to dismiss it
    @objc private func handlePreviewTap(_ gestureRecognizer: UITapGestureRecognizer) {
        removeHoverPreview()
    }
}

// MARK: - UIPointerInteractionDelegate
extension threadRepliesCell: UIPointerInteractionDelegate {
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        // Create a hover preview with the image shape using device corner radius
        let targetRect = threadImage.bounds
        let previewParams = UIPreviewParameters()
        // Use device corner radius for consistency
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        previewParams.visiblePath = UIBezierPath(roundedRect: targetRect, cornerRadius: deviceCornerRadius)

        let preview = UITargetedPreview(view: threadImage, parameters: previewParams)

        return UIPointerStyle(effect: .highlight(preview), shape: nil)
    }

    func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        guard !threadImage.isHidden, let window = window else { return }

        // Get the center of the threadImage in window coordinates
        let imageCenter = threadImage.convert(CGPoint(x: threadImage.bounds.midX, y: threadImage.bounds.midY), to: window)

        // Show hover preview at this location
        showHoverPreview(at: imageCenter)
    }

    func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        removeHoverPreview()
    }
}

// MARK: - UIGestureRecognizerDelegate
extension threadRepliesCell {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition to not interfere with text selection
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // For our spoiler tap gesture, check if we're tapping on a spoiler
        guard let textView = gestureRecognizer.view as? UITextView,
              let attributedText = textView.attributedText else {
            return true
        }

        let location = gestureRecognizer.location(in: textView)
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer

        var fraction: CGFloat = 0
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )

        guard characterIndex < attributedText.length else { return true }

        // Only begin if tapping on a spoiler
        if let isSpoiler = attributedText.attribute(.isSpoiler, at: characterIndex, effectiveRange: nil) as? Bool,
           isSpoiler {
            return true
        }

        // Otherwise, let other gestures handle it
        return false
    }
}
