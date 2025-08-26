import UIKit
import VLCKit
import AVFoundation

// MARK: - WebMViewController
/// A view controller responsible for playing and optionally downloading WebM videos.
class WebMViewController: UIViewController, VLCMediaPlayerDelegate {
    
    // MARK: - Properties
    /// The URL string of the video to be played.
    var videoURL: String = ""
    /// A flag to control the visibility of the download button.
    var hideDownloadButton: Bool = false
    
    /// Timer for periodic audio checking
    private var audioCheckTimer: Timer?
    
    /// Current mute state - always start muted for privacy/courtesy
    private var isMuted: Bool = true
    /// Timer to monitor playback position and force loop at end
    private var loopCheckTimer: Timer?
    
    // MARK: - UI Elements
    /// The view that displays the video content.
    private lazy var videoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
    }()
    
    /// The VLC media player responsible for playing the video.
    private lazy var vlcPlayer: VLCMediaPlayer = {
        let player = VLCMediaPlayer()
        player.drawable = videoView
        player.audio?.isMuted = true
        player.audio?.volume = 0
        
        print("🎵 DEBUG: WebMViewController - VLC Player created")
        print("🎵 DEBUG: WebMViewController - Initial Audio Muted: \(player.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - Initial Audio Volume: \(player.audio?.volume ?? -1)")
        
        return player
    }()
    
    
    // MARK: - Lifecycle Methods
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("DEBUG: WebMViewController - viewDidLoad started")
        print("DEBUG: WebMViewController - Video URL: \(videoURL)")
        print("DEBUG: WebMViewController - Hide download button: \(hideDownloadButton)")
        
        setupUI()
        setupVideo()
        createWebMDirectory() // Ensure the directory exists
        
        setupNavigationButtons()
        
        // Set navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        
        // Add notification observer for VLC state changes (for loop debug)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(vlcPlayerDidReachEnd),
                                               name: NSNotification.Name("VLCMediaPlayerStateChanged"),
                                               object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // VLC player automatically handles view resizing
    }

    /// Called just before the view controller is dismissed, covered, or otherwise hidden.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Reset navigation bar to default appearance when leaving this view controller
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = defaultAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = defaultAppearance
        navigationController?.navigationBar.compactAppearance = defaultAppearance
        navigationController?.navigationBar.isTranslucent = true
        
        // Stop playback and remove observer
        vlcPlayer.stop()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("VLCMediaPlayerStateChanged"), object: nil)
        
        // Stop periodic audio checking
        stopPeriodicAudioChecking()

        // Stop loop monitoring
        stopLoopMonitoring()
    }
    
    // MARK: - Setup Methods
    /// Sets up the UI elements and layout constraints.
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(videoView)
        
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    /// Initializes the VLC video player with the provided video URL.
    private func setupVideo() {
        print("DEBUG: WebMViewController - setupVideo called with URL: \(videoURL)")
        guard let url = URL(string: videoURL) else { 
            print("DEBUG: WebMViewController - Failed to create URL from string: \(videoURL)")
            return 
        }
        print("DEBUG: WebMViewController - Successfully created URL: \(url)")
        
        
        // VP9 detection for local files only (remote detection handled in urlWeb)
        print("DEBUG: WebMViewController - Checking if this is VP9...")
        var isVP9 = false
        
        if url.isFileURL {
            Task {
                isVP9 = await detectVP9Codec(fileURL: url)
                
                DispatchQueue.main.async {
                    if isVP9 {
                        print("DEBUG: WebMViewController - VP9 codec detected! VLCKit may have compatibility issues.")
                        print("DEBUG: WebMViewController - Consider using WKWebView playback instead for VP9 content.")
                        print("DEBUG: WebMViewController - VP9 codec detected! VLCKit may have compatibility issues.")
                    } else {
                        print("DEBUG: WebMViewController - VP8 or other VLC-compatible codec detected")
                    }
                    
                    // Continue with VLC setup after detection
                    self.setupVLCPlayer(with: url)
                }
            }
            return // Exit early to let async detection complete
        } else {
            // For remote files, we can't easily detect codec without downloading
            print("DEBUG: WebMViewController - Remote file, cannot detect codec beforehand")
        }
        
        // For remote files, continue immediately with VLC setup
        setupVLCPlayer(with: url)
    }
    
    /// Sets up VLC player with the given URL
    private func setupVLCPlayer(with url: URL) {
        // Create VLC media object
        let media = VLCMedia(url: url)
        vlcPlayer.media = media
        
        // Add basic VLC media debugging
        print("DEBUG: WebMViewController - VLC Media created")
        print("DEBUG: WebMViewController - VLC Version: \(VLCLibrary.version())")
        
        // Verify muting before setting delegate
        print("🎵 DEBUG: WebMViewController - Pre-delegate Audio Muted: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - Pre-delegate Audio Volume: \(vlcPlayer.audio?.volume ?? -1)")
        print("🎵 DEBUG: WebMViewController - Audio available: \(vlcPlayer.audio != nil)")
        
        // Set up delegate to handle player events
        vlcPlayer.delegate = self
        
        // NUCLEAR OPTION: Disable audio completely
        isMuted = true
        vlcPlayer.audio?.isMuted = true
        vlcPlayer.audio?.volume = 0
        
        print("🎵 DEBUG: WebMViewController - NUCLEAR AUDIO DISABLING - videos always start muted")
        print("🎵 DEBUG: WebMViewController - Pre-play Audio Muted: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - Pre-play Audio Volume: \(vlcPlayer.audio?.volume ?? -1)")
        
        // Start playback
        print("DEBUG: WebMViewController - Starting VLC playback")
        vlcPlayer.play()
        
        // IMMEDIATE mute enforcement - multiple attempts to catch VLC before audio starts
        // Attempt 1: Immediate
        vlcPlayer.audio?.isMuted = true
        vlcPlayer.audio?.volume = 0
        print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #1")
        
        // Attempt 2: Next run loop
        DispatchQueue.main.async {
            print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #2 (async)")
            self.vlcPlayer.audio?.isMuted = true
            self.vlcPlayer.audio?.volume = 0
        }
        
        // Attempt 3: Microsecond delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #3 (0.001s)")
            self.vlcPlayer.audio?.isMuted = true
            self.vlcPlayer.audio?.volume = 0
        }
        
        // Attempt 4: 5ms delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
            print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #4 (0.005s)")
            self.vlcPlayer.audio?.isMuted = true
            self.vlcPlayer.audio?.volume = 0
        }
        
        // Attempt 5: 10ms delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #5 (0.01s)")
            self.vlcPlayer.audio?.isMuted = true
            self.vlcPlayer.audio?.volume = 0
        }
        
        // Check audio state immediately after play() call
        print("🎵 DEBUG: WebMViewController - Post-play() Audio Muted: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - Post-play() Audio Volume: \(vlcPlayer.audio?.volume ?? -1)")
        
        // Add multiple delayed checks to track when audio settings change
        for delay in [0.1, 0.2, 0.5, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                print("🎵 DEBUG: WebMViewController - \(delay)s delay check - Audio Muted: \(self.vlcPlayer.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - \(delay)s delay check - Audio Volume: \(self.vlcPlayer.audio?.volume ?? -1)")
                print("🎵 DEBUG: WebMViewController - \(delay)s delay check - Player State: \(self.vlcPlayer.state.rawValue)")
                print("🎵 DEBUG: WebMViewController - \(delay)s delay check - isMuted variable: \(self.isMuted)")
                
                // Force mute again if not muted
                if !(self.vlcPlayer.audio?.isMuted ?? true) {
                    print("🎵 DEBUG: WebMViewController - \(delay)s delay - AUDIO NOT MUTED! Forcing mute again")
                    self.vlcPlayer.audio?.isMuted = true
                    self.vlcPlayer.audio?.volume = 0
                    self.isMuted = true
                    print("🎵 DEBUG: WebMViewController - \(delay)s delay - After force mute - Audio Muted: \(self.vlcPlayer.audio?.isMuted ?? false)")
                }
            }
        }

        // Start loop monitoring as a safety net
        startLoopMonitoring()
    }
    
    /// Called when the VLC player state changes.
    @objc func vlcPlayerDidReachEnd(notification: Notification) {
        guard let player = notification.object as? VLCMediaPlayer else { return }
        print("DEBUG: WebMViewController - VLC state changed via Notification: \(player.state.rawValue), position: \(player.position)")
        
        // Robust loop trigger on stop near the end
        if player.state == .stopped && player.position >= 0.99 {
            print("DEBUG: WebMViewController - Detected .stopped near end via Notification, looping")
            player.position = 0.0
            player.play()
        }
    }
    
    /// Sets up navigation bar buttons (mute/unmute and optional download)
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
        
        // Add download button if not hidden
        if !hideDownloadButton {
            let downloadButton = UIBarButtonItem(
                image: UIImage(named: "downloadWV")?.withRenderingMode(.alwaysTemplate),
                style: .plain,
                target: self,
                action: #selector(downloadVideo)
            )
            downloadButton.tintColor = .white
            rightButtons.append(downloadButton)
        }
        
        navigationItem.rightBarButtonItems = rightButtons
    }
    
    /// Returns the appropriate mute button image based on current state
    private func getMuteButtonImage() -> UIImage? {
        let imageName = isMuted ? "speaker.slash" : "speaker.wave.2"
        return UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
    }
    
    /// Creates the directory for storing downloaded WebM files if it doesn't exist.
    private func createWebMDirectory() {
        let fileManager = FileManager.default
        let webmDirectory = getWebMDirectory()
        
        if !fileManager.fileExists(atPath: webmDirectory.path) {
            do {
                try fileManager.createDirectory(at: webmDirectory, withIntermediateDirectories: true)
                print("WebM directory created successfully")
            } catch {
                print("Error creating WebM directory: \(error)")
            }
        } else {
            print("WebM directory already exists")
        }
    }
    
    // MARK: - Audio Control Methods
    /// Toggles the mute/unmute state of the video
    @objc private func toggleMute() {
        print("🎵 DEBUG: WebMViewController - === TOGGLE MUTE CALLED ===")
        print("🎵 DEBUG: WebMViewController - toggleMute() - isMuted BEFORE toggle: \(isMuted)")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Muted BEFORE: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Volume BEFORE: \(vlcPlayer.audio?.volume ?? -1)")
        
        let wasMuted = isMuted
        isMuted.toggle()
        
        print("🎵 DEBUG: WebMViewController - toggleMute() - isMuted AFTER toggle: \(isMuted) (was: \(wasMuted))")
        
        // Apply mute state to VLC player
        vlcPlayer.audio?.isMuted = isMuted
        vlcPlayer.audio?.volume = isMuted ? Int32(0) : Int32(50)
        
        print("🎵 DEBUG: WebMViewController - toggleMute() - Applied settings to VLC")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Muted AFTER: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Volume AFTER: \(vlcPlayer.audio?.volume ?? -1)")
        
        // Update the navigation bar button
        setupNavigationButtons()
        
        print("🎵 DEBUG: WebMViewController - toggleMute() - Updated navigation buttons")
        print("🎵 DEBUG: WebMViewController - === TOGGLE MUTE COMPLETE ===")
    }
    
    // MARK: - Download Methods
    /// Initiates the download of the video when the download button is tapped.
    @objc private func downloadVideo() {
        guard let sourceURL = URL(string: videoURL) else {
            showAlert(message: "Invalid video URL")
            return
        }
        
        let webmDir = getWebMDirectory()
        let filename = sourceURL.lastPathComponent
        let destinationURL = webmDir.appendingPathComponent(filename)
        
        Task {
            await download(url: sourceURL, to: destinationURL)
        }
    }
    
    /// Downloads the video from the given URL to the specified local URL.
    private func download(url: URL, to localUrl: URL) async {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        // Derive a better Referer for 4chan media to avoid rate limits
        if url.host == "i.4cdn.org" {
            let comps = url.pathComponents
            if comps.count > 1 {
                let board = comps[1]
                request.setValue("https://boards.4chan.org/\(board)/", forHTTPHeaderField: "Referer")
                request.setValue("https://boards.4chan.org", forHTTPHeaderField: "Origin")
            }
        } else if let scheme = url.scheme, let host = url.host {
            let origin = "\(scheme)://\(host)"
            request.setValue(origin + "/", forHTTPHeaderField: "Referer")
            request.setValue(origin, forHTTPHeaderField: "Origin")
        }
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        do {
            print("DEBUG: WebMViewController - Starting download: \(url.absoluteString)")
            print("DEBUG: WebMViewController - Headers: \(request.allHTTPHeaderFields ?? [:])")
            let (tempLocalUrl, response) = try await URLSession.shared.download(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DEBUG: WebMViewController - Non-HTTP response: \(response)")
                showAlert(message: "Non-HTTP response during download")
                return
            }
            print("DEBUG: WebMViewController - HTTP status: \(httpResponse.statusCode)")
            print("DEBUG: WebMViewController - Response headers: \(httpResponse.allHeaderFields)")
            guard (200...299).contains(httpResponse.statusCode) else {
                showAlert(message: "Failed to download video (status: \(httpResponse.statusCode))")
                return
            }
            
            // Ensure destination directory exists and no conflicting file remains
            let dir = localUrl.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            if FileManager.default.fileExists(atPath: localUrl.path) {
                try? FileManager.default.removeItem(at: localUrl)
            }
            try FileManager.default.moveItem(at: tempLocalUrl, to: localUrl)
            let attrs = try? FileManager.default.attributesOfItem(atPath: localUrl.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
            print("DEBUG: WebMViewController - Saved file size: \(size) bytes at \(localUrl.path)")
            
            // Download and save API thumbnail for the downloaded video
            await downloadAndSaveThumbnail(originalURL: url, localURL: localUrl)
            
            showAlert(message: "WebM downloaded")
        } catch {
            let nsErr = error as NSError
            print("DEBUG: WebMViewController - Download failed: \(error.localizedDescription) (code=\(nsErr.code), domain=\(nsErr.domain))")
            if let urlErr = error as? URLError {
                print("DEBUG: WebMViewController - URLError code: \(urlErr.code)")
            }
            showAlert(message: "Download failed: \(error.localizedDescription)")
        }
    }
    
    /// Returns the URL of the directory where WebM files are stored.
    private func getWebMDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("webm", isDirectory: true)
    }
    
    /// Downloads and saves the API thumbnail for the downloaded media file
    private func downloadAndSaveThumbnail(originalURL: URL, localURL: URL) async {
        print("DEBUG: WebMViewController - Downloading API thumbnail for: \(originalURL.absoluteString)")
        
        // Download the API thumbnail
        if let thumbnailURL = getThumbnailURL(from: originalURL),
           let thumbnailData = await downloadThumbnailData(from: thumbnailURL) {
            saveThumbnail(thumbnailData, for: localURL)
            print("DEBUG: WebMViewController - API thumbnail saved successfully")
        } else {
            print("DEBUG: WebMViewController - Failed to download API thumbnail")
        }
    }
    
    /// Generates the thumbnail URL from a media URL (using 4chan API format)
    private func getThumbnailURL(from mediaURL: URL) -> URL? {
        let urlString = mediaURL.absoluteString
        
        if urlString.hasSuffix(".webm") || urlString.hasSuffix(".mp4") {
            // For videos: replace .webm/.mp4 with s.jpg
            let components = urlString.components(separatedBy: "/")
            if let last = components.last {
                let fileExtension = mediaURL.pathExtension.lowercased()
                let base = last.replacingOccurrences(of: ".\(fileExtension)", with: "")
                let thumbnailURLString = urlString.replacingOccurrences(of: last, with: "\(base)s.jpg")
                return URL(string: thumbnailURLString)
            }
        } else {
            // For images: add 's' before the extension
            let components = urlString.components(separatedBy: "/")
            if let last = components.last, let dot = last.firstIndex(of: ".") {
                let filename = String(last[..<dot]) + "s.jpg"
                let thumbnailURLString = urlString.replacingOccurrences(of: last, with: filename)
                return URL(string: thumbnailURLString)
            }
        }
        
        return nil
    }
    
    /// Downloads thumbnail data from the API
    private func downloadThumbnailData(from thumbnailURL: URL) async -> Data? {
        do {
            var request = URLRequest(url: thumbnailURL)
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            
            // Set appropriate headers for 4chan
            if thumbnailURL.host == "i.4cdn.org" {
                let comps = thumbnailURL.pathComponents
                if comps.count > 1 {
                    let board = comps[1]
                    request.setValue("https://boards.4chan.org/\(board)/", forHTTPHeaderField: "Referer")
                    request.setValue("https://boards.4chan.org", forHTTPHeaderField: "Origin")
                }
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("DEBUG: WebMViewController - Failed to download thumbnail, status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            
            return data
        } catch {
            print("DEBUG: WebMViewController - Error downloading thumbnail: \(error)")
            return nil
        }
    }
    
    /// Saves thumbnail data to a hidden file alongside the media file
    @discardableResult
    private func saveThumbnail(_ thumbnailData: Data, for mediaURL: URL) -> URL? {
        var thumbnailURL = getLocalThumbnailURL(for: mediaURL)
        
        do {
            // Ensure directory exists
            let directory = thumbnailURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            
            // Write thumbnail data
            try thumbnailData.write(to: thumbnailURL)
            
            // Hide the thumbnail file
            var resourceValues = URLResourceValues()
            resourceValues.isHidden = true
            try thumbnailURL.setResourceValues(resourceValues)
            
            print("DEBUG: WebMViewController - Saved thumbnail: \(thumbnailURL.path)")
            return thumbnailURL
        } catch {
            print("DEBUG: WebMViewController - Failed to save thumbnail: \(error)")
            return nil
        }
    }
    
    /// Gets the URL where a thumbnail should be stored for a given media file
    private func getLocalThumbnailURL(for mediaURL: URL) -> URL {
        let directory = mediaURL.deletingLastPathComponent()
        let fileName = mediaURL.deletingPathExtension().lastPathComponent
        let thumbnailFileName = ".\(fileName).thumbnail.png" // Hidden file with dot prefix
        return directory.appendingPathComponent(thumbnailFileName)
    }
    
    // MARK: - Helper Methods
    /// Displays an alert with the specified message.
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Periodic Audio Checking
    /// Starts periodic checking of audio state to catch any unmuting
    private func startPeriodicAudioChecking() {
        print("🎵 DEBUG: WebMViewController - Starting periodic audio checking")
        audioCheckTimer?.invalidate()
        audioCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAndEnforceAudioMuting()
        }
    }
    
    /// Stops periodic audio checking
    private func stopPeriodicAudioChecking() {
        print("🎵 DEBUG: WebMViewController - Stopping periodic audio checking")
        audioCheckTimer?.invalidate()
        audioCheckTimer = nil
    }
    
    /// Checks current audio state and enforces user's mute preference
    private func checkAndEnforceAudioMuting() {
        let playerIsMuted = vlcPlayer.audio?.isMuted ?? false
        let playerVolume = vlcPlayer.audio?.volume ?? -1
        
        print("🎵 DEBUG: WebMViewController - Periodic check - Player Muted: \(playerIsMuted), Player Volume: \(playerVolume), User Preference: \(isMuted)")
        
        // Enforce user's mute preference
        let expectedVolume = isMuted ? Int32(0) : Int32(50)
        if playerIsMuted != isMuted || playerVolume != expectedVolume {
            print("🎵 DEBUG: WebMViewController - Enforcing user mute preference...")
            vlcPlayer.audio?.isMuted = isMuted
            vlcPlayer.audio?.volume = expectedVolume
            print("🎵 DEBUG: WebMViewController - Applied user preference - Audio Muted: \(vlcPlayer.audio?.isMuted ?? false), Volume: \(vlcPlayer.audio?.volume ?? -1)")
        }
    }
    
    /// Detects if a WebM file uses VP9 codec using AVAsset
    private func detectVP9Codec(fileURL: URL) async -> Bool {
        do {
            let asset = AVAsset(url: fileURL)
            
            // Load the tracks asynchronously
            let tracks = try await asset.loadTracks(withMediaType: .video)
            
            guard let videoTrack = tracks.first else {
                print("DEBUG: WebMViewController - No video track found in asset")
                return false
            }
            
            // Load format descriptions from the track
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            
            for formatDesc in formatDescriptions {
                // Get the media subtype (codec)
                let mediaSubtype = CMFormatDescriptionGetMediaSubType(formatDesc)
                
                // Convert to string for logging
                let codecString = String(format: "%c%c%c%c", 
                    (mediaSubtype >> 24) & 255,
                    (mediaSubtype >> 16) & 255, 
                    (mediaSubtype >> 8) & 255,
                    mediaSubtype & 255)
                
                print("DEBUG: WebMViewController - Found video codec: \(codecString), fourCC: \(mediaSubtype)")
                
                // VP9 codec fourCC codes
                let vp90 = FourCharCode(0x76703930) // 'vp90'
                let vp09 = FourCharCode(0x76703039) // 'vp09'
                
                if mediaSubtype == vp90 || mediaSubtype == vp09 {
                    print("DEBUG: WebMViewController - VP9 codec confirmed via AVAsset")
                    return true
                }
            }
            
            print("DEBUG: WebMViewController - No VP9 codec detected via AVAsset")
            return false
            
        } catch {
            print("DEBUG: WebMViewController - Error detecting codec with AVAsset: \(error)")
            // Fallback to false - let VLC try to play it
            return false
        }
    }
}

