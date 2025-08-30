import UIKit

/// UIImage extensions for common image operations
extension UIImage {
    
    /// Resizes the image to the specified size
    /// - Parameter size: Target size for the resized image
    /// - Returns: Resized UIImage or nil if the operation fails
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}