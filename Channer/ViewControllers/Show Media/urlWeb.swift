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

        // If the URL ends with "s.jpg", try to find the corresponding video file
        if url.absoluteString.hasSuffix("s.jpg") {
            // First try .webm
            let webmURLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".webm")
            if let webmURL = URL(string: webmURLString) {
                url = webmURL
                print("Using WebM URL: \(webmURL.absoluteString)")
            } else {
                // Try .mp4 if webm failed
                let mp4URLString = url.absoluteString.replacingOccurrences(of: "s.jpg", with: ".mp4")
                if let mp4URL = URL(string: mp4URLString) {
                    url = mp4URL
                    print("Using MP4 URL: \(mp4URL.absoluteString)")
                }
            }
        }

        // Show activity indicator while content is loading
        activityIndicator.startAnimating()
        
        if url.pathExtension.lowercased() == "webm" || url.pathExtension.lowercased() == "mp4" {
            print("Loading video: \(url.absoluteString)")
            
            // First try native playback for MP4 files (more widely supported)
            if url.pathExtension.lowercased() == "mp4" {
                tryNativePlayback(url: url)
            } 
            // For WebM files, check file type before attempting native playback
            else if url.pathExtension.lowercased() == "webm" {
                // Start with web playback for WebM files which have better support in web view
                tryWebPlayback(url: url)
            } else {
                // For any other video format, try native playback first
                tryNativePlayback(url: url)
            }
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
        
        // Create AVURLAsset with specific options for better streaming
        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let asset = AVURLAsset(url: url, options: options)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Add specific playback settings for better WebM compatibility
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
                    // Failed to load with native player, try web fallback
                    let errorMessage = item.error?.localizedDescription ?? "Unknown error"
                    print("Native playback failed: \(errorMessage), trying web playback")
                    
                    // Use web playback as fallback
                    self.tryWebPlayback(url: url)
                    
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
            // Create custom HTML for video display with proper controls
            let videoHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
                <style>
                    body { margin: 0; padding: 0; background-color: #000; }
                    video {
                        position: fixed;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        object-fit: contain;
                    }
                </style>
            </head>
            <body>
                <video controls autoplay loop playsinline>
                    <source src="\(url.absoluteString)" type="video/\(url.pathExtension.lowercased())">
                    Your browser does not support the video tag.
                </video>
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
        showAlert(title: "Error", message: error.localizedDescription)
    }
}

