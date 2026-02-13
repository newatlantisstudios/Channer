import UIKit
import AVFoundation
import VLCKit

// MARK: - SeekSlider
/// UISlider subclass that reliably detects tracking start/end on all platforms including Mac Catalyst,
/// where standard .touchDown/.touchUpInside control events don't fire for mouse/trackpad input.
private class SeekSlider: UISlider {
    var onTrackingBegan: (() -> Void)?
    var onTrackingEnded: (() -> Void)?

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let result = super.beginTracking(touch, with: event)
        if result {
            onTrackingBegan?()
        }
        return result
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        onTrackingEnded?()
    }
}

// MARK: - WebMViewController
/// A view controller responsible for playing and optionally downloading WebM videos.
class WebMViewController: UIViewController, VLCMediaPlayerDelegate {

    // MARK: - Properties
    /// The URL string of the video to be played.
    var videoURL: String = ""
    /// A flag to control the visibility of the download button.
    var hideDownloadButton: Bool = false

    /// Array of video URLs for navigation (optional - enables left/right navigation)
    var videoURLs: [URL] = []
    /// Current index in the videoURLs array
    var currentIndex: Int = 0

    /// Timer for periodic audio checking
    private var audioCheckTimer: Timer?
    /// Timer for aggressive mute enforcement on playback start
    private var aggressiveMuteTimer: Timer?
    /// Tracks audio track count changes during aggressive enforcement
    private var aggressiveMuteLastTrackCount: Int = -1
    /// Duration for aggressive mute enforcement on playback start
    private let aggressiveMuteDuration: TimeInterval = 1.0
    /// Interval for aggressive mute enforcement ticks
    private let aggressiveMuteInterval: TimeInterval = 0.05

    /// Current mute state - default comes from settings
    private var isMuted: Bool = MediaSettings.defaultMuted
    /// Remembers the preferred audio track so we can re-enable it after mute
    private var preferredAudioTrackIndex: Int?
    /// Force muting when playback begins for a new item
    private var shouldForceMuteOnNextPlay: Bool = MediaSettings.defaultMuted
    /// Timer to monitor playback position and force loop at end
    private var loopCheckTimer: Timer?
    /// Timer to update seek bar position
    private var seekBarUpdateTimer: Timer?
    /// Flag to prevent seek bar updates while user is dragging
    private var isSeeking: Bool = false
    /// Timestamp of last seek to prevent slider snap-back
    private var lastSeekTime: Date?
    /// Cached actual duration calculated from position/time (for videos with incorrect metadata)
    private var calculatedDurationMs: Int32 = 0

    /// Timer for auto-hiding controls
    private var controlsHideTimer: Timer?
    /// Flag to track if controls are currently visible
    private var controlsVisible: Bool = true
    /// Duration before controls auto-hide (in seconds)
    private let controlsHideDelay: TimeInterval = 1.5

