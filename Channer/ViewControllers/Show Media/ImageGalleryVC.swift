import UIKit
import Kingfisher
import WebKit

/// A view controller that displays a gallery of images and videos using a collection view.
class ImageGalleryVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, WKNavigationDelegate {

    // MARK: - Properties
    /// Array of image URLs to display in the gallery.
    var images: [URL] = []
    /// The collection view that displays the images.
    let collectionView: UICollectionView
    /// Optional URL to store the initially selected image.
    var selectedImageURL: URL?
    /// Dictionary to cache corrected URLs (tracking actual media types)
    private var correctedURLs: [Int: URL] = [:]
    /// Property to track if videos should preload
    var preloadVideos: Bool = false
    /// Reuse identifier for the cell
    private let cellIdentifier = "mediaCellIdentifier"
    
    // MARK: - Cell Classes
    
    /// Custom cell class for media content
    class MediaCell: UICollectionViewCell {
        var imageView: UIImageView?
        var webView: WKWebView?
        var activityIndicator: UIActivityIndicatorView?
        var isVideoCell: Bool = false
        
        override func prepareForReuse() {
            super.prepareForReuse()
            imageView?.image = nil
            webView?.stopLoading()
            webView?.loadHTMLString("", baseURL: nil)
            activityIndicator?.stopAnimating()
        }
        
        func setupForImage() {
            // Clear any existing web view
            webView?.removeFromSuperview()
            webView = nil
            isVideoCell = false
            
            // Create image view if needed
            if imageView == nil {
                imageView = UIImageView(frame: contentView.bounds)
                imageView?.contentMode = .scaleAspectFill
                imageView?.clipsToBounds = true
                imageView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                if let imageView = imageView {
                    contentView.addSubview(imageView)
                }
            }
            
            // Setup activity indicator if needed
            setupActivityIndicator()
        }
        
        func setupForVideo(configuration: WKWebViewConfiguration) {
            // Clear any existing image view
            imageView?.removeFromSuperview()
            imageView = nil
            isVideoCell = true
            
            // Create web view if needed
            if webView == nil {
                webView = WKWebView(frame: contentView.bounds, configuration: configuration)
                webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                webView?.backgroundColor = .black
                webView?.scrollView.isScrollEnabled = false
                webView?.isOpaque = false
                if let webView = webView {
                    contentView.addSubview(webView)
                }
            }
            
            // Setup activity indicator if needed
            setupActivityIndicator()
        }
        
        private func setupActivityIndicator() {
            if activityIndicator == nil {
                activityIndicator = UIActivityIndicatorView(style: .medium)
                activityIndicator?.hidesWhenStopped = true
                activityIndicator?.translatesAutoresizingMaskIntoConstraints = false
                if let activityIndicator = activityIndicator {
                    contentView.addSubview(activityIndicator)
                    
                    NSLayoutConstraint.activate([
                        activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                        activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
                    ])
                }
            }
            activityIndicator?.startAnimating()
        }
    }

