// 
//  threadReplyCell.swift
//  Channer
//
//  Created by x on 4/15/19.
//  Copyright © 2019 x. All rights reserved.
//

import UIKit
import AVFoundation
import Kingfisher
import WebKit
import VLCKit

class threadReplyCell: UICollectionViewCell, VLCMediaPlayerDelegate {

    @IBOutlet weak var threadImage: UIButton!
    @IBOutlet weak var replyText: UITextView!
    @IBOutlet weak var boardReplyCount: UILabel!
    @IBOutlet weak var threadReplyCount: UILabel!
    @IBOutlet weak var replyTextNoImage: UITextView!
    @IBOutlet weak var thread: UIButton!

    // Variables for hover functionality
    private var imageURL: String?
    private var hoveredPreviewView: UIView?
    private var hoverOverlayView: UIView?
    private var pointerInteraction: UIPointerInteraction?
    private var hoverProgressTimer: Timer?
    private var hoverVLCPlayer: VLCMediaPlayer?
    /// AVPlayer used for hover preview on Mac Catalyst (after WebM conversion)
    private var hoverAVPlayer: AVPlayer?
    /// AVPlayerLayer for hover preview
    private var hoverAVPlayerLayer: AVPlayerLayer?
    /// Observer for AVPlayer looping in hover preview
    private var hoverAVPlayerEndObserver: NSObjectProtocol?

    // Quote link hover preview
    weak var quoteLinkHoverDelegate: QuoteLinkHoverDelegate?
    private var quoteLinkPreviewView: UIView?
    private var quoteLinkOverlayView: UIView?
    private var currentlyHoveredPostNumber: String?

    // Subject label for OP
    lazy var subjectLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = ThemeManager.shared.primaryTextColor
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private var subjectLabelAdded = false

    override func awakeFromNib() {
        super.awakeFromNib()
        setupPointerInteraction()
        setupQuoteLinkHoverGestures()

        // Make thread button larger and more noticeable
        if let threadButton = thread {
            threadButton.showsTouchWhenHighlighted = true
            threadButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            threadButton.layer.cornerRadius = 15
            threadButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            threadButton.tintColor = .systemBlue
            
            threadButton.layer.shadowColor = UIColor.black.cgColor
            threadButton.layer.shadowOffset = CGSize(width: 0, height: 2)
            threadButton.layer.shadowOpacity = 0.2
            threadButton.layer.shadowRadius = 3
            
            // Increase size (will need to adjust constraints in storyboard)
            threadButton.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }
    }
    
    // Prepare for reuse to clean up resources
    override func prepareForReuse() {
        super.prepareForReuse()
        removeHoverPreview()
        removeQuoteLinkPreview()
        quoteLinkHoverDelegate = nil
        subjectLabel.isHidden = true
        subjectLabel.text = nil
    }
    
    // MARK: - Pointer Interaction for Apple Pencil Hover
    
    private func setupPointerInteraction() {
        guard threadImage != nil else { return }
        
        // Remove any existing interaction
        if let existingInteraction = pointerInteraction {
            threadImage.removeInteraction(existingInteraction)
        }
        
        // Create new interaction
        pointerInteraction = UIPointerInteraction(delegate: self)
        if let interaction = pointerInteraction {
            threadImage.addInteraction(interaction)
            
            // Add blue border to indicate hover capability
            threadImage.layer.borderWidth = 0.0
        }
    }
    
