import UIKit

// MARK: - Pencil Hover Support for iPad
@available(iOS 13.4, *)
extension threadRepliesCV {
    
    func setupPencilHoverSupport() {
        // Configure cells for hover as they are displayed
        for cell in collectionView.visibleCells {
            if let replyCell = cell as? threadReplyCell {
                replyCell.setupHoverGestureRecognizer()
            }
        }
    }
    
    // Method to be called from cellForItemAt
    func configureHoverGestureRecognizer(for cell: threadReplyCell, at indexPath: IndexPath) {
        // Configure image URL if available
        if indexPath.row < threadRepliesImages.count {
            let imageURL = threadRepliesImages[indexPath.row]
            cell.setImageURL(imageURL)
        }
    }
}