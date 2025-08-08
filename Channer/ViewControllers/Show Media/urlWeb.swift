import UIKit
import WebKit
import AVKit
import AVFoundation
import VLCKit

class urlWeb: UIViewController, WKScriptMessageHandler, VLCMediaPlayerDelegate {

    // MARK: - Properties
    // Array of image URLs to display
    var images: [URL] = []

    // Current index in the images array
    var currentIndex: Int = 0

    // Property to enable or disable swipes
    var enableSwipes: Bool = true
    
    // Fallback URL to try if the first URL fails
    private var fallbackURL: URL? = nil
    
    // Temporary file URL for downloaded content
    private var temporaryFileURL: URL? = nil
    
    // Flag to track if we should use VLC for playback
    private var shouldUseVLCPlayback: Bool = false
    // One-shot retry guard per load to avoid loops
    private var attemptedAVPlayerFallback = false

    // MARK: - Simple per-host rate limiting (handles 429 Retry-After)
    private static var hostBackoffUntil: [String: Date] = [:]
    private static func setBackoff(for url: URL, seconds: Int) {
        guard let host = url.host else { return }
        let jitter = Double.random(in: 0.5...1.5)
        hostBackoffUntil[host] = Date().addingTimeInterval(Double(seconds) + jitter)
        print("DEBUG: urlWeb - Set backoff for host \(host) for \(seconds)s (+jitter)")
    }
    private static func backoffRemaining(for url: URL) -> TimeInterval {
        guard let host = url.host, let until = hostBackoffUntil[host] else { return 0 }
        return max(0, until.timeIntervalSinceNow)
    }
    private static func clearBackoff(for url: URL) {
        guard let host = url.host else { return }
        hostBackoffUntil.removeValue(forKey: host)
    }
    private static func parseRetryAfter(_ value: String) -> Int? {
        if let seconds = Int(value.trimmingCharacters(in: .whitespaces)) { return seconds }
        // Ignore HTTP-date format for simplicity
        return nil
    }
    private static func saveCookies(from response: HTTPURLResponse) {
        guard let url = response.url else { return }
        var headerFields: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let key = k as? String, let val = v as? String {
                headerFields[key] = val
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
            print("DEBUG: urlWeb - Saved cookie: \(cookie.name) for \(cookie.domain)")
        }
    }
    private static func awaitBackoffIfNeeded(for url: URL) async {
        let remaining = backoffRemaining(for: url)
        if remaining > 0 {
            print("DEBUG: urlWeb - Honoring host backoff for \(String(format: "%.1f", remaining))s before retrying: \(url.host ?? "")")
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }

    // Optional explicit Referer to use for downloads (e.g., 4chan thread URL)
    var refererString: String? = nil
    
    // VLC player components
    private var vlcPlayer: VLCMediaPlayer?
    private var audioCheckTimer: Timer?
    private var bufferingStartTime: Date?
    
    /// Current mute state - always start muted for privacy/courtesy
    private var isMuted: Bool = true
    private lazy var vlcVideoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.isHidden = true // Hidden by default
        return view
    }()
    

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
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .black
        
