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
    /// Currently selected index for highlighting
    private var selectedIndex: Int = 0
    /// Media counter label for navigation bar
    private lazy var mediaCounterLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    /// Dictionary to cache corrected URLs (tracking actual media types)
    private var correctedURLs: [Int: URL] = [:]
    /// Dictionary to cache alternate format URLs (for switching between formats)
    private var alternateURLs: [Int: URL] = [:]
    /// Property to track if videos should preload - reads from UserDefaults
    var preloadVideos: Bool {
        return UserDefaults.standard.bool(forKey: "channer_preload_videos_enabled")
    }
    /// Reuse identifier for the cell
    private let cellIdentifier = "mediaCellIdentifier"
    /// Maximum number of playing videos to limit memory usage
    private let maxPlayingVideos = 12
    /// Set to track currently playing video cells by their index paths
    private var playingVideoCells = Set<Int>()
    
    // MARK: - Cell Classes
    
    /// Custom cell class for media content
    class MediaCell: UICollectionViewCell {
        var imageView: UIImageView?
        var webView: WKWebView?
        var activityIndicator: UIActivityIndicatorView?
        var isVideoCell: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            // Make sure the cell can be tapped by setting these properties
            isUserInteractionEnabled = true
            contentView.isUserInteractionEnabled = true
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            
            isUserInteractionEnabled = true
            contentView.isUserInteractionEnabled = true
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            
            // Clean up existing content
            imageView?.image = nil
            webView?.stopLoading()
            webView?.loadHTMLString("", baseURL: nil)
            activityIndicator?.stopAnimating()
            
            // Reset any styling
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = nil
            contentView.backgroundColor = .clear
            contentView.layer.shadowOpacity = 0
            
            // Reset selection state
            setSelected(false, animated: false)
        }
        
        /// Updates the cell's selection state with visual feedback
        func setSelected(_ selected: Bool, animated: Bool = true) {
            let changes = {
                if selected {
                    self.contentView.layer.borderWidth = 3
                    self.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                    self.contentView.layer.cornerRadius = 8
                    self.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                    
                    // Add subtle shadow
                    self.contentView.layer.shadowColor = UIColor.systemBlue.cgColor
                    self.contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
                    self.contentView.layer.shadowOpacity = 0.3
                    self.contentView.layer.shadowRadius = 4
                } else {
                    self.contentView.layer.borderWidth = 0
                    self.contentView.layer.borderColor = nil
                    self.contentView.layer.cornerRadius = 4
                    self.contentView.backgroundColor = .clear
                    self.contentView.layer.shadowOpacity = 0
                }
            }
            
            if animated {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: changes)
            } else {
                changes()
            }
        }
        
        /// Adds hover effect for better user feedback
        func setHighlighted(_ highlighted: Bool, animated: Bool = true) {
            let changes = {
                if highlighted {
                    self.contentView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    self.contentView.alpha = 0.8
                } else {
                    self.contentView.transform = .identity
                    self.contentView.alpha = 1.0
                }
            }
            
            if animated {
                UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: changes)
            } else {
                changes()
            }
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
                imageView?.isUserInteractionEnabled = false // Don't let image view intercept touches
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
                
                // Critical for ensuring taps reach the collection view cell
                webView?.isUserInteractionEnabled = false
                
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
        
        // Use Auto Layout constraints instead of frame-based layout
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        // Pin collection view to all edges of the view
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Scroll to the initially selected image if set
        if let selectedURL = selectedImageURL, let index = images.firstIndex(of: selectedURL) {
            selectedIndex = index
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
        
        // Setup navigation bar with media counter
        setupNavigationBarWithCounter()

        // Process URLs to determine media types
        processMediaURLs()
        
        // Apply preload setting from UserDefaults
        if preloadVideos {
            applyPreloadSetting()
        } else {
            collectionView.reloadData()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(galleryCellSizeDidChange), name: .galleryCellSizeDidChange, object: nil)
    }

    @objc private func galleryCellSizeDidChange() {
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Invalidate the collection view layout on rotation to recalculate cell sizes
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
    
    // MARK: - Navigation Bar Setup
    /// Sets up the navigation bar with media counter
    private func setupNavigationBarWithCounter() {
        updateMediaCounter()
        navigationItem.titleView = mediaCounterLabel
    }
    
    /// Updates the media counter display
    private func updateMediaCounter() {
        let currentPosition = selectedIndex + 1
        mediaCounterLabel.text = "\(currentPosition) of \(images.count)"
    }
    
    // MARK: - URL Processing
    /// Processes media URLs to determine the correct file types
    private func processMediaURLs() {
        print("🔍 Processing \(images.count) media URLs to identify videos")
        
        // IMPORTANT: When preload is enabled, we'll convert ALL image URLs to potential video URLs
        // This ensures thumbnail images are tried as videos, which is what users expect
        let aggressiveConversion = true
        
        for (index, url) in images.enumerated() {
            print("🔍 URL \(index): \(url.absoluteString)")
            
            // Case 1: Direct video URL - use it directly
            if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
                correctedURLs[index] = url
                print("✅ Found direct video URL: \(url.absoluteString)")
                continue
            }
            
            // Case 2: Thumbnail with "s.jpg" pattern (common in imageboard APIs)
        if url.absoluteString.contains("s.jpg") {
            // Create both WebM and MP4 URLs to try - store both to try either format
            let webmString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
            let mp4String = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".mp4")
            
            var hasMP4 = false
            var hasWebM = false
            
            // Store MP4 URL if valid
            if let mp4URL = URL(string: mp4String) {
                // We're testing both formats and storing both - MP4 as primary if possible
                correctedURLs[index] = mp4URL
                hasMP4 = true
                print("✅ Storing MP4 URL: \(mp4URL.lastPathComponent)")
            }
            
            // Store WebM URL
            if let webmURL = URL(string: webmString) {
                // If we already have MP4, store WebM as alternate
                if hasMP4 {
                    alternateURLs[index] = webmURL
                    print("✅ Storing alternate WebM URL: \(webmURL.lastPathComponent)")
                } else {
                    // Otherwise use WebM as primary
                    correctedURLs[index] = webmURL
                    hasWebM = true
                    print("✅ Storing WebM URL: \(webmURL.lastPathComponent)")
                }
            }
            
            // If we found either format, continue to next URL
            if hasMP4 || hasWebM {
                continue
            }
        }
            
            // Case 3: Aggressive conversion of ANY image URL to a potential video URL
            if aggressiveConversion && (
                url.pathExtension.lowercased() == "jpg" || 
                url.pathExtension.lowercased() == "jpeg" || 
                url.pathExtension.lowercased() == "png" ||
                url.pathExtension.lowercased() == "gif") {
                
                // Generate both WebM and MP4 URLs to try
                let mp4String = url.absoluteString.replacingOccurrences(
                    of: ".\(url.pathExtension.lowercased())", 
                    with: ".mp4")
                
                let webmString = url.absoluteString.replacingOccurrences(
                    of: ".\(url.pathExtension.lowercased())", 
                    with: ".webm")
                
                var hasMP4 = false
                var hasWebM = false
                
                // Store MP4 URL if valid
                if let mp4URL = URL(string: mp4String) {
                    correctedURLs[index] = mp4URL
                    hasMP4 = true
                    print("🔄 Aggressive conversion to primary MP4: \(mp4URL.absoluteString)")
                }
                
                // Store WebM format
                if let webmURL = URL(string: webmString) {
                    if hasMP4 {
                        // Store as alternate if we already have MP4
                        alternateURLs[index] = webmURL
                        print("🔄 Aggressive conversion to alternate WebM: \(webmURL.absoluteString)")
                    } else {
                        // Otherwise use as primary
                        correctedURLs[index] = webmURL
                        hasWebM = true
                        print("🔄 Aggressive conversion to primary WebM: \(webmURL.absoluteString)")
                    }
                }
                
                // If we found either format, continue to next URL
                if hasMP4 || hasWebM {
                    continue
                }
            }
        }
        
        // Summary of processed URLs
        print("📊 Processed URLs: Found \(correctedURLs.count) video URLs out of \(images.count) total URLs")
        
        // If we still don't have any video URLs, use a desperate approach
        if correctedURLs.isEmpty && !images.isEmpty {
            print("⚠️ No video URLs found - using desperate fallback approach")
            
            // Force ALL images to be treated as potential video files (both MP4 and WebM)
            for (index, url) in images.enumerated() {
                if let lastPathComponent = url.absoluteString.split(separator: "/").last {
                    var hasMP4 = false
                    
                    // Try MP4
                    let mp4String = url.absoluteString.replacingOccurrences(
                        of: String(lastPathComponent),
                        with: "\(lastPathComponent).mp4")
                    
                    if let mp4URL = URL(string: mp4String) {
                        correctedURLs[index] = mp4URL
                        hasMP4 = true
                        print("⚠️ Desperate primary MP4 conversion: \(mp4URL.absoluteString)")
                    }
                    
                    // Also try WebM
                    let webmString = url.absoluteString.replacingOccurrences(
                        of: String(lastPathComponent),
                        with: "\(lastPathComponent).webm")
                    
                    if let webmURL = URL(string: webmString) {
                        if hasMP4 {
                            // Store as alternate if we already have MP4
                            alternateURLs[index] = webmURL
                            print("⚠️ Desperate alternate WebM conversion: \(webmURL.absoluteString)")
                        } else {
                            // Otherwise use as primary
                            correctedURLs[index] = webmURL
                            print("⚠️ Desperate primary WebM conversion: \(webmURL.absoluteString)")
                        }
                    }
                }
            }
            
            // After fallback, print summary again
            print("📊 After desperate fallback: Found \(correctedURLs.count) primary videos and \(alternateURLs.count) alternate videos out of \(images.count) total URLs")
        }
    }
    
    // This method is no longer needed as preloadVideos is now a computed property
    // that reads from UserDefaults. The setting is now controlled in the settings screen.
    // We're keeping the implementation as a helper method with a different name
    // in case it needs to be called when UserDefaults change
    private func applyPreloadSetting() {
        print("🔄 Preload setting applied: \(preloadVideos ? "ON" : "OFF")")
        
        // Process images to ensure we have video URLs
        if preloadVideos && correctedURLs.isEmpty {
            // Force detection of video URLs before reloading cells
            processMediaURLs()
        }
        
        // Clear tracking
        playingVideoCells.removeAll()
        
        // Always reload all cells to change their type
        UIView.performWithoutAnimation {
            collectionView.reloadData()
        }
        
        // Ensure we start playing videos if needed
        if preloadVideos {
            print("▶️ Starting playback of visible videos")
            
            // Add a delay to ensure cells are properly loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Start playing videos
                for cell in self.collectionView.visibleCells {
                    if let mediaCell = cell as? MediaCell, let webView = mediaCell.webView {
                        // Force video playback via JS
                        webView.evaluateJavaScript("""
                            if (document.querySelector('video')) {
                                var video = document.querySelector('video');
                                video.muted = true;
                                video.play();
                                console.log('Starting video via explicit JS call');
                            }
                        """)
                    }
                }
            }
        }
    }
    
    /// Start playing all visible video cells
    private func startPlayingAllVisibleVideos() {
        // This is now a simple wrapper around the scroll-based function
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkVisibleVideosAfterScroll()
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
        
        print("📱 Configuring cell at index \(indexPath.row)")
        
        // Update selection state
        cell.setSelected(indexPath.row == selectedIndex, animated: false)
        
        // Simplified approach: Treat all cells as potential videos in preload mode
        if preloadVideos {
            // Choose URL based on correctness map or fallback
            var videoURL = imageURL
            
            // Tag the cell with its index FIRST so setupVideoCell can use it
            cell.tag = indexPath.row
            
            // If we have a corrected URL, use it
            if let correctedURL = correctedURLs[indexPath.row] {
                videoURL = correctedURL
                print("🎬 Using corrected video URL for cell \(indexPath.row): \(videoURL.lastPathComponent)")
                
                // Check if we have an alternate URL too
                if let alternateURL = alternateURLs[indexPath.row] {
                    print("🔄 Also have alternate URL for cell \(indexPath.row): \(alternateURL.lastPathComponent)")
                }
            } 
            // If not, try to create one by substituting extensions
            else if videoURL.pathExtension.lowercased() == "jpg" || 
                    videoURL.pathExtension.lowercased() == "jpeg" || 
                    videoURL.pathExtension.lowercased() == "png" {
                // Try both formats - MP4 first then WebM
                let potentialMP4URL = URL(string: videoURL.absoluteString.replacingOccurrences(
                    of: "." + videoURL.pathExtension, with: ".mp4"))
                
                let potentialWebmURL = URL(string: videoURL.absoluteString.replacingOccurrences(
                    of: "." + videoURL.pathExtension, with: ".webm"))
                
                if let mp4URL = potentialMP4URL {
                    videoURL = mp4URL
                    correctedURLs[indexPath.row] = mp4URL // Store MP4 as primary
                    print("🎬 Created primary MP4 URL: \(videoURL.lastPathComponent)")
                    
                    // Also store WebM as alternate if available
                    if let webmURL = potentialWebmURL {
                        alternateURLs[indexPath.row] = webmURL
                        print("🎬 Created alternate WebM URL: \(webmURL.lastPathComponent)")
                    }
                }
                else if let webmURL = potentialWebmURL {
                    videoURL = webmURL
                    correctedURLs[indexPath.row] = webmURL // Store WebM as primary
                    print("🎬 Created primary WebM URL: \(videoURL.lastPathComponent)")
                }
            }
            
            print("▶️ Setting up video cell for index \(indexPath.row)")
            
            // Setup cell for video with both primary and alternate URLs
            setupVideoCell(cell, url: videoURL)
            
            // Add to playing videos tracking
            playingVideoCells.insert(indexPath.row)
        } 
        // Non-preload mode - use regular image cells
        else {
            print("🖼️ Using image cell for index \(indexPath.row)")
            setupImageCell(cell, url: imageURL)
        }
        
        return cell
    }

    // MARK: - Cell Setup Methods
    
    /// Set up a cell to display an image
    private func setupImageCell(_ cell: MediaCell, url: URL) {
        cell.setupForImage()
        
        // For video files, display thumbnail but keep original URL for playback
        var displayURL = url
        if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
            // Convert to thumbnail URL for display in gallery grid
            let components = url.absoluteString.components(separatedBy: "/")
            if let last = components.last {
                let fileExtension = url.pathExtension.lowercased()
                let base = last.replacingOccurrences(of: ".\(fileExtension)", with: "")
                if let thumbnailURL = URL(string: url.absoluteString.replacingOccurrences(of: last, with: "\(base)s.jpg")) {
                    displayURL = thumbnailURL
                    print("Using thumbnail for display: \(thumbnailURL.absoluteString)")
                }
            }
        }
        
        cell.imageView?.kf.setImage(with: displayURL) { _ in
            cell.activityIndicator?.stopAnimating()
        }
    }
    
    /// Set up a cell to display a video - simpler, more reliable approach
    private func setupVideoCell(_ cell: MediaCell, url: URL) {
        print("🎬 Setting up video cell for URL: \(url.absoluteString)")
        
        // Get the cell index from tag
        let cellIndex = cell.tag
        
        // Check if we have an alternate URL for this cell
        var alternateURL: URL? = nil
        if cellIndex >= 0 {
            alternateURL = alternateURLs[cellIndex]
            if let altURL = alternateURL {
                print("🔄 Found alternate URL for cell \(cellIndex): \(altURL.absoluteString)")
            }
        }
        
        // Create WKWebViewConfiguration for video
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [] // Allow videos to play without user interaction
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Ensure the cell is properly configured for video
        cell.setupForVideo(configuration: config)
        
        // Simplify MIME type detection
        let fileExtension = url.pathExtension.lowercased()
        let primaryMimeType: String
        
        if fileExtension == "webm" {
            primaryMimeType = "video/webm"
        } else if fileExtension == "mp4" {
            primaryMimeType = "video/mp4"
        } else {
            primaryMimeType = "video/\(fileExtension)"
        }
        
        // Determine the alternate MIME type if we have an alternate URL
        var alternateMimeType: String = ""
        if let altURL = alternateURL {
            let altExtension = altURL.pathExtension.lowercased()
            if altExtension == "webm" {
                alternateMimeType = "video/webm"
            } else if altExtension == "mp4" {
                alternateMimeType = "video/mp4"
            } else {
                alternateMimeType = "video/\(altExtension)"
            }
        }
        
        print("🎬 Using primary MIME type: \(primaryMimeType)")
        if !alternateMimeType.isEmpty {
            print("🎬 Using alternate MIME type: \(alternateMimeType)")
        }
        
        // Create HTML that includes both sources if available
        let alternateSourceTag = alternateURL != nil ? 
            "<source src=\"\(alternateURL!.absoluteString)\" type=\"\(alternateMimeType)\">" : ""
        
        // Create a much simpler and more reliable HTML for video display with fallback support
        let videoHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body, html { 
                    margin: 0; 
                    padding: 0; 
                    width: 100%; 
                    height: 100%; 
                    background: #000; 
                    overflow: hidden;
                }
                video {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                    background: #000;
                }
                .error-msg {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: white;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    background: rgba(0,0,0,0.7);
                    padding: 10px;
                    border-radius: 5px;
                    display: none;
                }
            </style>
        </head>
        <body>
            <video autoplay loop muted playsinline webkit-playsinline>
                <source src="\(url.absoluteString)" type="\(primaryMimeType)">
                \(alternateSourceTag)
                Your browser does not support the video tag.
            </video>
            
            <div class="error-msg" id="errorMsg">Error loading video</div>
            
            <script>
                // Get video element and force autoplay
                var video = document.querySelector('video');
                var errorMsg = document.getElementById('errorMsg');
                
                // Function to ensure video plays
                function ensureVideoPlays() {
                    if(video && video.paused) {
                        console.log("Starting video playback");
                        video.muted = true;
                        video.play().catch(function(e) {
                            console.log("Error playing video: " + e);
                            setTimeout(ensureVideoPlays, 200);
                        });
                    }
                }
                
                // Try to play video immediately
                ensureVideoPlays();
                
                // Also try after a short delay to handle edge cases
                setTimeout(ensureVideoPlays, 100);
                setTimeout(ensureVideoPlays, 500);
                setTimeout(ensureVideoPlays, 1000);
                
                // Keep checking that video plays
                setInterval(ensureVideoPlays, 2000);
                
                // Handle video events
                video.addEventListener('loadeddata', function() {
                    console.log("Video loaded");
                    ensureVideoPlays();
                    errorMsg.style.display = 'none';
                });
                
                video.addEventListener('canplay', function() {
                    console.log("Video can play");
                    ensureVideoPlays();
                    errorMsg.style.display = 'none';
                });
                
                video.addEventListener('play', function() {
                    console.log("Video started playing");
                    errorMsg.style.display = 'none';
                });
                
                video.addEventListener('pause', function() {
                    console.log("Video paused");
                    ensureVideoPlays();
                });
                
                video.addEventListener('ended', function() {
                    console.log("Video ended");
                    ensureVideoPlays();
                });
                
                video.addEventListener('error', function(e) {
                    console.log("Video error: " + e);
                    errorMsg.style.display = 'block';
                    
                    // Try switching source order if there are multiple sources
                    if (video.querySelectorAll('source').length > 1) {
                        var sources = Array.from(video.querySelectorAll('source'));
                        // Move the second source to be first
                        video.insertBefore(sources[1], sources[0]);
                        // Reload video to try the other source
                        video.load();
                        setTimeout(ensureVideoPlays, 200);
                    }
                });
            </script>
        </body>
        </html>
        """
        
        // Load HTML directly
        cell.webView?.navigationDelegate = self
        cell.webView?.loadHTMLString(videoHTML, baseURL: nil)
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🌐 WebView finished loading HTML")
        
        // Find the cell containing this webView
        for cell in collectionView.visibleCells {
            if let mediaCell = cell as? MediaCell, mediaCell.webView == webView {
                // Stop activity indicator
                mediaCell.activityIndicator?.stopAnimating()
                
                // Get the index path for this cell if possible
                if let indexPath = collectionView.indexPath(for: cell) {
                    print("🎬 WebView loaded at index \(indexPath.row)")
                    
                    // Add to tracking set when navigation completes
                    if preloadVideos {
                        playingVideoCells.insert(indexPath.row)
                    }
                }
                
                // If preload is enabled, ensure video plays
                if preloadVideos {
                    // Use a simple JavaScript to force play
                    webView.evaluateJavaScript("""
                    var video = document.querySelector('video');
                    if (video) {
                        video.muted = true;
                        video.loop = true;
                        video.play();
                        
                        // Also try with a slight delay (sometimes helps with browser quirks)
                        setTimeout(function() {
                            video.play();
                        }, 250);
                    }
                    """)
                }
                
                break
            }
        }
    }
    
    // Simple error handling for WebView
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView navigation failed: \(error.localizedDescription)")
        handleWebViewError(webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
        handleWebViewError(webView)
    }
    
    // Helper to handle WebView errors
    private func handleWebViewError(_ webView: WKWebView) {
        // Find the cell containing this webView
        for cell in collectionView.visibleCells {
            if let mediaCell = cell as? MediaCell, mediaCell.webView == webView {
                // Stop activity indicator
                mediaCell.activityIndicator?.stopAnimating()
                
                // If in preload mode, try to recover by showing the image instead
                if preloadVideos, let indexPath = collectionView.indexPath(for: cell) {
                    // Try to show image instead
                    if indexPath.row < images.count {
                        let imageURL = images[indexPath.row]
                        setupImageCell(mediaCell, url: imageURL)
                    }
                }
                
                break
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // When scrolling stops, play all visible videos if preload is enabled
        if preloadVideos {
            checkVisibleVideosAfterScroll()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // When user stops dragging, play videos if preload is enabled
        if !decelerate && preloadVideos {
            checkVisibleVideosAfterScroll()
        }
    }
    
    // Add continuous scrolling detection for smoother video loading
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // During scrolling, debounce the check for new visible cells
        if preloadVideos {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkVisibleVideosAfterScroll), object: nil)
            perform(#selector(checkVisibleVideosAfterScroll), with: nil, afterDelay: 0.1)
        }
    }
    
    @objc private func checkVisibleVideosAfterScroll() {
        // When scrolling changes visible cells, make sure videos are playing
        guard preloadVideos else { return }
        
        // Get all currently visible cells
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? MediaCell }
        print("👀 There are \(visibleCells.count) visible cells")
        
        // Make sure all visible video cells are playing
        for cell in visibleCells {
            if cell.isVideoCell, let webView = cell.webView {
                // Use simple JavaScript to ensure video is playing
                webView.evaluateJavaScript("""
                    var video = document.querySelector('video');
                    if (video) {
                        video.muted = true;
                        video.volume = 0;
                        if (video.paused) {
                            video.play();
                        }
                    }
                """)
                
                // Track this cell if we have its index path
                if let indexPath = collectionView.indexPath(for: cell) {
                    playingVideoCells.insert(indexPath.row)
                }
            }
            // If cell isn't yet a video cell but should be (like if we're reusing a cell)
            else if !cell.isVideoCell {
                if let indexPath = collectionView.indexPath(for: cell),
                   indexPath.row < images.count {
                    
                    var videoURL = images[indexPath.row]
                    
                    // Check if we have a corrected URL for this index
                    if let correctedURL = correctedURLs[indexPath.row] {
                        videoURL = correctedURL
                    }
                    
                    // If this should be a video (based on user toggling preload on), set it up
                    if preloadVideos {
                        setupVideoCell(cell, url: videoURL)
                        
                        // Track this cell
                        playingVideoCells.insert(indexPath.row)
                    }
                }
            }
        }
        
        // We don't need to pause non-visible videos - WebKit will suspend non-visible WebViews automatically
        // The operating system will manage memory for us
    }

    // MARK: - UICollectionViewDelegate
    /// Handles selection of a collection view item.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Update selected index and refresh counter
        let previousIndex = selectedIndex
        selectedIndex = indexPath.row
        updateMediaCounter()

        // Update cell selection states
        if let previousCell = collectionView.cellForItem(at: IndexPath(row: previousIndex, section: 0)) as? MediaCell {
            previousCell.setSelected(false, animated: true)
        }
        if let currentCell = collectionView.cellForItem(at: indexPath) as? MediaCell {
            currentCell.setSelected(true, animated: true)
        }

        let selectedURL = images[indexPath.row]
        let fileExtension = selectedURL.pathExtension.lowercased()

        print("ImageGalleryVC - selectedURL - " + selectedURL.absoluteString)
        print("ImageGalleryVC - fileExtension - " + fileExtension)

        // Derive referer from URL for 4chan
        var refererString: String? = nil
        if let host = selectedURL.host, host == "i.4cdn.org" {
            let comps = selectedURL.pathComponents
            if comps.count > 1 {
                let board = comps[1]
                refererString = "https://boards.4chan.org/\(board)/"
            }
        }

        if fileExtension == "webm" || fileExtension == "mp4" {
            // Use WebMViewController for video playback (same as Downloaded view)
            print("ImageGalleryVC - Opening video with WebMViewController")

            // Get all video URLs for navigation
            let videoURLs = images.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "webm" || ext == "mp4"
            }

            // Find the index of the selected video in the filtered list
            let selectedVideoIndex = videoURLs.firstIndex(of: selectedURL) ?? 0

            let vlcVC = WebMViewController()
            vlcVC.videoURL = selectedURL.absoluteString
            vlcVC.videoURLs = videoURLs
            vlcVC.currentIndex = selectedVideoIndex

            if let navController = navigationController {
                navController.pushViewController(vlcVC, animated: true)
            } else {
                let navController = UINavigationController(rootViewController: vlcVC)
                present(navController, animated: true)
            }
        } else if fileExtension == "gif" {
            // Use urlWeb for GIFs (WKWebView handles animation properly)
            print("ImageGalleryVC - Opening GIF with urlWeb for animation support")

            let urlWebVC = urlWeb()
            urlWebVC.images = images
            urlWebVC.currentIndex = indexPath.row
            urlWebVC.enableSwipes = true
            urlWebVC.refererString = refererString

            if let navController = navigationController {
                navController.pushViewController(urlWebVC, animated: true)
            } else {
                let navController = UINavigationController(rootViewController: urlWebVC)
                present(navController, animated: true)
            }
        } else {
            // Use ImageViewController for JPG/PNG images (same as Downloaded view)
            // This provides proper zoom/pan functionality
            print("ImageGalleryVC - Opening image with ImageViewController")

            // Get all image URLs for navigation (excluding videos and GIFs)
            let imageURLs = images.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "jpg" || ext == "jpeg" || ext == "png"
            }

            // Find the index of the selected image in the filtered list
            let selectedImageIndex = imageURLs.firstIndex(of: selectedURL) ?? 0

            let imageVC = ImageViewController(imageURL: selectedURL)
            imageVC.imageURLs = imageURLs
            imageVC.currentIndex = selectedImageIndex
            imageVC.enableSwipes = imageURLs.count > 1
            imageVC.refererString = refererString

            if let navController = navigationController {
                navController.pushViewController(imageVC, animated: true)
            } else {
                let navController = UINavigationController(rootViewController: imageVC)
                present(navController, animated: true)
            }
        }
    }
    
    /// Handles cell highlighting for touch feedback
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? MediaCell {
            cell.setHighlighted(true, animated: true)
        }
    }
    
    /// Handles removing cell highlighting
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? MediaCell {
            cell.setHighlighted(false, animated: true)
        }
    }

    // MARK: - Context Menu Configuration
    /// Provides context menu for collection view items
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let imageURL = images[indexPath.row]

        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return nil }

            var actions: [UIMenuElement] = []

            // Save Image action
            let saveAction = UIAction(
                title: "Save Image",
                image: UIImage(systemName: "square.and.arrow.down")
            ) { _ in
                self.saveImage(at: indexPath)
            }
            actions.append(saveAction)

            // Share action
            let shareAction = UIAction(
                title: "Share",
                image: UIImage(systemName: "square.and.arrow.up")
            ) { _ in
                self.shareImage(at: indexPath)
            }
            actions.append(shareAction)

            // Copy Image URL action
            let copyURLAction = UIAction(
                title: "Copy Image URL",
                image: UIImage(systemName: "link")
            ) { _ in
                UIPasteboard.general.string = imageURL.absoluteString
            }
            actions.append(copyURLAction)

            // Reverse Image Search submenu
            let reverseSearchMenu = ReverseImageSearchManager.shared.createSearchMenu(for: imageURL)
            actions.append(reverseSearchMenu)

            return UIMenu(title: "", children: actions)
        }
    }

    /// Saves the image at the given index path to Photos
    private func saveImage(at indexPath: IndexPath) {
        let imageURL = images[indexPath.row]

        // Check if image has already been saved to Photos
        if DownloadedMediaTracker.shared.hasBeenSavedToPhotos(url: imageURL) {
            showToast("This image has already been saved to Photos")
            return
        }

        // Get the cell to access the image
        if let cell = collectionView.cellForItem(at: indexPath) as? MediaCell,
           let image = cell.imageView?.image {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            DownloadedMediaTracker.shared.markAsSavedToPhotos(url: imageURL)
            showToast("Image saved to Photos")
        } else {
            // Download and save if not already loaded
            downloadAndSaveImage(url: imageURL)
        }
    }

    /// Downloads and saves an image from URL
    private func downloadAndSaveImage(url: URL) {
        // Check if image has already been saved to Photos
        if DownloadedMediaTracker.shared.hasBeenSavedToPhotos(url: url) {
            showToast("This image has already been saved to Photos")
            return
        }

        Task {
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

                // Add 4chan-specific headers
                if let host = url.host, host == "i.4cdn.org" {
                    let pathComponents = url.pathComponents
                    if pathComponents.count > 1 {
                        let board = pathComponents[1]
                        request.setValue("https://boards.4chan.org/\(board)/", forHTTPHeaderField: "Referer")
                    }
                }

                let (data, _) = try await URLSession.shared.data(for: request)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        DownloadedMediaTracker.shared.markAsSavedToPhotos(url: url)
                        self.showToast("Image saved to Photos")
                    }
                }
            } catch {
                await MainActor.run {
                    self.showToast("Failed to save image")
                }
            }
        }
    }

    /// Shares the image at the given index path
    private func shareImage(at indexPath: IndexPath) {
        let imageURL = images[indexPath.row]

        // If the image is already loaded in the cell, share it directly
        if let cell = collectionView.cellForItem(at: indexPath) as? MediaCell,
           let image = cell.imageView?.image {
            presentShareSheet(with: image, sourceIndexPath: indexPath)
        } else {
            // Download the image first, then share
            Task {
                do {
                    var request = URLRequest(url: imageURL)
                    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

                    if let host = imageURL.host, host == "i.4cdn.org" {
                        let pathComponents = imageURL.pathComponents
                        if pathComponents.count > 1 {
                            let board = pathComponents[1]
                            request.setValue("https://boards.4chan.org/\(board)/", forHTTPHeaderField: "Referer")
                        }
                    }

                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.presentShareSheet(with: image, sourceIndexPath: indexPath)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showToast("Failed to load image for sharing")
                    }
                }
            }
        }
    }

    /// Presents the share sheet with the given image
    private func presentShareSheet(with image: UIImage, sourceIndexPath: IndexPath) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        // iPad support
        if let popover = activityVC.popoverPresentationController {
            if let cell = collectionView.cellForItem(at: sourceIndexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }

        present(activityVC, animated: true)
    }

    /// Shows a toast message
    private func showToast(_ message: String) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.text = "  \(message)  "
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            toastLabel.heightAnchor.constraint(equalToConstant: 35)
        ])

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

    // MARK: - UICollectionViewDelegateFlowLayout
    /// Returns the size for the item at the given index path.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 5
        let columns = GalleryCellSizeManager.shared.columns
        let availableWidth = collectionView.frame.width - padding * (columns + 1)
        let widthPerItem = availableWidth / columns
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    // MARK: - Navigation Updates
    /// Updates gallery state when returning from full-screen view
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Restore navigation bar appearance from theme when returning from media viewers
        // Media viewers (WebMViewController, ImageViewController, urlWeb) set black nav bar
        // and reset to "default" which doesn't match the app's theme
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = ThemeManager.shared.backgroundColor
        appearance.titleTextAttributes = [.foregroundColor: ThemeManager.shared.primaryTextColor]

        // Animate the navigation bar color transition
        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.navigationController?.navigationBar.standardAppearance = appearance
                self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
                self.navigationController?.navigationBar.compactAppearance = appearance
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.navigationBar.tintColor = nil
            }, completion: nil)
        } else {
            // Fallback if no transition coordinator (e.g., not during navigation)
            UIView.animate(withDuration: 0.3) {
                self.navigationController?.navigationBar.standardAppearance = appearance
                self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
                self.navigationController?.navigationBar.compactAppearance = appearance
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.navigationBar.tintColor = nil
            }
        }

        // Refresh the selection state when returning from urlWeb
        collectionView.reloadData()
        updateMediaCounter()
    }
}
