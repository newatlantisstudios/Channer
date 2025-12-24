import UIKit
import Kingfisher

/// A view controller that displays an image with zooming and panning capabilities.
/// Supports both local file URLs and remote HTTP/HTTPS URLs.
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

    /// Array of image URLs for navigation (optional)
    var imageURLs: [URL] = []
    /// Current index in the imageURLs array
    var currentIndex: Int = 0
    /// Enable swipe navigation between images
    var enableSwipes: Bool = true
    /// Optional referer string for remote image loading
    var refererString: String?

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

        loadImage()
    }

    /// Loads the image from either local file or remote URL
    private func loadImage() {
        hasInitializedZoomScale = false

        if imageURL.isFileURL {
            // Local file
            print("DEBUG: ImageViewController - Loading local file: \(imageURL.path)")
            print("DEBUG: ImageViewController - File exists: \(FileManager.default.fileExists(atPath: imageURL.path))")

            if let image = UIImage(contentsOfFile: imageURL.path) {
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
                .cacheOriginalImage
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
                }
            }
        }
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
        scrollView.maximumZoomScale = 3.0
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
    
    /// Tells the delegate that the scroll view’s zoom factor changed.
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        alignImageToTop()
    }
}
