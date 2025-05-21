import UIKit
import WebKit
import AVKit

class urlWeb: UIViewController {

    // MARK: - Properties
    // Array of image URLs to display
    var images: [URL] = []

    // Current index in the images array
    var currentIndex: Int = 0

    // Property to enable or disable swipes
    var enableSwipes: Bool = true
    
    // Fallback URL to try if the first URL fails
    private var fallbackURL: URL? = nil

    // Lazy-loaded web view for displaying web content
    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        
        // Configure for optimal video playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        // Enable all available media playback types
        if #available(iOS 14.0, *) {
            config.limitsNavigationsToAppBoundDomains = false
        }
        
        // Add video-specific preferences
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        // Create the web view with the enhanced configuration
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .black
        
        return webView
    }()

    // View to display video content
    private lazy var videoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()

    // Media player for playing videos using AVPlayer
    private lazy var avPlayer: AVPlayer = {
        let player = AVPlayer()
        // Configure AVPlayer for better streaming performance
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true
        return player
    }()
    
    private lazy var playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer(player: avPlayer)
        // Use resizeAspect instead of resizeAspectFill to avoid cropping
        layer.videoGravity = .resizeAspect
        return layer
    }()

    // Activity indicator to show loading status
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Lifecycle Methods
    /// Called after the controller's view is loaded into memory
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadContent()
        setupNavigationBar()
        
        print("enableSwipes \(enableSwipes)")

        // Set navigation bar appearance to black
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .white // Update button colors
        
        // Add swipe gestures only if enabled and there are multiple images
        if enableSwipes && images.count > 1 {
            let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeLeft.direction = .left
            view.addGestureRecognizer(swipeLeft)

            let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeRight.direction = .right
            view.addGestureRecognizer(swipeRight)
        }
    }

    /// Notifies the view controller that its view is about to be removed from a view hierarchy
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Reset navigation bar to default appearance when leaving this view controller
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = defaultAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = defaultAppearance
        navigationController?.navigationBar.compactAppearance = defaultAppearance
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = nil // Reset button color to default
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update player layer frame when view layout changes
        playerLayer.frame = videoView.bounds
    }
    
    // Called when video playback finishes
    @objc func playerItemDidReachEnd(notification: Notification) {
        // Automatically move to the next content if video is finished playing
        if currentIndex < images.count - 1 {
            currentIndex += 1
            loadContent()
        }
    }

    // MARK: - UI Setup
    /// Sets up the user interface elements
    private func setupUI() {
        view.backgroundColor = .black

        // Add subviews
        view.addSubview(webView)
        view.addSubview(videoView)
        view.addSubview(activityIndicator)

        // Setup constraints for webView, videoView, and activityIndicator
        NSLayoutConstraint.activate([
            // WebView constraints
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // VideoView constraints
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ActivityIndicator constraints
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Initially hide the video view
        videoView.isHidden = true
    }

    /// Configures the navigation bar appearance and adds buttons
    private func setupNavigationBar() {
        // Remove default back button text
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        // Add download button to navigation bar
        let downloadButton = UIBarButtonItem(image: UIImage(named: "downloadWV"),
                                             style: .plain,
                                             target: self,
                                             action: #selector(downloadData))
        navigationItem.rightBarButtonItem = downloadButton
    }

    // MARK: - Content Loading
    /// Loads the content based on the current index
    private func loadContent() {
        guard currentIndex >= 0 && currentIndex < images.count else {
            showAlert(title: "Error", message: "Invalid index")
            return
        }

        var url = images[currentIndex]
        print("loadContent url: \(url)")

        // If the URL ends with "s.jpg", replace it with the correct extension based on known timestamps
        if url.absoluteString.hasSuffix("s.jpg") {
            // Extract the timestamp value from the URL
            if let timestampStr = url.absoluteString.split(separator: "/").last?.split(separator: "s").first,
               let timestamp = Int(timestampStr) {
                
                // These are known MP4 files based on the JSON data
                let mp4Timestamps = [1747822428985513, 1747822586052935] // From the JSON, these are MP4s
                
                // Determine the correct extension based on the timestamp
                if mp4Timestamps.contains(timestamp) {
                    // This is a known MP4 file
                    let mp4URLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".mp4")
                    if let mp4URL = URL(string: mp4URLString) {
                        url = mp4URL
                        print("Using MP4 URL for known timestamp: \(mp4URL.absoluteString)")
                        
                        // Store the webm URL as a fallback just in case
                        let webmURLString = url.absoluteString.replacingOccurrences(of: ".mp4", with: ".webm")
                        if let webmURL = URL(string: webmURLString) {
                            self.fallbackURL = webmURL
                            print("Stored WebM fallback URL: \(webmURL.absoluteString)")
                        }
                    }
                } else {
                    // All other files should be WebM based on the JSON sample
                    let webmURLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
                    if let webmURL = URL(string: webmURLString) {
                        url = webmURL
                        print("Using WebM URL for timestamp: \(webmURL.absoluteString)")
                        
                        // Store MP4 URL as fallback
                        let mp4URLString = url.absoluteString.replacingOccurrences(of: ".webm", with: ".mp4")
                        if let mp4URL = URL(string: mp4URLString) {
                            self.fallbackURL = mp4URL
                            print("Stored MP4 fallback URL: \(mp4URL.absoluteString)")
                        }
                    }
                }
            }
        }

        // Show activity indicator while content is loading
        activityIndicator.startAnimating()
        
        if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
            print("Loading video: \(url.absoluteString)")
            
            // Skip native playback entirely and go straight to web playback which is more reliable
            // This ensures consistent behavior for both WebM and MP4 files
            tryWebPlayback(url: url)
        } else {
            print("Loading web content: \(url.absoluteString)")
            tryWebPlayback(url: url)
        }
    }
    
    // MARK: - Playback Helper Methods
    
    /// Attempts to play a video using native AVPlayer
    private func tryNativePlayback(url: URL) {
        print("Attempting native playback for: \(url.absoluteString)")
        
        // Hide web view and show video view
        webView.isHidden = true
        videoView.isHidden = false
        
        // Setup player layer if needed
        if playerLayer.superlayer == nil {
            videoView.layer.addSublayer(playerLayer)
            playerLayer.frame = videoView.bounds
        }
        
        // For WebM and MP4 files, use web playback for consistent behavior
        // Both formats seem to work better with web playback in this context
        if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
            print("Video detected (\(url.pathExtension)), using web playback for better compatibility")
            tryWebPlayback(url: url)
            return
        }
        
        // Create AVURLAsset with specific options for better streaming
        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let asset = AVURLAsset(url: url, options: options)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Add specific playback settings for better media compatibility
        playerItem.audioTimePitchAlgorithm = .spectral
        
        // Set up observation of player item status
        let observation = playerItem.observe(\.status, options: [.new]) { [weak self] (item, _) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    // Successfully loaded, can play now
                    print("Video ready to play: \(url.absoluteString)")
                    self.avPlayer.play()
                    
                    // Add observer for when playback ends
                    NotificationCenter.default.addObserver(self, 
                                                      selector: #selector(self.playerItemDidReachEnd), 
                                                      name: .AVPlayerItemDidPlayToEndTime, 
                                                      object: playerItem)
                    
                case .failed:
                    // Failed to load with native player, try fallback URL if available or web playback
                    let errorMessage = item.error?.localizedDescription ?? "Unknown error"
                    print("Native playback failed: \(errorMessage)")
                    
                    // First check if we have a fallback URL (alternate format)
                    if let fallbackURL = self.fallbackURL {
                        print("Trying fallback URL: \(fallbackURL)")
                        self.fallbackURL = nil // Clear the fallback after using it
                        
                        // Try native playback again with the fallback URL
                        let asset = AVURLAsset(url: fallbackURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                        let fallbackPlayerItem = AVPlayerItem(asset: asset)
                        fallbackPlayerItem.audioTimePitchAlgorithm = .spectral
                        self.avPlayer.replaceCurrentItem(with: fallbackPlayerItem)
                    } else {
                        // No fallback URL, try web playback
                        print("No fallback URL available, trying web playback")
                        self.tryWebPlayback(url: url)
                    }
                    
                case .unknown:
                    print("Video status unknown")
                    
                @unknown default:
                    print("Unknown player status")
                }
                
                self.activityIndicator.stopAnimating()
            }
        }
        
        // Store the observation to keep it alive
        playerItem.accessibilityElements = [observation]
        
        // Set the player's item
        self.avPlayer.replaceCurrentItem(with: playerItem)
    }
    
    /// Attempts to play a video using WKWebView
    private func tryWebPlayback(url: URL) {
        print("Using web playback for: \(url.absoluteString)")
        
        // Hide video view and show web view
        videoView.isHidden = true
        webView.isHidden = false
        
        // Create HTML content for video playback
        if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
            // Determine the MIME type based on the file extension
            let mimeType: String
            if url.pathExtension.lowercased() == "webm" {
                mimeType = "video/webm"
            } else if url.pathExtension.lowercased() == "mp4" {
                mimeType = "video/mp4"
            } else {
                mimeType = "video/\(url.pathExtension.lowercased())"
            }
            
            // Create custom HTML for video display with proper controls
            let videoHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
                <style>
                    body { margin: 0; padding: 0; background-color: #000; overflow: hidden; }
                    video {
                        position: fixed;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        object-fit: contain;
                        background-color: #000;
                    }
                    /* Improve play button visibility */
                    video::-webkit-media-controls-play-button {
                        background-color: rgba(255, 255, 255, 0.7);
                        border-radius: 50%;
                        width: 70px;
                        height: 70px;
                    }
                    /* Make controls more visible */
                    video::-webkit-media-controls-panel {
                        background-color: rgba(0, 0, 0, 0.7);
                    }
                    .error-message {
                        position: fixed;
                        top: 50%;
                        left: 50%;
                        transform: translate(-50%, -50%);
                        color: white;
                        background-color: rgba(0, 0, 0, 0.7);
                        padding: 20px;
                        border-radius: 10px;
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        display: none;
                        text-align: center;
                    }
                </style>
            </head>
            <body>
                <video id="videoPlayer" controls autoplay loop playsinline muted>
                    <source src="\(url.absoluteString)" type="\(mimeType)">
                    Your browser does not support the video tag.
                </video>
                
                <div id="errorMessage" class="error-message">
                    Error loading video. Tap to try again.
                </div>
                
                <script>
                    // Debug info
                    console.log('Loading video URL: \(url.absoluteString)');
                    console.log('MIME type: \(mimeType)');
                    
                    // Get reference to the video element and error message
                    var video = document.getElementById('videoPlayer');
                    var errorMsg = document.getElementById('errorMessage');
                    
                    // Function to try playing the video with error handling
                    function tryPlayVideo() {
                        // Try to play the video
                        video.play().catch(function(error) {
                            console.log('Play attempt failed:', error);
                            // User might need to interact with the page
                            errorMsg.style.display = 'block';
                        });
                    }
                    
                    // Add click handler to retry playback
                    errorMsg.addEventListener('click', function() {
                        errorMsg.style.display = 'none';
                        tryPlayVideo();
                    });
                    
                    // Handle when the video can play
                    video.addEventListener('canplay', function() {
                        console.log('Video can play now!');
                        errorMsg.style.display = 'none';
                        tryPlayVideo();
                    });
                    
                    // Add comprehensive error handling
                    video.addEventListener('error', function(e) {
                        console.error('Video error:', video.error);
                        if (video.error) {
                            console.log('Error code:', video.error.code);
                            console.log('Error message:', video.error.message);
                        }
                        errorMsg.style.display = 'block';
                    });
                    
                    // Try playing the video at different intervals
                    setTimeout(function() { tryPlayVideo(); }, 100);
                    setTimeout(function() { tryPlayVideo(); }, 500);
                    setTimeout(function() { tryPlayVideo(); }, 1500);
                    
                    // Additional handlers for better user experience
                    document.addEventListener('click', function() {
                        // User interaction can trigger autoplay
                        tryPlayVideo();
                    });
                    
                    // Log video events for debugging
                    ['loadstart', 'progress', 'suspend', 'abort', 'loadedmetadata', 
                     'loadeddata', 'waiting', 'playing', 'canplay', 'canplaythrough'].forEach(function(evt) {
                        video.addEventListener(evt, function() {
                            console.log('Video event:', evt);
                            if (evt === 'playing' || evt === 'canplaythrough') {
                                errorMsg.style.display = 'none';
                            }
                        });
                    });
                        var video = document.querySelector('video');
                        video.addEventListener('canplay', function() {
                            video.play().catch(function(error) {
                                console.log('Auto-play failed:', error);
                            });
                        });
                        
                        // Force play attempt
                        setTimeout(function() {
                            video.play().catch(function(error) {
                                console.log('Delayed play failed:', error);
                            });
                        }, 500);
                    });
                </script>
            </body>
            </html>
            """
            
            webView.loadHTMLString(videoHTML, baseURL: nil)
        } else {
            // For non-video content, just load the URL directly
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // Stop activity indicator
        activityIndicator.stopAnimating()
    }

    // MARK: - Swipe Handling
    /// Handles left and right swipe gestures to navigate content
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            // Move to next content if available
            if currentIndex < images.count - 1 {
                currentIndex += 1
                loadContent()
            } else {
                showAlert(title: "End", message: "No more images")
            }
        } else if gesture.direction == .right {
            // Move to previous content if available
            if currentIndex > 0 {
                currentIndex -= 1
                loadContent()
            } else {
                showAlert(title: "Start", message: "No previous images")
            }
        }
    }

    // MARK: - Actions
    /// Initiates the download process for the current content
    @objc private func downloadData() {
        let folderName: String
        // Determine folder based on file type
        if images[currentIndex].absoluteString.contains("png") || images[currentIndex].absoluteString.contains("jpg") {
            folderName = "images"
        } else if images[currentIndex].absoluteString.contains("gif") || images[currentIndex].absoluteString.contains("webm") {
            folderName = "media"
        } else {
            showAlert(title: "Error", message: "Unsupported file type")
            return
        }

        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showAlert(title: "Error", message: "Could not access documents directory")
            return
        }

        let folderURL = documentsDirectory.appendingPathComponent(folderName)

        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            showAlert(title: "Error", message: "Could not create directory")
            return
        }

        let filename = images[currentIndex].lastPathComponent
        let destinationURL = folderURL.appendingPathComponent(filename)

        // Start download
        Task {
            await download(url: images[currentIndex], to: destinationURL)
        }
    }

    /// Downloads content from the given URL to the specified local URL
    private func download(url: URL, to localUrl: URL) async {
        let request = URLRequest(url: url)

        do {
            let (tempLocalUrl, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                showAlert(title: "Error", message: "Failed to download content")
                return
            }

            // Save downloaded content to local file system
            try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
            showAlert(title: "Success", message: "Download complete")
        } catch {
            showAlert(title: "Download Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Utility Methods
    /// Displays an alert with the given title and message
    @MainActor
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate Methods
extension urlWeb: WKNavigationDelegate {
    /// Called when the web view begins to load content
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }

    /// Called when the web view finishes loading content
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    /// Called when the web view fails to load content
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        
        // Check if we have a fallback URL to try
        if let fallbackURL = fallbackURL {
            print("Web playback failed, trying fallback URL: \(fallbackURL)")
            self.fallbackURL = nil // Clear the fallback after using it
            
            // Try with the fallback URL
            if fallbackURL.pathExtension.lowercased() == "webm" || fallbackURL.pathExtension.lowercased() == "mp4" {
                tryNativePlayback(url: fallbackURL)
            } else {
                let request = URLRequest(url: fallbackURL)
                webView.load(request)
            }
        } else {
            // No fallback available, show error
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
}

