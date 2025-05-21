import UIKit

// MARK: - Pencil Hover Support
@available(iOS 13.4, *)
extension threadRepliesTV {
    
    func setupPencilHoverSupport() {
        // Configure cells for hover as they are displayed
        for cell in tableView.visibleCells {
            if let replyCell = cell as? threadRepliesCell {
                replyCell.setupHoverGestureRecognizer()
            }
        }
    }
    
    // Method to be called from cellForRowAt
    func configureHoverGestureRecognizer(for cell: threadRepliesCell, at indexPath: IndexPath) {
        cell.setupHoverGestureRecognizer()
        
        // Configure image URL if available
        if indexPath.row < threadRepliesImages.count {
            let imageURL = threadRepliesImages[indexPath.row]
            cell.setImageURL(imageURL)
        }
    }
}