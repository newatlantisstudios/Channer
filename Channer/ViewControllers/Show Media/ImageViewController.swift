import UIKit
import Kingfisher
import ImageIO
import UniformTypeIdentifiers

/// A view controller that displays an image with zooming and panning capabilities.
/// Supports both local file URLs and remote HTTP/HTTPS URLs.
/// Enhanced with double-tap zoom, context menus, and HEIC/AVIF support.
class ImageViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Properties
    /// The image view that displays the image.
    private var imageView: UIImageView!
    /// The scroll view that enables zooming and panning.
    private var scrollView: UIScrollView!
    /// The URL of the image to be displayed.
    var imageURL: URL
    /// A flag to ensure zoom scale is initialized only once.
    private var hasInitializedZoomScale = false
    /// Activity indicator for loading remote images
    private var activityIndicator: UIActivityIndicatorView!
    /// Flag to track if currently zoomed in (for double-tap toggle)
    private var isZoomedIn = false
    /// Holds a cropped/edited image if the user modifies the original
    private var editedImage: UIImage?

    /// Array of image URLs for navigation (optional)
    var imageURLs: [URL] = []
    /// Current index in the imageURLs array
    var currentIndex: Int = 0
    /// Enable swipe navigation between images
    var enableSwipes: Bool = true
    /// Optional referer string for remote image loading
    var refererString: String?

    /// Supported image formats including modern formats
    static let supportedImageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "avif", "bmp", "tiff", "ico"]

    // MARK: - Keyboard Shortcuts
    override var keyCommands: [UIKeyCommand]? {
        guard supportsHardwareNavigation,
              enableSwipes,
              imageURLs.count > 1 else {
            return nil
        }

        let nextImageCommand = UIKeyCommand(input: UIKeyCommand.inputDownArrow,
                                            modifierFlags: [],
                                            action: #selector(nextImageShortcut))
        nextImageCommand.discoverabilityTitle = "Next Image"
        if #available(iOS 15.0, *) {
            nextImageCommand.wantsPriorityOverSystemBehavior = true
        }

        let previousImageCommand = UIKeyCommand(input: UIKeyCommand.inputUpArrow,
                                                modifierFlags: [],
                                                action: #selector(previousImageShortcut))
        previousImageCommand.discoverabilityTitle = "Previous Image"
        if #available(iOS 15.0, *) {
            previousImageCommand.wantsPriorityOverSystemBehavior = true
        }

        return [nextImageCommand, previousImageCommand]
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    // MARK: - Initializers
    /// Initializes the view controller with the given image URL.
    /// - Parameter imageURL: The URL of the image to display.
    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
        print("DEBUG: ImageViewController - Initialized with URL: \(imageURL)")
    }
    
    /// Required initializer with coder (not implemented).
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle Methods
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()

        print("DEBUG: ImageViewController - viewDidLoad started")
        print("DEBUG: ImageViewController - Loading image from: \(imageURL)")

        view.backgroundColor = .black
        setupScrollView()
        setupImageView()
        setupActivityIndicator()
        setupSwipeGestures()
        setupDoubleTapGesture()
        setupLongPressGesture()
        setupNavigationBarItems()

        loadImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    // MARK: - Keyboard Shortcut Methods
    @objc private func nextImageShortcut() {
        navigateImage(by: 1)
    }

    @objc private func previousImageShortcut() {
        navigateImage(by: -1)
    }

    private func navigateImage(by offset: Int) {
        guard imageURLs.count > 1 else { return }
        let newIndex = currentIndex + offset
        guard newIndex >= 0, newIndex < imageURLs.count else { return }
        currentIndex = newIndex
        imageURL = imageURLs[currentIndex]
        loadImage()
    }

    private var supportsHardwareNavigation: Bool {
        let idiom = UIDevice.current.userInterfaceIdiom
        if idiom == .pad { return true }
        if #available(iOS 14.0, *) {
            return idiom == .mac
        }
        return false
    }

    // MARK: - Navigation Bar Setup
    /// Sets up navigation bar items including download and actions buttons
    private func setupNavigationBarItems() {
        // Create download button
        let downloadButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(downloadImage)
        )
        downloadButton.tintColor = .white

        // Create action menu button
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showActionsMenu)
        )
        menuButton.tintColor = .white

        navigationItem.rightBarButtonItems = [menuButton, downloadButton]
    }

    /// Shows actions menu for the current image
    @objc private func showActionsMenu() {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )

        // Crop action
        alertController.addAction(UIAlertAction(
            title: "Crop",
            style: .default,
            image: UIImage(systemName: "crop")
        ) { [weak self] _ in
            self?.presentCropController()
        })

        // Share action
        alertController.addAction(UIAlertAction(
            title: "Share",
            style: .default,
            image: UIImage(systemName: "square.and.arrow.up")
        ) { [weak self] _ in
            self?.shareImage()
        })

        // Copy Image action
        alertController.addAction(UIAlertAction(
            title: "Copy Image",
            style: .default,
            image: UIImage(systemName: "doc.on.doc")
        ) { [weak self] _ in
            self?.copyImageToClipboard()
        })

        // Reverse Image Search submenu
        alertController.addAction(UIAlertAction(
            title: "Reverse Image Search",
            style: .default,
            image: UIImage(systemName: "magnifyingglass")
        ) { [weak self] _ in
            guard let self = self else { return }
            ReverseImageSearchManager.shared.showSearchOptions(for: self.imageURL, from: self)
        })

        // Copy URL action
        alertController.addAction(UIAlertAction(
            title: "Copy Image URL",
            style: .default,
            image: UIImage(systemName: "link")
        ) { [weak self] _ in
            UIPasteboard.general.string = self?.imageURL.absoluteString
            self?.showToast("URL copied to clipboard")
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad support
        if let popover = alertController.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alertController, animated: true)
    }

    // MARK: - Double-Tap Zoom
    /// Sets up double-tap gesture for zoom toggle
    private func setupDoubleTapGesture() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }

    /// Handles double-tap gesture to toggle zoom
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard imageView.image != nil else { return }

        if isZoomedIn {
            // Zoom out to minimum scale
            UIView.animate(withDuration: 0.3) {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }
            isZoomedIn = false
        } else {
            // Zoom in to the tapped point
            let tapPoint = gesture.location(in: imageView)
            let zoomScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 3)

            // Calculate zoom rect centered on tap point
            let zoomWidth = scrollView.bounds.width / zoomScale
            let zoomHeight = scrollView.bounds.height / zoomScale
            let zoomRect = CGRect(
                x: tapPoint.x - zoomWidth / 2,
                y: tapPoint.y - zoomHeight / 2,
                width: zoomWidth,
                height: zoomHeight
            )

            UIView.animate(withDuration: 0.3) {
                self.scrollView.zoom(to: zoomRect, animated: false)
            }
            isZoomedIn = true
        }
    }

    // MARK: - Long Press Context Menu
    /// Sets up long press gesture for context menu
    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        scrollView.addGestureRecognizer(longPressGesture)
    }

    /// Handles long press gesture to show context menu
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        showActionsMenu()
    }

    // MARK: - Image Actions
    /// Downloads the current image to the app's documents folder
    @objc private func downloadImage() {
        if let editedImage = editedImage {
            saveEditedImageToDownloads(editedImage)
            return
        }

        if imageURL.isFileURL {
            showToast("Image already downloaded")
            return
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showToast("Unable to access downloads folder")
            return
        }

        let imagesDirectory = documentsDirectory.appendingPathComponent("images", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        } catch {
            showToast("Failed to create downloads folder")
            return
        }

        let destinationURL = imagesDirectory.appendingPathComponent(imageURL.lastPathComponent)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            showToast("Image already downloaded")
            return
        }

        Task {
            do {
                let request = makeDownloadRequest(for: imageURL)
                let (tempURL, response) = try await URLSession.shared.download(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        self.showToast("Failed to download image")
                    }
                    return
                }

                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                await MainActor.run {
                    self.showToast("Image downloaded")
                }
            } catch {
                await MainActor.run {
                    self.showToast("Download failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func makeDownloadRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        if let referer = refererString {
            request.setValue(referer, forHTTPHeaderField: "Referer")
            if let refererURL = URL(string: referer),
               let scheme = refererURL.scheme,
               let host = refererURL.host {
                let origin = "\(scheme)://\(host)"
                request.setValue(origin, forHTTPHeaderField: "Origin")
            }
        } else if url.host == "i.4cdn.org" {
            let components = url.pathComponents
            if components.count > 1 {
                let board = components[1]
                request.setValue("https://boards.4chan.org/\(board)/", forHTTPHeaderField: "Referer")
                request.setValue("https://boards.4chan.org", forHTTPHeaderField: "Origin")
            }
        } else if let scheme = url.scheme, let host = url.host {
            let origin = "\(scheme)://\(host)"
            request.setValue(origin + "/", forHTTPHeaderField: "Referer")
            request.setValue(origin, forHTTPHeaderField: "Origin")
        }

        return request
    }

    /// Shares the current image
    private func shareImage() {
        var itemsToShare: [Any] = []

        if let image = editedImage ?? imageView.image {
            itemsToShare.append(image)
        }
        if editedImage == nil {
            itemsToShare.append(imageURL)
        }

        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(activityVC, animated: true)
    }

    /// Copies the current image to clipboard
    private func copyImageToClipboard() {
        guard let image = editedImage ?? imageView.image else {
            showToast("No image to copy")
            return
        }

        UIPasteboard.general.image = image
        showToast("Image copied to clipboard")
    }

    /// Shows a toast message
    private func showToast(_ message: String) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            toastLabel.heightAnchor.constraint(equalToConstant: 35)
        ])

        // Add padding
        toastLabel.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0)

        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }

    private func presentCropController() {
        guard let image = imageView.image else {
            showToast("Image not loaded yet")
            return
        }

        let cropVC = ImageCropViewController(image: image) { [weak self] croppedImage in
            self?.handleCroppedImage(croppedImage)
        }
        navigationController?.pushViewController(cropVC, animated: true)
    }

    private func handleCroppedImage(_ image: UIImage) {
        editedImage = image
        imageView.image = image
        showToast("Cropped image ready")
    }

    private func saveEditedImageToDownloads(_ image: UIImage) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showToast("Unable to access downloads folder")
            return
        }

        let imagesDirectory = documentsDirectory.appendingPathComponent("images", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        } catch {
            showToast("Failed to create downloads folder")
            return
        }

        let baseName = imageURL.deletingPathExtension().lastPathComponent
        let safeBase = baseName.isEmpty ? "image" : baseName
        let filename = "\(safeBase)-cropped.jpg"
        let destinationURL = uniqueDestinationURL(in: imagesDirectory, filename: filename)

        guard let data = image.jpegData(compressionQuality: 0.92) ?? image.pngData() else {
            showToast("Failed to encode image")
            return
        }

        do {
            try data.write(to: destinationURL)
            showToast("Cropped image saved")
        } catch {
            showToast("Save failed: \(error.localizedDescription)")
        }
    }

    private func uniqueDestinationURL(in directory: URL, filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var candidate = directory.appendingPathComponent(filename)
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            let numberedName = "\(base)-\(index).\(ext)"
            candidate = directory.appendingPathComponent(numberedName)
            index += 1
        }

        return candidate
    }

    /// Loads the image from either local file or remote URL
    private func loadImage() {
        hasInitializedZoomScale = false
        isZoomedIn = false  // Reset zoom state when loading new image
        editedImage = nil

        if imageURL.isFileURL {
            // Local file - with HEIC/AVIF support
            print("DEBUG: ImageViewController - Loading local file: \(imageURL.path)")
            print("DEBUG: ImageViewController - File exists: \(FileManager.default.fileExists(atPath: imageURL.path))")

            if let image = loadLocalImage(from: imageURL) {
                print("DEBUG: ImageViewController - Successfully loaded image, size: \(image.size)")
                displayImage(image)
            } else {
                print("DEBUG: ImageViewController - Failed to load image from path: \(imageURL.path)")
            }
        } else {
            // Remote URL - use Kingfisher
            print("DEBUG: ImageViewController - Loading remote URL: \(imageURL)")
            activityIndicator.startAnimating()

            var options: KingfisherOptionsInfo = [
                .transition(.fade(0.2)),
                .cacheOriginalImage,
                .backgroundDecode  // Decode images in background for better performance
            ]

            // Add referer header if provided
            if let referer = refererString {
                let modifier = AnyModifier { request in
                    var r = request
                    r.setValue(referer, forHTTPHeaderField: "Referer")
                    return r
                }
                options.append(.requestModifier(modifier))
            }

            imageView.kf.setImage(with: imageURL, options: options) { [weak self] result in
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()

                switch result {
                case .success(let value):
                    print("DEBUG: ImageViewController - Successfully loaded remote image, size: \(value.image.size)")
                    self.displayImage(value.image)
                case .failure(let error):
                    print("DEBUG: ImageViewController - Failed to load remote image: \(error)")
                    // Show error state
                    self.showErrorState(error: error)
                }
            }
        }
    }

    /// Loads a local image with support for HEIC/AVIF formats
    private func loadLocalImage(from url: URL) -> UIImage? {
        let ext = url.pathExtension.lowercased()

        // Try standard UIImage first
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        // For HEIC/AVIF, try using ImageIO for better support
        if ext == "heic" || ext == "heif" || ext == "avif" {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldAllowFloat: true
            ]

            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }

        return nil
    }

    /// Shows an error state when image loading fails
    private func showErrorState(error: Error) {
        let errorLabel = UILabel()
        errorLabel.text = "Failed to load image"
        errorLabel.textColor = .gray
        errorLabel.textAlignment = .center
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// Displays the loaded image and updates scroll view
    private func displayImage(_ image: UIImage) {
        imageView.image = image
        imageView.sizeToFit()
        scrollView.contentSize = imageView.bounds.size
        updateZoomScaleForSize(scrollView.bounds.size)
        alignImageToTop()
        hasInitializedZoomScale = true
    }

    /// Sets up activity indicator for loading state
    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// Sets up swipe gestures for navigation between images
    private func setupSwipeGestures() {
        guard enableSwipes && imageURLs.count > 1 else { return }

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    /// Handles swipe gestures for navigation
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard imageURLs.count > 1 else { return }

        if gesture.direction == .left && currentIndex < imageURLs.count - 1 {
            currentIndex += 1
            imageURL = imageURLs[currentIndex]
            loadImage()
        } else if gesture.direction == .right && currentIndex > 0 {
            currentIndex -= 1
            imageURL = imageURLs[currentIndex]
            loadImage()
        }
    }
    
    /// Notifies the view controller that its view is about to be added to a view hierarchy.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the navigation bar appearance to black for this view.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .white
    }
    
    /// Notifies the view controller that its view is about to be removed from a view hierarchy.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Revert the navigation bar appearance to the default.
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = defaultAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = defaultAppearance
        navigationController?.navigationBar.compactAppearance = defaultAppearance
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = nil
    }
    
    /// Lays out subviews and initializes zoom scale if needed.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Only update zoom scale if image is already loaded and bounds have changed
        if hasInitializedZoomScale && imageView.image != nil {
            updateZoomScaleForSize(scrollView.bounds.size)
            alignImageToTop()
        }
    }
    
    // MARK: - UI Setup Methods
    /// Sets up the scroll view for zooming and panning.
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0  // Increased for better zoom capability
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    /// Sets up the image view inside the scroll view.
    private func setupImageView() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
    }
    
    // MARK: - Image Alignment
    /// Aligns the image to the top of the scroll view.
    private func alignImageToTop() {
        let scrollViewSize = scrollView.bounds.size
        let imageViewSize = imageView.frame.size

        // Calculate horizontal inset for centering.
        let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        
        // Set vertical inset to 0 to align at the top.
        scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: horizontalInset,
            bottom: 0,
            right: horizontalInset
        )
    }
    
    // MARK: - Zoom Handling Methods
    /// Updates the zoom scale based on the provided size.
    /// - Parameter size: The size to use for calculating the zoom scale.
    private func updateZoomScaleForSize(_ size: CGSize) {
        guard let image = imageView.image else { return }

        // Calculate scales to fit image in view.
        let widthScale = size.width / image.size.width
        let heightScale = size.height / image.size.height
        let minScale = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale // Reset zoom to minimum.

        // Align image at the top.
        alignImageToTop()
    }
    
    /// Asks the delegate for the view to scale when zooming is about to occur.
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    /// Tells the delegate that the scroll view's zoom factor changed.
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        alignImageToTop()

        // Update zoom state based on current scale
        let tolerance: CGFloat = 0.01
        isZoomedIn = abs(scrollView.zoomScale - scrollView.minimumZoomScale) > tolerance
    }
}

// MARK: - UIAlertAction Extension for Images
extension UIAlertAction {
    convenience init(title: String?, style: UIAlertAction.Style, image: UIImage?, handler: ((UIAlertAction) -> Void)? = nil) {
        self.init(title: title, style: style, handler: handler)
        self.setValue(image, forKey: "image")
    }
}
