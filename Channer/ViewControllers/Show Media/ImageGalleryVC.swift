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
        collectionView.frame = view.bounds
        view.addSubview(collectionView)
        
        // Scroll to the initially selected image if set
        if let selectedURL = selectedImageURL, let index = images.firstIndex(of: selectedURL) {
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }

        // Process URLs to determine media types
        processMediaURLs()
        
        // Apply preload setting from UserDefaults
        if preloadVideos {
            applyPreloadSetting()
        } else {
            collectionView.reloadData()
        }
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
                // Extract ID from URL
                if let fileName = url.absoluteString.split(separator: "/").last {
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
                    var hasWebM = false
                    
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
                            hasWebM = true
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
        config.preferences.javaScriptEnabled = true
        
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
                    if (video && video.paused) {
                        video.play();
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
        // Get the original URL - let urlWeb handle format detection like thread view does
        let selectedURL = images[indexPath.row]
        
        print("ImageGalleryVC - selectedURL - " + selectedURL.absoluteString)
        
        // Pass original URLs directly to urlWeb like thread view does
        // This matches thread view's approach: thread view passes unprocessed URLs from JSON
        // and lets urlWeb handle format detection and playback
        let urlWebVC = urlWeb()
        urlWebVC.images = images // Pass all original URLs without processing
        urlWebVC.currentIndex = indexPath.row // Set the current index to the selected item
        urlWebVC.enableSwipes = true // Enable swipes to allow navigation between multiple items
        // If the media comes from i.4cdn.org, set a board-level referer to reduce 429s
        if let host = selectedURL.host, host == "i.4cdn.org" {
            let comps = selectedURL.pathComponents
            if comps.count > 1 {
                let board = comps[1]
                urlWebVC.refererString = "https://boards.4chan.org/\(board)/"
                print("Creating URLWeb with board referer: \(urlWebVC.refererString!)")
            }
        }
        
        print("Creating URLWeb view controller with \(images.count) original URLs (matching thread view approach)")
        
        // Add the urlWebVC to the navigation stack
        if let navController = navigationController {
            print("Pushing urlWebVC onto navigation stack from ImageGalleryVC - using thread view's approach with original URLs.")
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
