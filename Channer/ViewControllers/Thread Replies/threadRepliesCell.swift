import UIKit
import Kingfisher

class threadRepliesCell: UITableViewCell {
    // Variables for hover functionality
    private var imageURL: String?
    private var hoveredImageView: UIImageView?
    private var hoverOverlayView: UIView?
    private var pointerInteraction: UIPointerInteraction?

    // MARK: - Spoiler Handling
    /// The post number for this cell (used for spoiler state tracking)
    var postNumber: String = ""
    /// Delegate for handling spoiler tap events
    weak var spoilerDelegate: SpoilerTapHandler?
    /// Tap gesture for spoiler reveal
    private var spoilerTapGesture: UITapGestureRecognizer?

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
    private var minHeightConstraint: NSLayoutConstraint?

    // MARK: - Initializer
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupSubviews()
        setupConstraints()
        setupPointerInteraction()
        setupSpoilerTapGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Prepare for reuse to clean up resources
    override func prepareForReuse() {
        super.prepareForReuse()
        removeHoverPreview()
        // Cancel any in-flight image downloads to prevent race conditions
        threadImage.kf.cancelImageDownloadTask()
        threadImage.setImage(nil, for: .normal)
        imageURL = nil
        postNumber = ""
        spoilerDelegate = nil
        replyCountLabel.isHidden = true
        replyCountLabel.text = nil
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
        // Reply bubble button removed - feature moved to long press menu
        contentView.addSubview(filterBadge)
        contentView.addSubview(replyCountLabel)
    }

    private func setupConstraints() {
        // Border width + padding to keep content inside the border
        // Account for the large corner radius (39pt) - content near corners needs more inset
        let cornerInset: CGFloat = 18  // Inset for corners (top-left, top-right, bottom corners)
        let sideInset: CGFloat = 14    // Inset for sides (where corner doesn't affect as much)

        // Common constraints
        NSLayoutConstraint.activate([
            customBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            customBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            customBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            customBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            threadImage.widthAnchor.constraint(equalToConstant: 120),
            threadImage.heightAnchor.constraint(equalToConstant: 120),
            threadImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: sideInset),
            threadImage.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 32),

            boardReplyCount.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: cornerInset),
            boardReplyCount.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: cornerInset),

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
        minHeightConstraint = customBackgroundView.heightAnchor.constraint(greaterThanOrEqualToConstant: 172)
        if let minHeightConstraint = minHeightConstraint {
            minHeightConstraint.priority = .defaultHigh
            minHeightConstraint.isActive = true
        }

        // Constraints for replyText with image
        replyTextWithImageConstraints = [
            replyText.leadingAnchor.constraint(equalTo: threadImage.trailingAnchor, constant: 8),
            replyText.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4),
            replyText.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            replyText.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -sideInset)
        ]

        // Constraints for replyText without image
        replyTextNoImageConstraints = [
            replyTextNoImage.leadingAnchor.constraint(equalTo: customBackgroundView.leadingAnchor, constant: cornerInset),
            replyTextNoImage.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4),
            replyTextNoImage.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -cornerInset),
            replyTextNoImage.bottomAnchor.constraint(lessThanOrEqualTo: customBackgroundView.bottomAnchor, constant: -sideInset)
        ]
    }

    // MARK: - Configuration Method
    func configure(withImage: Bool, text: NSAttributedString, boardNumber: String, isFiltered: Bool = false, replyCount: Int = 0) {
        print("threadRepliesCell - Configure called with withImage: \(withImage)")
        threadImage.isHidden = !withImage
        replyText.isHidden = !withImage
        replyTextNoImage.isHidden = withImage

        if withImage {
            print("threadRepliesCell - Image constraints - width: 120, height: 120")
            print("threadRepliesCell - Final image frame after constraints: \(threadImage.frame)")
        }

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
    
    // Show preview for Apple Pencil hover
    private func showHoverPreview(at location: CGPoint) {
        // Avoid recreating the preview if it is already visible
        if hoveredImageView != nil {
            return
        }

        if let overlayView = hoverOverlayView {
            overlayView.removeFromSuperview()
            hoverOverlayView = nil
        }
        
        guard let image = threadImage.imageView?.image else { return }
        
        // Create overlay view for the entire screen
        let overlayView = UIView()
        
        // Create preview image view with larger size
        let previewSize: CGFloat = 550
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
        imageView.contentMode = .scaleAspectFit
        // Use device corner radius for preview image
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        imageView.layer.cornerRadius = deviceCornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.systemBackground
        imageView.layer.borderColor = UIColor.label.cgColor
        imageView.layer.borderWidth = 1.0
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 5)
        imageView.layer.shadowOpacity = 0.5
        imageView.layer.shadowRadius = 12
        imageView.image = image
        
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
            imageView.frame.origin = CGPoint(
                x: centerX - (previewSize / 2),
                y: centerY - (previewSize / 2)
            )
            
            // Add the overlay first, then the image on top
            window.addSubview(overlayView)
            window.addSubview(imageView)
            
            // Store references to both views
            hoverOverlayView = overlayView
            hoveredImageView = imageView
            
            // Add appear animation - faster for better responsiveness
            imageView.alpha = 0
            imageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                imageView.alpha = 1
                imageView.transform = .identity
            }
        }
    }
    
    // Update position of hover preview
    private func updateHoverPreviewPosition(to location: CGPoint) {
        guard let imageView = hoveredImageView else { return }
        
        let previewSize = imageView.frame.size.width
        let positionY = location.y - previewSize - 20
        let positionX = location.x - (previewSize / 2)
        
        // Use window bounds to keep preview on screen
        if let window = imageView.window {
            let minX: CGFloat = 20
            let maxX = window.bounds.width - previewSize - 20
            let finalX = max(minX, min(positionX, maxX))
            
            imageView.frame.origin = CGPoint(x: finalX, y: positionY)
        } else {
            imageView.frame.origin = CGPoint(x: positionX, y: positionY)
        }
    }
    
    // Remove hover preview
    private func removeHoverPreview() {
        let imageView = hoveredImageView
        let overlayView = hoverOverlayView

        guard imageView != nil || overlayView != nil else { return }

        // Animate out
        UIView.animate(withDuration: 0.15, animations: {
            imageView?.alpha = 0
            imageView?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            overlayView?.alpha = 0
        }, completion: { _ in
            imageView?.removeFromSuperview()
            overlayView?.removeFromSuperview()

            if let imageView = imageView, self.hoveredImageView === imageView {
                self.hoveredImageView = nil
            }

            if let overlayView = overlayView, self.hoverOverlayView === overlayView {
                self.hoverOverlayView = nil
            }
        })
    }
    
    deinit {
        // Ensure we clean up any previews when cell is deallocated
        if let imageView = hoveredImageView {
            imageView.removeFromSuperview()
        }

        if let overlayView = hoverOverlayView {
            overlayView.removeFromSuperview()
        }
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
