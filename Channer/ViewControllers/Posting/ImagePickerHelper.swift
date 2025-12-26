import UIKit
import PhotosUI

/// Result of image selection
struct SelectedImage {
    let data: Data
    let filename: String
    let mimeType: String
    let thumbnail: UIImage?
}

/// Helper class for selecting images using PHPickerViewController
class ImagePickerHelper: NSObject {

    /// Callback for image selection
    var onImageSelected: ((SelectedImage?) -> Void)?

    /// Maximum image size in bytes (4MB default)
    var maxImageSize: Int = 4 * 1024 * 1024

    /// Target compression quality for JPEG (0.0 - 1.0)
    var jpegCompressionQuality: CGFloat = 0.85

    private weak var presentingViewController: UIViewController?

    // MARK: - Public Methods

    /// Present the image picker
    /// - Parameters:
    ///   - viewController: The view controller to present from
    ///   - completion: Callback with selected image or nil if cancelled
    func presentPicker(from viewController: UIViewController, completion: @escaping (SelectedImage?) -> Void) {
        self.presentingViewController = viewController
        self.onImageSelected = completion

        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .livePhotos])
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    // MARK: - Private Methods

    /// Process the selected image
    private func processImage(_ image: UIImage, originalFilename: String?) -> SelectedImage? {
        // Determine output format
        let filename = originalFilename ?? "image.jpg"
        let ext = (filename as NSString).pathExtension.lowercased()

        var imageData: Data?
        var mimeType: String
        var finalFilename: String

        if ext == "png" {
            // Try PNG first
            imageData = image.pngData()
            mimeType = "image/png"
            finalFilename = filename
        } else if ext == "gif" {
            // GIF - try to preserve
            imageData = image.pngData() // UIImage doesn't preserve GIF animation
            mimeType = "image/gif"
            finalFilename = filename
        } else {
            // Default to JPEG
            imageData = image.jpegData(compressionQuality: jpegCompressionQuality)
            mimeType = "image/jpeg"
            finalFilename = ext == "jpg" || ext == "jpeg" ? filename : "image.jpg"
        }

        // Check if we need to compress further
        if var data = imageData, data.count > maxImageSize {
            // Try progressive compression for JPEG
            var quality = jpegCompressionQuality
            while data.count > maxImageSize && quality > 0.1 {
                quality -= 0.1
                if let compressed = image.jpegData(compressionQuality: quality) {
                    data = compressed
                    mimeType = "image/jpeg"
                    finalFilename = "image.jpg"
                }
            }

            // If still too large, resize the image
            if data.count > maxImageSize {
                let scale = sqrt(Double(maxImageSize) / Double(data.count))
                let newSize = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                if let resizedImage = resizeImage(image, to: newSize),
                   let resizedData = resizedImage.jpegData(compressionQuality: 0.8) {
                    data = resizedData
                    mimeType = "image/jpeg"
                    finalFilename = "image.jpg"
                }
            }

            imageData = data
        }

        guard let finalData = imageData else { return nil }

        // Create thumbnail
        let thumbnailSize = CGSize(width: 100, height: 100)
        let thumbnail = resizeImage(image, to: thumbnailSize)

        return SelectedImage(
            data: finalData,
            filename: finalFilename,
            mimeType: mimeType,
            thumbnail: thumbnail
        )
    }

    /// Resize an image to fit within the given size
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let size = image.size

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ImagePickerHelper: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            onImageSelected?(nil)
            return
        }

        let itemProvider = result.itemProvider

        // Get filename
        let filename = itemProvider.suggestedName ?? "image.jpg"

        // Load image
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        let selectedImage = self?.processImage(image, originalFilename: filename)
                        self?.onImageSelected?(selectedImage)
                    } else {
                        self?.onImageSelected?(nil)
                    }
                }
            }
        } else {
            onImageSelected?(nil)
        }
    }
}

// MARK: - UIImagePickerController Support (Fallback)
extension ImagePickerHelper: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    /// Present camera picker (for taking photos)
    func presentCamera(from viewController: UIViewController, completion: @escaping (SelectedImage?) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            completion(nil)
            return
        }

        self.presentingViewController = viewController
        self.onImageSelected = completion

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false

        viewController.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        if let image = info[.originalImage] as? UIImage {
            let selectedImage = processImage(image, originalFilename: "photo.jpg")
            onImageSelected?(selectedImage)
        } else {
            onImageSelected?(nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        onImageSelected?(nil)
    }
}
