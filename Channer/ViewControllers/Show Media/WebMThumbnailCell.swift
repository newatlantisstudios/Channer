import UIKit
import AVFoundation
import VLCKit

// MARK: - WebMThumbnailCell
/// A custom collection view cell that displays a thumbnail image.
class WebMThumbnailCell: UICollectionViewCell {
    
    // MARK: - Reuse Identifier
    /// The reuse identifier for this cell.
    static let reuseIdentifier = "WebMThumbnailCell"
    
    // MARK: - UI Components
    /// An image view to display the thumbnail image.
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill  // Scale the image to fill while maintaining aspect ratio.
        imageView.clipsToBounds = true            // Prevent image overflow.
        imageView.translatesAutoresizingMaskIntoConstraints = false  // Enable Auto Layout.
        return imageView
    }()
    
    /// Selection indicator for multi-selection mode
    let selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Checkmark image view for selection indicator
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initializers
    /// Initializes the cell with a frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(selectionIndicator)
        selectionIndicator.addSubview(checkmarkImageView)
        
        // Set up constraints to make the image view fill the cell.
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Selection indicator (top-right corner)
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            selectionIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // Checkmark inside selection indicator
            checkmarkImageView.centerXAnchor.constraint(equalTo: selectionIndicator.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: selectionIndicator.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 12),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    /// Required initializer for decoding the cell from a storyboard or nib.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    /// Configures the cell with an image.
    /// - Parameter image: The image to display in the thumbnail image view.
    func configure(with image: UIImage?) {
        thumbnailImageView.image = image
    }
    
    // MARK: - Selection Methods
    /// Shows or hides the selection indicator
    /// - Parameter isSelected: Whether the cell should show as selected
    func setSelected(_ isSelected: Bool) {
        selectionIndicator.isHidden = !isSelected
    }

    /// Shows or hides the selection mode UI elements
    /// - Parameters:
    ///   - isSelectionMode: Whether we're in selection mode
    ///   - isSelected: Whether this cell is currently selected
    func setSelectionMode(_ isSelectionMode: Bool, isSelected: Bool = false) {
        // In selection mode, we always show the selection indicator (selected or not)
        // When not selected, show an empty circle
        if isSelectionMode {
            selectionIndicator.isHidden = false
            if !isSelected {
                selectionIndicator.backgroundColor = UIColor.clear
                selectionIndicator.layer.borderWidth = 2
                selectionIndicator.layer.borderColor = UIColor.systemGray4.cgColor
                checkmarkImageView.isHidden = true
            } else {
                selectionIndicator.backgroundColor = UIColor.systemBlue
                selectionIndicator.layer.borderWidth = 0
                checkmarkImageView.isHidden = false
            }
        } else {
            selectionIndicator.isHidden = true
            selectionIndicator.layer.borderWidth = 0
        }
    }

    /// Updates the cell's visual selection state with gallery-style feedback (matching ImageGalleryVC)
    func setGallerySelected(_ selected: Bool, animated: Bool = true) {
        let changes = {
            if selected {
                self.contentView.layer.borderWidth = 3
                self.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                self.contentView.layer.cornerRadius = 8
                self.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)

                // Add subtle shadow
                self.contentView.layer.shadowColor = UIColor.systemBlue.cgColor
                self.contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
                self.contentView.layer.shadowOpacity = 0.3
                self.contentView.layer.shadowRadius = 4
            } else {
                self.contentView.layer.borderWidth = 0
                self.contentView.layer.borderColor = nil
                self.contentView.layer.cornerRadius = 4
                self.contentView.backgroundColor = .clear
                self.contentView.layer.shadowOpacity = 0
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    /// Adds hover/tap effect for better user feedback (matching ImageGalleryVC)
    func setHighlighted(_ highlighted: Bool, animated: Bool = true) {
        let changes = {
            if highlighted {
                self.contentView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.contentView.alpha = 0.8
            } else {
                self.contentView.transform = .identity
                self.contentView.alpha = 1.0
            }
        }

        if animated {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        selectionIndicator.isHidden = true
        selectionIndicator.layer.borderWidth = 0
        checkmarkImageView.isHidden = false

        // Reset gallery-style selection state
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = nil
        contentView.backgroundColor = .clear
        contentView.layer.shadowOpacity = 0
        contentView.transform = .identity
        contentView.alpha = 1.0
    }
}

// MARK: - FileThumbnailCell
/// A custom collection view cell that displays a thumbnail image with filename for file browser.
class FileThumbnailCell: UICollectionViewCell {

    // MARK: - Reuse Identifier
    /// The reuse identifier for this cell.
    static let reuseIdentifier = "FileThumbnailCell"

    // MARK: - Video Preview Properties
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: Any? // AVPlayerLooper requires AVQueuePlayer
    private var queuePlayer: AVQueuePlayer?
    private var looperItem: AVPlayerItem?
    private var playerObserver: NSObjectProtocol?

    // VLCKit properties for WebM preview
    private var vlcPlayer: VLCMediaPlayer?
    private var vlcDrawableView: UIView?
    private var vlcEndObserver: NSObjectProtocol?

    // MARK: - UI Components
    /// An image view to display the thumbnail image.
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 8
        return imageView
    }()

    /// A small play icon badge to indicate video files.
    private let videoIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "play.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 1)
        imageView.layer.shadowOpacity = 0.6
        imageView.layer.shadowRadius = 2
        return imageView
    }()
    
    /// A label to display the filename.
    let filenameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// A visual indicator for directories.
    let directoryIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Selection indicator for multi-selection mode
    let selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Checkmark image view for selection indicator
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initializers
    /// Initializes the cell with a frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(directoryIndicator)
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(videoIconView)
        contentView.addSubview(filenameLabel)
        contentView.addSubview(selectionIndicator)
        selectionIndicator.addSubview(checkmarkImageView)

        // Set up constraints
        NSLayoutConstraint.activate([
            // Directory indicator (background)
            directoryIndicator.topAnchor.constraint(equalTo: contentView.topAnchor),
            directoryIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            directoryIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            directoryIndicator.heightAnchor.constraint(equalTo: contentView.widthAnchor),

            // Thumbnail image view
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            thumbnailImageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, constant: -8),

            // Video icon (bottom-left of thumbnail)
            videoIconView.leadingAnchor.constraint(equalTo: thumbnailImageView.leadingAnchor, constant: 4),
            videoIconView.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: -4),
            videoIconView.widthAnchor.constraint(equalToConstant: 14),
            videoIconView.heightAnchor.constraint(equalToConstant: 14),

            // Filename label
            filenameLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 2),
            filenameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            filenameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            filenameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -2),

            // Selection indicator (top-right corner)
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            selectionIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),

            // Checkmark inside selection indicator
            checkmarkImageView.centerXAnchor.constraint(equalTo: selectionIndicator.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: selectionIndicator.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 12),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    /// Required initializer for decoding the cell from a storyboard or nib.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = thumbnailImageView.bounds
        vlcDrawableView?.frame = thumbnailImageView.bounds
    }
    
    // MARK: - Configuration
    /// Configures the cell with an image, filename, and directory status.
    /// - Parameters:
    ///   - image: The image to display in the thumbnail image view.
    ///   - fileName: The name of the file to display.
    ///   - isDirectory: Whether this item represents a directory.
    func configure(with image: UIImage?, fileName: String, isDirectory: Bool) {
        thumbnailImageView.image = image
        filenameLabel.text = fileName
        directoryIndicator.isHidden = !isDirectory
        
        if isDirectory {
            filenameLabel.textColor = .systemBlue
            filenameLabel.font = UIFont.boldSystemFont(ofSize: 12)
        } else {
            filenameLabel.textColor = .label
            filenameLabel.font = UIFont.systemFont(ofSize: 12)
        }
    }
    
    // MARK: - Selection Methods
    /// Shows or hides the selection indicator
    /// - Parameter isSelected: Whether the cell should show as selected
    func setSelected(_ isSelected: Bool) {
        selectionIndicator.isHidden = !isSelected
    }

    /// Shows or hides the selection mode UI elements
    /// - Parameters:
    ///   - isSelectionMode: Whether we're in selection mode
    ///   - isSelected: Whether this cell is currently selected
    func setSelectionMode(_ isSelectionMode: Bool, isSelected: Bool = false) {
        // In selection mode, we always show the selection indicator (selected or not)
        // When not selected, show an empty circle
        if isSelectionMode {
            selectionIndicator.isHidden = false
            if !isSelected {
                selectionIndicator.backgroundColor = UIColor.clear
                selectionIndicator.layer.borderWidth = 2
                selectionIndicator.layer.borderColor = UIColor.systemGray4.cgColor
                checkmarkImageView.isHidden = true
            } else {
                selectionIndicator.backgroundColor = UIColor.systemBlue
                selectionIndicator.layer.borderWidth = 0
                checkmarkImageView.isHidden = false
            }
        } else {
            selectionIndicator.isHidden = true
            selectionIndicator.layer.borderWidth = 0
        }
    }

    /// Updates the cell's visual selection state with gallery-style feedback (matching ImageGalleryVC)
    func setGallerySelected(_ selected: Bool, animated: Bool = true) {
        let changes = {
            if selected {
                self.contentView.layer.borderWidth = 3
                self.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                self.contentView.layer.cornerRadius = 8
                self.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)

                // Add subtle shadow
                self.contentView.layer.shadowColor = UIColor.systemBlue.cgColor
                self.contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
                self.contentView.layer.shadowOpacity = 0.3
                self.contentView.layer.shadowRadius = 4
            } else {
                self.contentView.layer.borderWidth = 0
                self.contentView.layer.borderColor = nil
                self.contentView.layer.cornerRadius = 4
                self.contentView.backgroundColor = .clear
                self.contentView.layer.shadowOpacity = 0
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    /// Adds hover/tap effect for better user feedback (matching ImageGalleryVC)
    func setHighlighted(_ highlighted: Bool, animated: Bool = true) {
        let changes = {
            if highlighted {
                self.contentView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.contentView.alpha = 0.8
            } else {
                self.contentView.transform = .identity
                self.contentView.alpha = 1.0
            }
        }

        if animated {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    // MARK: - Video Preview Methods

    /// Starts playing a video preview in the cell thumbnail area.
    func startVideoPreview(url: URL) {
        stopVideoPreview()

        let ext = url.pathExtension.lowercased()
        if ext == "webm" {
            startVLCPreview(url: url)
        } else {
            startAVPreview(url: url)
        }

        videoIconView.isHidden = true
    }

    /// Starts an AVPlayer-based preview for MP4/MOV files.
    private func startAVPreview(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: playerItem)
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false

        let looper = AVPlayerLooper(player: queue, templateItem: playerItem)

        let layer = AVPlayerLayer(player: queue)
        layer.videoGravity = .resizeAspectFill
        layer.cornerRadius = 8
        layer.masksToBounds = true
        layer.frame = thumbnailImageView.bounds
        thumbnailImageView.layer.addSublayer(layer)

        self.queuePlayer = queue
        self.playerLayer = layer
        self.playerLooper = looper

        queue.play()
    }

    /// Starts a VLCKit-based preview for WebM files.
    private func startVLCPreview(url: URL) {
        let drawable = UIView()
        drawable.frame = thumbnailImageView.bounds
        drawable.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        drawable.clipsToBounds = true
        drawable.layer.cornerRadius = 8
        thumbnailImageView.addSubview(drawable)

        let player = VLCMediaPlayer()
        player.drawable = drawable
        player.audio?.isMuted = true
        player.audio?.volume = 0

        let media = VLCMedia(url: url)
        media?.addOption("--no-audio")
        player.media = media

        // Loop when playback ends
        vlcEndObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VLCMediaPlayerStateChanged"),
            object: player,
            queue: .main
        ) { [weak player] _ in
            guard let player = player, player.state == .stopped, player.position >= 0.99 else { return }
            player.position = 0
            player.play()
        }

        self.vlcPlayer = player
        self.vlcDrawableView = drawable

        player.play()
    }

    /// Stops the video preview and cleans up resources.
    func stopVideoPreview() {
        // Stop AVPlayer preview
        queuePlayer?.pause()
        queuePlayer?.replaceCurrentItem(with: nil)
        playerLayer?.removeFromSuperlayer()

        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        queuePlayer = nil
        playerLayer = nil
        playerLooper = nil
        looperItem = nil
        playerObserver = nil

        // Stop VLC preview
        if let observer = vlcEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        vlcPlayer?.stop()
        vlcDrawableView?.removeFromSuperview()
        vlcPlayer = nil
        vlcDrawableView = nil
        vlcEndObserver = nil
    }

    /// Whether a video preview is currently playing.
    var isPlayingVideoPreview: Bool {
        if let qp = queuePlayer, qp.rate != 0 { return true }
        if let vp = vlcPlayer, vp.isPlaying { return true }
        return false
    }

    /// Shows or hides the video icon badge.
    func setVideoIconVisible(_ visible: Bool) {
        videoIconView.isHidden = !visible
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        stopVideoPreview()
        thumbnailImageView.image = nil
        filenameLabel.text = nil
        directoryIndicator.isHidden = true
        selectionIndicator.isHidden = true
        selectionIndicator.layer.borderWidth = 0
        checkmarkImageView.isHidden = false
        videoIconView.isHidden = true

        // Reset gallery-style selection state
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = nil
        contentView.backgroundColor = .clear
        contentView.layer.shadowOpacity = 0
        contentView.transform = .identity
        contentView.alpha = 1.0
    }
}

// MARK: - FileListCell
/// A list-style cell for the file browser.
class FileListCell: UICollectionViewCell {
    static let reuseIdentifier = "FileListCell"

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 10
        contentView.backgroundColor = .clear

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(detailLabel)

        contentView.addSubview(iconImageView)
        contentView.addSubview(textStack)
        contentView.addSubview(selectionImageView)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),

            textStack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: selectionImageView.leadingAnchor, constant: -12),

            selectionImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            selectionImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionImageView.widthAnchor.constraint(equalToConstant: 22),
            selectionImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with image: UIImage?, fileName: String, isDirectory: Bool, detailText: String?) {
        iconImageView.image = image
        nameLabel.text = fileName
        detailLabel.text = detailText
        detailLabel.isHidden = detailText == nil

        if isDirectory {
            nameLabel.textColor = .systemBlue
            nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        } else {
            nameLabel.textColor = .label
            nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        }
    }

    func setSelectionMode(_ isSelectionMode: Bool, isSelected: Bool = false) {
        if isSelectionMode {
            selectionImageView.isHidden = false
            selectionImageView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            selectionImageView.tintColor = isSelected ? .systemBlue : .systemGray3
        } else {
            selectionImageView.isHidden = true
            selectionImageView.image = nil
        }
    }

    func setHighlighted(_ highlighted: Bool, animated: Bool = true) {
        let changes = {
            self.contentView.backgroundColor = highlighted ? UIColor.systemGray5 : UIColor.clear
        }

        if animated {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        nameLabel.text = nil
        detailLabel.text = nil
        selectionImageView.isHidden = true
        selectionImageView.image = nil
        contentView.backgroundColor = .clear
    }
}
