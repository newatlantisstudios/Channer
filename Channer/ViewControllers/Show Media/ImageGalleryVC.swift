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
    /// Post numbers corresponding to each image (parallel array to `images`)
    var postNumbers: [String] = []
    /// Reply counts for each image's post (parallel array to `images`)
    var replyCounts: [Int] = []
    /// Callback when the user taps the replies button in the single-image viewer; passes the post number
    var onShowReplies: ((String) -> Void)?
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

    private static let videoExtensions: Set<String> = ["webm", "mp4"]
    private let debugID = UUID().uuidString.prefix(8)
    private let debugStartTime = Date()
    private var debugLayoutPassCount = 0
    private var debugCellConfigCount = 0
    private var debugSizeRequestCount = 0
    private var debugLoggedImageCompletions = 0
    
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
            stopMediaPlayback()
            imageView?.kf.cancelDownloadTask()
            imageView?.image = nil
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
            stopMediaPlayback()
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

        func stopMediaPlayback() {
            if let webView = webView {
                webView.navigationDelegate = nil
                webView.stopLoading()
                webView.evaluateJavaScript("""
                    document.querySelectorAll('video').forEach(function(video) {
                        video.pause();
                        video.removeAttribute('src');
                        video.load();
                    });
                """, completionHandler: nil)
                webView.loadHTMLString("", baseURL: nil)
                webView.removeFromSuperview()
                self.webView = nil
            }

            imageView?.kf.cancelDownloadTask()
            activityIndicator?.stopAnimating()
            isVideoCell = false
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
        galleryDebugLog("init images=\(images.count) preloadVideos=\(preloadVideos) replaceVideoThumbnails=\(MediaSettings.replaceVideoThumbnails)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        galleryDebugLog("deinit")
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        galleryDebugLog("viewDidLoad begin selectedImageURL=\(selectedImageURL?.absoluteString ?? "nil") viewBounds=\(view.bounds) collectionBounds=\(collectionView.bounds)")

        view.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(MediaCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.backgroundColor = .systemBackground
        collectionView.contentInsetAdjustmentBehavior = .never
        
        // Use Auto Layout constraints instead of frame-based layout
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        // Pin collection view to all edges of the view
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Scroll to the initially selected image if set
        if let selectedURL = selectedImageURL, let index = images.firstIndex(of: selectedURL) {
            selectedIndex = index
            let indexPath = IndexPath(item: index, section: 0)
            galleryDebugLog("viewDidLoad scrolling to selected index=\(index)")
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
        
        // Setup navigation bar with media counter
        setupNavigationBarWithCounter()
        galleryDebugLog("viewDidLoad navigation configured")

        // Process URLs to determine media types
        processMediaURLs()
        galleryDebugLog("viewDidLoad media processing finished correctedVideos=\(correctedURLs.count) alternates=\(alternateURLs.count)")
        
        // Apply preload setting from UserDefaults
        if preloadVideos {
            galleryDebugLog("viewDidLoad applying preload setting")
            applyPreloadSetting()
        } else {
            galleryDebugLog("viewDidLoad reloadData without preload")
            collectionView.reloadData()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(galleryCellSizeDidChange), name: .galleryCellSizeDidChange, object: nil)
        galleryDebugLog("viewDidLoad end")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        debugLayoutPassCount += 1
        if debugLayoutPassCount <= 10 || debugLayoutPassCount % 25 == 0 {
            galleryDebugLog("viewDidLayoutSubviews pass=\(debugLayoutPassCount) viewBounds=\(view.bounds) collectionBounds=\(collectionView.bounds) safeInsets=\(view.safeAreaInsets) contentInset=\(collectionView.contentInset) offset=\(collectionView.contentOffset)")
        }
        updateGalleryCollectionInsets()
    }

    private func updateGalleryCollectionInsets() {
        let topInset = view.safeAreaInsets.top
        let bottomInset = view.safeAreaInsets.bottom
        var contentInset = collectionView.contentInset
        let oldTopInset = contentInset.top
        let oldBottomInset = contentInset.bottom

        guard abs(oldTopInset - topInset) > 0.5 || abs(oldBottomInset - bottomInset) > 0.5 else { return }

        galleryDebugLog("updateGalleryCollectionInsets top \(oldTopInset)->\(topInset) bottom \(oldBottomInset)->\(bottomInset) offsetBefore=\(collectionView.contentOffset)")

        let viewportTop = collectionView.contentOffset.y + oldTopInset
        contentInset.top = topInset
        contentInset.bottom = bottomInset
        collectionView.contentInset = contentInset
        collectionView.scrollIndicatorInsets = contentInset

        let adjustedOffsetY = viewportTop - topInset
        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: adjustedOffsetY),
            animated: false
        )
        galleryDebugLog("updateGalleryCollectionInsets offsetAfter=\(collectionView.contentOffset)")
    }

    @objc private func galleryCellSizeDidChange() {
        galleryDebugLog("galleryCellSizeDidChange columns=\(GalleryCellSizeManager.shared.columns)")
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
    /// Sets up the navigation bar with media counter and grid size button
    private func setupNavigationBarWithCounter() {
        updateMediaCounter()
        navigationItem.titleView = mediaCounterLabel
        navigationItem.rightBarButtonItem = makeGridSizeBarButton()
    }

    /// Creates a bar button with a pull-down menu for changing grid size
    private func makeGridSizeBarButton() -> UIBarButtonItem {
        let sizeLabels = ["XXXS", "XXS", "XS", "S", "M", "L", "XL"]
        let currentIndex = GalleryCellSizeManager.shared.sizeIndex

        let actions = sizeLabels.enumerated().map { index, label in
            UIAction(
                title: label,
                state: index == currentIndex ? .on : .off
            ) { [weak self] _ in
                GalleryCellSizeManager.shared.setSizeIndex(index)
                self?.navigationItem.rightBarButtonItem = self?.makeGridSizeBarButton()
            }
        }

        let menu = UIMenu(title: "Grid Size", children: actions)
        let button = UIBarButtonItem(image: UIImage(systemName: "square.grid.3x3"), menu: menu)
        return button
    }

    /// Updates the media counter display
    private func updateMediaCounter() {
        let currentPosition = selectedIndex + 1
        mediaCounterLabel.text = "\(currentPosition) of \(images.count)"
    }
    
    // MARK: - URL Processing
    /// Processes media URLs to determine the correct file types
    private func processMediaURLs() {
        galleryDebugLog("processMediaURLs begin images=\(images.count)")

        correctedURLs.removeAll()
        alternateURLs.removeAll()
        
        for (index, url) in images.enumerated() {
            let fileExtension = url.pathExtension.lowercased()

            // Direct video URL - use it directly. The thread reply pipeline already
            // preserves the media extension, so guessing videos from image URLs can
            // create many failing WKWebViews and lock up the gallery transition.
            if Self.videoExtensions.contains(fileExtension) {
                correctedURLs[index] = url
                galleryDebugLog("processMediaURLs video index=\(index) url=\(url.absoluteString)")
                continue
            }
        }
        
        // Summary of processed URLs
        galleryDebugLog("processMediaURLs end videos=\(correctedURLs.count) alternates=\(alternateURLs.count)")
    }
    
    // This method is no longer needed as preloadVideos is now a computed property
    // that reads from UserDefaults. The setting is now controlled in the settings screen.
    // We're keeping the implementation as a helper method with a different name
    // in case it needs to be called when UserDefaults change
    private func applyPreloadSetting() {
        galleryDebugLog("applyPreloadSetting begin enabled=\(preloadVideos) correctedVideos=\(correctedURLs.count)")
        
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
        galleryDebugLog("applyPreloadSetting reloadData returned visibleCells=\(collectionView.visibleCells.count)")
        
        // Ensure we start playing videos if needed
        if preloadVideos {
            galleryDebugLog("applyPreloadSetting scheduled visible video playback")
            
            // Add a delay to ensure cells are properly loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.galleryDebugLog("applyPreloadSetting delayed playback firing visibleCells=\(self.collectionView.visibleCells.count)")
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
        galleryDebugLog("numberOfItems section=\(section) count=\(images.count)")
        return images.count
    }

    /// Configures and returns the cell for the given index path.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! MediaCell
        let imageURL = images[indexPath.row]
        let fileExtension = imageURL.pathExtension.lowercased()
        cell.tag = indexPath.row
        debugCellConfigCount += 1
        
        if debugCellConfigCount <= 40 || debugCellConfigCount % 50 == 0 {
            galleryDebugLog("cellForItem row=\(indexPath.row) count=\(debugCellConfigCount) ext=\(fileExtension) preload=\(preloadVideos) replaceVideo=\(MediaSettings.replaceVideoThumbnails) url=\(imageURL.absoluteString)")
        }
        
        // Update selection state
        cell.setSelected(indexPath.row == selectedIndex, animated: false)
        
        // Keep image cells lightweight; only actual video URLs get WKWebView previews.
        if fileExtension == "pdf" {
            setupPDFCell(cell, url: imageURL)
        } else if Self.videoExtensions.contains(fileExtension) && (preloadVideos || MediaSettings.replaceVideoThumbnails) {
            // Choose URL based on correctness map or fallback
            var videoURL = imageURL
            
            // If we have a corrected URL, use it
            if let correctedURL = correctedURLs[indexPath.row] {
                videoURL = correctedURL
                galleryDebugLog("cellForItem using corrected video row=\(indexPath.row) file=\(videoURL.lastPathComponent)")
                
                // Check if we have an alternate URL too
                if let alternateURL = alternateURLs[indexPath.row] {
                    galleryDebugLog("cellForItem alternate video row=\(indexPath.row) file=\(alternateURL.lastPathComponent)")
                }
            }
            galleryDebugLog("cellForItem setup video row=\(indexPath.row)")
            
            // Setup cell for video with both primary and alternate URLs
            setupVideoCell(cell, url: videoURL)
            
            // Add to playing videos tracking
            playingVideoCells.insert(indexPath.row)
        } 
        // Non-preload mode - use regular image cells
        else {
            if debugCellConfigCount <= 40 || debugCellConfigCount % 50 == 0 {
                galleryDebugLog("cellForItem setup image row=\(indexPath.row)")
            }
            setupImageCell(cell, url: imageURL)
        }
        
        return cell
    }

    // MARK: - Cell Setup Methods
    
    /// Set up a cell to display an image
    private func setupImageCell(_ cell: MediaCell, url: URL) {
        let row = cell.tag
        if debugCellConfigCount <= 40 || debugCellConfigCount % 50 == 0 {
            galleryDebugLog("setupImageCell begin row=\(row) url=\(url.absoluteString)")
        }
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
                    galleryDebugLog("setupImageCell using video thumbnail row=\(row) thumbnail=\(thumbnailURL.absoluteString)")
                }
            }
        }
        
        cell.imageView?.kf.setImage(with: displayURL) { [weak self, weak cell] result in
            guard let self = self else { return }
            cell?.activityIndicator?.stopAnimating()
            self.debugLoggedImageCompletions += 1
            if self.debugLoggedImageCompletions <= 25 || self.debugLoggedImageCompletions % 50 == 0 {
                let currentRow = cell?.tag ?? row
                switch result {
                case .success:
                    self.galleryDebugLog("setupImageCell image load success row=\(currentRow) completionCount=\(self.debugLoggedImageCompletions)")
                case .failure(let error):
                    self.galleryDebugLog("setupImageCell image load failed row=\(currentRow) completionCount=\(self.debugLoggedImageCompletions) error=\(error.localizedDescription)")
                }
            }
        }
    }

    private func setupPDFCell(_ cell: MediaCell, url: URL) {
        galleryDebugLog("setupPDFCell row=\(cell.tag) url=\(url.absoluteString)")
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        cell.setupForVideo(configuration: config)
        cell.webView?.navigationDelegate = self
        cell.webView?.load(URLRequest(url: url))
    }
    
    /// Set up a cell to display a video - simpler, more reliable approach
    private func setupVideoCell(_ cell: MediaCell, url: URL) {
        galleryDebugLog("setupVideoCell begin row=\(cell.tag) url=\(url.absoluteString)")
        
        // Get the cell index from tag
        let cellIndex = cell.tag
        
        // Check if we have an alternate URL for this cell
        var alternateURL: URL? = nil
        if cellIndex >= 0 {
            alternateURL = alternateURLs[cellIndex]
            if let altURL = alternateURL {
                galleryDebugLog("setupVideoCell alternate row=\(cellIndex) url=\(altURL.absoluteString)")
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
        
        galleryDebugLog("setupVideoCell mime row=\(cell.tag) primary=\(primaryMimeType) alternate=\(alternateMimeType.isEmpty ? "none" : alternateMimeType)")
        
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
        galleryDebugLog("setupVideoCell loadHTMLString returned row=\(cell.tag)")
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
        
        // Offscreen video previews are torn down in didEndDisplaying so rapid scrolling
        // cannot leave WebKit playback and JavaScript timers alive behind reusable cells.
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let mediaCell = cell as? MediaCell else { return }

        mediaCell.stopMediaPlayback()
        playingVideoCells.remove(indexPath.row)
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

        let postReplyCount = indexPath.row < replyCounts.count ? replyCounts[indexPath.row] : 0
        let postNumber = indexPath.row < postNumbers.count ? postNumbers[indexPath.row] : ""
        let onShowRepliesForPost: (() -> Void)? = (postReplyCount > 0 && !postNumber.isEmpty)
            ? { [weak self] in self?.onShowReplies?(postNumber) }
            : nil

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
            vlcVC.replyCount = postReplyCount
            vlcVC.onShowReplies = onShowRepliesForPost

            if let navController = navigationController {
                navController.pushViewController(vlcVC, animated: true)
            } else {
                let navController = CatalystNavigationController(rootViewController: vlcVC)
                navController.modalPresentationStyle = .fullScreen
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
            urlWebVC.replyCount = postReplyCount
            urlWebVC.onShowReplies = onShowRepliesForPost

            if let navController = navigationController {
                navController.pushViewController(urlWebVC, animated: true)
            } else {
                let navController = CatalystNavigationController(rootViewController: urlWebVC)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }
        } else if fileExtension == "pdf" {
            let urlWebVC = urlWeb()
            urlWebVC.images = [selectedURL]
            urlWebVC.currentIndex = 0
            urlWebVC.enableSwipes = false
            urlWebVC.refererString = refererString
            urlWebVC.replyCount = postReplyCount
            urlWebVC.onShowReplies = onShowRepliesForPost

            if let navController = navigationController {
                navController.pushViewController(urlWebVC, animated: true)
            } else {
                let navController = CatalystNavigationController(rootViewController: urlWebVC)
                navController.modalPresentationStyle = .fullScreen
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
            imageVC.replyCount = postReplyCount
            imageVC.onShowReplies = onShowRepliesForPost

            if let navController = navigationController {
                navController.pushViewController(imageVC, animated: true)
            } else {
                let navController = CatalystNavigationController(rootViewController: imageVC)
                navController.modalPresentationStyle = .fullScreen
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
                popover.channerAnchor(in: self, sourceView: cell, sourceRect: cell.bounds)
            } else {
                popover.sourceView = collectionView
                popover.sourceRect = CGRect(
                    x: collectionView.bounds.midX,
                    y: collectionView.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = .any
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
        debugSizeRequestCount += 1
        if debugSizeRequestCount <= 20 || debugSizeRequestCount % 100 == 0 {
            galleryDebugLog("sizeForItem row=\(indexPath.row) request=\(debugSizeRequestCount) columns=\(columns) collectionWidth=\(collectionView.frame.width) item=\(widthPerItem)")
        }
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    // MARK: - Navigation Updates
    /// Updates gallery state when returning from full-screen view
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        galleryDebugLog("viewWillAppear animated=\(animated) visibleCells=\(collectionView.visibleCells.count) nav=\(String(describing: navigationController))")
        updateGalleryCollectionInsets()

        // Restore navigation bar appearance from theme when returning from media viewers
        // Media viewers (WebMViewController, ImageViewController, urlWeb) set black nav bar
        // and reset to "default" which doesn't match the app's theme
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
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
        galleryDebugLog("viewWillAppear reloadData before visibleCells=\(collectionView.visibleCells.count)")
        collectionView.reloadData()
        updateMediaCounter()
        galleryDebugLog("viewWillAppear end visibleCells=\(collectionView.visibleCells.count)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        galleryDebugLog("viewDidAppear animated=\(animated) visibleCells=\(collectionView.visibleCells.count) contentSize=\(collectionView.contentSize) offset=\(collectionView.contentOffset)")
    }

    private func galleryDebugLog(_ message: String) {
        let elapsed = String(format: "%.3fs", Date().timeIntervalSince(debugStartTime))
        #if targetEnvironment(macCatalyst)
        let platform = "macCatalyst"
        #else
        let platform = "iOS"
        #endif
        print("[ImageGalleryDebug:\(debugID)] +\(elapsed) platform=\(platform) main=\(Thread.isMainThread) \(message)")
    }
}
