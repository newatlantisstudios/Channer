// 
//  threadReplyCell.swift
//  Channer
//
//  Created by x on 4/15/19.
//  Copyright © 2019 x. All rights reserved.
//

import UIKit
import Kingfisher

class threadReplyCell: UICollectionViewCell {
    
    @IBOutlet weak var threadImage: UIButton!
    @IBOutlet weak var replyText: UITextView!
    @IBOutlet weak var boardReplyCount: UILabel!
    @IBOutlet weak var threadReplyCount: UILabel!
    @IBOutlet weak var replyTextNoImage: UITextView!
    @IBOutlet weak var thread: UIButton!
    
    // Variables for hover functionality
    private var imageURL: String?
    private var hoveredImageView: UIImageView?
    private var hoverOverlayView: UIView?
    private var pointerInteraction: UIPointerInteraction?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupPointerInteraction()
        
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
        let previewSize: CGFloat = 650  // Even larger on iPad
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 15
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