// MARK: - VLCMediaPlayerDelegate
extension WebMViewController {
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("DEBUG: WebMViewController - VLC State changed to: \(player.state.rawValue)")
            
            // Basic media information when media changes
            if let media = player.media {
                print("DEBUG: WebMViewController - Media info:")
                print("  - Duration: \(media.length.value)ms")
            }
            
            switch player.state {
            case .playing:
                print("DEBUG: WebMViewController - VLC player started playing")
                print("🎵 DEBUG: WebMViewController - === PLAYING STATE ENTERED ===")
                
                // Check audio state before applying preference
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Muted BEFORE: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Volume BEFORE: \(player.audio?.volume ?? -1)")
                print("🎵 DEBUG: WebMViewController - Playing state - isMuted variable BEFORE: \(self.isMuted)")
                print("🎵 DEBUG: WebMViewController - Playing state - Audio object available: \(player.audio != nil)")
                
                // PROGRAMMATICALLY trigger the mute button to ensure consistent muting behavior
                // This addresses the timing issue where VLC might start playing before muting is fully applied
                if !self.isMuted {
                    print("🎵 DEBUG: WebMViewController - isMuted is false - Programmatically triggering mute button on play start")
                    self.toggleMute() // This will set isMuted to true and apply all muting logic
                    print("🎵 DEBUG: WebMViewController - After toggleMute() - isMuted: \(self.isMuted)")
                    print("🎵 DEBUG: WebMViewController - After toggleMute() - Audio Muted: \(player.audio?.isMuted ?? false)")
                    print("🎵 DEBUG: WebMViewController - After toggleMute() - Audio Volume: \(player.audio?.volume ?? -1)")
                } else {
                    // Even if already marked as muted, force apply the muting to be absolutely sure
                    print("🎵 DEBUG: WebMViewController - isMuted is true - Already marked as muted, but force-applying muting logic")
                    player.audio?.isMuted = true
                    player.audio?.volume = 0
                    print("🎵 DEBUG: WebMViewController - After force apply - Audio Muted: \(player.audio?.isMuted ?? false)")
                    print("🎵 DEBUG: WebMViewController - After force apply - Audio Volume: \(player.audio?.volume ?? -1)")
                    // Update navigation button to reflect muted state
                    self.setupNavigationButtons()
                }
                
                // IMMEDIATE audio check after delegate processing
                print("🎵 DEBUG: WebMViewController - IMMEDIATE check after delegate logic:")
                print("🎵 DEBUG: WebMViewController - IMMEDIATE - Audio Muted: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - IMMEDIATE - Audio Volume: \(player.audio?.volume ?? -1)")
                print("🎵 DEBUG: WebMViewController - IMMEDIATE - isMuted variable: \(self.isMuted)")
                
                // Additional safety measure: programmatically trigger mute after multiple delays
                for delay in [0.05, 0.1, 0.2, 0.5] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self = self else { return }
                        print("🎵 DEBUG: WebMViewController - \(delay)s delegate delay check - Audio Muted: \(player.audio?.isMuted ?? false)")
                        print("🎵 DEBUG: WebMViewController - \(delay)s delegate delay check - Audio Volume: \(player.audio?.volume ?? -1)")
                        print("🎵 DEBUG: WebMViewController - \(delay)s delegate delay check - isMuted variable: \(self.isMuted)")
                        
                        if !self.isMuted {
                            print("🎵 DEBUG: WebMViewController - \(delay)s delegate delay - isMuted is false, triggering toggleMute()")
                            self.toggleMute()
                        }
                        
                        // ALWAYS force apply muting regardless of state - this is our nuclear option
                        let wasMuted = player.audio?.isMuted ?? false
                        let wasVolume = player.audio?.volume ?? -1
                        player.audio?.isMuted = true
                        player.audio?.volume = 0
                        print("🎵 DEBUG: WebMViewController - \(delay)s NUCLEAR FORCE MUTE - Before: muted=\(wasMuted), volume=\(wasVolume)")
                        print("🎵 DEBUG: WebMViewController - \(delay)s NUCLEAR FORCE MUTE - After: muted=\(player.audio?.isMuted ?? false), volume=\(player.audio?.volume ?? -1)")
                    }
                }
                
                // Verify forced muting was applied
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Muted AFTER: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Volume AFTER: \(player.audio?.volume ?? -1)")
                print("🎵 DEBUG: WebMViewController - === PLAYING STATE PROCESSING COMPLETE ===")
                
                // Get more detailed playback information
                print("DEBUG: WebMViewController - Player info:")
                print("  - Position: \(player.position)")
                print("  - Time: \(player.time.value)ms")
                print("  - Length: \(player.media?.length.value ?? 0)ms")
                print("  - Rate: \(player.rate)")
                print("  - Has Video Output: \(player.hasVideoOut)")
                print("  - Video Size: \(player.videoSize)")
                print("  - Audio Muted: \(player.audio?.isMuted ?? false)")
                print("  - Audio Volume: \(player.audio?.volume ?? -1)")
                
                // Start periodic audio checking
                self.startPeriodicAudioChecking()

                // Also start loop monitoring while playing
                self.startLoopMonitoring()
                
            case .stopped:
                print("DEBUG: WebMViewController - VLC player stopped")
                let pos = player.position
                print("DEBUG: WebMViewController - VLC stopped at position: \(pos)")
                if pos >= 0.99 {
                    print("DEBUG: WebMViewController - Looping VLC video from .stopped state")
                    player.position = 0.0
                    player.play()
                }
                
            case .error:
                print("DEBUG: WebMViewController - VLC player error")
                
                // Try to get more error details
                if let media = player.media {
                    print("DEBUG: WebMViewController - Media available on error")
                } else {
                    print("DEBUG: WebMViewController - No media available on error")
                }
                
                self.showAlert(message: "Failed to play video with VLC player - check console for details")
                
            case .buffering:
                print("DEBUG: WebMViewController - VLC player buffering")
                print("🎵 DEBUG: WebMViewController - === BUFFERING STATE ENTERED ===")
                
                // CRITICAL: VLC can start playing audio during buffering - force mute immediately
                print("🎵 DEBUG: WebMViewController - Buffering state - Audio Muted BEFORE: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Buffering state - Audio Volume BEFORE: \(player.audio?.volume ?? -1)")
                
                // NUCLEAR OPTION: Disable audio completely during buffering
                self.isMuted = true
                player.audio?.isMuted = true
                player.audio?.volume = 0
                
                print("🎵 DEBUG: WebMViewController - Buffering state - NUCLEAR AUDIO DISABLE APPLIED")
                print("🎵 DEBUG: WebMViewController - Buffering state - Audio Muted AFTER: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Buffering state - Audio Volume AFTER: \(player.audio?.volume ?? -1)")
                
                // Update navigation button to reflect muted state
                self.setupNavigationButtons()
                
            case .paused:
                print("DEBUG: WebMViewController - VLC player paused")
                
            case .opening:
                print("DEBUG: WebMViewController - VLC player opening media")
                
            default:
                print("DEBUG: WebMViewController - VLC player state: \(player.state.rawValue)")
            }
        }
    }

    // MARK: - Loop Monitoring
    private func startLoopMonitoring() {
        print("DEBUG: WebMViewController - Starting loop monitoring timer")
        loopCheckTimer?.invalidate()
        loopCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let pos = self.vlcPlayer.position
            let state = self.vlcPlayer.state
            print("DEBUG: WebMViewController - Loop monitor tick - state: \(state.rawValue), position: \(pos)")
            if pos >= 0.995 || (state == .stopped && pos >= 0.8) {
                print("DEBUG: WebMViewController - Loop monitor: looping video (seek to 0 + play)")
                self.vlcPlayer.position = 0.0
                self.vlcPlayer.play()
            }
        }
    }

    private func stopLoopMonitoring() {
        print("DEBUG: WebMViewController - Stopping loop monitoring timer")
        loopCheckTimer?.invalidate()
        loopCheckTimer = nil
    }
}
