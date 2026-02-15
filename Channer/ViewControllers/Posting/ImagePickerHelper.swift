import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

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

    #if targetEnvironment(macCatalyst)
    /// Strong reference to the NSOpenPanel instance used on Mac Catalyst.
    /// Required to keep it alive during the asynchronous file selection.
    private var nativeOpenPanel: NSObject?
    #endif

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

    /// Present a document picker for video files (webm, mp4)
    /// - Parameters:
    ///   - viewController: The view controller to present from
    ///   - completion: Callback with selected file or nil if cancelled
    func presentDocumentPicker(from viewController: UIViewController, completion: @escaping (SelectedImage?) -> Void) {
        self.presentingViewController = viewController
        self.onImageSelected = completion

        var types: [UTType] = [.mpeg4Movie]
        if let webm = UTType(filenameExtension: "webm") {
            types.append(webm)
        }

        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, UIDocumentPickerViewController maps to NSOpenPanel but breaks
        // when presented from a view controller in a sheet presentation window (all VCs are
        // "detached" in the _UIBridgedPresentationWindow). Bypass UIKit entirely and invoke
        // NSOpenPanel directly through the Objective-C runtime.
        presentNativeOpenPanel(types: types)
        #else
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        viewController.present(picker, animated: true)
        #endif
    }

    #if targetEnvironment(macCatalyst)
    /// Directly invoke NSOpenPanel via the ObjC runtime, bypassing UIDocumentPickerViewController.
    private func presentNativeOpenPanel(types: [UTType]) {
        guard let panelClass = NSClassFromString("NSOpenPanel") else {
            onImageSelected?(nil)
            return
        }

        let openSel = NSSelectorFromString("openPanel")
        guard (panelClass as AnyObject).responds(to: openSel),
              let result = (panelClass as AnyObject).perform(openSel) else {
            onImageSelected?(nil)
            return
        }

        let panel = result.takeUnretainedValue()
        nativeOpenPanel = panel as? NSObject

        panel.setValue(types, forKey: "allowedContentTypes")
        panel.setValue(false, forKey: "allowsMultipleSelection")
        panel.setValue(true, forKey: "canChooseFiles")
        panel.setValue(false, forKey: "canChooseDirectories")

        let handler: @convention(block) (Int) -> Void = { [weak self] response in
            self?.nativeOpenPanel = nil

            // NSModalResponseOK = 1
            if response == 1, let urls = panel.value(forKey: "URLs") as? [URL], let url = urls.first {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let selectedImage = self?.processVideoFile(at: url)
                    DispatchQueue.main.async {
                        if selectedImage == nil, let error = self?.lastVideoError {
                            if let presenter = self?.presentingViewController {
                                let alert = UIAlertController(title: "File Error", message: error, preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default))
                                presenter.present(alert, animated: true)
                            }
                        }
                        self?.onImageSelected?(selectedImage)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.onImageSelected?(nil)
                }
            }
        }

        let beginSel = NSSelectorFromString("beginWithCompletionHandler:")
        panel.perform(beginSel, with: handler)
    }
    #endif

    // MARK: - Private Methods

    /// Error info from the last failed video processing attempt
    var lastVideoError: String?

    /// Process a selected video file, transcoding to H264 if needed for 4chan compatibility
    private func processVideoFile(at url: URL) -> SelectedImage? {
        lastVideoError = nil
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        // WebM files are passed through as-is (must already be VP8/VP9)
        if ext == "webm" {
            guard let data = try? Data(contentsOf: url) else {
                lastVideoError = "Could not read file: \(filename)"
                return nil
            }
            let thumbnail = generateVideoThumbnail(from: url)
            return SelectedImage(data: data, filename: filename, mimeType: "video/webm", thumbnail: thumbnail)
        }

        // For MP4/M4V, check codec and transcode if not H264
        let asset = AVAsset(url: url)
        let videoTracks = asset.tracks(withMediaType: .video)

        guard let videoTrack = videoTracks.first else {
            lastVideoError = "No video track found in file"
            return nil
        }

        let codecType = videoTrack.formatDescriptions.first.flatMap { desc -> CMVideoCodecType? in
            let formatDesc = desc as! CMFormatDescription
            return CMFormatDescriptionGetMediaSubType(formatDesc)
        }

        let isH264 = codecType == kCMVideoCodecType_H264

        if isH264 {
            // Already H264 — pass through directly
            guard let data = try? Data(contentsOf: url) else {
                lastVideoError = "Could not read file: \(filename)"
                return nil
            }
            let thumbnail = generateVideoThumbnail(from: url)
            return SelectedImage(data: data, filename: filename, mimeType: "video/mp4", thumbnail: thumbnail)
        }

        // Transcode to H264
        let thumbnail = generateVideoThumbnail(from: url)
        guard let transcodedData = transcodeVideoToH264(asset: asset) else {
            // lastVideoError is set by transcodeVideoToH264
            return nil
        }

        let h264Filename = (filename as NSString).deletingPathExtension + ".mp4"
        return SelectedImage(data: transcodedData, filename: h264Filename, mimeType: "video/mp4", thumbnail: thumbnail)
    }

    /// Transcode a video asset to H264/MP4 using AVAssetExportSession
    private func transcodeVideoToH264(asset: AVAsset) -> Data? {
        // Try presets in order of quality (highest that produces < 4MB)
        let presets = [
            AVAssetExportPresetMediumQuality,
            AVAssetExportPresetLowQuality
        ]

        for preset in presets {
            guard AVAssetExportSession.exportPresets(compatibleWith: asset).contains(preset) else {
                continue
            }

            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                continue
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")

            session.outputURL = tempURL
            session.outputFileType = .mp4

            let semaphore = DispatchSemaphore(value: 0)
            session.exportAsynchronously { semaphore.signal() }
            semaphore.wait()

            defer { try? FileManager.default.removeItem(at: tempURL) }

            guard session.status == .completed else {
                let errorMsg = session.error?.localizedDescription ?? "Unknown export error"
                print("Transcode failed with preset \(preset): \(errorMsg)")
                continue
            }

            guard let data = try? Data(contentsOf: tempURL) else { continue }

            if data.count <= maxImageSize {
                return data
            }
            // File too large with this preset, try a lower quality
        }

        lastVideoError = "Could not transcode video to H264 within the 4MB file size limit. Try a shorter or lower-resolution video."
        return nil
    }

    /// Generate a thumbnail image from a video file
    private func generateVideoThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            // Fallback to a generic video icon (e.g. webm not supported by AVFoundation)
            return UIImage(systemName: "film")
        }
    }

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

    /// Create a SelectedImage from a UIImage (used by drag-and-drop on macOS)
    func createSelectedImage(from image: UIImage, originalFilename: String?) -> SelectedImage? {
        return processImage(image, originalFilename: originalFilename)
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

// MARK: - UIDocumentPickerDelegate (Video Files)
extension ImagePickerHelper: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            onImageSelected?(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.processVideoFile(at: url)
            DispatchQueue.main.async {
                if result == nil, let error = self?.lastVideoError {
                    if let presenter = self?.presentingViewController {
                        let alert = UIAlertController(title: "File Error", message: error, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        presenter.present(alert, animated: true)
                    }
                }
                self?.onImageSelected?(result)
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onImageSelected?(nil)
    }
}