    private func updatePointerInteractionIfNeeded() {
        // Make sure we only set up interaction for visible images
        if threadImage != nil && !threadImage.isHidden {
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
        let previewView: UIView
        if isVideo, let urlString = imageURL, let url = URL(string: urlString) {
            print("[HoverVideo] Starting video hover preview for URL: \(urlString)")
            // Container holds video view + native poster/progress overlays
            let container = UIView(frame: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
            container.backgroundColor = .black
            container.layer.cornerRadius = 15
            container.clipsToBounds = true
            container.isUserInteractionEnabled = false
            container.layer.borderColor = UIColor.label.cgColor
            container.layer.borderWidth = 1.0

            // Native poster overlay (shows thumbnail immediately while video loads)
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

            #if targetEnvironment(macCatalyst)
            // Mac Catalyst: convert WebM to MP4 and use AVPlayer
            if WebMConversionService.shared.needsConversion(url: url) {
                let conversionStart = CFAbsoluteTimeGetCurrent()
                print("[HoverVideo] Mac Catalyst: converting WebM for hover preview")
                // Video view for AVPlayer
                let videoView = UIView(frame: container.bounds)
                videoView.backgroundColor = .black
                container.insertSubview(videoView, at: 0)

                WebMConversionService.shared.convertWebMToMP4(source: url, progress: nil) { [weak self, weak container, weak posterView, weak gradientView, weak progressTrack, weak videoView] result in
                    guard let self = self, let container = container, let videoView = videoView else { return }
                    let elapsed = CFAbsoluteTimeGetCurrent() - conversionStart
                    switch result {
                    case .success(let mp4URL):
                        print("[HoverVideo] Mac Catalyst: conversion done in \(String(format: "%.2f", elapsed))s, playing \(mp4URL)")
                        let player = AVPlayer(url: mp4URL)
                        let hoverSoundEnabled = HoverPreviewManager.shared.videoSoundEnabled
                        player.isMuted = !hoverSoundEnabled
                        player.volume = hoverSoundEnabled ? 1.0 : 0.0

                        let playerLayer = AVPlayerLayer(player: player)
                        playerLayer.frame = videoView.bounds
                        playerLayer.videoGravity = .resizeAspect
                        videoView.layer.addSublayer(playerLayer)

                        self.hoverAVPlayer = player
                        self.hoverAVPlayerLayer = playerLayer

                        // Loop playback
                        self.hoverAVPlayerEndObserver = NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { [weak player] _ in
                            player?.seek(to: .zero)
                            player?.play()
                        }

                        player.play()

                        // Fade out poster once ready
                        UIView.animate(withDuration: 0.3) {
                            posterView?.alpha = 0
                            gradientView?.alpha = 0
                            progressTrack?.alpha = 0
                        }

                    case .failure(let error):
                        print("[HoverVideo] Mac Catalyst: conversion failed after \(String(format: "%.2f", elapsed))s (\(error)), falling back to VLC")
                        self.setupVLCHoverPlayer(url: url, container: container, posterView: posterView, gradientView: gradientView, progressTrack: progressTrack, progressFill: progressFill, shimmerView: shimmerView, previewSize: previewSize)
                    }
                }
            } else {
                setupVLCHoverPlayer(url: url, container: container, posterView: posterView, gradientView: gradientView, progressTrack: progressTrack, progressFill: progressFill, shimmerView: shimmerView, previewSize: previewSize)
            }
            #else
            setupVLCHoverPlayer(url: url, container: container, posterView: posterView, gradientView: gradientView, progressTrack: progressTrack, progressFill: progressFill, shimmerView: shimmerView, previewSize: previewSize)
            #endif

            previewView = container
        } else {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
            imageView.contentMode = .scaleAspectFit
            imageView.layer.cornerRadius = 15
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
    /// Sets up VLC-based hover video playback (used on iOS/iPadOS, or as fallback on Mac Catalyst)
    private func setupVLCHoverPlayer(url: URL, container: UIView, posterView: UIImageView?, gradientView: UIView?, progressTrack: UIView?, progressFill: UIView?, shimmerView: UIView?, previewSize: CGFloat) {
        // VLC video view
        let vlcVideoView = UIView(frame: container.bounds)
        vlcVideoView.backgroundColor = .black
        container.insertSubview(vlcVideoView, at: 0)

        // Create VLC player
        let player = VLCMediaPlayer()
        print("[HoverVLC] Created new VLCMediaPlayer \(Unmanaged.passUnretained(player).toOpaque()) on thread: \(Thread.isMainThread ? "main" : "bg") for URL: \(url)")
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

        // Start VLC playback
        player.play()
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

            if isPlaying && position > 0 {
                let pct = CGFloat(min(max(position, 0), 1))
                let tw = progressTrack?.bounds.width ?? 0
                UIView.animate(withDuration: 0.2) {
                    progressFill?.frame.size.width = tw * pct
                }
                shimmerView?.layer.removeAllAnimations()
                shimmerView?.isHidden = true
            }

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
    }

    private func removeHoverPreview() {
        hoverProgressTimer?.invalidate()
        hoverProgressTimer = nil

        let previewView = hoveredPreviewView
        let overlayView = hoverOverlayView

        guard previewView != nil || overlayView != nil else { return }

        // Cancel any in-flight full-res image download
        (previewView as? UIImageView)?.kf.cancelDownloadTask()

        // Clean up AVPlayer if used for hover (Mac Catalyst WebM conversion path)
        if let observer = hoverAVPlayerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            hoverAVPlayerEndObserver = nil
        }
        hoverAVPlayer?.pause()
        hoverAVPlayerLayer?.removeFromSuperlayer()
        hoverAVPlayer = nil
        hoverAVPlayerLayer = nil

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

        // Clean up AVPlayer hover resources
        if let observer = hoverAVPlayerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            hoverAVPlayerEndObserver = nil
        }
        hoverAVPlayer?.pause()
        hoverAVPlayerLayer?.removeFromSuperlayer()
        hoverAVPlayer = nil
        hoverAVPlayerLayer = nil

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
        if let tv = replyText {
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleQuoteLinkHover(_:)))
            tv.addGestureRecognizer(hover)
        }
        if let tv = replyTextNoImage {
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleQuoteLinkHover(_:)))
            tv.addGestureRecognizer(hover)
        }
    }

    @objc private func handleQuoteLinkHover(_ gesture: UIHoverGestureRecognizer) {
        guard let textView = gesture.view as? UITextView,
              let text = textView.text, !text.isEmpty else { return }

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

            let nsText = text as NSString
            guard characterIndex < nsText.length else {
                removeQuoteLinkPreview()
                return
            }

            // Find >>(\d+) patterns in the text and check if characterIndex is within one
            if let regex = try? NSRegularExpression(pattern: ">>(\\d+)"),
               let match = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                .first(where: { NSLocationInRange(characterIndex, $0.range) }) {
                let postNum = nsText.substring(with: match.range(at: 1))
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
        let headerHeight: CGFloat = 30
        let contentHeight = ceil(boundingRect.height) + textInset * 2
        let minContentHeight = (thumbnailURL != nil) ? thumbnailSize + padding : 40
        let totalHeight = min(headerHeight + padding + max(contentHeight, minContentHeight) + padding, maxHeight)

        // Build card with frame-based layout
        let cardWidth = maxWidth
        let card = UIView(frame: CGRect(
            x: (window.bounds.width - cardWidth) / 2,
            y: (window.bounds.height - totalHeight) / 2,
            width: cardWidth,
            height: totalHeight
        ))
        card.backgroundColor = ThemeManager.shared.cellBackgroundColor
        card.layer.cornerRadius = 15
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.isUserInteractionEnabled = false

        // Header
        let header = UILabel(frame: CGRect(x: padding, y: 12, width: cardWidth - padding * 2, height: 20))
        header.text = ">>\(postNum)"
        header.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        header.textColor = .systemBlue
        card.addSubview(header)

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

    func configureSubject(_ subject: String?) {
        guard let subject = subject, !subject.isEmpty else {
            subjectLabel.isHidden = true
            return
        }
        if !subjectLabelAdded {
            contentView.addSubview(subjectLabel)
            NSLayoutConstraint.activate([
                subjectLabel.leadingAnchor.constraint(equalTo: boardReplyCount.leadingAnchor),
                subjectLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                subjectLabel.topAnchor.constraint(equalTo: boardReplyCount.bottomAnchor, constant: 4)
            ])
            subjectLabelAdded = true
        }
        subjectLabel.text = subject
        subjectLabel.textColor = ThemeManager.shared.primaryTextColor
        subjectLabel.isHidden = false
    }

    func setImageURL(_ url: String?) {
        self.imageURL = url
        
        // Mark image as hoverable with blue border
        if threadImage != nil && !threadImage.isHidden {
            threadImage.layer.borderWidth = 0.0
            
            // Make sure hover interaction is set up
            updatePointerInteractionIfNeeded()
        }
    }
    
    // Handle tap on the preview overlay to dismiss it
    @objc private func handlePreviewTap(_ gestureRecognizer: UITapGestureRecognizer) {
        removeHoverPreview()
    }
}

// MARK: - UIPointerInteractionDelegate
extension threadReplyCell: UIPointerInteractionDelegate {
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        guard threadImage != nil else { return nil }
        
        // Create a hover preview with the image shape
        let targetRect = threadImage.bounds
        let previewParams = UIPreviewParameters()
        previewParams.visiblePath = UIBezierPath(roundedRect: targetRect, cornerRadius: 8)
        
        let preview = UITargetedPreview(view: threadImage, parameters: previewParams)
        
        return UIPointerStyle(effect: .highlight(preview), shape: nil)
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        guard threadImage != nil && !threadImage.isHidden, let window = window else { return }
        
        // Get the center of the threadImage in window coordinates
        let imageCenter = threadImage.convert(CGPoint(x: threadImage.bounds.midX, y: threadImage.bounds.midY), to: window)
        
        // Show hover preview at this location
        showHoverPreview(at: imageCenter)
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        removeHoverPreview()
    }
}
