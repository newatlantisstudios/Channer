import UIKit

@available(iOS 13.0, *)
public class PencilInteractionManager: NSObject {
    
    // Singleton instance
    public static let shared = PencilInteractionManager()
    
    // Reference to the hover view
    private var hoverPreviewView: UIView?
    private var previewImageView: UIImageView?
    
    // Currently active interactions
    private var activeInteractions = [UIView: UIHoverInteraction]()
    
    private override init() {
        super.init()
        print("PencilInteractionManager: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Enables pencil hover interactions for a view
    public func enableHoverInteractions(for view: UIView, withImage image: UIImage? = nil, imageURL: String? = nil) {
        print("PencilInteractionManager: Enabling hover for view \(view)")
        
        // Remove any existing interaction first
        if let existingInteraction = activeInteractions[view] {
            view.removeInteraction(existingInteraction)
            activeInteractions.removeValue(forKey: view)
        }
        
        // Store image and URL in view's associated objects
        if let image = image {
            objc_setAssociatedObject(view, &AssociatedKeys.previewImage, image, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        if let imageURL = imageURL {
            objc_setAssociatedObject(view, &AssociatedKeys.imageURL, imageURL, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        // Create and add the interaction
        let interaction = UIHoverInteraction(delegate: self)
        view.addInteraction(interaction)
        activeInteractions[view] = interaction
        
        // Set this view as hover-enabled with a visual indicator in debug mode
        view.layer.borderColor = UIColor.blue.cgColor
        view.layer.borderWidth = 1.0
        
        print("PencilInteractionManager: Hover enabled for view \(view)")
    }
    
    /// Disables pencil hover interactions for a view
    public func disableHoverInteractions(for view: UIView) {
        print("PencilInteractionManager: Disabling hover for view \(view)")
        
        if let interaction = activeInteractions[view] {
            view.removeInteraction(interaction)
            activeInteractions.removeValue(forKey: view)
            
            // Remove any visual indicator
            view.layer.borderWidth = 0
        }
    }
    
    /// Cleanup all interactions
    public func cleanupAllInteractions() {
        print("PencilInteractionManager: Cleaning up all interactions")
        
        for (view, interaction) in activeInteractions {
            view.removeInteraction(interaction)
        }
        
        activeInteractions.removeAll()
        removeHoverPreview()
    }
    
    // MARK: - Private Methods
    
    private func createHoverPreview() -> UIView {
        print("PencilInteractionManager: Creating hover preview")
        
        // Main container view
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 250, height: 250))
        containerView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        containerView.layer.cornerRadius = 15
        containerView.clipsToBounds = true
        
        // Add a visible border so we can see if it's showing up
        containerView.layer.borderWidth = 3
        containerView.layer.borderColor = UIColor.red.cgColor
        
        // Add shadow
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 5)
        containerView.layer.shadowOpacity = 0.5
        containerView.layer.shadowRadius = 10
        
        // Image view
        let imageView = UIImageView(frame: CGRect(x: 10, y: 10, width: 230, height: 230))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        containerView.addSubview(imageView)
        
        self.previewImageView = imageView
        
        return containerView
    }
    
    private func showHoverPreview(at location: CGPoint, with image: UIImage) {
        print("PencilInteractionManager: Showing hover preview at \(location) with image size \(image.size)")
        
        // Create the view if needed
        if hoverPreviewView == nil {
            hoverPreviewView = createHoverPreview()
        }
        
        // Set the image
        previewImageView?.image = image
        
        // Position the view
        if let hoverView = hoverPreviewView {
            hoverView.center = CGPoint(x: location.x, y: location.y - 150)
            
            // Add to window if not already added
            if hoverView.superview == nil {
                // Find the key window
                let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
                keyWindow?.addSubview(hoverView)
                
                print("PencilInteractionManager: Added hover view to window")
                
                // Add a slight animation to make it more noticeable
                hoverView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                UIView.animate(withDuration: 0.2) {
                    hoverView.transform = CGAffineTransform.identity
                }
            }
        }
    }
    
    private func updateHoverPreviewPosition(to location: CGPoint) {
        guard let hoverView = hoverPreviewView else { return }
        
        // Update position
        hoverView.center = CGPoint(x: location.x, y: location.y - 150)
    }
    
    private func removeHoverPreview() {
        print("PencilInteractionManager: Removing hover preview")
        
        if let hoverView = hoverPreviewView {
            UIView.animate(withDuration: 0.2, animations: {
                hoverView.alpha = 0
            }) { _ in
                hoverView.removeFromSuperview()
                self.hoverPreviewView = nil
                self.previewImageView = nil
            }
        }
    }
}

// MARK: - UIHoverInteractionDelegate
@available(iOS 13.0, *)
extension PencilInteractionManager: UIHoverInteractionDelegate {
    
    public func hoverInteraction(_ interaction: UIHoverInteraction, willHover hover: UIHoverGestureRecognizer) {
        print("PencilInteractionManager: willHover called")
    }
    
    public func hoverInteraction(_ interaction: UIHoverInteraction, didHover hover: UIHoverGestureRecognizer) {
        print("PencilInteractionManager: didHover called with state \(hover.state.rawValue)")
        
        guard let view = interaction.view else { return }
        
        // Get location in window coordinates
        let location = hover.location(in: nil)
        print("PencilInteractionManager: Hover location in window: \(location)")
        
        // Get the associated image
        let associatedImage = objc_getAssociatedObject(view, &AssociatedKeys.previewImage) as? UIImage
        print("PencilInteractionManager: Associated image exists: \(associatedImage != nil)")
        
        switch hover.state {
        case .began, .changed:
            // Visual feedback on the view
            view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            
            // Show preview if we have an image
            if let image = associatedImage {
                showHoverPreview(at: location, with: image)
            } else {
                // Try to create a placeholder instead
                let placeholderImage = UIImage(systemName: "photo") ?? UIImage()
                showHoverPreview(at: location, with: placeholderImage)
            }
            
            // Update position
            updateHoverPreviewPosition(to: location)
            
        case .ended, .cancelled:
            // Remove visual feedback
            view.backgroundColor = UIColor.clear
            
            // Remove preview
            removeHoverPreview()
            
        default:
            break
        }
    }
}

// MARK: - Associated Objects Keys
private struct AssociatedKeys {
    static var previewImage = "PencilInteractionManager.previewImage"
    static var imageURL = "PencilInteractionManager.imageURL"
}