        // Enable console message logging for debugging
        if #available(iOS 14.0, *) {
            webView.configuration.userContentController.add(self, name: "consoleLog")
        }
        
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
        // FORCE AVPlayer to always start muted for privacy/courtesy
        player.isMuted = true
        player.volume = 0.0
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
        
        // Clean up old temporary files
        cleanupOldTemporaryFiles()
        
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
        
        // Clean up temporary file if we downloaded one
        cleanupTemporaryFile()
        
        // Clean up VLC player
        vlcPlayer?.stop()
        vlcPlayer?.delegate = nil
        vlcPlayer = nil
        
        // Stop periodic audio checking
        stopPeriodicAudioChecking()
    }
    
    /// Cleans up any temporary downloaded files
    private func cleanupTemporaryFile() {
        guard let tempFileURL = temporaryFileURL else { return }
        
        do {
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
                print("DEBUG: urlWeb - Cleaned up temporary file: \(tempFileURL.path)")
            }
        } catch {
            print("DEBUG: urlWeb - Failed to clean up temporary file: \(error)")
        }
        
        temporaryFileURL = nil
    }
    
    /// Detects if a WebM file uses VP9 codec using AVAsset
    private func detectVP9Codec(fileURL: URL) async -> Bool {
        do {
            // Ensure file exists and is readable
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("DEBUG: urlWeb - File does not exist for VP9 detection: \(fileURL.path)")
                return false
            }
            
            let asset = AVAsset(url: fileURL)
            
            // Load the tracks asynchronously with timeout
            let tracks = try await withTimeout(seconds: 3.0) {
                try await asset.loadTracks(withMediaType: .video)
            }
            
            guard let videoTrack = tracks.first else {
                print("DEBUG: urlWeb - No video track found in asset")
                return await fallbackVP9Detection(fileURL: fileURL)
            }
            
            // Load format descriptions from the track
            let formatDescriptions = try await withTimeout(seconds: 2.0) {
                try await videoTrack.load(.formatDescriptions)
            }
            
            for formatDesc in formatDescriptions {
                // Get the media subtype (codec)
                let mediaSubtype = CMFormatDescriptionGetMediaSubType(formatDesc)
                
                // Convert to string for logging
                let codecString = String(format: "%c%c%c%c", 
                    (mediaSubtype >> 24) & 255,
                    (mediaSubtype >> 16) & 255, 
                    (mediaSubtype >> 8) & 255,
                    mediaSubtype & 255)
                
                print("DEBUG: urlWeb - Found video codec: \(codecString), fourCC: \(mediaSubtype)")
                
                // VP9 codec fourCC codes
                let vp90 = FourCharCode(0x76703930) // 'vp90'
                let vp09 = FourCharCode(0x76703039) // 'vp09'
                
                if mediaSubtype == vp90 || mediaSubtype == vp09 {
                    print("DEBUG: urlWeb - VP9 codec confirmed via AVAsset")
                    return true
                }
            }
            
            print("DEBUG: urlWeb - No VP9 codec detected via AVAsset")
            return false
            
        } catch {
            print("DEBUG: urlWeb - Error detecting codec with AVAsset: \(error)")
            // Try fallback detection method
            return await fallbackVP9Detection(fileURL: fileURL)
        }
    }
    
    /// Fallback VP9 detection using file extension and basic content analysis
    private func fallbackVP9Detection(fileURL: URL) async -> Bool {
        print("DEBUG: urlWeb - Using fallback VP9 detection method")
        
        // Only consider WebM files for VP9 (MP4 files are typically H.264)
        guard fileURL.pathExtension.lowercased() == "webm" else {
            print("DEBUG: urlWeb - Not a WebM file, assuming not VP9")
            return false
        }
        
        // Be conservative with fallback detection - don't assume all WebM files are VP9
        // Many WebM files use VP8 which VLC handles fine
        // Only route to web player when we have stronger evidence of VP9
        print("DEBUG: urlWeb - WebM file detected, but being conservative - let VLC try first")
        print("DEBUG: urlWeb - Will monitor VLC for VP9-specific errors and fallback if needed")
        return false
    }
    
    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error {}
    
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
        view.addSubview(vlcVideoView)
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

            // VLC VideoView constraints
            vlcVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            vlcVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vlcVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vlcVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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

        setupNavigationButtons()
    }
    
    /// Sets up navigation bar buttons (mute/unmute and download)
    private func setupNavigationButtons() {
        var rightButtons: [UIBarButtonItem] = []
        
        // Always add mute/unmute button
        let muteButton = UIBarButtonItem(
            image: getMuteButtonImage(),
            style: .plain,
            target: self,
            action: #selector(toggleMute)
        )
        muteButton.tintColor = .white
        rightButtons.append(muteButton)
        
        // Add download button
        let downloadButton = UIBarButtonItem(
            image: UIImage(named: "downloadWV"),
            style: .plain,
            target: self,
            action: #selector(downloadData)
        )
        downloadButton.tintColor = .white
        rightButtons.append(downloadButton)
        
        navigationItem.rightBarButtonItems = rightButtons
    }
    
    /// Returns the appropriate mute button image based on current state
    private func getMuteButtonImage() -> UIImage? {
        let imageName = isMuted ? "speaker.slash" : "speaker.wave.2"
        return UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
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
            
            // For remote video files, download temporarily and use VLC for better codec support
            if !url.isFileURL {
                print("DEBUG: urlWeb - Remote video detected, using temporary download + VLC approach")
                downloadTemporarilyAndPlayWithVLC(url: url)
            } else {
                // Local files can go straight to VLC
                print("DEBUG: urlWeb - Local video file, using VLC directly")
                playWithVLC(fileURL: url)
            }
        } else {
            print("Loading web content: \(url.absoluteString)")
            tryWebPlayback(url: url)
        }
    }
    
    // MARK: - Playback Helper Methods
    
    /// Downloads a remote video file temporarily and plays it with VLC
    private func downloadTemporarilyAndPlayWithVLC(url: URL) {
        print("DEBUG: urlWeb - Starting temporary download for: \(url.absoluteString)")
        
        // Create temporary directory if needed
        let tempDir = getTemporaryDirectory()
        let filename = url.lastPathComponent
        let tempFileURL = tempDir.appendingPathComponent(filename)
        
        print("DEBUG: urlWeb - Temporary file path: \(tempFileURL.path)")
        
        // Remove existing file if it exists to prevent conflicts
        if FileManager.default.fileExists(atPath: tempFileURL.path) {
            do {
                try FileManager.default.removeItem(at: tempFileURL)
                print("DEBUG: urlWeb - Removed existing temporary file")
            } catch {
                print("DEBUG: urlWeb - Failed to remove existing file: \(error)")
            }
        }
        
        // Update loading message
        DispatchQueue.main.async {
            // We'll add a loading message here later
        }
        
        // Start download
        Task {
            do {
                // Build a request with common headers some CDNs require
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                // Spoof a common mobile Safari UA to avoid blocks
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                // Provide a reasonable referer/origin: prefer explicit referer if provided
                if let explicitRef = refererString {
                    request.setValue(explicitRef, forHTTPHeaderField: "Referer")
                    if let refURL = URL(string: explicitRef), let refScheme = refURL.scheme, let refHost = refURL.host {
                        request.setValue("\(refScheme)://\(refHost)", forHTTPHeaderField: "Origin")
                    }
                } else if url.host == "i.4cdn.org" {
                    // Infer 4chan board from path and use boards.4chan.org as referer
                    let comps = url.pathComponents
                    if comps.count > 1 {
                        let board = comps[1]
                        let ref = "https://boards.4chan.org/\(board)/"
                        request.setValue(ref, forHTTPHeaderField: "Referer")
                        request.setValue("https://boards.4chan.org", forHTTPHeaderField: "Origin")
                    }
                } else if let scheme = url.scheme, let host = url.host {
                    let origin = "\(scheme)://\(host)"
                    request.setValue(origin + "/", forHTTPHeaderField: "Referer")
                    request.setValue(origin, forHTTPHeaderField: "Origin")
                }
                request.setValue("*/*", forHTTPHeaderField: "Accept")
                request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

                // Debug request
                print("DEBUG: urlWeb - Starting download request")
                print("DEBUG: urlWeb - URL: \(url.absoluteString)")
                print("DEBUG: urlWeb - Headers: \(request.allHTTPHeaderFields ?? [:])")

                // Respect any active backoff for this host before attempting download
                await urlWeb.awaitBackoffIfNeeded(for: url)
                let (tempDownloadURL, response) = try await URLSession.shared.download(for: request)
                print("DEBUG: urlWeb - URLSession.download returned temp URL: \(tempDownloadURL.path)")

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("DEBUG: urlWeb - Non-HTTP response: \(response)")
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.showAlert(title: "Error", message: "Non-HTTP response during download")
                    }
                    return
                }

                // Log response details
                print("DEBUG: urlWeb - HTTP status: \(httpResponse.statusCode)")
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                    print("DEBUG: urlWeb - Content-Type: \(contentType)")
                }
                if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
                    print("DEBUG: urlWeb - Content-Length header: \(contentLength)")
                }
                print("DEBUG: urlWeb - Response headers: \(httpResponse.allHeaderFields)")
                // Persist any cookies (e.g., Cloudflare) to improve subsequent requests
                urlWeb.saveCookies(from: httpResponse)

                guard (200...299).contains(httpResponse.statusCode) else {
                    print("DEBUG: urlWeb - Download failed with status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 429 {
                        let retryStr = httpResponse.value(forHTTPHeaderField: "retry-after") ?? ""
                        if let seconds = urlWeb.parseRetryAfter(retryStr) {
                            urlWeb.setBackoff(for: url, seconds: seconds)
                            print("DEBUG: urlWeb - Rate limited. Will retry in \(seconds)s")
                        } else {
                            urlWeb.setBackoff(for: url, seconds: 10)
                            print("DEBUG: urlWeb - Rate limited. Retry-After missing, defaulting to 10s")
                        }
                        DispatchQueue.main.async {
                            self.activityIndicator.startAnimating()
                        }
                        Task { [weak self] in
                            guard let self = self else { return }
                            await urlWeb.awaitBackoffIfNeeded(for: url)
                            self.downloadTemporarilyAndPlayWithVLC(url: url)
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.showAlert(title: "Error", message: "Failed to download video")
                    }
                    return
                }

                // Status OK: move file to our temp target
                let tempAttrs = try? FileManager.default.attributesOfItem(atPath: tempDownloadURL.path)
                let tempSize = (tempAttrs?[.size] as? NSNumber)?.int64Value ?? -1
                print("DEBUG: urlWeb - Downloaded file size at temp path: \(tempSize) bytes")

                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try? FileManager.default.removeItem(at: tempFileURL)
                }
                try FileManager.default.moveItem(at: tempDownloadURL, to: tempFileURL)
                print("DEBUG: urlWeb - Moved file to temp target: \(tempFileURL.path)")

                let movedAttrs = try? FileManager.default.attributesOfItem(atPath: tempFileURL.path)
                let movedSize = (movedAttrs?[.size] as? NSNumber)?.int64Value ?? -1
                print("DEBUG: urlWeb - File size at target path: \(movedSize) bytes")

                // VP9 detection on valid data (for diagnostics only)
                let isVP9 = await self.detectVP9Codec(fileURL: tempFileURL)
                print("DEBUG: urlWeb - VP9 codec detection result: \(isVP9)")
                // Always use VLC for WebM playback (VP8/VP9) to maximize compatibility on iOS
                if isVP9 {
                    print("DEBUG: urlWeb - VP9 detected. Proceeding with VLC playback (WKWebView may lack VP9 support)")
                } else {
                    print("DEBUG: urlWeb - No VP9 detected, proceeding with VLC playback")
                }

                print("DEBUG: urlWeb - Successfully downloaded to temp: \(tempFileURL.path)")
                
                // Store temp file URL for cleanup
                self.temporaryFileURL = tempFileURL
                
                // Play with VLC
                DispatchQueue.main.async {
                    self.playWithVLC(fileURL: tempFileURL)
                }
                
            } catch {
                let nsErr = error as NSError
                print("DEBUG: urlWeb - Download failed: \(error.localizedDescription) (code=\(nsErr.code), domain=\(nsErr.domain))")
                if let urlErr = error as? URLError {
                    print("DEBUG: urlWeb - URLError code: \(urlErr.code)")
                }
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Download Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    /// Plays a local file using integrated VLC player
    private func playWithVLC(fileURL: URL) {
        print("DEBUG: urlWeb - Playing with integrated VLC: \(fileURL.path)")
        
        shouldUseVLCPlayback = true
        
        // Hide other views and show VLC view
        webView.isHidden = true
        videoView.isHidden = true
        vlcVideoView.isHidden = false
        
        activityIndicator.stopAnimating()
        
        // Initialize VLC player
        vlcPlayer = VLCMediaPlayer()
        
        vlcPlayer?.drawable = vlcVideoView
        vlcPlayer?.delegate = self
        
        
        // Simple codec detection for debug output (VP9 should be handled earlier)
        print("DEBUG: urlWeb - VP8 or other codec detected, playing with integrated VLCKit")
        
        // Create VLC media and start playback
        let media = VLCMedia(url: fileURL)
        vlcPlayer?.media = media
        
        // Start playback
        print("DEBUG: urlWeb - Starting VLC playback")
        vlcPlayer?.play()
        
        print("DEBUG: urlWeb - Started VLC playback")
        activityIndicator.stopAnimating()

        // Start periodic mute + loop checking
        startPeriodicAudioChecking()
    }
    
    // MARK: - Periodic Audio Checking
    /// Starts periodic checking of audio state to catch any unmuting
    private func startPeriodicAudioChecking() {
        print("🎵 DEBUG: urlWeb - Starting periodic audio/loop checking")
        audioCheckTimer?.invalidate()
        audioCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkAndEnforceAudioMuting()
            // Loop safeguard for VLC path
            if let player = self.vlcPlayer {
                let pos = player.position
                let state = player.state
                print("DEBUG: urlWeb - Loop monitor tick - state: \(state.rawValue), position: \(pos)")
                if pos >= 0.995 || (state == .stopped && pos >= 0.8) {
                    print("DEBUG: urlWeb - Loop monitor: looping video (seek to 0 + play)")
                    player.position = 0.0
                    player.play()
                }
            }
        }
    }
    
    /// Stops periodic audio checking
    private func stopPeriodicAudioChecking() {
        print("🎵 DEBUG: urlWeb - Stopping periodic audio checking")
        audioCheckTimer?.invalidate()
        audioCheckTimer = nil
    }
    
    /// Checks current audio state and enforces user's mute preference
    private func checkAndEnforceAudioMuting() {
        guard let vlcPlayer = vlcPlayer else { return }
        
        let playerIsMuted = vlcPlayer.audio?.isMuted ?? false
        let playerVolume = vlcPlayer.audio?.volume ?? -1
        
        print("🎵 DEBUG: urlWeb - Periodic check - Player Muted: \(playerIsMuted), Player Volume: \(playerVolume), User Preference: \(isMuted)")
        
        // Enforce user's mute preference
        let expectedVolume = isMuted ? Int32(0) : Int32(50)
        if playerIsMuted != isMuted || playerVolume != expectedVolume {
            print("🎵 DEBUG: urlWeb - Enforcing user mute preference...")
            vlcPlayer.audio?.isMuted = isMuted
            vlcPlayer.audio?.volume = expectedVolume
            print("🎵 DEBUG: urlWeb - Applied user preference - Audio Muted: \(vlcPlayer.audio?.isMuted ?? false), Volume: \(vlcPlayer.audio?.volume ?? -1)")
        }
    }
    
    /// Helper method to get human-readable state description
    private func stateDescription(_ state: VLCMediaPlayerState) -> String {
        switch state {
        case .stopped: return "STOPPED"
        case .opening: return "OPENING"
        case .buffering: return "BUFFERING"
        case .playing: return "PLAYING"
        case .paused: return "PAUSED"
        case .error: return "ERROR"
        @unknown default: return "UNKNOWN(\(state.rawValue))"
        }
    }
    
    /// Plays video via VLC by downloading temporarily if needed
    private func playWithAVPlayer(url: URL) {
        print("DEBUG: urlWeb - Redirecting AVPlayer path to VLC for: \(url.absoluteString)")
        if url.isFileURL {
            self.playWithVLC(fileURL: url)
        } else {
            self.downloadTemporarilyAndPlayWithVLC(url: url)
        }
    }
    
    /// Starts continuous AVPlayer mute monitoring to prevent any audio leakage
    private func startAVPlayerMuteMonitoring() {
        print("🎵 DEBUG: urlWeb - Starting AVPlayer continuous mute monitoring")
        audioCheckTimer?.invalidate()
        audioCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if !self.avPlayer.isMuted || self.avPlayer.volume != 0.0 {
                print("🎵 DEBUG: urlWeb - AVPlayer UNMUTED DETECTED! Force muting - was isMuted: \(self.avPlayer.isMuted), volume: \(self.avPlayer.volume)")
                self.avPlayer.isMuted = true
                self.avPlayer.volume = 0.0
                self.isMuted = true
                print("🎵 DEBUG: urlWeb - AVPlayer FORCE MUTED - now isMuted: \(self.avPlayer.isMuted), volume: \(self.avPlayer.volume)")
                
                // Update UI
                DispatchQueue.main.async {
                    self.setupNavigationButtons()
                }
            }
        }
    }

    /// Gets the temporary directory for video downloads
    private func getTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ChannerVideoCache", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                print("DEBUG: urlWeb - Created temp directory: \(tempDir.path)")
            } catch {
                print("DEBUG: urlWeb - Failed to create temp directory: \(error)")
            }
        }
        
        return tempDir
    }
    
    /// Cleans up old temporary files to prevent excessive storage usage
    private func cleanupOldTemporaryFiles() {
        let tempDir = getTemporaryDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: [])
            
            // Remove files older than 1 hour
            let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
            
            for fileURL in files {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let creationDate = attributes[.creationDate] as? Date,
                       creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: fileURL)
                        print("DEBUG: urlWeb - Cleaned up old temp file: \(fileURL.lastPathComponent)")
                    }
                } catch {
                    print("DEBUG: urlWeb - Error checking file date: \(error)")
                }
            }
        } catch {
            print("DEBUG: urlWeb - Error cleaning up temp directory: \(error)")
        }
    }
    
    /// Attempts to play a video using VLC instead of AVPlayer
    private func tryNativePlayback(url: URL) {
        print("DEBUG: urlWeb - Redirecting native playback to VLC for: \(url.absoluteString)")
        if url.isFileURL {
            playWithVLC(fileURL: url)
        } else {
            downloadTemporarilyAndPlayWithVLC(url: url)
        }
    }
    
    /// Attempts to play a video using WKWebView
    private func tryWebPlayback(url: URL) {
        print("Using web playback for: \(url.absoluteString)")
        
        // Hide video view and VLC components, show web view
        videoView.isHidden = true
        vlcVideoView.isHidden = true
        webView.isHidden = false
        
        print("DEBUG: urlWeb - Hidden VLC components and showing web view")
        
        // Handle local and remote video files uniformly via custom HTML with forced loop/mute
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
            
            // Check if we have a fallback URL to try
            let alternateSourceTag = fallbackURL != nil ? 
                        "<source src=\"\(fallbackURL!.absoluteString)\" type=\"\(fallbackURL!.pathExtension.lowercased() == "webm" ? "video/webm" : "video/mp4")\">" : ""
            
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
                    /* Make controls more visible and accessible */
                    video::-webkit-media-controls-panel {
                        background-color: rgba(0, 0, 0, 0.8);
                        min-height: 50px;
                    }
                    video::-webkit-media-controls {
                        min-height: 50px;
                    }
                    /* Ensure touch targets are large enough */
                    video::-webkit-media-controls-timeline {
                        min-height: 40px;
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
                <video id="videoPlayer" controls autoplay loop playsinline muted volume="0">
                    <source src="\(url.absoluteString)" type="\(mimeType)">
                    \(alternateSourceTag)
                    Your browser does not support the video tag.
                </video>
                
                <div id="errorMessage" class="error-message">
                    Error loading video. Tap to try again.
                </div>
                
                <script>
                    // Override console.log to send messages to iOS
                    const originalConsoleLog = console.log;
                    console.log = function(...args) {
                        originalConsoleLog.apply(console, args);
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                            window.webkit.messageHandlers.consoleLog.postMessage(args.join(' '));
                        }
                    };
                    
                    // Debug info
                    console.log('=== VIDEO PLAYER DEBUG START ===');
                    console.log('Loading primary video URL: \(url.absoluteString)');
                    console.log('Primary MIME type: \(mimeType)');
                    console.log('User agent: ' + navigator.userAgent);
                    console.log('Video element supported: ' + !!document.createElement('video').canPlayType);
                    console.log('WebM support: ' + document.createElement('video').canPlayType('video/webm'));
                    console.log('VP8 support: ' + document.createElement('video').canPlayType('video/webm; codecs="vp8"'));
                    console.log('VP9 support: ' + document.createElement('video').canPlayType('video/webm; codecs="vp9"'));
                    
                    // Check if VP9 is not supported and show a message
                    var vp9Support = document.createElement('video').canPlayType('video/webm; codecs="vp9"');
                    if (!vp9Support || vp9Support === '') {
                        console.log('VP9 not supported - this WebM file may not play on iOS');
                    }
                    
                    \(fallbackURL != nil ? "console.log('Alternate URL available: \(fallbackURL!.absoluteString)');" : "")
                    
                    // Get reference to the video element and error message
                    var video = document.getElementById('videoPlayer');
                    var errorMsg = document.getElementById('errorMessage');
                    var sourceIndex = 0;
                    var sources = video.querySelectorAll('source');
                    
                    // NUCLEAR MUTING: Force videos to always start muted for privacy/courtesy
                    video.muted = true;
                    video.volume = 0;
                    video.setAttribute('muted', 'muted');
                    video.setAttribute('volume', '0');
                    console.log('NUCLEAR MUTING: Initial video muting applied - muted:', video.muted, 'volume:', video.volume);
                    
                    // Loop safeguard: if native looping fails, manually loop on 'ended'
                    video.addEventListener('ended', function() {
                        console.log('Loop safeguard: video ended, resetting to 0 and replaying');
                        try {
                            video.currentTime = 0;
                            const p = video.play();
                            if (p && p.catch) { p.catch(e => console.log('Loop replay play() rejected:', e)); }
                        } catch (e) {
                            console.log('Loop safeguard error:', e);
                        }
                    });
                    
                    // Add codec detection when video metadata is loaded
                    video.addEventListener('loadedmetadata', function() {
                        console.log('=== CODEC DETECTION START ===');
                        console.log('Video duration:', video.duration);
                        console.log('Video dimensions:', video.videoWidth + 'x' + video.videoHeight);
                        
                        // Try to get codec information from the video
                        if (video.getVideoPlaybackQuality) {
                            var quality = video.getVideoPlaybackQuality();
                            console.log('Video playback quality:', quality);
                        }
                        
                        // Check if we can get codec information
                        try {
                            var stream = video.captureStream();
                            var track = stream.getVideoTracks()[0];
                            if (track && track.getSettings) {
                                var settings = track.getSettings();
                                console.log('Video track settings:', settings);
                            }
                        } catch (e) {
                            console.log('Could not capture video stream for codec detection:', e);
                        }
                        
                        console.log('=== CODEC DETECTION END ===');
                    });
                    
                    console.log('Video element found:', !!video);
                    console.log('Video has controls:', video.controls);
                    console.log('Video sources count:', sources.length);
                    
                    // Function to try playing the video with error handling and NUCLEAR muting
                    function tryPlayVideo() {
                        // NUCLEAR MUTING: Force videos to always start muted for privacy/courtesy
                        console.log('NUCLEAR MUTING: Pre-play muting enforcement');
                        video.muted = true;
                        video.volume = 0;
                        video.setAttribute('muted', 'muted');
                        video.setAttribute('volume', '0');
                        console.log('NUCLEAR MUTING: Pre-play muting applied - muted:', video.muted, 'volume:', video.volume);
                        
                        // Try to play the video
                        var playPromise = video.play().catch(function(error) {
                            console.log('Play attempt failed:', error);
                            // User might need to interact with the page
                            errorMsg.style.display = 'block';
                        });
                        
                        // NUCLEAR MUTING: Force mute immediately after play() call
                        if (playPromise !== undefined) {
                            playPromise.then(function() {
                                console.log('NUCLEAR MUTING: Post-play muting enforcement');
                                video.muted = true;
                                video.volume = 0;
                                console.log('NUCLEAR MUTING: Post-play muting applied - muted:', video.muted, 'volume:', video.volume);
                            }).catch(function(error) {
                                console.log('Play failed:', error);
                            });
                        }
                        
                        // Set up continuous mute monitoring
                        setInterval(function() {
                            if (!video.muted || video.volume !== 0) {
                                console.log('NUCLEAR MUTING: Unmuted video detected! Force muting - was muted:', video.muted, 'volume:', video.volume);
                                video.muted = true;
                                video.volume = 0;
                                console.log('NUCLEAR MUTING: Force muting applied - now muted:', video.muted, 'volume:', video.volume);
                            }
                        }, 100); // Check every 100ms
                    }
                    
                    // Add click handler to retry playback
                    errorMsg.addEventListener('click', function() {
                        errorMsg.style.display = 'none';
                        // Try alternating sources on click if available
                        if (sources.length > 1) {
                            switchSource();
                        }
                        tryPlayVideo();
                    });
                    
                    // Function to switch between available sources
                    function switchSource() {
                        if (sources.length <= 1) return;
                        
                        // Try the next source
                        sourceIndex = (sourceIndex + 1) % sources.length;
                        console.log('Switching to source ' + sourceIndex + ': ' + sources[sourceIndex].src);
                        
                        // Move the selected source to be first (highest priority)
                        video.insertBefore(sources[sourceIndex], video.firstChild);
                        
                        // Reload the video with the new source order
                        video.load();
                        
                        // Try playing after a short delay
                        setTimeout(tryPlayVideo, 300);
                    }
                    
                    
                    // Add comprehensive error handling
                    video.addEventListener('error', function(e) {
                        console.error('Video error:', video.error);
                        if (video.error) {
                            console.log('Error code:', video.error.code);
                            console.log('Error message:', video.error.message);
                        }
                        
                        // Show error message
                        errorMsg.style.display = 'block';
                        
                        // Try switching source if we have multiple
                        if (sources.length > 1) {
                            console.log('Trying alternate source due to error');
                            switchSource();
                        }
                    });
                    
                    // Handle when the video can play - ensure autoplay works
                    video.addEventListener('canplay', function() {
                        console.log('Video can play now!');
                        errorMsg.style.display = 'none';
                        // FORCE videos to always start muted for privacy/courtesy
                        video.muted = true;
                        video.volume = 0;
                        if (video.paused) {
                            tryPlayVideo();
                        }
                    });
                    
                    // Log volume changes for debugging - no longer enforcing muted state
                    video.addEventListener('volumechange', function() {
                        console.log('Volume changed - muted:', video.muted, 'volume:', video.volume);
                    });
                    
                    video.addEventListener('loadstart', function() {
                        // NUCLEAR MUTING: Force videos to always start muted for privacy/courtesy
                        console.log('NUCLEAR MUTING: loadstart event - applying muting');
                        video.muted = true;
                        video.volume = 0;
                        video.setAttribute('muted', 'muted');
                        video.setAttribute('volume', '0');
                        console.log('NUCLEAR MUTING: loadstart muting applied - muted:', video.muted, 'volume:', video.volume);
                    });
                    
                    // Additional handlers for better user experience
                    // Disabled to avoid interfering with pause functionality
                    /*
                    document.addEventListener('click', function(e) {
                        // Only trigger autoplay if not clicking on video controls
                        if (e.target !== video && !video.contains(e.target)) {
                            // User interaction can trigger autoplay
                            if (video.paused) {
                                tryPlayVideo();
                            }
                        }
                    });
                    */
                    
                    // Log important video events for debugging
                    ['pause', 'play', 'ended'].forEach(function(evt) {
                        video.addEventListener(evt, function() {
                            console.log('Video event:', evt, 'paused:', video.paused, 'muted:', video.muted, 'volume:', video.volume);
                            // NUCLEAR MUTING: Force muting on ALL video events for privacy/courtesy
                            console.log('NUCLEAR MUTING: ' + evt + ' event - enforcing muting');
                            video.muted = true;
                            video.volume = 0;
                            video.setAttribute('muted', 'muted');
                            video.setAttribute('volume', '0');
                            console.log('NUCLEAR MUTING: ' + evt + ' event muting applied - videos always start muted');
                        });
                    });
                    
                    
                    // Source error handling - crucial for format compatibility
                    for (var i = 0; i < sources.length; i++) {
                        sources[i].addEventListener('error', function(e) {
                            console.log('Source error, trying next source if available');
                            // This helps handle incompatible source formats
                            if (sources.length > 1) {
                                switchSource();
                            }
                        });
                    }
                </script>
            </body>
            </html>
            """
            
            print("DEBUG: urlWeb - Loading HTML video content")
            print("DEBUG: urlWeb - Video HTML length: \(videoHTML.count) characters")
            print("DEBUG: urlWeb - Video source URL: \(url.absoluteString)")
            print("DEBUG: urlWeb - MIME type: \(mimeType)")
            print("DEBUG: urlWeb - Is file URL: \(url.isFileURL)")
            print("DEBUG: urlWeb - Has fallback URL: \(fallbackURL != nil)")
            
            // For local files, we need to set the proper baseURL to allow access
            if url.isFileURL {
                print("DEBUG: urlWeb - Loading local file, setting baseURL to: \(url.deletingLastPathComponent())")
                webView.loadHTMLString(videoHTML, baseURL: url.deletingLastPathComponent())
            } else {
                print("DEBUG: urlWeb - Loading remote file with no baseURL")
                webView.loadHTMLString(videoHTML, baseURL: nil)
            }
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
    /// Toggles the mute/unmute state of the video
    @objc private func toggleMute() {
        print("🎵 DEBUG: urlWeb - === TOGGLE MUTE CALLED ===")
        print("🎵 DEBUG: urlWeb - toggleMute() - isMuted BEFORE toggle: \(isMuted)")
        if let vlcPlayer = vlcPlayer {
            print("🎵 DEBUG: urlWeb - toggleMute() - VLC Audio Muted BEFORE: \(vlcPlayer.audio?.isMuted ?? false)")
            print("🎵 DEBUG: urlWeb - toggleMute() - VLC Audio Volume BEFORE: \(vlcPlayer.audio?.volume ?? -1)")
        }
        print("🎵 DEBUG: urlWeb - toggleMute() - AVPlayer Muted BEFORE: \(avPlayer.isMuted)")
        print("🎵 DEBUG: urlWeb - toggleMute() - AVPlayer Volume BEFORE: \(avPlayer.volume)")
        
        let wasMuted = isMuted
        isMuted.toggle()
        
        print("🎵 DEBUG: urlWeb - toggleMute() - isMuted AFTER toggle: \(isMuted) (was: \(wasMuted))")
        
        // Apply mute state to VLC player if it's active
        if let vlcPlayer = vlcPlayer {
            vlcPlayer.audio?.isMuted = isMuted
            vlcPlayer.audio?.volume = isMuted ? Int32(0) : Int32(50)
            print("🎵 DEBUG: urlWeb - toggleMute() - Applied VLC settings")
            print("🎵 DEBUG: urlWeb - toggleMute() - VLC Audio Muted AFTER: \(vlcPlayer.audio?.isMuted ?? false)")
            print("🎵 DEBUG: urlWeb - toggleMute() - VLC Audio Volume AFTER: \(vlcPlayer.audio?.volume ?? -1)")
        }
        
        // Apply mute state to AVPlayer if it's active
        avPlayer.isMuted = isMuted
        avPlayer.volume = isMuted ? 0.0 : 0.5
        print("🎵 DEBUG: urlWeb - toggleMute() - Applied AVPlayer settings")
        print("🎵 DEBUG: urlWeb - toggleMute() - AVPlayer Muted AFTER: \(avPlayer.isMuted)")
        print("🎵 DEBUG: urlWeb - toggleMute() - AVPlayer Volume AFTER: \(avPlayer.volume)")
        
        // Update the navigation bar button
        setupNavigationButtons()
        
        // Update web view audio state via JavaScript if web player is active
        if !webView.isHidden {
            let jsCommand = isMuted ? 
                "var video = document.getElementById('videoPlayer'); if (video) { video.muted = true; video.volume = 0; }" :
                "var video = document.getElementById('videoPlayer'); if (video) { video.muted = false; video.volume = 0.5; }"
            webView.evaluateJavaScript(jsCommand) { result, error in
                if let error = error {
                    print("DEBUG: urlWeb - Error updating web video mute state: \(error)")
                } else {
                    print("DEBUG: urlWeb - Successfully updated web video mute state to: \(self.isMuted ? "muted" : "unmuted")")
                }
            }
        }
        
        print("🎵 DEBUG: urlWeb - === TOGGLE MUTE COMPLETE ===")
    }
    
    /// Initiates the download process for the current content
    @objc private func downloadData() {
        let folderName: String
        // Determine folder based on file type or extension
        let fileExtension = images[currentIndex].pathExtension.lowercased()
        if fileExtension == "png" || fileExtension == "jpg" || fileExtension == "jpeg" {
            folderName = "images"
        } else if fileExtension == "gif" || fileExtension == "webm" || fileExtension == "mp4" {
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
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "consoleLog" {
            print("DEBUG: urlWeb - JavaScript Console: \(message.body)")
        }
    }
}

// MARK: - VLCMediaPlayerDelegate
extension urlWeb {
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("DEBUG: urlWeb - VLC State changed to: \(player.state.rawValue)")
            
            switch player.state {
            case .playing:
                print("DEBUG: urlWeb - VLC player started playing")
                
            case .stopped:
                print("DEBUG: urlWeb - VLC player stopped")
                // Loop videos when playing via thread/local views
                // Only loop if we actually reached the end (position ~ 1.0)
                let pos = player.position
                print("DEBUG: urlWeb - VLC stopped at position: \(pos)")
                if pos >= 0.99 {
                    print("DEBUG: urlWeb - Looping VLC video: seeking to start and replaying")
                    player.position = 0.0
                    player.play()
                }
                
            case .error:
                print("DEBUG: urlWeb - VLC player error")
                
                // If WebM fails in VLC, try MP4 variant via AVPlayer (if available), then fallback to web
                let currentURL = self.images[self.currentIndex]
                let isWebMFile = currentURL.pathExtension.lowercased() == "webm"
                if isWebMFile {
                    // Attempt MP4 alternative commonly available on some boards
                    let mp4URLString = currentURL.absoluteString.replacingOccurrences(of: ".webm", with: ".mp4")
                    if let mp4URL = URL(string: mp4URLString) {
                        print("DEBUG: urlWeb - VLC failed on WebM. Trying MP4 via VLC: \(mp4URL)")
                        self.vlcPlayer?.stop()
                        self.vlcVideoView.isHidden = true
                        self.playWithAVPlayer(url: mp4URL)
                        return
                    }
                    // As a last resort, attempt web playback
                    print("DEBUG: urlWeb - MP4 alternative unavailable. Trying web playback as last resort")
                    self.vlcPlayer?.stop()
                    self.vlcVideoView.isHidden = true
                    self.tryWebPlayback(url: currentURL)
                } else {
                    self.showAlert(title: "Playback Error", message: "Failed to play video")
                }
                
            case .buffering:
                print("DEBUG: urlWeb - VLC player buffering")
                
            case .paused:
                print("DEBUG: urlWeb - VLC player paused")
                
            case .opening:
                print("DEBUG: urlWeb - VLC player opening media")
                
            default:
                print("DEBUG: urlWeb - VLC player state: \(player.state.rawValue)")
            }
        }
    }
}

// MARK: - WKUIDelegate Methods
extension urlWeb: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("DEBUG: urlWeb - JavaScript Alert: \(message)")
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("DEBUG: urlWeb - JavaScript Confirm: \(message)")
        completionHandler(true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        print("DEBUG: urlWeb - JavaScript Prompt: \(prompt)")
        completionHandler(defaultText)
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
        print("DEBUG: urlWeb - WKWebView finished loading navigation")
        
        // Execute JavaScript to check if video loaded properly
        webView.evaluateJavaScript("document.getElementById('videoPlayer') ? 'Video element found' : 'Video element not found'") { result, error in
            if let result = result {
                print("DEBUG: urlWeb - JavaScript result: \(result)")
            }
            if let error = error {
                print("DEBUG: urlWeb - JavaScript error: \(error)")
            }
        }
    }
    
    /// Called when the web view fails to load content during provisional navigation
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        
        print("DEBUG: urlWeb - Provisional navigation failed with error: \(error.localizedDescription)")
        print("DEBUG: urlWeb - Error code: \((error as NSError).code)")
        print("DEBUG: urlWeb - Error domain: \((error as NSError).domain)")
        
        // Check if this is a "plugin handled load" error, which means the media is actually playing
        let nsError = error as NSError
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 204 {
            // Error code 204 means "Plug-in handled load" - this is actually success for media files
            print("DEBUG: urlWeb - Plugin handled load (media playing successfully), suppressing error popup")
            return
        }
        
        // For real errors, show alert
        showAlert(title: "Error", message: error.localizedDescription)
    }

    /// Called when the web view fails to load content
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        
        print("DEBUG: urlWeb - Navigation failed with error: \(error.localizedDescription)")
        print("DEBUG: urlWeb - Error code: \((error as NSError).code)")
        print("DEBUG: urlWeb - Error domain: \((error as NSError).domain)")
        
        // Check if this is a "plugin handled load" error, which means the media is actually playing
        let nsError = error as NSError
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 204 {
            // Error code 204 means "Plug-in handled load" - this is actually success for media files
            print("DEBUG: urlWeb - Plugin handled load (media playing successfully), suppressing error popup")
            return
        }
        
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
            // No fallback available, show error only for real errors
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
}