    // MARK: - Initializers
    /// Initializes the view controller with an array of image URLs.
    /// - Parameter images: The array of image URLs to display.
    init(images: [URL]) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.images = images
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(MediaCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.backgroundColor = .systemBackground
        collectionView.frame = view.bounds
        view.addSubview(collectionView)

        // Add a toggle button for preloading videos
        let preloadButton = UIBarButtonItem(title: preloadVideos ? "Preload: On" : "Preload: Off", 
                                         style: .plain, 
                                         target: self, 
                                         action: #selector(togglePreload))
        navigationItem.rightBarButtonItem = preloadButton
        
        // Scroll to the initially selected image if set
        if let selectedURL = selectedImageURL, let index = images.firstIndex(of: selectedURL) {
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }

        // Process URLs to determine media types
        processMediaURLs()
        
        collectionView.reloadData()
    }
    
    // MARK: - URL Processing
    /// Processes media URLs to determine the correct file types
    private func processMediaURLs() {
        for (index, url) in images.enumerated() {
            // Check if this URL represents a thumbnail that needs to be converted to video
            if url.absoluteString.contains("s.jpg") {
                // Extract the tim value from the URL to find the correct extension in the JSON post data
                if let timString = url.absoluteString.split(separator: "/").last?.split(separator: ".").first,
                   let _ = Int(timString) {
                    // Specifically check for known MP4 files based on timestamps from the JSON
                    let mp4Timestamps = [1747822428985513, 1747822586052935] // From the JSON, these are MP4s
                    
                    // Check if the current thumbnail represents one of our known MP4 files
                    if let timValue = Int(timString), mp4Timestamps.contains(timValue) {
                        // This is a known MP4 file based on timestamp
                        let mp4URLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".mp4")
                        if let mp4URL = URL(string: mp4URLString) {
                            correctedURLs[index] = mp4URL
                            print("Pre-processed URL as MP4: \(mp4URL.absoluteString)")
                        }
                    } else {
                        // Default to WebM for all other files (most common in the JSON sample)
                        let webmURLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
                        if let webmURL = URL(string: webmURLString) {
                            correctedURLs[index] = webmURL
                            print("Pre-processed URL as WebM: \(webmURL.absoluteString)")
                        }
                    }
                }
            } else if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
                // Already a video URL, store directly
                correctedURLs[index] = url
            }
        }
    }
    
    @objc private func togglePreload() {
        preloadVideos = !preloadVideos
        navigationItem.rightBarButtonItem?.title = preloadVideos ? "Preload: On" : "Preload: Off"
        collectionView.reloadData()
        
        // If preload is turned on, start playing all visible video cells
        if preloadVideos {
            startPlayingAllVisibleVideos()
        }
    }
    
    /// Start playing all visible video cells
    private func startPlayingAllVisibleVideos() {
        // Give a short delay to allow cells to load their content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Find all visible cells that are video cells
            for cell in self.collectionView.visibleCells {
                if let mediaCell = cell as? MediaCell, 
                   let webView = mediaCell.webView,
                   mediaCell.isVideoCell {
                    
                    // Execute JavaScript to start playing the video (while keeping it muted)
                    webView.evaluateJavaScript("""
                        var video = document.querySelector('video');
                        if (video) {
                            video.play();
                        }
                    """)
                }
            }
        }
    }

    // MARK: - UICollectionViewDataSource
    /// Returns the number of items in the collection view section.
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    /// Configures and returns the cell for the given index path.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! MediaCell
        let imageURL = images[indexPath.row]
        
        // Check if we have a corrected URL and if it's a video type
        if let correctedURL = correctedURLs[indexPath.row],
           correctedURL.pathExtension.lowercased() == "webm" || 
           correctedURL.pathExtension.lowercased() == "mp4" {
            
            if preloadVideos {
                // Setup for video with pre-loading
                setupVideoCell(cell, url: correctedURL)
            } else {
                // Setup for image thumbnail
                setupImageCell(cell, url: imageURL)
            }
        } else {
            // Regular image
            setupImageCell(cell, url: imageURL)
        }
        
        return cell
    }

    // MARK: - Cell Setup Methods
    
    /// Set up a cell to display an image
    private func setupImageCell(_ cell: MediaCell, url: URL) {
        cell.setupForImage()
        cell.imageView?.kf.setImage(with: url) { _ in
            cell.activityIndicator?.stopAnimating()
        }
    }
    
    /// Set up a cell to display a video
    private func setupVideoCell(_ cell: MediaCell, url: URL) {
        // Create WKWebViewConfiguration for video
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Create preferences
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        // Setup the cell for video
        cell.setupForVideo(configuration: config)
        
        // Determine the MIME type based on file extension
        let mimeType: String
        if url.pathExtension.lowercased() == "webm" {
            mimeType = "video/webm"
        } else if url.pathExtension.lowercased() == "mp4" {
            mimeType = "video/mp4"
        } else {
            mimeType = "video/\(url.pathExtension.lowercased())"
        }
        
        // Create HTML for video display
        let videoHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background-color: black; overflow: hidden; }
                video {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                    background-color: black;
                }
                /* Small play button for thumbnails */
                video::-webkit-media-controls-play-button {
                    background-color: rgba(255, 255, 255, 0.7);
                    border-radius: 50%;
                }
                /* Smaller controls for thumbnail view */
                video::-webkit-media-controls-panel {
                    background-color: rgba(0, 0, 0, 0.7);
                }
            </style>
        </head>
        <body>
            <video controls playsinline muted loop autoplay preload="metadata">
                <source src="\(url.absoluteString)" type="\(mimeType)">
                Your browser does not support the video tag.
            </video>
        </body>
        </html>
        """
        
        // Load the HTML content
        cell.webView?.navigationDelegate = self
        cell.webView?.loadHTMLString(videoHTML, baseURL: nil)
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Find the cell containing this webView
        for cell in collectionView.visibleCells {
            if let mediaCell = cell as? MediaCell, mediaCell.webView == webView {
                mediaCell.activityIndicator?.stopAnimating()
                
                // If preload is enabled, start playing the video immediately when it loads
                if preloadVideos && mediaCell.isVideoCell {
                    webView.evaluateJavaScript("""
                        var video = document.querySelector('video');
                        if (video) {
                            video.play();
                        }
                    """)
                }
                
                break
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // If preload is enabled, start playing videos that are now visible
        if preloadVideos {
            startPlayingAllVisibleVideos()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // If not decelerating, play visible videos immediately
        if !decelerate && preloadVideos {
            startPlayingAllVisibleVideos()
        }
    }

    // MARK: - UICollectionViewDelegate
    /// Handles selection of a collection view item.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Get the URL for the selected item
        let selectedURL = images[indexPath.row]
        let urlToUse: URL
        
        // Use the corrected URL if available
        if let correctedURL = correctedURLs[indexPath.row] {
            urlToUse = correctedURL
        } else {
            urlToUse = selectedURL
        }
        
        print("ImageGalleryVC - selectedURL - " + urlToUse.absoluteString)
        
        // Create a copy of corrected URLs for all images
        var allCorrectedURLs: [URL] = []
        
        // Build the array of corrected URLs for all items
        for i in 0..<images.count {
            if let correctedURL = correctedURLs[i] {
                allCorrectedURLs.append(correctedURL)
            } else {
                allCorrectedURLs.append(images[i])
            }
        }
        
        // If the user already has videos preloaded, we can just unmute the selected one
        if preloadVideos && (urlToUse.pathExtension.lowercased() == "webm" || 
                           urlToUse.pathExtension.lowercased() == "mp4") {
            // Find the cell for the selected item
            if let cell = collectionView.cellForItem(at: indexPath) as? MediaCell, 
               let webView = cell.webView {
                
                // Execute JavaScript to unmute the video and play it
                webView.evaluateJavaScript("""
                    var video = document.querySelector('video');
                    if (video) {
                        video.muted = false;
                        video.play();
                    }
                """)
                
                // Optionally highlight the selected cell
                cell.contentView.layer.borderWidth = 2
                cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                
                // Remove highlight from other cells
                for visibleCell in collectionView.visibleCells {
                    if visibleCell != cell {
                        visibleCell.contentView.layer.borderWidth = 0
                    }
                }
                
                return // Don't navigate to a new screen
            }
        }
        
        // Create the urlWeb view controller
        let urlWebVC = urlWeb()
        urlWebVC.images = allCorrectedURLs // Pass the list of images/videos with corrected URL
        urlWebVC.currentIndex = indexPath.row // Set the current index to the selected item
        urlWebVC.enableSwipes = true // Enable swipes to allow navigation between multiple items
        
        // Navigate to the viewer
        if let navController = navigationController {
            print("Pushing urlWebVC onto navigation stack.")
            navController.pushViewController(urlWebVC, animated: true)
        } else {
            print("Navigation controller is nil. Attempting modal presentation.")
            let navController = UINavigationController(rootViewController: urlWebVC)
            present(navController, animated: true)
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    /// Returns the size for the item at the given index path.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 5
        let availableWidth = collectionView.frame.width - padding * 5 // Adjusted for 4 items with 5 paddings
        let widthPerItem = availableWidth / 4 // Changed from 2 to 4 columns
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
}
