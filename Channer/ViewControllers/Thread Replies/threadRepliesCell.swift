import UIKit
import Kingfisher

class threadRepliesCell: UITableViewCell {
    // Variables for hover functionality
    private var imageURL: String?
    private var hoveredImageView: UIImageView?
    private var pointerInteraction: UIPointerInteraction?

    // MARK: - UI Components
    let threadImage: UIButton = {
        let button = UIButton()
        // Use device corner radius for consistency with threads view
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
        button.setImage(UIImage(named: "thread"), for: .normal)
        
        // Make button more visually appealing
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        button.layer.cornerRadius = 15
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        button.tintColor = .systemBlue // Make the icon blue
        
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
        setupPointerInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Prepare for reuse to clean up resources
    override func prepareForReuse() {
        super.prepareForReuse()
        removeHoverPreview()
    }
    
    // Update UI when trait collection changes (light/dark mode)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors when appearance changes
            customBackgroundView.backgroundColor = ThemeManager.shared.cellBackgroundColor
            customBackgroundView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
            boardReplyCount.textColor = ThemeManager.shared.primaryTextColor
            
            // Update thread button appearance for dark/light mode
            thread.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            thread.tintColor = .systemBlue
            
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
        contentView.addSubview(filterBadge)
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

            thread.widthAnchor.constraint(equalToConstant: 40),
            thread.heightAnchor.constraint(equalToConstant: 40),
            thread.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -12),
            thread.bottomAnchor.constraint(equalTo: customBackgroundView.bottomAnchor, constant: -12),
            
            // Filter badge constraints
            filterBadge.topAnchor.constraint(equalTo: customBackgroundView.topAnchor, constant: 8),
            filterBadge.trailingAnchor.constraint(equalTo: customBackgroundView.trailingAnchor, constant: -8),
            filterBadge.widthAnchor.constraint(equalToConstant: 80),
            filterBadge.heightAnchor.constraint(equalToConstant: 24)
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
    func configure(withImage: Bool, text: NSAttributedString, boardNumber: String, isFiltered: Bool = false) {
        print("threadRepliesCell - Configure called with withImage: \(withImage)")
        threadImage.isHidden = !withImage
        replyText.isHidden = !withImage
        replyTextNoImage.isHidden = withImage
        
        if withImage {
            print("threadRepliesCell - Image constraints - width: 120, height: 120")
            print("threadRepliesCell - Final image frame after constraints: \(threadImage.frame)")
        }
        
        // Add visual feedback for the thread reply button
        thread.showsTouchWhenHighlighted = true
        
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
        // Remove any existing preview
        removeHoverPreview()
        
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
            
            // Add tap gesture to dismiss the preview
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
            overlayView.addGestureRecognizer(tapGesture)
            overlayView.isUserInteractionEnabled = true
            
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
            overlayView.tag = 9998
            imageView.tag = 9999
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
        guard let imageView = hoveredImageView else { return }
        
        // Find the overlay view using tag
        let overlayView = imageView.superview?.viewWithTag(9998)
        
        // Animate out
        UIView.animate(withDuration: 0.15, animations: {
            imageView.alpha = 0
            imageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            overlayView?.alpha = 0
        }, completion: { _ in
            // Make sure views are still in hierarchy before removing
            if imageView.superview != nil {
                imageView.removeFromSuperview()
            }
            
            if overlayView?.superview != nil {
                overlayView?.removeFromSuperview()
            }
            
            // Clear reference
            if self.hoveredImageView === imageView {
                self.hoveredImageView = nil
            }
        })
    }
    
    deinit {
        // Ensure we clean up any previews when cell is deallocated
        if let imageView = hoveredImageView {
            if imageView.superview != nil {
                imageView.removeFromSuperview()
            }
            
            // Also remove the overlay
            if let overlayView = imageView.superview?.viewWithTag(9998), overlayView.superview != nil {
                overlayView.removeFromSuperview()
            }
        }
    }
    
    func setImageURL(_ url: String?) {
        print("threadRepliesCell - setImageURL called with: \(url ?? "nil")")
        self.imageURL = url
        
        if let url = url, let imageURL = URL(string: url) {
            print("threadRepliesCell - Loading image from URL")
            threadImage.kf.setImage(with: imageURL, for: .normal, placeholder: UIImage(named: "loadingBoardImage"))
        } else {
            print("threadRepliesCell - Setting placeholder image")
            threadImage.setImage(UIImage(named: "loadingBoardImage"), for: .normal)
        }
        
        // Remove any border from image
        if !threadImage.isHidden {
            threadImage.layer.borderWidth = 0.0
        }
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
