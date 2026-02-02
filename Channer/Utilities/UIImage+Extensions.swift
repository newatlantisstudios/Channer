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

    /// Returns an image with orientation normalized to .up
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }

    /// Crops the image to the given pixel rect (in the image's pixel coordinate space)
    func cropped(to pixelRect: CGRect) -> UIImage? {
        let normalized = normalizedOrientation()
        guard let cgImage = normalized.cgImage else { return nil }

        let imageRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clippedRect = pixelRect.integral.intersection(imageRect)
        guard clippedRect.width > 0, clippedRect.height > 0 else { return nil }
        guard let cropped = cgImage.cropping(to: clippedRect) else { return nil }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }
}