    // MARK: - AVPlayer Properties (for Mac Catalyst converted playback)
    /// Whether the current video is being played via AVPlayer (converted MP4)
    private var isUsingAVPlayer: Bool = false
    /// Native AVPlayer for converted MP4 playback on Mac Catalyst
    private lazy var avPlayer: AVPlayer = {
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true
        let startMuted = MediaSettings.defaultMuted
        player.isMuted = startMuted
        player.volume = startMuted ? 0.0 : 0.5
        return player
    }()
    /// AVPlayerLayer for rendering converted video
    private lazy var avPlayerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer(player: avPlayer)
        layer.videoGravity = .resizeAspect
        return layer
    }()
    /// Observer for AVPlayer end-of-playback notification
    private var avPlayerEndObserver: NSObjectProtocol?
    /// Time observer for AVPlayer seek bar updates
    private var avPlayerTimeObserver: Any?
    /// KVO observation for avPlayerLayer.isReadyForDisplay
    private var layerReadyObservation: NSKeyValueObservation?

    // MARK: - Conversion Progress Bar UI
    /// Thin track bar shown during WebM-to-MP4 conversion
    private lazy var conversionProgressTrack: UIView = {
        let track = UIView()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        track.layer.cornerRadius = 1.5
        track.clipsToBounds = true
        track.isHidden = true
        return track
    }()
    /// White fill bar showing determinate conversion progress
    private lazy var conversionProgressFill: UIView = {
        let fill = UIView()
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        fill.layer.cornerRadius = 1.5
        return fill
    }()
    /// Shimmer bar for indeterminate loading state
    private lazy var conversionShimmer: UIView = {
        let shimmer = UIView()
        shimmer.translatesAutoresizingMaskIntoConstraints = false
        shimmer.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        return shimmer
    }()
    /// Width constraint for the progress fill bar
    private var conversionProgressFillWidth: NSLayoutConstraint?
    /// Tracks whether conversion is currently in progress
    private var isConversionInProgress = false
    /// Tracks whether conversion was active when viewWillDisappear fired
    private var wasConvertingWhenDisappeared = false
    /// Generation counter to ignore stale conversion callbacks after rapid navigation
    private var conversionGeneration: Int = 0

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
        let startMuted = MediaSettings.defaultMuted
        player.audio?.isMuted = startMuted
        player.audio?.volume = startMuted ? 0 : 50
        
        print("🎵 DEBUG: WebMViewController - VLC Player created")
        print("🎵 DEBUG: WebMViewController - Initial Audio Muted: \(player.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - Initial Audio Volume: \(player.audio?.volume ?? -1)")

        return player
    }()

    /// Container view for seek bar controls
    private lazy var seekBarContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()

    /// Seek bar slider (SeekSlider subclass for reliable tracking on Mac Catalyst)
    private lazy var seekBar: SeekSlider = {
        let slider = SeekSlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.thumbTintColor = .white
        slider.addTarget(self, action: #selector(seekBarValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(seekBarTouchDown(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(seekBarTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        // beginTracking/endTracking callbacks work reliably on all platforms including Mac Catalyst
        slider.onTrackingBegan = { [weak self] in
            self?.isSeeking = true
            self?.stopControlsHideTimer()
        }
        slider.onTrackingEnded = { [weak self] in
            guard let self = self else { return }
            self.seekBarTouchUp(self.seekBar)
        }
        return slider
    }()

    /// Current time label
    private lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.text = "0:00"
        label.textAlignment = .left
        return label
    }()

    /// Duration label
    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.text = "0:00"
        label.textAlignment = .right
        return label
    }()

    /// Play/pause button (centered on video)
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
        button.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 40
        button.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        return button
    }()

    /// Upper tap zone for navigation to previous video
    private lazy var upTapZone: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(upTapZoneTapped))
        view.addGestureRecognizer(tap)
        return view
    }()

    /// Lower tap zone for navigation to next video
    private lazy var downTapZone: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(downTapZoneTapped))
        view.addGestureRecognizer(tap)
        return view
    }()

    /// Up navigation hint (chevron)
    private lazy var upHint: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.up.circle.fill"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = UIColor.white.withAlphaComponent(0.7)
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0
        return imageView
    }()

    /// Down navigation hint (chevron)
    private lazy var downHint: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.down.circle.fill"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = UIColor.white.withAlphaComponent(0.7)
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0
        return imageView
    }()

    /// Media counter label showing current position
    private lazy var mediaCounterLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    // MARK: - Keyboard Shortcuts
    override var keyCommands: [UIKeyCommand]? {
        guard supportsHardwareNavigation,
              videoURLs.count > 1 else {
            return nil
        }

        let nextVideoCommand = UIKeyCommand(input: UIKeyCommand.inputDownArrow,
                                            modifierFlags: [],
                                            action: #selector(nextVideoShortcut))
        nextVideoCommand.discoverabilityTitle = "Next Video"
        if #available(iOS 15.0, *) {
            nextVideoCommand.wantsPriorityOverSystemBehavior = true
        }

        let previousVideoCommand = UIKeyCommand(input: UIKeyCommand.inputUpArrow,
                                                modifierFlags: [],
                                                action: #selector(previousVideoShortcut))
        previousVideoCommand.discoverabilityTitle = "Previous Video"
        if #available(iOS 15.0, *) {
            previousVideoCommand.wantsPriorityOverSystemBehavior = true
        }

        return [nextVideoCommand, previousVideoCommand]
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    // MARK: - Lifecycle Methods
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("DEBUG: WebMViewController - viewDidLoad started")
        print("DEBUG: WebMViewController - Video URL: \(videoURL)")
        print("DEBUG: WebMViewController - Hide download button: \(hideDownloadButton)")
        print("MUTE DEBUG: viewDidLoad isMuted=\(isMuted) shouldForceMuteOnNextPlay=\(shouldForceMuteOnNextPlay)")
        
        setupUI()
        setupVideo()
        createWebMDirectory() // Ensure the directory exists

        setupNavigationButtons()
        setupNavigationUI() // Setup left/right navigation for multiple videos
        
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update AVPlayerLayer frame when layout changes (rotation, etc.)
        if isUsingAVPlayer {
            avPlayerLayer.frame = videoView.bounds
        }
    }

    /// Called just before the view controller is dismissed, covered, or otherwise hidden.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Use transition coordinator to handle interactive pop gesture cancellation
        if let transitionCoordinator = transitionCoordinator {
            transitionCoordinator.notifyWhenInteractionChanges { [weak self] context in
                guard let self = self else { return }

                if context.isCancelled {
                    // Gesture was cancelled - restore navigation bar appearance
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = .black
                    appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
                    self.navigationController?.navigationBar.standardAppearance = appearance
                    self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
                    self.navigationController?.navigationBar.compactAppearance = appearance
                    self.navigationController?.navigationBar.isTranslucent = false

                    // Restore navigation bar hidden state based on controls visibility
                    if !self.controlsVisible {
                        self.navigationController?.setNavigationBarHidden(true, animated: false)
                    }

                    // Restart video playback and restore audio state
                    self.resumePlaybackAfterCancelledTransition()
                }
            }
        }

        // Restore navigation bar visibility and default appearance when leaving
        navigationController?.setNavigationBarHidden(false, animated: animated)
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = defaultAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = defaultAppearance
        navigationController?.navigationBar.compactAppearance = defaultAppearance
        navigationController?.navigationBar.isTranslucent = true

        // Track whether conversion was in-flight before cancelling
        wasConvertingWhenDisappeared = isConversionInProgress

        // Cancel any active WebM conversion
        WebMConversionService.shared.cancelConversion()
        hideConversionOverlay()

        if isUsingAVPlayer {
            // Clean up AVPlayer
            cleanupAVPlayer()
        } else {
            // Detach drawable and delegate before stopping to prevent VLCSampleBufferDisplay
            // from dispatching blocks that reference freed resources (EXC_BAD_ACCESS crash)
            vlcPlayer.delegate = nil
            vlcPlayer.drawable = nil
            vlcPlayer.stop()
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("VLCMediaPlayerStateChanged"), object: nil)

            // Stop periodic audio checking
            stopPeriodicAudioChecking()

            // Stop aggressive mute enforcement
            stopAggressiveMuteEnforcement()

            // Stop loop monitoring
            stopLoopMonitoring()
        }

        // Stop seek bar updates
        stopSeekBarUpdates()
        stopAVPlayerSeekBarUpdates()

        // Stop controls hide timer
        stopControlsHideTimer()
    }
    
    // MARK: - Setup Methods
    /// Sets up the UI elements and layout constraints.
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(videoView)
        view.addSubview(seekBarContainer)

        // Add seek bar elements to container (play/pause button moved to center of video)
        seekBarContainer.addSubview(currentTimeLabel)
        seekBarContainer.addSubview(seekBar)
        seekBarContainer.addSubview(durationLabel)

        // Add play/pause button centered on video view
        view.addSubview(playPauseButton)

        // Add tap gesture to video view for play/pause
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoViewTapped))
        videoView.addGestureRecognizer(tapGesture)

        // Add navigation tap zones (only if we have multiple videos)
        view.addSubview(upTapZone)
        view.addSubview(downTapZone)
        view.addSubview(upHint)
        view.addSubview(downHint)
        view.addSubview(mediaCounterLabel)

        // Add conversion progress bar (above seek bar)
        view.addSubview(conversionProgressTrack)
        conversionProgressTrack.addSubview(conversionProgressFill)
        conversionProgressTrack.addSubview(conversionShimmer)

        // Ensure seek bar container is above tap zones so mouse clicks reach the slider on Catalyst
        view.bringSubviewToFront(seekBarContainer)

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Seek bar container overlays the bottom of the video
            seekBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            seekBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            seekBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            seekBarContainer.heightAnchor.constraint(equalToConstant: 44),

            // Play/pause button centered on video
            playPauseButton.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            playPauseButton.heightAnchor.constraint(equalToConstant: 80),

            // Current time label (now at leading edge since play/pause moved)
            currentTimeLabel.leadingAnchor.constraint(equalTo: seekBarContainer.leadingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: seekBarContainer.centerYAnchor),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 45),

            // Seek bar slider
            seekBar.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            seekBar.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            seekBar.centerYAnchor.constraint(equalTo: seekBarContainer.centerYAnchor),

            // Duration label
            durationLabel.trailingAnchor.constraint(equalTo: seekBarContainer.trailingAnchor, constant: -12),
            durationLabel.centerYAnchor.constraint(equalTo: seekBarContainer.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 45),

            // Up tap zone (25% of height at top)
            upTapZone.topAnchor.constraint(equalTo: videoView.topAnchor),
            upTapZone.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            upTapZone.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            upTapZone.heightAnchor.constraint(equalTo: videoView.heightAnchor, multiplier: 0.25),

            // Down tap zone (25% of height at bottom)
            downTapZone.bottomAnchor.constraint(equalTo: videoView.bottomAnchor),
            downTapZone.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            downTapZone.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            downTapZone.heightAnchor.constraint(equalTo: videoView.heightAnchor, multiplier: 0.25),

            // Up hint (centered in upper tap zone)
            upHint.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            upHint.centerYAnchor.constraint(equalTo: upTapZone.centerYAnchor),
            upHint.widthAnchor.constraint(equalToConstant: 44),
            upHint.heightAnchor.constraint(equalToConstant: 44),

            // Down hint (centered in lower tap zone)
            downHint.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            downHint.centerYAnchor.constraint(equalTo: downTapZone.centerYAnchor),
            downHint.widthAnchor.constraint(equalToConstant: 44),
            downHint.heightAnchor.constraint(equalToConstant: 44),

            // Media counter label (top center)
            mediaCounterLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            mediaCounterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mediaCounterLabel.heightAnchor.constraint(equalToConstant: 28),
            mediaCounterLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            // Conversion progress bar (slim bar above seek bar)
            conversionProgressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            conversionProgressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            conversionProgressTrack.bottomAnchor.constraint(equalTo: seekBarContainer.topAnchor, constant: -12),
            conversionProgressTrack.heightAnchor.constraint(equalToConstant: 3),

            conversionProgressFill.leadingAnchor.constraint(equalTo: conversionProgressTrack.leadingAnchor),
            conversionProgressFill.topAnchor.constraint(equalTo: conversionProgressTrack.topAnchor),
            conversionProgressFill.bottomAnchor.constraint(equalTo: conversionProgressTrack.bottomAnchor),

            conversionShimmer.topAnchor.constraint(equalTo: conversionProgressTrack.topAnchor),
            conversionShimmer.bottomAnchor.constraint(equalTo: conversionProgressTrack.bottomAnchor),
            conversionShimmer.widthAnchor.constraint(equalTo: conversionProgressTrack.widthAnchor, multiplier: 0.3)
        ])

        // Set initial zero-width for progress fill
        let fillWidth = conversionProgressFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth.isActive = true
        conversionProgressFillWidth = fillWidth
    }

    /// Initializes the video player with the provided video URL.
    /// On Mac Catalyst with WebM files, converts to MP4 first and uses AVPlayer.
    /// On iOS/iPadOS, uses VLCKit directly.
    private func setupVideo() {
        print("DEBUG: WebMViewController - setupVideo called with URL: \(videoURL)")
        guard let url = URL(string: videoURL) else {
            print("DEBUG: WebMViewController - Failed to create URL from string: \(videoURL)")
            return
        }
        print("DEBUG: WebMViewController - Successfully created URL: \(url)")

        // Mac Catalyst: convert WebM to MP4 and use native AVPlayer
        if WebMConversionService.shared.needsConversion(url: url) {
            isUsingAVPlayer = true
            conversionGeneration += 1
            let expectedGeneration = conversionGeneration
            showConversionOverlay()

            WebMConversionService.shared.convertWebMToMP4(source: url, progress: { [weak self] progressValue in
                guard let self = self, self.conversionGeneration == expectedGeneration else { return }
                // Stop shimmer when first determinate progress arrives
                if progressValue > 0 {
                    self.conversionShimmer.layer.removeAllAnimations()
                    self.conversionShimmer.isHidden = true
                }
                let trackWidth = self.conversionProgressTrack.bounds.width
                self.conversionProgressFillWidth?.constant = CGFloat(progressValue) * trackWidth
                UIView.animate(withDuration: 0.2) {
                    self.conversionProgressTrack.layoutIfNeeded()
                }
            }) { [weak self] result in
                guard let self = self else { return }
                // Ignore stale callbacks from cancelled conversions after rapid navigation
                guard self.conversionGeneration == expectedGeneration else { return }
                switch result {
                case .success(let mp4URL):
                    // Fill progress bar to 100%; setupAVPlayer will hide it once video renders
                    self.conversionShimmer.layer.removeAllAnimations()
                    self.conversionShimmer.isHidden = true
                    self.conversionProgressFillWidth?.constant = self.conversionProgressTrack.bounds.width
                    self.conversionProgressTrack.layoutIfNeeded()
                    self.setupAVPlayer(with: mp4URL)
                case .failure(let error):
                    self.hideConversionOverlay()
                    print("DEBUG: WebMViewController - Conversion failed: \(error), falling back to VLC")
                    self.isUsingAVPlayer = false
                    self.setupVLCPlayer(with: url)
                }
            }
            return
        }

        // iOS/iPadOS: VP9 detection for local files only (remote detection handled in urlWeb)
        isUsingAVPlayer = false
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

    private func resumePlaybackAfterCancelledTransition() {
        if isUsingAVPlayer {
            // If conversion was in-flight when the gesture started, restart it
            if wasConvertingWhenDisappeared {
                wasConvertingWhenDisappeared = false
                guard let url = URL(string: videoURL) else { return }
                conversionGeneration += 1
                let expectedGeneration = conversionGeneration
                showConversionOverlay()
                WebMConversionService.shared.convertWebMToMP4(source: url, progress: { [weak self] progressValue in
                    guard let self = self, self.conversionGeneration == expectedGeneration else { return }
                    if progressValue > 0 {
                        self.conversionShimmer.layer.removeAllAnimations()
                        self.conversionShimmer.isHidden = true
                    }
                    let trackWidth = self.conversionProgressTrack.bounds.width
                    self.conversionProgressFillWidth?.constant = CGFloat(progressValue) * trackWidth
                    UIView.animate(withDuration: 0.2) {
                        self.conversionProgressTrack.layoutIfNeeded()
                    }
                }) { [weak self] result in
                    guard let self = self, self.conversionGeneration == expectedGeneration else { return }
                    switch result {
                    case .success(let mp4URL):
                        self.conversionShimmer.layer.removeAllAnimations()
                        self.conversionShimmer.isHidden = true
                        self.conversionProgressFillWidth?.constant = self.conversionProgressTrack.bounds.width
                        self.conversionProgressTrack.layoutIfNeeded()
                        self.setupAVPlayer(with: mp4URL)
                    case .failure(let error):
                        self.hideConversionOverlay()
                        print("DEBUG: WebMViewController - Conversion failed after resume: \(error), falling back to VLC")
                        self.isUsingAVPlayer = false
                        if let url = URL(string: self.videoURL) {
                            self.setupVLCPlayer(with: url)
                        }
                    }
                }
                setupNavigationButtons()
                return
            }
            avPlayer.play()
            startAVPlayerSeekBarUpdates()
            resetControlsHideTimer()
            setupNavigationButtons()
            return
        }

        // Restore observer removed in viewWillDisappear
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("VLCMediaPlayerStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(vlcPlayerDidReachEnd),
                                               name: NSNotification.Name("VLCMediaPlayerStateChanged"),
                                               object: nil)

        if isMuted {
            shouldForceMuteOnNextPlay = true
            disableAudioTracksForMutedStart()
            startAggressiveMuteEnforcement(reason: "interactive-cancel")
        } else {
            shouldForceMuteOnNextPlay = false
            stopAggressiveMuteEnforcement()
            enableAudioTracksForUnmute()
        }

        vlcPlayer.play()
        startLoopMonitoring()
        startPeriodicAudioChecking()
        startSeekBarUpdates()
        resetControlsHideTimer()
        setupNavigationButtons()
    }
    
    /// Sets up VLC player with the given URL
    private func setupVLCPlayer(with url: URL) {
        // Restore drawable in case it was nilled during cleanup
        vlcPlayer.drawable = videoView

        // Create VLC media object
        let media = VLCMedia(url: url)
        vlcPlayer.media = media
        print("MUTE DEBUG: setupVLCPlayer url=\(url.absoluteString) isMuted=\(isMuted) shouldForceMuteOnNextPlay=\(shouldForceMuteOnNextPlay)")
        print("MUTE DEBUG: audio tracks pre-play count=\(vlcPlayer.audioTracks.count)")
        
        // Add basic VLC media debugging
        print("DEBUG: WebMViewController - VLC Media created")
        print("DEBUG: WebMViewController - VLC Version: \(VLCLibrary.version())")
        
        // Verify muting before setting delegate
        print("🎵 DEBUG: WebMViewController - Pre-delegate Audio Muted: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - Pre-delegate Audio Volume: \(vlcPlayer.audio?.volume ?? -1)")
        print("🎵 DEBUG: WebMViewController - Audio available: \(vlcPlayer.audio != nil)")
        logAudioDebug("setupVLCPlayer-preDelegate")
        
        // Set up delegate to handle player events
        vlcPlayer.delegate = self
        
        // Apply default mute preference before playback
        preferredAudioTrackIndex = nil
        shouldForceMuteOnNextPlay = isMuted
        if isMuted {
            disableAudioTracksForMutedStart()
            print("MUTE DEBUG: after disableAudioTracksForMutedStart isMuted=\(isMuted) vlcMuted=\(vlcPlayer.audio?.isMuted ?? false) vlcVolume=\(vlcPlayer.audio?.volume ?? -1)")
            logAudioDebug("setupVLCPlayer-prePlay")
            print("🎵 DEBUG: WebMViewController - Mute enforcement enabled (default muted)")
            print("🎵 DEBUG: WebMViewController - Pre-play Audio Muted: \(vlcPlayer.audio?.isMuted ?? false)")
            print("🎵 DEBUG: WebMViewController - Pre-play Audio Volume: \(vlcPlayer.audio?.volume ?? -1)")
        } else {
            enableAudioTracksForUnmute()
        }
        
        // Start playback
        print("DEBUG: WebMViewController - Starting VLC playback")
        vlcPlayer.play()
        logAudioDebug("setupVLCPlayer-postPlay")
        if isMuted {
            startAggressiveMuteEnforcement(reason: "initial-play")
        }

        // Start auto-hide timer for controls
        resetControlsHideTimer()

        if isMuted {
            // IMMEDIATE mute enforcement - multiple attempts to catch VLC before audio starts
            // Attempt 1: Immediate
            disableAudioTracksForMutedStart()
            print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #1")
            
            // Attempt 2: Next run loop
            DispatchQueue.main.async {
                print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #2 (async)")
                self.disableAudioTracksForMutedStart()
            }
            
            // Attempt 3: Microsecond delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #3 (0.001s)")
                self.disableAudioTracksForMutedStart()
            }
            
            // Attempt 4: 5ms delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #4 (0.005s)")
                self.disableAudioTracksForMutedStart()
            }
            
            // Attempt 5: 10ms delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                print("🎵 DEBUG: WebMViewController - IMMEDIATE mute attempt #5 (0.01s)")
                self.disableAudioTracksForMutedStart()
            }
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
                self.logAudioDebug("delay-\(delay)s")

                if self.isMuted && self.vlcPlayer.audioTracks.count > 0 {
                    print("MUTE DEBUG: \(delay)s delay - tracks present, forcing deselect")
                    self.disableAudioTracksForMutedStart()
                }
                
                // Force mute again if not muted
                if self.isMuted && !(self.vlcPlayer.audio?.isMuted ?? true) {
                    print("🎵 DEBUG: WebMViewController - \(delay)s delay - AUDIO NOT MUTED! Forcing mute again")
                    self.disableAudioTracksForMutedStart()
                    print("🎵 DEBUG: WebMViewController - \(delay)s delay - After force mute - Audio Muted: \(self.vlcPlayer.audio?.isMuted ?? false)")
                }
            }
        }

        // Start loop monitoring as a safety net
        startLoopMonitoring()

        // Start seek bar updates directly as a fallback (delegate may not always fire)
        // Use a small delay to allow VLC to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startSeekBarUpdates()
        }
    }

    // MARK: - AVPlayer Setup (Mac Catalyst converted playback)

    /// Sets up native AVPlayer for playing a converted MP4 file
    private func setupAVPlayer(with mp4URL: URL) {

        // Cancel any stale layer-ready observation
        layerReadyObservation?.invalidate()
        layerReadyObservation = nil

        // Reset player state so avPlayerLayer.isReadyForDisplay becomes false
        // (prevents stale true from a previous session when cleanupAVPlayer wasn't called)
        avPlayer.replaceCurrentItem(with: nil)

        // Add player layer to videoView
        avPlayerLayer.frame = videoView.bounds
        videoView.layer.addSublayer(avPlayerLayer)

        // Create player item and replace current
        let playerItem = AVPlayerItem(url: mp4URL)
        avPlayer.replaceCurrentItem(with: playerItem)

        // Apply mute settings
        avPlayer.isMuted = isMuted
        avPlayer.volume = isMuted ? 0.0 : 0.5

        // Observe end of playback for looping
        avPlayerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.avPlayer.seek(to: .zero)
            self?.avPlayer.play()
        }

        // Keep progress bar visible until the player layer renders its first frame
        layerReadyObservation = avPlayerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            guard let self = self else { return }
            if layer.isReadyForDisplay {
                self.hideConversionOverlay()
                self.layerReadyObservation?.invalidate()
                self.layerReadyObservation = nil
            }
        }

        // Start playback
        avPlayer.play()

        // Start seek bar updates
        startAVPlayerSeekBarUpdates()

        // Auto-hide controls
        resetControlsHideTimer()

        // Update play/pause button
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
        playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
    }

    /// Starts periodic seek bar updates for AVPlayer
    private func startAVPlayerSeekBarUpdates() {
        stopSeekBarUpdates()
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        avPlayerTimeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateAVPlayerSeekBar()
        }
    }

    /// Stops AVPlayer seek bar updates
    private func stopAVPlayerSeekBarUpdates() {
        if let observer = avPlayerTimeObserver {
            avPlayer.removeTimeObserver(observer)
            avPlayerTimeObserver = nil
        }
    }

    /// Updates the seek bar position and time labels for AVPlayer
    private func updateAVPlayerSeekBar() {
        guard !isSeeking else { return }
        guard let currentItem = avPlayer.currentItem else { return }

        let currentTime = CMTimeGetSeconds(avPlayer.currentTime())
        let duration = CMTimeGetSeconds(currentItem.duration)

        guard duration.isFinite && duration > 0 else { return }

        // Skip slider updates briefly after a seek to prevent snap-back
        let recentlySeekd = lastSeekTime.map { Date().timeIntervalSince($0) < 0.5 } ?? false
        if !recentlySeekd {
            seekBar.value = Float(currentTime / duration)
        }

        currentTimeLabel.text = formatTime(milliseconds: Int32(currentTime * 1000))
        durationLabel.text = formatTime(milliseconds: Int32(duration * 1000))
    }

    /// Cleans up AVPlayer resources
    private func cleanupAVPlayer() {
        layerReadyObservation?.invalidate()
        layerReadyObservation = nil
        stopAVPlayerSeekBarUpdates()

        if let observer = avPlayerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            avPlayerEndObserver = nil
        }

        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        avPlayerLayer.removeFromSuperlayer()
    }

    // MARK: - Conversion Overlay

    /// Shows the conversion progress bar with shimmer animation
    private func showConversionOverlay() {
        isConversionInProgress = true

        // Cancel any pending hide animation so its completion block doesn't clobber this show
        conversionProgressTrack.layer.removeAllAnimations()

        conversionProgressFillWidth?.constant = 0
        conversionProgressTrack.isHidden = false
        conversionProgressTrack.alpha = 1
        conversionShimmer.isHidden = false
        view.layoutIfNeeded()

        // Start shimmer animation (left-to-right sweep)
        conversionShimmer.transform = CGAffineTransform(translationX: -conversionProgressTrack.bounds.width * 0.3, y: 0)
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .curveEaseInOut]) {
            self.conversionShimmer.transform = CGAffineTransform(translationX: self.conversionProgressTrack.bounds.width, y: 0)
        }
    }

    /// Hides the conversion progress bar with fade-out
    private func hideConversionOverlay() {
        isConversionInProgress = false
        conversionShimmer.layer.removeAllAnimations()
        let hideGeneration = conversionGeneration
        UIView.animate(withDuration: 0.3, animations: {
            self.conversionProgressTrack.alpha = 0
        }) { _ in
            // Only apply if no new showConversionOverlay has been called since this hide started
            guard !self.isConversionInProgress && self.conversionGeneration == hideGeneration else { return }
            self.conversionProgressTrack.isHidden = true
            self.conversionShimmer.isHidden = true
            self.conversionProgressFillWidth?.constant = 0
        }
    }

    /// Called when the VLC player state changes.
    @objc func vlcPlayerDidReachEnd(notification: Notification) {
        guard let player = notification.object as? VLCMediaPlayer else { return }
        print("DEBUG: WebMViewController - VLC state changed via Notification: \(player.state.rawValue), position: \(player.position)")
        
        // Robust loop trigger on stop near the end
        if player.state == .stopped && player.position >= 0.99 {
            print("DEBUG: WebMViewController - Detected .stopped near end via Notification, looping")
            print("🎵 DEBUG: WebMViewController - Notification Pre-loop Audio Muted: \(player.audio?.isMuted ?? false)")
            print("🎵 DEBUG: WebMViewController - Notification Pre-loop isMuted variable: \(isMuted)")

            player.position = 0.0
            prepareForMutedPlaybackStart()
            player.play()

            print("🎵 DEBUG: WebMViewController - Notification Post-loop forced mute")
            print("🎵 DEBUG: WebMViewController - Notification Post-loop Audio Muted: \(player.audio?.isMuted ?? false)")
            print("🎵 DEBUG: WebMViewController - Notification Post-loop isMuted variable: \(isMuted)")
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
    private func cachePreferredAudioTrackIndexIfNeeded() {
        guard preferredAudioTrackIndex == nil else { return }

        let tracks = vlcPlayer.audioTracks
        if let selectedIndex = tracks.firstIndex(where: { $0.isSelected }) {
            preferredAudioTrackIndex = selectedIndex
        } else if !tracks.isEmpty {
            preferredAudioTrackIndex = 0
        }
    }

    private func disableAudioTracksForMutedStart() {
        if !isMuted && !shouldForceMuteOnNextPlay {
            return
        }
        cachePreferredAudioTrackIndexIfNeeded()
        vlcPlayer.deselectAllAudioTracks()
        vlcPlayer.audio?.isMuted = true
        vlcPlayer.audio?.volume = 0
    }

    private func enableAudioTracksForUnmute() {
        cachePreferredAudioTrackIndexIfNeeded()
        let tracks = vlcPlayer.audioTracks
        if !tracks.isEmpty && !tracks.contains(where: { $0.isSelected }) {
            let preferredIndex = preferredAudioTrackIndex ?? 0
            let clampedIndex = min(preferredIndex, tracks.count - 1)
            vlcPlayer.selectTrack(at: clampedIndex, type: VLCMedia.TrackType.audio)
        }

        vlcPlayer.audio?.isMuted = false
        vlcPlayer.audio?.volume = 50
    }

    private func logAudioDebug(_ context: String) {
        let tracks = vlcPlayer.audioTracks
        let selectedTracks = tracks.enumerated().compactMap { index, track -> String? in
            guard track.isSelected else { return nil }
            return "\(index):\(track.trackName)"
        }
        let session = AVAudioSession.sharedInstance()
        let routes = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        print("MUTE DEBUG: \(context) isMutedVar=\(isMuted) shouldForceMuteOnNextPlay=\(shouldForceMuteOnNextPlay) vlcMuted=\(vlcPlayer.audio?.isMuted ?? false) vlcVolume=\(vlcPlayer.audio?.volume ?? -1) audioTracks=\(tracks.count) selected=\(selectedTracks)")
        print("MUTE DEBUG: \(context) session category=\(session.category.rawValue) mode=\(session.mode.rawValue) otherAudio=\(session.isOtherAudioPlaying) silencedHint=\(session.secondaryAudioShouldBeSilencedHint) outputVolume=\(session.outputVolume) route=\(routes)")
    }

    private func startAggressiveMuteEnforcement(reason: String) {
        guard isMuted else { return }
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startAggressiveMuteEnforcement(reason: reason)
            }
            return
        }
        aggressiveMuteTimer?.invalidate()
        aggressiveMuteLastTrackCount = -1
        let startTime = Date()
        print("MUTE DEBUG: aggressive mute start reason=\(reason)")
        logAudioDebug("aggressive-mute-start")
        aggressiveMuteTimer = Timer.scheduledTimer(withTimeInterval: aggressiveMuteInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if Date().timeIntervalSince(startTime) >= self.aggressiveMuteDuration {
                timer.invalidate()
                self.aggressiveMuteTimer = nil
                print("MUTE DEBUG: aggressive mute stop")
                self.logAudioDebug("aggressive-mute-stop")
                return
            }
            if self.isMuted {
                self.disableAudioTracksForMutedStart()
            }
            let trackCount = self.vlcPlayer.audioTracks.count
            if trackCount != self.aggressiveMuteLastTrackCount {
                self.aggressiveMuteLastTrackCount = trackCount
                self.logAudioDebug("aggressive-mute-trackCount=\(trackCount)")
            }
        }
    }

    private func stopAggressiveMuteEnforcement() {
        aggressiveMuteTimer?.invalidate()
        aggressiveMuteTimer = nil
    }

    private func prepareForMutedPlaybackStart() {
        guard isMuted else {
            shouldForceMuteOnNextPlay = false
            stopAggressiveMuteEnforcement()
            DispatchQueue.main.async { [weak self] in
                self?.setupNavigationButtons()
            }
            return
        }

        shouldForceMuteOnNextPlay = true
        disableAudioTracksForMutedStart()
        print("MUTE DEBUG: prepareForMutedPlaybackStart isMuted=\(isMuted) shouldForceMuteOnNextPlay=\(shouldForceMuteOnNextPlay) vlcMuted=\(vlcPlayer.audio?.isMuted ?? false) vlcVolume=\(vlcPlayer.audio?.volume ?? -1)")
        logAudioDebug("prepareForMutedPlaybackStart")
        startAggressiveMuteEnforcement(reason: "prepare")
        DispatchQueue.main.async { [weak self] in
            self?.setupNavigationButtons()
        }
    }

    /// Toggles the mute/unmute state of the video
    @objc private func toggleMute() {
        print("🎵 DEBUG: WebMViewController - === TOGGLE MUTE CALLED ===")
        print("🎵 DEBUG: WebMViewController - toggleMute() - isMuted BEFORE toggle: \(isMuted)")

        let wasMuted = isMuted
        isMuted.toggle()

        print("🎵 DEBUG: WebMViewController - toggleMute() - isMuted AFTER toggle: \(isMuted) (was: \(wasMuted))")

        if isUsingAVPlayer {
            avPlayer.isMuted = isMuted
            avPlayer.volume = isMuted ? 0.0 : 0.5
            setupNavigationButtons()
            print("🎵 DEBUG: WebMViewController - toggleMute() - Applied to AVPlayer, muted=\(avPlayer.isMuted)")
            return
        }

        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Muted BEFORE: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Volume BEFORE: \(vlcPlayer.audio?.volume ?? -1)")

        if isMuted {
            disableAudioTracksForMutedStart()
        } else {
            shouldForceMuteOnNextPlay = false
            stopAggressiveMuteEnforcement()
            enableAudioTracksForUnmute()
        }

        print("🎵 DEBUG: WebMViewController - toggleMute() - Applied settings to VLC")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Muted AFTER: \(vlcPlayer.audio?.isMuted ?? false)")
        print("🎵 DEBUG: WebMViewController - toggleMute() - VLC Audio Volume AFTER: \(vlcPlayer.audio?.volume ?? -1)")

        // Update the navigation bar button
        setupNavigationButtons()

        print("🎵 DEBUG: WebMViewController - toggleMute() - Updated navigation buttons")
        print("🎵 DEBUG: WebMViewController - === TOGGLE MUTE COMPLETE ===")
    }

    // MARK: - Play/Pause Control Methods
    /// Toggles controls visibility when video view is tapped
    @objc private func videoViewTapped() {
        if controlsVisible {
            hideControls()
        } else {
            showControls()
        }
    }

    /// Toggles the play/pause state of the video
    @objc private func togglePlayPause() {
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)

        if isUsingAVPlayer {
            if avPlayer.rate > 0 {
                avPlayer.pause()
                playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
                showControls(autoHide: false)
            } else {
                avPlayer.play()
                playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
                resetControlsHideTimer()
            }
            return
        }

        if vlcPlayer.isPlaying {
            vlcPlayer.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
            // Show controls and keep them visible when paused
            showControls(autoHide: false)
        } else {
            vlcPlayer.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
            // Start auto-hide timer when playing
            resetControlsHideTimer()
        }
    }

    /// Updates the play/pause button icon based on player state
    private func updatePlayPauseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
        let isPlaying = isUsingAVPlayer ? (avPlayer.rate > 0) : vlcPlayer.isPlaying
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }

    // MARK: - Controls Visibility Methods
    /// Shows the video controls with animation
    private func showControls(autoHide: Bool = true) {
        controlsVisible = true
        controlsHideTimer?.invalidate()

        navigationController?.setNavigationBarHidden(false, animated: true)

        let hasMultipleVideos = videoURLs.count > 1

        UIView.animate(withDuration: 0.25) {
            self.playPauseButton.alpha = 1.0
            self.seekBarContainer.alpha = 1.0
            self.mediaCounterLabel.alpha = hasMultipleVideos ? 1.0 : 0.0
            // Show navigation hints if there are multiple videos
            self.upHint.alpha = hasMultipleVideos ? 0.7 : 0.0
            self.downHint.alpha = hasMultipleVideos ? 0.7 : 0.0
        }

        let isPlaying = isUsingAVPlayer ? (avPlayer.rate > 0) : vlcPlayer.isPlaying
        if autoHide && isPlaying {
            resetControlsHideTimer()
        }
    }

    /// Hides the video controls with animation
    private func hideControls() {
        controlsVisible = false
        controlsHideTimer?.invalidate()

        navigationController?.setNavigationBarHidden(true, animated: true)

        UIView.animate(withDuration: 0.25) {
            self.playPauseButton.alpha = 0.0
            self.seekBarContainer.alpha = 0.0
            self.mediaCounterLabel.alpha = 0.0
            self.upHint.alpha = 0.0
            self.downHint.alpha = 0.0
        }
    }

    /// Resets the auto-hide timer for controls
    private func resetControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: controlsHideDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let isPlaying = self.isUsingAVPlayer ? (self.avPlayer.rate > 0) : self.vlcPlayer.isPlaying
            if isPlaying {
                self.hideControls()
            }
        }
    }

    /// Stops the controls hide timer
    private func stopControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
    }

    // MARK: - Seek Bar Control Methods
    /// Called when user starts dragging the seek bar
    @objc private func seekBarTouchDown(_ sender: UISlider) {
        isSeeking = true
        // Keep controls visible while user is seeking
        stopControlsHideTimer()
    }

    /// Called when user releases the seek bar
    @objc private func seekBarTouchUp(_ sender: UISlider) {
        isSeeking = false
        // Record seek time to prevent slider snap-back
        lastSeekTime = Date()

        if isUsingAVPlayer {
            if let duration = avPlayer.currentItem?.duration {
                let totalSeconds = CMTimeGetSeconds(duration)
                if totalSeconds.isFinite && totalSeconds > 0 {
                    let seekTime = CMTime(seconds: Double(sender.value) * totalSeconds, preferredTimescale: 600)
                    avPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
            if avPlayer.rate > 0 {
                resetControlsHideTimer()
            }
        } else {
            // Perform the seek when user releases - VLCKit 4.x position is Double (0.0-1.0)
            vlcPlayer.position = Double(sender.value)
            // Reset auto-hide timer after seeking
            if vlcPlayer.isPlaying {
                resetControlsHideTimer()
            }
        }
    }

    /// Called when seek bar value changes during dragging
    @objc private func seekBarValueChanged(_ sender: UISlider) {
        if isUsingAVPlayer {
            if let duration = avPlayer.currentItem?.duration {
                let totalMs = CMTimeGetSeconds(duration) * 1000
                if totalMs.isFinite && totalMs > 0 {
                    let currentMs = Int32(Double(sender.value) * totalMs)
                    currentTimeLabel.text = formatTime(milliseconds: currentMs)
                }
            }
            // Fast scrub for AVPlayer
            guard isSeeking else { return }
            let now = Date()
            if lastSeekTime == nil || now.timeIntervalSince(lastSeekTime!) > 0.05 {
                lastSeekTime = now
                if let duration = avPlayer.currentItem?.duration {
                    let totalSeconds = CMTimeGetSeconds(duration)
                    if totalSeconds.isFinite && totalSeconds > 0 {
                        let seekTime = CMTime(seconds: Double(sender.value) * totalSeconds, preferredTimescale: 600)
                        avPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                }
            }
            return
        }

        // Update time label while dragging to show where user will seek to
        // Use calculated duration if available (more accurate for WebM files)
        let duration = calculatedDurationMs > 0 ? calculatedDurationMs : (vlcPlayer.media?.length.intValue ?? 0)
        if duration > 0 && duration < 3600000 {
            let currentMs = Int32(sender.value * Float(duration))
            currentTimeLabel.text = formatTime(milliseconds: currentMs)
        }

        // Fast scrub: seek while dragging with a small throttle
        guard isSeeking else { return }
        let now = Date()
        if lastSeekTime == nil || now.timeIntervalSince(lastSeekTime!) > 0.05 {
            lastSeekTime = now
            vlcPlayer.position = Double(sender.value)
        }
    }

    /// Starts the timer to update seek bar position
    private func startSeekBarUpdates() {
        seekBarUpdateTimer?.invalidate()
        seekBarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateSeekBar()
        }
    }

    /// Stops the seek bar update timer
    private func stopSeekBarUpdates() {
        seekBarUpdateTimer?.invalidate()
        seekBarUpdateTimer = nil
    }

    /// Updates the seek bar position and time labels
    private func updateSeekBar() {
        guard !isSeeking else { return }

        // Update slider position (only if valid, VLC returns -1 when not ready)
        // Skip slider updates briefly after a seek to prevent snap-back
        let position = vlcPlayer.position
        let recentlySeekd = lastSeekTime.map { Date().timeIntervalSince($0) < 0.5 } ?? false
        if position >= 0 && !recentlySeekd {
            seekBar.value = Float(position)
        }

        // Get current time in milliseconds
        let currentMs = vlcPlayer.time.intValue

        // Calculate actual duration from position and time
        // VLCKit sometimes reports incorrect duration for WebM files
        // Formula: actual_duration = current_time / position
        if position > 0.05 && currentMs > 0 {
            let computed = Int32(Double(currentMs) / position)
            // Only update if we get a reasonable value (less than 1 hour for typical videos)
            if computed > 0 && computed < 3600000 {
                calculatedDurationMs = computed
            }
        }

        // Use calculated duration if available, otherwise try VLC's reported duration
        var durationMs = calculatedDurationMs
        if durationMs <= 0, let media = vlcPlayer.media {
            let vlcDuration = media.length.intValue
            // Only use VLC duration if it's reasonable (less than 1 hour)
            if vlcDuration > 0 && vlcDuration < 3600000 {
                durationMs = vlcDuration
            }
        }

        // Update time labels if we have valid duration
        if durationMs > 0 {
            currentTimeLabel.text = formatTime(milliseconds: max(0, currentMs))
            durationLabel.text = formatTime(milliseconds: durationMs)
        }
    }

    /// Formats milliseconds into a time string (m:ss or h:mm:ss)
    private func formatTime(milliseconds: Int32) -> String {
        let totalSeconds = Int(milliseconds) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
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

        // Check if video has already been downloaded
        if DownloadedMediaTracker.fileExists(at: destinationURL) {
            showAlert(message: "This video has already been downloaded")
            return
        }

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
            
            // Ensure destination directory exists
            let dir = localUrl.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
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
        logAudioDebug("periodic-start")
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
        logAudioDebug("periodic-check")
        
        // Enforce user's mute preference
        let expectedVolume = isMuted ? Int32(0) : Int32(50)
        if playerIsMuted != isMuted || playerVolume != expectedVolume {
            print("🎵 DEBUG: WebMViewController - Enforcing user mute preference...")
            if isMuted {
                disableAudioTracksForMutedStart()
            } else {
                enableAudioTracksForUnmute()
            }
            print("🎵 DEBUG: WebMViewController - Applied user preference - Audio Muted: \(vlcPlayer.audio?.isMuted ?? false), Volume: \(vlcPlayer.audio?.volume ?? -1)")
        }

        if isMuted {
            disableAudioTracksForMutedStart()
        } else {
            enableAudioTracksForUnmute()
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
            self.logAudioDebug("delegate-state-\(player.state.rawValue)")
            
            // Basic media information when media changes
            if let media = player.media {
                print("DEBUG: WebMViewController - Media info:")
                print("  - Duration: \(media.length.value?.intValue ?? 0)ms")
            }
            
            switch player.state {
            case .playing:
                print("DEBUG: WebMViewController - VLC player started playing")
                print("🎵 DEBUG: WebMViewController - === PLAYING STATE ENTERED ===")

                // Update play/pause button
                self.updatePlayPauseButton()
                
                // Check audio state before applying preference
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Muted BEFORE: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Volume BEFORE: \(player.audio?.volume ?? -1)")
                print("🎵 DEBUG: WebMViewController - Playing state - isMuted variable BEFORE: \(self.isMuted)")
                print("🎵 DEBUG: WebMViewController - Playing state - Audio object available: \(player.audio != nil)")
                
                if self.shouldForceMuteOnNextPlay {
                    self.shouldForceMuteOnNextPlay = false
                    self.isMuted = true
                    self.startAggressiveMuteEnforcement(reason: "delegate-playing")
                }

                if self.isMuted {
                    print("🎵 DEBUG: WebMViewController - isMuted is true - Disabling audio tracks to enforce mute")
                    self.disableAudioTracksForMutedStart()
                    self.setupNavigationButtons()
                } else {
                    print("🎵 DEBUG: WebMViewController - isMuted is false - Enabling audio tracks")
                    self.enableAudioTracksForUnmute()
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
                        
                        if self.isMuted {
                            self.disableAudioTracksForMutedStart()
                        } else {
                            self.enableAudioTracksForUnmute()
                        }
                    }
                }
                
                // Verify forced muting was applied
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Muted AFTER: \(player.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Playing state - Audio Volume AFTER: \(player.audio?.volume ?? -1)")
                print("🎵 DEBUG: WebMViewController - === PLAYING STATE PROCESSING COMPLETE ===")
                
                // Get more detailed playback information
                print("DEBUG: WebMViewController - Player info:")
                print("  - Position: \(player.position)")
                print("  - Time: \(player.time.value?.intValue ?? 0)ms")
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

                // Start seek bar updates
                self.startSeekBarUpdates()

            case .stopped:
                print("DEBUG: WebMViewController - VLC player stopped")
                self.updatePlayPauseButton()
                let pos = player.position
                print("DEBUG: WebMViewController - VLC stopped at position: \(pos)")
                if pos >= 0.99 {
                    print("DEBUG: WebMViewController - Looping VLC video from .stopped state")
                    print("🎵 DEBUG: WebMViewController - Pre-loop Audio Muted: \(player.audio?.isMuted ?? false)")
                    print("🎵 DEBUG: WebMViewController - Pre-loop Audio Volume: \(player.audio?.volume ?? -1)")
                    print("🎵 DEBUG: WebMViewController - Pre-loop isMuted variable: \(self.isMuted)")

                    player.position = 0.0
                    self.prepareForMutedPlaybackStart()
                    player.play()

                    print("🎵 DEBUG: WebMViewController - Post-loop forced mute")
                    print("🎵 DEBUG: WebMViewController - Post-loop Audio Muted: \(player.audio?.isMuted ?? false)")
                    print("🎵 DEBUG: WebMViewController - Post-loop Audio Volume: \(player.audio?.volume ?? -1)")
                    print("🎵 DEBUG: WebMViewController - Post-loop isMuted variable: \(self.isMuted)")

                    // Additional delayed enforcement to catch any VLC timing issues
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                        guard let self = self else { return }
                        self.disableAudioTracksForMutedStart()
                        print("🎵 DEBUG: WebMViewController - Post-loop 0.01s delay mute enforced")
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        self.disableAudioTracksForMutedStart()
                        print("🎵 DEBUG: WebMViewController - Post-loop 0.05s delay mute enforced")
                    }
                }
                
            case .error:
                print("DEBUG: WebMViewController - VLC player error")
                
                // Try to get more error details
                if player.media != nil {
                    print("DEBUG: WebMViewController - Media available on error")
                } else {
                    print("DEBUG: WebMViewController - No media available on error")
                }
                
                self.showAlert(message: "Failed to play video with VLC player - check console for details")
                
            case .buffering:
                print("DEBUG: WebMViewController - VLC player buffering")
                print("🎵 DEBUG: WebMViewController - === BUFFERING STATE ENTERED ===")
                
                if self.shouldForceMuteOnNextPlay || self.isMuted {
                    // CRITICAL: VLC can start playing audio during buffering - force mute immediately
                    print("🎵 DEBUG: WebMViewController - Buffering state - Audio Muted BEFORE: \(player.audio?.isMuted ?? false)")
                    print("🎵 DEBUG: WebMViewController - Buffering state - Audio Volume BEFORE: \(player.audio?.volume ?? -1)")
                    
                    // NUCLEAR OPTION: Disable audio completely during buffering
                    self.isMuted = true
                    self.disableAudioTracksForMutedStart()
                    
                    print("🎵 DEBUG: WebMViewController - Buffering state - NUCLEAR AUDIO DISABLE APPLIED")
                    print("🎵 DEBUG: WebMViewController - Buffering state - Audio Muted AFTER: \(player.audio?.isMuted ?? false)")
                    print("🎵 DEBUG: WebMViewController - Buffering state - Audio Volume AFTER: \(player.audio?.volume ?? -1)")
                    self.startAggressiveMuteEnforcement(reason: "delegate-buffering")
                    
                    // Update navigation button to reflect muted state
                    self.setupNavigationButtons()
                } else {
                    print("MUTE DEBUG: buffering - respecting user unmute")
                }
                
            case .paused:
                print("DEBUG: WebMViewController - VLC player paused")
                self.updatePlayPauseButton()
                
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
                print("🎵 DEBUG: WebMViewController - Loop monitor Pre-loop Audio Muted: \(self.vlcPlayer.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Loop monitor Pre-loop isMuted variable: \(self.isMuted)")

                self.vlcPlayer.position = 0.0
                self.prepareForMutedPlaybackStart()
                self.vlcPlayer.play()

                print("🎵 DEBUG: WebMViewController - Loop monitor Post-loop forced mute")
                print("🎵 DEBUG: WebMViewController - Loop monitor Post-loop Audio Muted: \(self.vlcPlayer.audio?.isMuted ?? false)")
                print("🎵 DEBUG: WebMViewController - Loop monitor Post-loop isMuted variable: \(self.isMuted)")
            }
        }
    }

    private func stopLoopMonitoring() {
        print("DEBUG: WebMViewController - Stopping loop monitoring timer")
        loopCheckTimer?.invalidate()
        loopCheckTimer = nil
    }

    // MARK: - Navigation Methods

    /// Sets up navigation UI based on whether we have multiple videos
    private func setupNavigationUI() {
        let hasMultipleVideos = videoURLs.count > 1

        // Show/hide tap zones
        upTapZone.isHidden = !hasMultipleVideos
        downTapZone.isHidden = !hasMultipleVideos

        // Show media counter if we have multiple videos
        if hasMultipleVideos {
            mediaCounterLabel.isHidden = false
            updateMediaCounter()

            // Add swipe gestures for navigation
            let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
            swipeUp.direction = .up
            videoView.addGestureRecognizer(swipeUp)

            let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
            swipeDown.direction = .down
            videoView.addGestureRecognizer(swipeDown)
        } else {
            mediaCounterLabel.isHidden = true
        }

        // Update hint visibility
        updateNavigationHints()
    }

    /// Handles swipe up gesture - go to previous video
    @objc private func handleSwipeUp() {
        upTapZoneTapped()
    }

    /// Handles swipe down gesture - go to next video
    @objc private func handleSwipeDown() {
        downTapZoneTapped()
    }

    /// Updates the media counter label
    private func updateMediaCounter() {
        let position = currentIndex + 1
        mediaCounterLabel.text = "  \(position) / \(videoURLs.count)  "
    }

    /// Updates navigation hint visibility based on current position
    private func updateNavigationHints() {
        // Only show hints if there's somewhere to navigate to
        upHint.alpha = currentIndex > 0 ? 0.7 : 0.3
        downHint.alpha = currentIndex < videoURLs.count - 1 ? 0.7 : 0.3
    }

    // MARK: - Keyboard Shortcut Methods
    @objc private func nextVideoShortcut() {
        navigateToNextVideo(ignoreControls: true)
    }

    @objc private func previousVideoShortcut() {
        navigateToPreviousVideo(ignoreControls: true)
    }

    /// Handles tap on upper zone - go to previous video
    @objc private func upTapZoneTapped() {
        navigateToPreviousVideo(ignoreControls: false)
    }

    /// Handles tap on lower zone - go to next video
    @objc private func downTapZoneTapped() {
        navigateToNextVideo(ignoreControls: false)
    }

    private func navigateToPreviousVideo(ignoreControls: Bool) {
        if !ignoreControls && !controlsVisible {
            showControls()
            return
        }

        guard videoURLs.count > 1, currentIndex > 0 else {
            // Flash the hint to show we're at the beginning
            flashHint(upHint)
            return
        }

        currentIndex -= 1
        loadVideo(at: currentIndex)

        // Pre-convert the next adjacent video
        if currentIndex > 0 {
            WebMConversionService.shared.preconvertIfNeeded(url: videoURLs[currentIndex - 1])
        }
    }

    private func navigateToNextVideo(ignoreControls: Bool) {
        if !ignoreControls && !controlsVisible {
            showControls()
            return
        }

        guard videoURLs.count > 1, currentIndex < videoURLs.count - 1 else {
            // Flash the hint to show we're at the end
            flashHint(downHint)
            return
        }

        currentIndex += 1
        loadVideo(at: currentIndex)

        // Pre-convert the next adjacent video
        if currentIndex < videoURLs.count - 1 {
            WebMConversionService.shared.preconvertIfNeeded(url: videoURLs[currentIndex + 1])
        }
    }

    private var supportsHardwareNavigation: Bool {
        let idiom = UIDevice.current.userInterfaceIdiom
        if idiom == .pad { return true }
        if #available(iOS 14.0, *) {
            return idiom == .mac
        }
        return false
    }

    /// Flashes a hint to indicate navigation limit
    private func flashHint(_ hint: UIImageView) {
        UIView.animate(withDuration: 0.15, animations: {
            hint.alpha = 1.0
            hint.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                hint.alpha = 0.3
                hint.transform = .identity
            }
        }
    }

    /// Loads and plays a video at the specified index
    private func loadVideo(at index: Int) {
        guard index >= 0, index < videoURLs.count else { return }

        // Cancel any active conversion and hide progress bar
        WebMConversionService.shared.cancelConversion()
        hideConversionOverlay()

        // Clean up current player
        if isUsingAVPlayer {
            cleanupAVPlayer()
        } else {
            // Detach drawable before stopping to prevent VLCSampleBufferDisplay crash
            vlcPlayer.delegate = nil
            vlcPlayer.drawable = nil
            vlcPlayer.stop()
            stopLoopMonitoring()
            stopPeriodicAudioChecking()
        }
        stopSeekBarUpdates()
        stopAVPlayerSeekBarUpdates()

        // Reset seek bar
        seekBar.value = 0
        currentTimeLabel.text = "0:00"
        durationLabel.text = "0:00"
        calculatedDurationMs = 0

        isMuted = MediaSettings.defaultMuted
        preferredAudioTrackIndex = nil
        shouldForceMuteOnNextPlay = isMuted
        isUsingAVPlayer = false
        setupNavigationButtons()

        // Update video URL
        let newURL = videoURLs[index]
        videoURL = newURL.absoluteString

        // Update UI
        updateMediaCounter()
        updateNavigationHints()

        // Load and play the new video
        setupVideo()
    }
}
