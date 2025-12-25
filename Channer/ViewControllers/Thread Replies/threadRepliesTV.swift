import UIKit
import Alamofire
import Kingfisher
import SwiftyJSON
import SystemConfiguration
import Foundation

// No need to import KeyboardShortcutManager as it's in the same project

// MARK: - Reachability (Network Connectivity)

/// Simple network reachability checker
/// Used to determine if device has internet connectivity
class Reachability {
    /// Checks if the device has network connectivity
    /// - Returns: True if connected to network, false otherwise
    class func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
    }
}

// MARK: - Preloading Pipeline
/// Extensions for optimizing thread content loading and caching
extension threadRepliesTV {
    /// Preloads thread content including cell height calculations and image prefetching
    /// Optimizes scrolling performance by precalculating content dimensions
    /// - Parameter completion: Called when preloading completes
    private func preloadThreadContent(completion: @escaping () -> Void) {
        guard !hasPreloadedContent else { completion(); return }
        self.view.layoutIfNeeded()
        self.tableView.layoutIfNeeded()

        let width = self.tableView.bounds.width
        guard width > 0 else { completion(); return }

        let replies = self.threadReplies
        let images = self.threadRepliesImages
        let board = self.boardAbv
        let useHQ = UserDefaults.standard.bool(forKey: "channer_high_quality_thumbnails_enabled")

        DispatchQueue.global(qos: .userInitiated).async {
            var newHeights: [Int: CGFloat] = [:]
            let baseMin: CGFloat = 172
            let verticalPadding: CGFloat = 56 // derived from layout
            let textWidthWithImage = max(0, width - 164) // 8+12+120+8 left, 16 right
            let textWidthNoImage = max(0, width - 36)    // 8+12 left, 16 right

            for i in 0..<replies.count {
                let hasImg = (i < images.count) && (images[i] != "https://i.4cdn.org/\(board)/")
                let text = replies[i]
                let constraintWidth = hasImg ? textWidthWithImage : textWidthNoImage
                let bounds = text.boundingRect(
                    with: CGSize(width: constraintWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let measured = ceil(bounds.height) + verticalPadding
                newHeights[i] = max(baseMin, measured)
            }

            let firstScreenCount = min(12, images.count)
            let firstScreenUrls: [URL] = (0..<firstScreenCount).compactMap { idx in
                guard images[idx] != "https://i.4cdn.org/\(board)/" else { return nil }
                return self.thumbnailURL(from: images[idx], useHQ: useHQ)
            }

            DispatchQueue.main.async {
                for (k, v) in newHeights { self.cellHeightCache[k] = v }
                self.hasPreloadedContent = true

                if !firstScreenUrls.isEmpty {
                    self.imagePrefetcher?.stop()
                    self.imagePrefetcher = ImagePrefetcher(urls: firstScreenUrls, progressBlock: nil) { _, _, _ in
                        completion()
                    }
                    self.imagePrefetcher?.start()
                } else {
                    completion()
                }

                // Background prefetch remaining thumbnails
                let remainingUrls: [URL] = images.enumerated().compactMap { i, raw in
                    guard i >= firstScreenCount, raw != "https://i.4cdn.org/\(board)/" else { return nil }
                    return self.thumbnailURL(from: raw, useHQ: useHQ)
                }
                if !remainingUrls.isEmpty {
                    let backgroundPrefetcher = ImagePrefetcher(urls: remainingUrls)
                    backgroundPrefetcher.start()
                }
            }
        }
    }

    /// Generates thumbnail URL from full image URL
    /// - Parameters:
    ///   - raw: Original full-size image URL
    ///   - useHQ: Whether to use high-quality thumbnails
    /// - Returns: Thumbnail URL or nil if conversion fails
    private func thumbnailURL(from raw: String, useHQ: Bool) -> URL? {
        if raw.hasSuffix(".webm") || raw.hasSuffix(".mp4") {
            let comps = raw.split(separator: "/")
            if let last = comps.last {
                let base = last.replacingOccurrences(of: ".webm", with: "").replacingOccurrences(of: ".mp4", with: "")
                return URL(string: raw.replacingOccurrences(of: String(last), with: "\(base)s.jpg"))
            }
            return URL(string: raw)
        }
        if useHQ { return URL(string: raw) }
        let comps = raw.split(separator: "/")
        if let last = comps.last, let dot = last.firstIndex(of: ".") {
            let filename = String(last[..<dot]) + "s.jpg"
            return URL(string: raw.replacingOccurrences(of: String(last), with: filename))
        }
        return URL(string: raw)
    }
}


// MARK: - Thread Replies Table View Controller

/// Main view controller for displaying thread replies
/// Supports search, filtering, favorites, gallery mode, and offline caching
/// Includes keyboard shortcuts for iPad and optimized scrolling performance
class threadRepliesTV: UIViewController, UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching, UITextViewDelegate, UISearchBarDelegate {
    
    // MARK: - Keyboard Shortcuts
    override var keyCommands: [UIKeyCommand]? {
        // Only provide shortcuts on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nextReplyCommand = UIKeyCommand(input: UIKeyCommand.inputDownArrow, 
                                                modifierFlags: [], 
                                                action: #selector(nextReply),
                                                discoverabilityTitle: "Next Reply")
            
            let previousReplyCommand = UIKeyCommand(input: UIKeyCommand.inputUpArrow, 
                                                    modifierFlags: [], 
                                                    action: #selector(previousReply),
                                                    discoverabilityTitle: "Previous Reply")
            
            let toggleFavoriteCommand = UIKeyCommand(input: "d", 
                                                    modifierFlags: .command, 
                                                    action: #selector(toggleFavoriteShortcut),
                                                    discoverabilityTitle: "Toggle Favorite")
            
            let openGalleryCommand = UIKeyCommand(input: "g", 
                                                modifierFlags: .command, 
                                                action: #selector(openGallery),
                                                discoverabilityTitle: "Open Gallery")
            
            let backToBoardCommand = UIKeyCommand(input: UIKeyCommand.inputEscape, 
                                                 modifierFlags: [], 
                                                 action: #selector(backToBoard),
                                                 discoverabilityTitle: "Back to Board")
            
            return [nextReplyCommand, previousReplyCommand, toggleFavoriteCommand, 
                    openGalleryCommand, backToBoardCommand]
        }
        
        return nil
    }
    
    // MARK: - Keyboard Shortcut Methods
    
    /// Navigate to the next reply
    @objc func nextReply() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else {
            // If nothing is selected, select the first row
            let firstIndexPath = IndexPath(row: 0, section: 0)
            tableView.selectRow(at: firstIndexPath, animated: true, scrollPosition: .middle)
            return
        }
        
        // Calculate the next row
        let nextRow = selectedIndexPath.row + 1
        if nextRow < tableView.numberOfRows(inSection: 0) {
            let nextIndexPath = IndexPath(row: nextRow, section: 0)
            tableView.selectRow(at: nextIndexPath, animated: true, scrollPosition: .middle)
        }
    }
    
    /// Navigate to the previous reply
    @objc func previousReply() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else {
            // If nothing is selected, select the first row
            let firstIndexPath = IndexPath(row: 0, section: 0)
            tableView.selectRow(at: firstIndexPath, animated: true, scrollPosition: .middle)
            return
        }
        
        // Calculate the previous row
        let prevRow = selectedIndexPath.row - 1
        if prevRow >= 0 {
            let prevIndexPath = IndexPath(row: prevRow, section: 0)
            tableView.selectRow(at: prevIndexPath, animated: true, scrollPosition: .middle)
        }
    }
    
    /// Toggle favorite status
    @objc func toggleFavoriteShortcut() {
        toggleFavorite()
    }
    
    /// Open gallery view
    @objc func openGallery() {
        // Implementation depends on how your gallery view is shown
        if totalImagesInThread > 0 {
            showGallery()
        }
    }
    
    /// Go back to board
    @objc func backToBoard() {
        navigationController?.popViewController(animated: true)
    }
    
    /// Called when keyboard shortcuts are toggled in settings
    @objc func keyboardShortcutsToggled(_ notification: Notification) {
        // This will trigger recreation of the keyCommands array
        self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
    
    // MARK: - Properties
    /// Outlets and general properties for the thread view
    let tableView = UITableView()
    var onViewReady: (() -> Void)?
    var boardAbv = ""
    var threadNumber = ""
    let cellIdentifier = "threadRepliesCell"
    private var showSpoilers = false
    private var spoilerButton: UIBarButtonItem?
    private var favoriteButton: UIBarButtonItem?
    private var originalTexts: [String] = []
    private var isLoading = true {
        didSet {
            updateLoadingUI()
        }
    }
    private var isThreadFavorited = false
    private var favorites: [String: [String: Any]] = [:] // Store favorites as [threadNumber: threadData]
    
    // MARK: - Search Properties
    private let searchBar = UISearchBar()
    private var searchText: String = ""
    private var searchFilteredIndices = Set<Int>() // Indices of replies filtered by search
    private var isSearchActive = false
    
    // MARK: - Loading Indicator
    /// UI components for displaying a loading indicator
    private lazy var loadingContainer: UIView = {
        let container = UIView()
        container.backgroundColor = ThemeManager.shared.backgroundColor
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .systemGray
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Thread Data
    /// Data structures for storing thread replies and related information
    var replyCount = 0
    var threadReplies = [NSAttributedString]()
    var threadBoardReplyNumber = [String]()
    var threadBoardReplies = [String: [String]]()
    var threadRepliesImages = [String]()
    var filteredReplyIndices = Set<Int>() // Track indices of filtered replies
    var totalImagesInThread: Int = 0

    // Post metadata for advanced filtering
    var postMetadataList = [PostMetadata]()
    
    // Storage for thread view
    private var threadRepliesOld = [NSAttributedString]()
    private var threadBoardReplyNumberOld = [String]()
    private var threadRepliesImagesOld = [String]()
    
    // Auto-refresh timer
    private var refreshTimer: Timer?
    private let threadsAutoRefreshIntervalKey = "channer_threads_auto_refresh_interval"
    private var lastRefreshTime: Date?
    private var nextRefreshTime: Date?
    
    // Refresh status indicator
    private let refreshStatusView = UIView()
    private let refreshStatusLabel = UILabel()
    private let refreshProgressView = UIProgressView(progressViewStyle: .default)
    private var refreshStatusHeight: NSLayoutConstraint?
    
    // Scroll performance optimization
    private var isScrolling = false
    private var pendingImageLoads = Set<IndexPath>()
    
    // Reload throttling
    private var reloadTimer: Timer?
    private var pendingReloadContext: String?
    
    // Cell height caching
    private var cellHeightCache = [Int: CGFloat]()
    
    // Image loading optimization
    private var imageLoadTimer: Timer?
    private var scrollImageLoadTimer: Timer?
    private let maxConcurrentScrollLoads = 6
    private var currentScrollLoads = 0
    private var lastScrollVelocity: CGFloat = 0

    // Image prefetcher
    private var imagePrefetcher: ImagePrefetcher?
    // Whether we have preloaded heights and first-screen images
    private var hasPreloadedContent = false
    
    // MARK: - Initializer
    
    init() {
        super.init(nibName: nil, bundle: nil)
        // Perform any custom setup here
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle Methods
    /// Lifecycle methods to set up the view
    override func loadView() {
        super.loadView()
        // Set up loading indicator immediately when view is created
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        loadingIndicator.startAnimating()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register for keyboard shortcuts notifications
        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(keyboardShortcutsToggled(_:)), 
                                             name: NSNotification.Name("KeyboardShortcutsToggled"), 
                                             object: nil)
                                             
        // Enable hover interactions for Apple Pencil
        #if canImport(UIHoverGestureRecognizer)
        if #available(iOS 13.4, *) {
            print("threadRepliesTV: Setting up hover gesture support")
            // Enable hover interactions for the entire view
            self.view.isUserInteractionEnabled = true
            // Configure hover interactions for existing cells
            for cell in tableView.visibleCells {
                if let replyCell = cell as? threadRepliesCell {
                    replyCell.setupHoverGestureRecognizer()
                }
            }
        }
        #endif
        
        // Search bar setup
        setupSearchBar()
        
        // Table view setup
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.prefetchDataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.allowsSelection = true
        tableView.register(threadRepliesCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
        
        // Improved scrolling performance
        // Using normal deceleration feels smoother and less abrupt
        tableView.decelerationRate = .normal
        tableView.showsVerticalScrollIndicator = true
        tableView.bounces = true
        tableView.alwaysBounceVertical = true
        tableView.scrollsToTop = true
        
        // Optimize for smooth scrolling
        if #available(iOS 15.0, *) {
            tableView.isPrefetchingEnabled = true // Enable prefetch for smoother image loads
            tableView.sectionHeaderTopPadding = 0
        }
        
        // Memory and performance optimizations
        tableView.remembersLastFocusedIndexPath = false
        
        // Additional scroll performance settings
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.insetsContentViewsToSafeArea = false
        
        // Add long press gesture recognizer for filtering
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        tableView.addGestureRecognizer(longPressGesture)
        
        setupLoadingIndicator()
        setupRefreshStatusIndicator()
        setupNavigationItems()
        checkIfFavorited()
        loadInitialData()
        setupAutoRefreshTimer()
        
        // Hover gesture support now handled by cells directly
        
        // Table constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // table above input bar
        ])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Clean up hover interactions when view disappears
        
        // Stop auto-refresh timer when view disappears
        stopAutoRefreshTimer()
        
        /// Marks the thread as seen in the favorites list when the view disappears, ensuring the reply count is updated.
        /// - Uses `threadNumber` to identify the thread and calls `markThreadAsSeen` in `FavoritesManager`.
        /// This ensures that the thread is no longer highlighted as having new replies in the favorites view.
        if !threadNumber.isEmpty { // Use threadNumber instead of threadID
            FavoritesManager.shared.markThreadAsSeen(threadID: threadNumber)
            FavoritesManager.shared.clearNewRepliesFlag(threadNumber: threadNumber)
            
            // Update application badge count
            DispatchQueue.main.async {
                // Count threads with new replies
                let favorites = FavoritesManager.shared.loadFavorites()
                let threadsWithNewReplies = favorites.filter { $0.hasNewReplies }
                let badgeCount = threadsWithNewReplies.count
                
                // Update badge
                UIApplication.shared.applicationIconBadgeNumber = badgeCount
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.navigationBar.isHidden = false

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

        // Ensure view is visible
        view.isHidden = false
        tableView.isHidden = false

        // Update search bar appearance
        updateSearchBarAppearance()

        // Restart auto-refresh timer when view appears
        setupAutoRefreshTimer()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateSearchBarAppearance()
        }
    }
    
    // MARK: - UI Setup Methods
    /// Methods to set up the UI components and appearance
    private func setupTableView() {
        // Clear background
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Remove any automatic adjustments
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        }
        
        // Configure table view
        tableView.separatorStyle = .none
        
        // Register cell if using programmatic cell
        // tableView.register(threadRepliesCell.self, forCellReuseIdentifier: cellIdentifier)
        
        // Add loading indicator
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func setupTableViewLayout() {
        // Configure table view basic properties
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set background colors
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Configure table view properties
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
    }
    
    private func setupUI() {
        // Configure view and table view
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.separatorStyle = .none
        
        // Remove any extra spacing or insets
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        
        // Configure loading indicator in center of view
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Setup navigation items
        setupNavigationItems()
        
        // Start in loading state
        isLoading = true
        updateLoadingUI()
    }
    
    private func configureView() {
        // Set background colors immediately
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Configure navigation bar
        navigationController?.navigationBar.backgroundColor = ThemeManager.shared.backgroundColor
        navigationController?.view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Configure table view
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
        
        // Setup loading indicator
        setupLoadingIndicator()
        
        // Setup navigation items
        setupNavigationItems()
    }
    
    private func configureViewAppearance() {
        // Clear background colors
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor

        // Configure table view
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
    }
    
    private func configureInitialUI() {
        // Set background colors
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Configure table view
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
        
        // Initially hide the table view while loading
        tableView.isHidden = true
        
        // Add and configure loading indicator
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Start loading state
        isLoading = true
        
        // Set up navigation items
        setupNavigationItems()
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        view.bringSubviewToFront(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func setupRefreshStatusIndicator() {
        // Sets up the refresh status indicator
        refreshStatusView.backgroundColor = ThemeManager.shared.secondaryBackgroundColor
        refreshStatusView.layer.borderWidth = 1
        refreshStatusView.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        refreshStatusView.translatesAutoresizingMaskIntoConstraints = false
        refreshStatusView.isHidden = true
        
        refreshStatusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        refreshStatusLabel.textColor = ThemeManager.shared.secondaryTextColor
        refreshStatusLabel.textAlignment = .center
        refreshStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        refreshProgressView.progressTintColor = ThemeManager.shared.primaryTextColor
        refreshProgressView.trackTintColor = ThemeManager.shared.secondaryBackgroundColor
        refreshProgressView.translatesAutoresizingMaskIntoConstraints = false
        
        refreshStatusView.addSubview(refreshStatusLabel)
        refreshStatusView.addSubview(refreshProgressView)
        view.addSubview(refreshStatusView)
        
        refreshStatusHeight = refreshStatusView.heightAnchor.constraint(equalToConstant: 44)
        NSLayoutConstraint.activate([
            refreshStatusView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            refreshStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            refreshStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            refreshStatusHeight!,
            
            refreshStatusLabel.topAnchor.constraint(equalTo: refreshStatusView.topAnchor, constant: 4),
            refreshStatusLabel.leadingAnchor.constraint(equalTo: refreshStatusView.leadingAnchor, constant: 8),
            refreshStatusLabel.trailingAnchor.constraint(equalTo: refreshStatusView.trailingAnchor, constant: -8),
            
            refreshProgressView.topAnchor.constraint(equalTo: refreshStatusLabel.bottomAnchor, constant: 4),
            refreshProgressView.leadingAnchor.constraint(equalTo: refreshStatusView.leadingAnchor, constant: 8),
            refreshProgressView.trailingAnchor.constraint(equalTo: refreshStatusView.trailingAnchor, constant: -8),
            refreshProgressView.bottomAnchor.constraint(equalTo: refreshStatusView.bottomAnchor, constant: -4),
            refreshProgressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
    
    // MARK: - Navigation Item Setup Methods
    /// Methods to configure navigation bar items and actions
    private func setupNavigationItems() {
        // Create the Favorites button with resized image
        let favoriteImage = (isThreadFavorited ? UIImage(named: "favoriteFilled") : UIImage(named: "favorite"))?.withRenderingMode(.alwaysTemplate)
        let resizedFavoriteImage = favoriteImage?.resized(to: CGSize(width: 22, height: 22))
        favoriteButton = UIBarButtonItem(image: resizedFavoriteImage,
                                         style: .plain,
                                         target: self,
                                         action: #selector(toggleFavorite))
        
        // Create the Gallery button with resized image
        let galleryImage = UIImage(named: "gallery")?.withRenderingMode(.alwaysTemplate)
        let resizedGalleryImage = galleryImage?.resized(to: CGSize(width: 22, height: 22))
        let galleryButton = UIBarButtonItem(image: resizedGalleryImage,
                                            style: .plain,
                                            target: self,
                                            action: #selector(showGallery))
        
        // Create the More button with resized image
        let moreImage = UIImage(named: "more")?.withRenderingMode(.alwaysTemplate)
        let resizedMoreImage = moreImage?.resized(to: CGSize(width: 22, height: 22))
        let moreButton = UIBarButtonItem(image: resizedMoreImage,
                                         style: .plain,
                                         target: self,
                                         action: #selector(showActionSheet))
        
        // Set the buttons in the navigation bar
        navigationItem.rightBarButtonItems = [moreButton, galleryButton, favoriteButton!]
    }
    
    // MARK: - Search Bar Setup
    private func setupSearchBar() {
        view.addSubview(searchBar)
        searchBar.delegate = self
        searchBar.placeholder = "Search in thread..."
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Remove all backgrounds and borders
        searchBar.backgroundImage = UIImage()
        searchBar.barTintColor = ThemeManager.shared.backgroundColor
        searchBar.backgroundColor = ThemeManager.shared.backgroundColor
        searchBar.isTranslucent = false
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        
        // Remove the search bar border
        searchBar.layer.borderWidth = 0
        searchBar.layer.borderColor = UIColor.clear.cgColor
        
        // Make the search field background match the theme
        if let searchField = searchBar.value(forKey: "searchField") as? UITextField {
            searchField.backgroundColor = ThemeManager.shared.cellBackgroundColor
            searchField.textColor = ThemeManager.shared.primaryTextColor
            searchField.layer.cornerRadius = 10
            searchField.clipsToBounds = true
        }
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func updateSearchBarAppearance() {
        // Update search bar colors
        searchBar.barTintColor = ThemeManager.shared.backgroundColor
        searchBar.backgroundColor = ThemeManager.shared.backgroundColor
        searchBar.backgroundImage = UIImage()
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        
        // Remove borders
        searchBar.layer.borderWidth = 0
        searchBar.layer.borderColor = UIColor.clear.cgColor
        
        // Update search field appearance
        if let searchField = searchBar.value(forKey: "searchField") as? UITextField {
            searchField.backgroundColor = ThemeManager.shared.cellBackgroundColor
            searchField.textColor = ThemeManager.shared.primaryTextColor
            searchField.layer.cornerRadius = 10
            searchField.clipsToBounds = true
        }
        
        // Update the placeholder text color
        if let searchField = searchBar.value(forKey: "searchField") as? UITextField,
           let placeholderLabel = searchField.value(forKey: "placeholderLabel") as? UILabel {
            placeholderLabel.textColor = ThemeManager.shared.secondaryTextColor
        }
    }
    
    @objc private func showActionSheet() {
        // Create an action sheet
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Add actions for additional navigation options
        actionSheet.addAction(UIAlertAction(title: "Refresh", style: .default, handler: { _ in
            self.refresh()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Bottom", style: .default, handler: { _ in
            self.down()
        }))
        
        actionSheet.addAction(UIAlertAction(title: showSpoilers ? "Hide Spoilers" : "Show Spoilers", style: .default, handler: { _ in
            self.toggleSpoilers()
        }))
        
        // Add filter options
        actionSheet.addAction(UIAlertAction(title: "Filter Content", style: .default, handler: { _ in
            self.showFilterOptions()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Open in Browser", style: .default, handler: { _ in
            self.openInBrowser()
        }))
        
        // Add Save for Offline Reading option if we're online and the thread isn't already cached
        if Reachability.isConnectedToNetwork() && !ThreadCacheManager.shared.isCached(boardAbv: boardAbv, threadNumber: threadNumber) {
            actionSheet.addAction(UIAlertAction(title: "Save for Offline Reading", style: .default, handler: { _ in
                self.saveForOfflineReading()
            }))
        } 
        // Add Remove from Offline Cache option if thread is cached
        else if ThreadCacheManager.shared.isCached(boardAbv: boardAbv, threadNumber: threadNumber) {
            actionSheet.addAction(UIAlertAction(title: "Remove from Offline Cache", style: .destructive, handler: { _ in
                self.removeFromOfflineCache()
            }))
        }
        
        // Add a cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // Configure the popover presentation controller for iPad or SplitView
        if let popover = actionSheet.popoverPresentationController {
            if let barButton = navigationItem.rightBarButtonItems?.first(where: { $0.action == #selector(showActionSheet) }) {
                popover.barButtonItem = barButton
                popover.permittedArrowDirections = .up
            } else {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the action sheet
        present(actionSheet, animated: true, completion: nil)
    }
    
    @objc private func showGallery() {
        print("Gallery button tapped.")
        
        // Pass original URLs directly to gallery (same as thread view does)
        // This ensures videos play correctly in gallery just like in thread view
        let imageUrls = threadRepliesImages.compactMap { imageUrlString -> URL? in
            guard let url = URL(string: imageUrlString) else { return nil }
            if url.absoluteString == "https://i.4cdn.org/\(boardAbv)/" { return nil }
            
            // Pass original URLs directly - no thumbnail conversion
            // This matches thread view behavior where original URLs are used
            print("Using original URL for gallery: \(imageUrlString)")
            return url
        }
        
        print("Filtered image URLs for gallery: \(imageUrls)")
        
        // Instantiate the gallery view controller with original URLs
        let galleryVC = ImageGalleryVC(images: imageUrls)
        print("GalleryVC instantiated with original URLs.")
        
        // Navigate to the gallery
        if let navController = navigationController {
            print("Pushing galleryVC onto navigation stack.")
            navController.pushViewController(galleryVC, animated: true)
        } else {
            print("Navigation controller is nil. Attempting modal presentation.")
            let navController = UINavigationController(rootViewController: galleryVC)
            present(navController, animated: true)
        }
    }
    
    // MARK: - Table View Data Source Methods
    /// Methods required to display data in the table view
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //print("Number of rows: \(isLoading ? 0 : replyCount)")
        if isLoading {
            return 0
        }
        
        // If search is active, only count unfiltered rows
        if isSearchActive && !searchText.isEmpty {
            return threadReplies.count - searchFilteredIndices.count
        }
        
        return threadReplies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Reduced logging - only for debugging if needed
        // print("🔄 CELL: Configuring cell \(indexPath.row)")
        
        // Always return a fully reusable cell; skip heavy work during scroll below
        
        // If search is active, we need to map the visible row index to the actual data index
        var actualIndex = indexPath.row
        if isSearchActive && !searchText.isEmpty {
            var visibleIndex = 0
            for dataIndex in 0..<threadReplies.count {
                if !searchFilteredIndices.contains(dataIndex) {
                    if visibleIndex == indexPath.row {
                        actualIndex = dataIndex
                        break
                    }
                    visibleIndex += 1
                }
            }
        }
        
        guard actualIndex < threadReplies.count else {
            print("Index out of bounds: \(actualIndex)")
            return UITableViewCell() // Placeholder to avoid crashing
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! threadRepliesCell
        
        // Set up the reply button's target-action
        //cell.reply.tag = actualIndex
        //cell.reply.addTarget(self, action: #selector(replyButtonTapped(_:)), for: .touchUpInside)
        
        // Set the text view delegate to self
        cell.replyTextDelegate = self
        
        // Add visual indicator for hover functionality
        if #available(iOS 13.4, *) {
            if actualIndex < threadRepliesImages.count {
                let hasValidImage = threadRepliesImages[actualIndex] != "https://i.4cdn.org/\(boardAbv)/"
                
                if hasValidImage {
                    // Remove any existing border
                    cell.threadImage.layer.borderWidth = 0.0
                }
            }
        }
        
        // Debug: Start of cell configuration
        //print("Debug: Configuring cell at row \(indexPath.row)")
        
        if threadReplies.isEmpty {
            //print("Debug: No replies available, showing loading text")
            cell.configure(withImage: false,
                           text: NSAttributedString(string: "Loading..."),
                           boardNumber: "",
                           isFiltered: false)
        } else {
            let imageUrl = threadRepliesImages[actualIndex]
            let hasImage = imageUrl != "https://i.4cdn.org/\(boardAbv)/"
            let attributedText = threadReplies[actualIndex]
            let boardNumber = threadBoardReplyNumber[actualIndex]
            let isFiltered = filteredReplyIndices.contains(actualIndex)
            
            // Debug: Content of the reply
            //print("Debug: Configuring cell with image: \(hasImage), text: \(attributedText.string), boardNumber: \(boardNumber)")
            
            // Configure the cell with text and other details
            cell.configure(withImage: hasImage,
                           text: attributedText,
                           boardNumber: boardNumber,
                           isFiltered: isFiltered)
            
            // Set the attributed text based on whether the cell has an image
            if hasImage {
                //print("Debug: Cell contains an image, setting replyText")
                cell.replyText.attributedText = attributedText
            } else {
                //print("Debug: Cell does not contain an image, setting replyTextNoImage")
                cell.replyTextNoImage.attributedText = attributedText
            }
            
            // Set up image if present
            if hasImage {
                print("🔄 CELL: Cell \(indexPath.row) has image, calling configureImage")
                configureImage(for: cell, with: imageUrl, at: indexPath)
                
                // Prepare cell for hover interaction
                if #available(iOS 13.4, *) {
                    // Remove any existing border
                    cell.threadImage.layer.borderWidth = 0.0
                    
                    // Store the image URL for hover preview
                    cell.setImageURL(imageUrl) 
                }
                cell.threadImage.tag = actualIndex
                cell.threadImage.addTarget(self, action: #selector(threadContentOpen), for: .touchUpInside)
            }
            
            // Configure reply button visibility
            if let replies = threadBoardReplies[boardNumber], !replies.isEmpty {
                //print("Debug: Found \(replies.count) replies for boardNumber \(boardNumber), showing thread button")
                cell.thread.isHidden = false
                cell.thread.tag = actualIndex
                cell.thread.addTarget(self, action: #selector(showThread), for: .touchUpInside)
            } else {
                //print("Debug: No replies for boardNumber \(boardNumber), hiding thread button")
                cell.thread.isHidden = true
            }
        }
        
        // Avoid forcing synchronous layout here to keep scrolling smooth
        
        return cell
    }
    
    // MARK: - Height Caching for Performance
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        // Return cached height if available
        if let cachedHeight = cellHeightCache[indexPath.row] {
            return cachedHeight
        }
        // Use a reasonable estimate based on content
        return 172
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Cache the actual cell height after it's been laid out
        let height = cell.frame.size.height
        cellHeightCache[indexPath.row] = height
    }
    
    // MARK: - Prefetching for Scroll Performance
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // Prefetch only image data using Kingfisher, not cells
        if isScrolling { return }
        let urls: [URL] = indexPaths.compactMap { ip in
            guard ip.row < threadRepliesImages.count else { return nil }
            let raw = threadRepliesImages[ip.row]
            guard !raw.isEmpty, raw != "https://i.4cdn.org/\(boardAbv)/" else { return nil }
            let useHQ = UserDefaults.standard.bool(forKey: "channer_high_quality_thumbnails_enabled")
            return thumbnailURL(from: raw, useHQ: useHQ)
        }
        guard !urls.isEmpty else { return }
        imagePrefetcher?.stop()
        imagePrefetcher = ImagePrefetcher(urls: urls)
        imagePrefetcher?.start()
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // Stop active image prefetching and clear pending markers
        imagePrefetcher?.stop()
        for indexPath in indexPaths { pendingImageLoads.remove(indexPath) }
    }
    
    // Removed minimal cell creation to avoid layout thrash and reuse issues
    
    // MARK: - Data Loading Methods
    /// Methods to handle data fetching and processing
    var shouldLoadFullThread: Bool = true
    
    private func loadInitialData() {
        // If shouldLoadFullThread is false, do not reload data
        guard shouldLoadFullThread else {
            isLoading = false
            print("Loading initial data...")
            print("Reply count: \(replyCount), Thread replies: \(threadReplies.count)")
            debugReloadData(context: "Search filter update")
            return
        }
        
        // Check if threadNumber is set
        guard !threadNumber.isEmpty else {
            isLoading = false
            onViewReady?()
            return
        }
        
        let urlString = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        print("Loading data from: \(urlString)") // Debug print
        
        // Check if thread is available in cache when offline
        if ThreadCacheManager.shared.isOfflineReadingEnabled() && !Reachability.isConnectedToNetwork() {
            print("Device is offline, checking cache")
            if let cachedData = ThreadCacheManager.shared.getCachedThread(boardAbv: boardAbv, threadNumber: threadNumber) {
                print("Loading thread from cache")
                DispatchQueue.main.async {
                    do {
                        // Parse JSON response from cached data
                        let json = try JSON(data: cachedData)
                        self.processThreadData(json)
                        self.structureThreadReplies()
                        self.preloadThreadContent { [weak self] in
                            guard let self = self else { return }
                            self.isLoading = false
                            self.loadingIndicator.stopAnimating()
                            self.tableView.reloadData()
                            self.onViewReady?()
                        }
                    } catch {
                        print("Error parsing cached JSON: \(error)")
                        self.handleLoadError()
                        self.onViewReady?()
                    }
                }
                return
            } else {
                // No cached version available
                self.handleOfflineError()
                return
            }
        }
        
        // Perform network request
        let request = AF.request(urlString)
        request.responseData { [weak self] response in
            guard let self = self else { return }
            
            // Process the response on main thread
            DispatchQueue.main.async {
                self.handleNetworkResponse(response)
            }
        }
    }
    
    private func handleNetworkResponse(_ response: AFDataResponse<Data>) {
        switch response.result {
        case .success(let data):
            do {
                // Parse JSON response
                let json = try JSON(data: data)
                self.processThreadData(json)
                self.structureThreadReplies()
                
                // Cache thread if offline reading is enabled
                if ThreadCacheManager.shared.isOfflineReadingEnabled() && 
                   ThreadCacheManager.shared.isCached(boardAbv: self.boardAbv, threadNumber: self.threadNumber) {
                    print("Thread was successfully loaded and is already cached")
                }
                
                // Preload heights and first-screen thumbnails, then present
                self.preloadThreadContent { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.loadingIndicator.stopAnimating()
                    self.debugReloadData(context: "Preload complete")
                    self.onViewReady?()
                }
            } catch {
                print("Error parsing JSON: \(error)")
                self.handleLoadError()
                self.onViewReady?()
            }
        case .failure(let error):
            print("Network error: \(error)")
            self.handleLoadError()
            self.onViewReady?()
        }
    }
    
    private func loadData() {
        guard !threadNumber.isEmpty else {
            isLoading = false
            return
        }
        
        let urlString = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        
        let request = AF.request(urlString)
        request.responseData { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.handleLoadDataResponse(response)
            }
        }
    }
    
    private func handleLoadDataResponse(_ response: AFDataResponse<Data>) {
        switch response.result {
        case .success(let data):
            do {
                let json = try JSON(data: data)
                self.processThreadData(json)
                self.structureThreadReplies()
                self.preloadThreadContent { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.tableView.reloadData()
                }
            } catch {
                print("JSON parsing error: \(error)")
                self.handleLoadError()
            }
        case .failure(let error):
            print("Network error: \(error)")
            self.handleLoadError()
        }
    }
    
    private func handleLoadError() {
        isLoading = false
        
        let alert = UIAlertController(
            title: "Loading Error",
            message: "Failed to load thread data. Please try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.loadInitialData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func handleOfflineError() {
        isLoading = false
        
        let alert = UIAlertController(
            title: "Offline Mode",
            message: "You are currently offline and this thread has not been saved for offline reading.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func processThreadData(_ json: JSON) {
        hasPreloadedContent = false
        // Clear existing data before processing
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        threadBoardReplies.removeAll()
        originalTexts.removeAll()
        postMetadataList.removeAll()
        
        // Get original reply count
        replyCount = Int(json["posts"][0]["replies"].stringValue) ?? 0
        
        // Handle case with no replies
        if replyCount == 0 {
            processPost(json["posts"][0], index: 0)
            replyCount = 1
            structureThreadReplies()
            return
        }
        
        // Apply content filtering to JSON if enabled
        var filteredJson: JSON = json
        if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
           let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
           let isEnabled = manager.perform(NSSelectorFromString("isFilteringEnabled"))?.takeUnretainedValue() as? Bool,
           isEnabled {
            // Use raw invocation to filter posts
            if let returnValue = manager.perform(NSSelectorFromString("filterPosts:"), with: json) {
                filteredJson = returnValue.takeUnretainedValue() as? JSON ?? json
            }
        }
        
        // Process all posts in the thread
        let posts = filteredJson["posts"].arrayValue
        for post in posts {
            processPost(post, index: posts.firstIndex(of: post) ?? 0)
        }
        
        // Apply additional content filtering
        applyContentFiltering()

        // Finalize thread structure
        structureThreadReplies()

        // Check for new replies to watched posts
        checkWatchedPostsForNewReplies()
    }

    /// Checks watched posts for new replies and creates notifications
    private func checkWatchedPostsForNewReplies() {
        guard !threadNumber.isEmpty, !boardAbv.isEmpty else { return }

        let newRepliesCount = WatchedPostsManager.shared.checkForNewReplies(
            threadNo: threadNumber,
            boardAbv: boardAbv,
            threadReplies: threadReplies,
            replyNumbers: threadBoardReplyNumber
        )

        if newRepliesCount > 0 {
            print("Found \(newRepliesCount) new replies to watched posts")
        }
    }
    
    private func processPost(_ post: JSON, index: Int) {
        // Extract the board reply number
        let replyNumber = String(describing: post["no"])
        threadBoardReplyNumber.append(replyNumber)

        // Extract the image URL and related data
        let imageTimestamp = post["tim"].stringValue
        let imageExtension = post["ext"].stringValue
        let imageName = post["filename"].stringValue
        let imageURL = imageTimestamp.isEmpty ? "" : "https://i.4cdn.org/\(boardAbv)/\(imageTimestamp)\(imageExtension)"
        threadRepliesImages.append(imageURL.isEmpty ? "https://i.4cdn.org/\(boardAbv)/" : imageURL)

        // Debug logging for PNG images
        if imageExtension == ".png" {
            print("PNG Image found in post #\(replyNumber): \(imageURL)")
        }

        // Extract and process the comment text
        let comment = post["com"].stringValue

        // Store the original unprocessed text for toggling spoilers later
        originalTexts.append(comment)

        // Format the comment text with spoiler visibility
        let formattedComment = TextFormatter.formatText(comment, showSpoilers: showSpoilers)
        threadReplies.append(formattedComment)

        // Extract additional metadata for advanced filtering
        let posterId = post["id"].stringValue  // Poster ID (if available on board)
        let tripCode = post["trip"].stringValue  // Trip code
        let countryCode = post["country"].stringValue  // Country code (e.g., "US")
        let countryName = post["country_name"].stringValue  // Country name
        let timestamp = post["time"].int  // Unix timestamp

        // Create PostMetadata for advanced filtering
        let metadata = PostMetadata(
            postNumber: replyNumber,
            comment: comment,
            posterId: posterId.isEmpty ? nil : posterId,
            tripCode: tripCode.isEmpty ? nil : tripCode,
            countryCode: countryCode.isEmpty ? nil : countryCode,
            countryName: countryName.isEmpty ? nil : countryName,
            timestamp: timestamp,
            imageUrl: imageURL.isEmpty ? nil : imageURL,
            imageExtension: imageExtension.isEmpty ? nil : imageExtension,
            imageName: imageName.isEmpty ? nil : imageName
        )
        postMetadataList.append(metadata)
    }
    
    // MARK: - Favorite Handling Methods
    /// Methods to manage thread favorites
    @objc private func toggleFavorite() {
        guard !threadNumber.isEmpty else { return }
        
        if FavoritesManager.shared.isFavorited(threadNumber: threadNumber) {
            print("Removing favorite for thread: \(threadNumber)")
            FavoritesManager.shared.removeFavorite(threadNumber: threadNumber)
            updateFavoriteButton()
        } else {
            // Show category selection
            showCategorySelectionForFavorite()
        }
        
        print("Favorite button updated.")
    }
    
    private func createThreadDataForFavorite() -> ThreadData {
        let threadData = ThreadData(
            number: threadNumber,
            stats: "\(replyCount)/\(totalImagesInThread)",
            title: title ?? "",
            comment: threadReplies.first?.string ?? "",
            imageUrl: threadRepliesImages.first ?? "",
            boardAbv: boardAbv,
            replies: replyCount,
            createdAt: "" // Populate if necessary
        )
        print("=== createThreadDataForFavorite ===")
        print("Created ThreadData with no category (will be set later)")
        print("Thread number: \(threadData.number)")
        print("Board: \(threadData.boardAbv)")
        return threadData
    }
    
    private func updateFavoriteButton() {
        let isFavorited = FavoritesManager.shared.isFavorited(threadNumber: threadNumber)
        let favoriteImage = UIImage(named: isFavorited ? "favoriteFilled" : "favorite")?.withRenderingMode(.alwaysTemplate)
        let resizedFavoriteImage = favoriteImage?.resized(to: CGSize(width: 22, height: 22))
        favoriteButton?.image = resizedFavoriteImage
    }
    
    private func addFavorite() {
        guard !threadNumber.isEmpty else {
            print("Cannot add favorite: threadNumber is empty")
            return
        }
        
        // Use the transferred totalImagesInThread count
        let stats = "\(replyCount)/\(totalImagesInThread)"
        print(stats)
        print(totalImagesInThread)
        
        let favorite = ThreadData(
            number: threadNumber,
            stats: stats,
            title: title ?? "",
            comment: threadReplies.first?.string ?? "",
            imageUrl: threadRepliesImages.first ?? "",
            boardAbv: boardAbv,
            replies: replyCount,
            createdAt: "" // Provide the appropriate value if needed
        )
        
        FavoritesManager.shared.addFavorite(favorite)
        
        print("Added to favorites: \(favorite)")
    }
    
    private func removeFavorite() {
        FavoritesManager.shared.removeFavorite(threadNumber: threadNumber)
    }
    
    private func loadFavorites() -> [ThreadData] {
        return FavoritesManager.shared.loadFavorites()
    }
    
    // Save a single favorite thread
    func saveFavorite(_ favorite: ThreadData) {
        FavoritesManager.shared.addFavorite(favorite)
    }
    
    private func checkIfFavorited() {
        let isFavorited = FavoritesManager.shared.isFavorited(threadNumber: threadNumber)
        
        // Update the favorite button's image
        let favoriteImageName = isFavorited ? "favoriteFilled" : "favorite"
        if let favoriteButton = navigationItem.rightBarButtonItems?.first(where: { $0.action == #selector(toggleFavorite) }) {
            let favoriteImage = UIImage(named: favoriteImageName)?.withRenderingMode(.alwaysTemplate)
            let resizedFavoriteImage = favoriteImage?.resized(to: CGSize(width: 22, height: 22))
            favoriteButton.image = resizedFavoriteImage
        } else {
            print("Favorite button not found in rightBarButtonItems")
        }
    }
    
    private func showCategorySelectionForFavorite() {
        print("=== showCategorySelectionForFavorite called ===")
        let categories = FavoritesManager.shared.getCategories()
        print("Available categories: \(categories.count)")
        
        // Create an action sheet with category options
        let alert = UIAlertController(title: "Select Category", message: "Choose a category for this bookmark", preferredStyle: .actionSheet)
        
        // Add an action for each category
        for category in categories {
            print("Adding action for category: \(category.name) (ID: \(category.id))")
            let action = UIAlertAction(title: category.name, style: .default) { [weak self] _ in
                guard let self = self else { return }
                print("=== Category selected: \(category.name) ===")
                print("Category ID: \(category.id)")
                print("Thread number: \(self.threadNumber)")
                
                let favorite = self.createThreadDataForFavorite()
                print("Created ThreadData with category to be set: \(category.id)")
                FavoritesManager.shared.addFavorite(favorite, to: category.id)
                self.updateFavoriteButton()
            }
            
            // Add category color as icon
            let color = UIColor(hex: category.color) ?? UIColor.systemBlue
            action.setValue(color, forKey: "titleTextColor")
            
            alert.addAction(action)
        }
        
        // Add cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad, set the popover presentation controller
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = favoriteButton
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Spoiler Handling Methods
    /// Methods to handle spoiler visibility in comments
    @objc private func toggleSpoilers() {
        showSpoilers.toggle()
        spoilerButton?.image = UIImage(named: showSpoilers ? "hide" : "show")
        print("Spoiler visibility toggled. Current state: \(showSpoilers)")
        
        // Reprocess all replies with updated spoiler state
        for (index, originalText) in originalTexts.enumerated() {
            let updatedText = TextFormatter.formatText(originalText, showSpoilers: showSpoilers)
            threadReplies[index] = updatedText
        }
        
        // Reload the table view
        debugReloadData(context: "Search filter update")
    }
    
    private func formatComment(_ comment: String, preserveOriginal: Bool = false) -> NSAttributedString {
        // Save original text if needed
        if preserveOriginal {
            originalTexts.append(comment)
        }
        
        // Initial cleanup of HTML codes
        var text = comment
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "<wbr>", with: "")
            .replacingOccurrences(of: "&amp;", with: "&")
        
        // Remove any remaining HTML tags
        let htmlPattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: htmlPattern, options: []) {
            text = regex.stringByReplacingMatches(in: text,
                                                  range: NSRange(text.startIndex..., in: text),
                                                  withTemplate: "")
        }
        
        let attributedString = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix(">>") {
                // Handle quoted reply references (blue color, clickable)
                let postNumber = line.dropFirst(2)
                let displayText = line + "\n"
                if let url = URL(string: "post://\(postNumber)") {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor.blue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: url,
                        .font: UIFont.systemFont(ofSize: 14) // Set font size to 14
                    ]
                    attributedString.append(NSAttributedString(string: displayText, attributes: attributes))
                } else {
                    // Fallback for when the URL creation fails
                    let normalAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: ThemeManager.shared.primaryTextColor,
                        .font: UIFont.systemFont(ofSize: 14) // Set font size to 14
                    ]
                    attributedString.append(NSAttributedString(string: displayText, attributes: normalAttributes))
                }
            } else if line.hasPrefix(">") && !line.hasPrefix(">>") {
                // Handle greentext (green color)
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0),
                    .font: UIFont.systemFont(ofSize: 14) // Set font size to 14
                ]
                let displayText = line + "\n"
                attributedString.append(NSAttributedString(string: displayText, attributes: attributes))
            } else {
                // Handle normal text
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: ThemeManager.shared.primaryTextColor,
                    .font: UIFont.systemFont(ofSize: 14) // Set font size to 14
                ]
                let displayText = line + "\n"
                attributedString.append(NSAttributedString(string: displayText, attributes: attributes))
            }
        }
        
        return attributedString
    }
    
    private func processSpoilerText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: showSpoilers ? UIColor.white : UIColor.black,
                .backgroundColor: UIColor.black
            ]
            result.append(NSAttributedString(string: line, attributes: attributes))
            
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        
        return result
    }
    
    private func processNormalText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            if line.hasPrefix(">>") {
                // Quote link - Using custom attributes instead of URL
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.blue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    // Store post number as custom attribute
                    .init(rawValue: "PostReference"): String(line.dropFirst(2))
                ]
                result.append(NSAttributedString(string: line, attributes: attributes))
            } else if line.hasPrefix(">") {
                // Greentext
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
                ]
                result.append(NSAttributedString(string: line, attributes: attributes))
            } else {
                // Normal text
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: ThemeManager.shared.primaryTextColor
                ]
                result.append(NSAttributedString(string: line, attributes: attributes))
            }
            
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        
        return result
    }
    
    // MARK: - Text View Delegate Methods
    /// UITextViewDelegate methods for handling text interactions
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        if URL.scheme == "post" {
            let postNumber = URL.host ?? ""
            if let index = threadBoardReplyNumber.firstIndex(of: postNumber) {
                // Show the specific thread post related to this reference
                showThread(sender: UIButton().apply { $0.tag = index })
            }
            return false // Prevent default interaction
        }
        
        // Handle any other types of URL as needed
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.returnKeyType = .default
    }
    
    // MARK: - Gesture Handling Methods
    /// Methods to handle gestures in the view
    @objc private func handleTextViewTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? UITextView else { return }
        
        let location = gesture.location(in: textView)
        let characterIndex = textView.layoutManager.characterIndex(for: location,
                                                                   in: textView.textContainer,
                                                                   fractionOfDistanceBetweenInsertionPoints: nil)
        
        // Check if the tap is within text bounds
        if characterIndex < textView.textStorage.length {
            let attributes = textView.attributedText.attributes(at: characterIndex, effectiveRange: nil)
            
            // Check for custom "PostReference" attribute
            if let postNumber = attributes[.init(rawValue: "PostReference")] as? String {
                // Find index and open the thread
                if let index = threadBoardReplyNumber.firstIndex(of: postNumber) {
                    showThread(sender: UIButton().apply { $0.tag = index })
                }
            }
        }
    }
    
    // MARK: - Image Handling Methods
    /// Methods to handle image loading and interactions
    private func configureImage(for cell: threadRepliesCell, with imageUrl: String, at indexPath: IndexPath? = nil) {
        print("Debug: Starting image configuration for URL: \(imageUrl)")

        // During scrolling, use velocity-based loading strategy
        if isScrolling {
            let shouldLoadDuringScroll = abs(lastScrollVelocity) < 800 || currentScrollLoads < maxConcurrentScrollLoads

            print("🖼️ IMAGE: isScrolling=\(isScrolling), velocity=\(lastScrollVelocity), currentLoads=\(currentScrollLoads)/\(maxConcurrentScrollLoads), shouldLoad=\(shouldLoadDuringScroll)")

            if shouldLoadDuringScroll {
                print("🖼️ IMAGE: Loading during scroll: \(imageUrl)")
                loadImageDuringScroll(for: cell, with: imageUrl)
            } else {
                print("🖼️ IMAGE: Deferring image load during fast scroll for: \(imageUrl)")
                cell.threadImage.setImage(UIImage(named: "loadingBoardImage"), for: .normal)
                // Track this cell for loading after scrolling ends
                if let indexPath = indexPath {
                    pendingImageLoads.insert(indexPath)
                    print("🖼️ IMAGE: Added indexPath \(indexPath.row) to pendingImageLoads")
                }
            }
            return
        }
        
        // Check if high-quality thumbnails are enabled
        let useHighQualityThumbnails = UserDefaults.standard.bool(forKey: "channer_high_quality_thumbnails_enabled")
        
        // Extract file extension from URL
        let fileExtension: String
        if imageUrl.hasSuffix(".jpg") {
            fileExtension = ".jpg"
        } else if imageUrl.hasSuffix(".png") {
            fileExtension = ".png"
            print("Debug: PNG image detected in configureImage: \(imageUrl)")
        } else if imageUrl.hasSuffix(".webm") {
            fileExtension = ".webm"
        } else if imageUrl.hasSuffix(".mp4") {
            fileExtension = ".mp4"
        } else {
            // Default to JPG if extension can't be determined
            fileExtension = ".jpg"
            print("Debug: Unknown extension, defaulting to JPG for: \(imageUrl)")
        }
        
        let finalUrl: String
        if fileExtension == ".webm" || fileExtension == ".mp4" {
            let components = imageUrl.components(separatedBy: "/")
            if let last = components.last {
                let base = last.replacingOccurrences(of: fileExtension, with: "")
                
                // For videos, always use thumbnail ("s.jpg" suffix)
                finalUrl = imageUrl.replacingOccurrences(of: last, with: "\(base)s.jpg")
                print("Debug: Video thumbnail URL: \(finalUrl)")
            } else {
                finalUrl = imageUrl
            }
        } else {
            // For images, use full image URL or thumbnail URL based on user preference
            if useHighQualityThumbnails {
                // Use the original full-quality image URL
                finalUrl = imageUrl
                print("Debug: Using high-quality image: \(finalUrl)")
            } else {
                // Use the thumbnail URL by adding "s" before the extension
                let components = imageUrl.components(separatedBy: "/")
                if let last = components.last, let range = last.range(of: ".") {
                    let filename = String(last[..<range.lowerBound])
                    
                    // 4chan always uses JPG for thumbnails regardless of the original file type
                    let thumbnailFilename = filename + "s.jpg"
                    finalUrl = imageUrl.replacingOccurrences(of: last, with: thumbnailFilename)
                    
                    if fileExtension == ".png" {
                        print("Debug: Using JPG thumbnail for PNG image: \(finalUrl)")
                    } else {
                        print("Debug: Generated thumbnail URL: \(finalUrl) for image type: \(fileExtension)")
                    }
                } else {
                    finalUrl = imageUrl
                    print("Debug: Could not parse URL components, using original: \(finalUrl)")
                }
            }
        }
        
        guard let url = URL(string: finalUrl) else {
            print("Debug: Invalid URL: \(finalUrl)")
            cell.threadImage.setBackgroundImage(UIImage(named: "loadingBoardImage"), for: .normal)
            return
        }
        print("Debug: Generated valid URL: \(url.absoluteString)")
        
        // Store the high-quality URL for when the image is tapped
        cell.setImageURL(imageUrl)
        print("Debug: Set full image URL for tap action: \(imageUrl)")
        
        // Load image with Kingfisher using the same style as catalog view
        // Use device corner radius to match board thread thumbnails
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        let processor = RoundCornerImageProcessor(cornerRadius: deviceCornerRadius)
        
        // Enhanced options for better image loading
        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .transition(.fade(0.2)),
            .cacheOriginalImage,
            .backgroundDecode,   // Decode in background to prevent UI stutter
            .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))), // Retry failed loads
            .callbackQueue(.mainAsync) // Ensure callbacks are on main thread
        ]
        
        print("Debug: Loading image with URL: \(url)")
        
        // Configure button's imageView for proper aspect fill scaling (like board view)
        cell.threadImage.imageView?.contentMode = .scaleAspectFill
        cell.threadImage.imageView?.clipsToBounds = true
        cell.threadImage.contentHorizontalAlignment = .fill
        cell.threadImage.contentVerticalAlignment = .fill

        cell.threadImage.kf.setImage(
            with: url,
            for: .normal,
            placeholder: UIImage(named: "loadingBoardImage"),
            options: options,
            completionHandler: { result in
                switch result {
                case .success(let value):
                    print("Debug: Successfully loaded image for URL: \(url)")
                    if let cgImage = value.image.cgImage {
                        print("Debug: Image size: \(value.image.size), hasAlpha: \(cgImage.alphaInfo != CGImageAlphaInfo.none)")
                    } else {
                        print("Debug: Image size: \(value.image.size)")
                    }

                    // Ensure proper layout after image loads
                    DispatchQueue.main.async {
                        cell.setNeedsLayout()
                    }
                case .failure(let error):
                    print("Debug: Failed to load image: \(error.localizedDescription)")
                    
                    // We shouldn't need fallbacks anymore since we're always using JPG thumbnails,
                    // but let's keep this just in case for robustness
                    if finalUrl.hasSuffix(".png") {
                        let jpgUrl = finalUrl.replacingOccurrences(of: ".png", with: ".jpg")
                        print("Debug: Thumbnail loading failed. Trying explicit JPG fallback: \(jpgUrl)")
                        
                        if let fallbackUrl = URL(string: jpgUrl) {
                            // Use main thread for UI updates to avoid actor isolation errors
                            DispatchQueue.main.async {
                                cell.threadImage.kf.setImage(
                                    with: fallbackUrl,
                                    for: .normal,
                                    placeholder: UIImage(named: "loadingBoardImage"),
                                    options: options)
                            }
                        }
                    }
                }
            }
        )
    }
    
    @objc func threadContentOpen(sender: UIButton) {
        let selectedImageURLString = threadRepliesImages[sender.tag]
        print("threadContentOpen: \(selectedImageURLString)")
        
        // Validate URL
        guard let selectedImageURL = URL(string: selectedImageURLString) else {
            print("Invalid URL: \(selectedImageURLString)")
            return
        }
        
        // Check the file extension to determine how to handle the content
        var fileExtension = selectedImageURL.pathExtension.lowercased()
        
        // Debug log for PNG image detection
        if fileExtension == "png" {
            print("Debug: PNG image detected for full-size viewing: \(selectedImageURLString)")
        }
        
        // Special handling for thumbnail URLs that may not have the correct extension
        if selectedImageURLString.contains("s.jpg") && selectedImageURLString.contains(".png") {
            print("Debug: Detected PNG image with JPG thumbnail, correcting extension")
            fileExtension = "png"
        }
        
        if fileExtension == "webm" || fileExtension == "mp4" {
            // Use WebMViewController for video playback (same as Downloaded view)
            print("Debug: Opening video with WebMViewController")

            // Get all video URLs from the thread for navigation
            let videoURLs = threadRepliesImages.compactMap { urlString -> URL? in
                guard let url = URL(string: urlString) else { return nil }
                let ext = url.pathExtension.lowercased()
                return (ext == "webm" || ext == "mp4") ? url : nil
            }

            // Find the index of the selected video
            let selectedIndex = videoURLs.firstIndex(of: selectedImageURL) ?? 0

            let vlcVC = WebMViewController()
            vlcVC.videoURL = selectedImageURL.absoluteString
            vlcVC.videoURLs = videoURLs
            vlcVC.currentIndex = selectedIndex

            // Handle navigation stack
            if let navController = navigationController {
                navController.pushViewController(vlcVC, animated: true)
            } else {
                let navController = UINavigationController(rootViewController: vlcVC)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }
        } else if fileExtension == "gif" {
            // Use urlWeb for GIFs (WKWebView handles animation properly)
            print("Debug: Opening GIF with urlWeb for animation support")
            let urlWebVC = urlWeb()
            urlWebVC.images = [selectedImageURL]
            urlWebVC.currentIndex = 0
            urlWebVC.enableSwipes = false

            if let navController = navigationController {
                navController.pushViewController(urlWebVC, animated: true)
            } else {
                let navController = UINavigationController(rootViewController: urlWebVC)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }
        } else {
            // Use ImageViewController for JPG/PNG images (same as Downloaded view)
            // This provides proper zoom/pan functionality
            print("Debug: Opening image with ImageViewController for extension: \(fileExtension)")

            // For PNG images, ensure we're using the correct URL with .png extension
            var imageURL = selectedImageURL
            if fileExtension == "png" || selectedImageURLString.contains(".png") {
                let correctedURLString = selectedImageURLString.replacingOccurrences(of: "s.jpg", with: ".png")
                if let correctedURL = URL(string: correctedURLString) {
                    imageURL = correctedURL
                    print("Debug: Using corrected PNG URL: \(correctedURLString)")
                }
            }

            // Get all image URLs from the thread for navigation (excluding videos and GIFs)
            let imageURLs = threadRepliesImages.compactMap { urlString -> URL? in
                guard let url = URL(string: urlString) else { return nil }
                let ext = url.pathExtension.lowercased()
                // Include jpg, jpeg, png - exclude webm, mp4, gif
                return (ext == "jpg" || ext == "jpeg" || ext == "png") ? url : nil
            }

            // Find the index of the selected image
            let selectedIndex = imageURLs.firstIndex(of: imageURL) ?? 0

            let imageVC = ImageViewController(imageURL: imageURL)
            imageVC.imageURLs = imageURLs
            imageVC.currentIndex = selectedIndex
            imageVC.enableSwipes = imageURLs.count > 1
            // Provide referer for 4chan
            if !boardAbv.isEmpty && !threadNumber.isEmpty {
                imageVC.refererString = "https://boards.4chan.org/\(boardAbv)/thread/\(threadNumber)"
            }

            // Handle navigation stack
            if let navController = navigationController {
                navController.pushViewController(imageVC, animated: true)
            } else {
                let navController = UINavigationController(rootViewController: imageVC)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }
        }
    }
    
    // MARK: - Thread Structure Methods
    /// Methods to structure and display thread replies
    private func structureThreadReplies() {
        for (i, reply) in threadReplies.enumerated() {
            // Get the string content from NSAttributedString
            let replyString = reply.string
            
            if replyString.contains(">>") {
                for (a, boardReplyNumber) in threadBoardReplyNumber.enumerated() {
                    if replyString.contains(">>" + boardReplyNumber) {
                        if threadBoardReplies[boardReplyNumber] == nil {
                            threadBoardReplies[boardReplyNumber] = [threadBoardReplyNumber[i]]
                        } else if !threadBoardReplies[boardReplyNumber]!.contains(threadBoardReplyNumber[i]) {
                            threadBoardReplies[boardReplyNumber]?.append(threadBoardReplyNumber[i])
                        }
                    }
                }
            }
        }
        
        debugReloadData(context: "Search filter update")
    }
    @objc private func showThread(sender: UIButton) {
        print("🔴showThread")
        let tag = sender.tag
        
        // Create thread data for the new view
        var threadRepliesNew: [NSAttributedString] = []
        var threadBoardReplyNumberNew: [String] = []
        var threadRepliesImagesNew: [String] = []
        
        // Get the board number that was clicked
        let selectedBoardNumber = threadBoardReplyNumber[tag]
        
        // Start with the original post
        if let index = threadBoardReplyNumber.firstIndex(of: selectedBoardNumber) {
            threadRepliesNew.append(threadReplies[index])
            threadBoardReplyNumberNew.append(threadBoardReplyNumber[index])
            threadRepliesImagesNew.append(threadRepliesImages[index])
        }
        
        // Use a Set to deduplicate replies
        var uniqueReplies = Set<String>()
        
        // Add only replies to this post (not the whole thread)
        if let replies = threadBoardReplies[selectedBoardNumber] {
            for replyNumber in replies {
                // Add to the set to prevent duplicates
                if uniqueReplies.insert(replyNumber).inserted,
                   let index = threadBoardReplyNumber.firstIndex(of: replyNumber) {
                    threadRepliesNew.append(threadReplies[index])
                    threadBoardReplyNumberNew.append(threadBoardReplyNumber[index])
                    threadRepliesImagesNew.append(threadRepliesImages[index])
                }
            }
        }
        
        // Create and configure new threadRepliesTV instance
        let newThreadVC = threadRepliesTV()
        
        // Set the data and prevent full thread load
        newThreadVC.threadReplies = threadRepliesNew
        newThreadVC.threadBoardReplyNumber = threadBoardReplyNumberNew
        newThreadVC.threadRepliesImages = threadRepliesImagesNew
        newThreadVC.replyCount = threadRepliesNew.count
        newThreadVC.boardAbv = self.boardAbv
        newThreadVC.threadNumber = self.threadNumber
        newThreadVC.shouldLoadFullThread = false // Prevent reloading the full thread
        
        // Transfer any filtered indices that are also in this view
        let filteredIndicesInNew = Set(filteredReplyIndices.compactMap { originalIndex in
            if let originalNumber = threadBoardReplyNumber.indices.contains(originalIndex) ? threadBoardReplyNumber[originalIndex] : nil,
               let newIndex = threadBoardReplyNumberNew.firstIndex(of: originalNumber) {
                return newIndex
            }
            return nil
        })
        newThreadVC.filteredReplyIndices = filteredIndicesInNew
        
        print("Selected post: \(selectedBoardNumber)")
        print("Filtered replies: \(Array(uniqueReplies))")
        print("New threadReplies count: \(threadRepliesNew.count)")
        
        // Set the title to show which post is being viewed
        newThreadVC.title = "\(selectedBoardNumber)"
        
        // Adapt behavior based on device type
        if let navController = navigationController {
            navController.pushViewController(newThreadVC, animated: true)
        } else {
            // Fallback to modal presentation for iPhones
            let navController = UINavigationController(rootViewController: newThreadVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
        
    }
    
    @objc private func completeThread() {
        // Restore navigation items
        setupNavigationItems()
        
        // Restore full thread
        threadReplies = threadRepliesOld
        threadBoardReplyNumber = threadBoardReplyNumberOld
        threadRepliesImages = threadRepliesImagesOld
        
        // Clear saved state
        threadRepliesOld.removeAll()
        threadBoardReplyNumberOld.removeAll()
        threadRepliesImagesOld.removeAll()
        
        replyCount = threadReplies.count
        debugReloadData(context: "Search filter update")
    }
    
    // MARK: - Helper Methods
    /// General helper methods used throughout the class
    
    /// Handle long press on a table cell
    @objc private func handleLongPress(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let point = gesture.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: point) {
                showCellActionSheet(for: indexPath)
            }
        }
    }
    
    /// Shows action sheet for a long-pressed cell
    private func showCellActionSheet(for indexPath: IndexPath) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Watch for replies option
        let postNo = threadBoardReplyNumber[indexPath.row]
        let isWatching = WatchedPostsManager.shared.isWatching(postNo: postNo, threadNo: threadNumber, boardAbv: boardAbv)
        let watchTitle = isWatching ? "Stop Watching for Replies" : "Watch for Replies"
        actionSheet.addAction(UIAlertAction(title: watchTitle, style: .default, handler: { _ in
            self.toggleWatchForReplies(at: indexPath.row)
        }))

        // Filter this reply option
        actionSheet.addAction(UIAlertAction(title: "Filter This Reply", style: .default, handler: { _ in
            self.toggleFilterForReply(at: indexPath.row)
        }))

        // Filter similar replies option
        actionSheet.addAction(UIAlertAction(title: "Filter Similar Content", style: .default, handler: { _ in
            self.filterSimilarContent(to: indexPath.row)
        }))

        // Add extract keywords option
        actionSheet.addAction(UIAlertAction(title: "Extract Keywords to Filter", style: .default, handler: { _ in
            self.extractKeywords(from: indexPath.row)
        }))

        // Add cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Configure popover for iPad
        if let popover = actionSheet.popoverPresentationController {
            if let cell = tableView.cellForRow(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }
            popover.permittedArrowDirections = [.up, .down]
        }
        
        present(actionSheet, animated: true)
    }

    /// Toggles watching for replies on a specific post
    private func toggleWatchForReplies(at index: Int) {
        guard index < threadBoardReplyNumber.count else { return }

        let postNo = threadBoardReplyNumber[index]
        let isCurrentlyWatching = WatchedPostsManager.shared.isWatching(
            postNo: postNo,
            threadNo: threadNumber,
            boardAbv: boardAbv
        )

        if isCurrentlyWatching {
            // Stop watching
            WatchedPostsManager.shared.unwatchPost(postNo: postNo, threadNo: threadNumber, boardAbv: boardAbv)
            showToast(message: "Stopped watching post #\(postNo)")
        } else {
            // Start watching - collect existing replies to this post
            var existingReplies: [String] = []
            for (i, reply) in threadReplies.enumerated() {
                guard i < threadBoardReplyNumber.count else { continue }
                if reply.string.contains(">>\(postNo)") && threadBoardReplyNumber[i] != postNo {
                    existingReplies.append(threadBoardReplyNumber[i])
                }
            }

            let postText = index < threadReplies.count ? threadReplies[index].string : ""
            WatchedPostsManager.shared.watchPost(
                boardAbv: boardAbv,
                threadNo: threadNumber,
                postNo: postNo,
                postText: postText,
                existingReplies: existingReplies
            )
            showToast(message: "Watching post #\(postNo) for new replies")
        }
    }

    /// Shows a brief toast message
    private func showToast(message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(toast, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            toast.dismiss(animated: true)
        }
    }

    /// Shows filter options in an action sheet
    @objc private func showFilterOptions() {
        let filterAlert = UIAlertController(title: "Filter Options", message: "Select filter action", preferredStyle: .alert)
        
        // Option to open Content Filter settings
        filterAlert.addAction(UIAlertAction(title: "Manage Global Filters", style: .default, handler: { _ in
            self.showFilterManagementView()
        }))
        
        // Option to filter the current thread by keyword
        filterAlert.addAction(UIAlertAction(title: "Filter Current Thread by Keyword", style: .default, handler: { _ in
            self.showFilterByKeywordAlert()
        }))
        
        // Option to add a global filter
        filterAlert.addAction(UIAlertAction(title: "Add New Filter", style: .default, handler: { _ in
            self.showAddGlobalFilterAlert()
        }))
        
        // Option to clear view filters
        filterAlert.addAction(UIAlertAction(title: "Clear Thread Filters", style: .default, handler: { _ in
            self.clearAllFilters()
        }))
        
        // Add toggle for filtering globally
        let isEnabled = ContentFilterManager.shared.isFilteringEnabled()

        let toggleTitle = isEnabled ? "Disable All Filtering" : "Enable All Filtering"

        filterAlert.addAction(UIAlertAction(title: toggleTitle, style: .default, handler: { _ in
            ContentFilterManager.shared.setFilteringEnabled(!isEnabled)
            self.applyContentFiltering() // Apply/unapply filters based on new setting

            // Show confirmation
            let message = isEnabled ? "Content filtering disabled" : "Content filtering enabled"
            let confirmToast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            self.present(confirmToast, animated: true)

            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                confirmToast.dismiss(animated: true)
            }
        }))
        
        filterAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(filterAlert, animated: true)
    }
    
    /// Shows an alert to add a global filter
    private func showAddGlobalFilterAlert() {
        let alert = UIAlertController(title: "Add Global Filter", message: "Enter text to filter across all content", preferredStyle: .alert)
        
        // Add a segmented control to select filter type
        let filterTypes = ["Keyword", "Poster ID", "Image Name"]
        let segmentedControl = UISegmentedControl(items: filterTypes)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the segmented control to the alert
        alert.view.addSubview(segmentedControl)
        
        // Position segmented control below the message
        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            segmentedControl.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 65),
            segmentedControl.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Add space for the segmented control
        let extraSpace = UIView()
        extraSpace.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(extraSpace)
        NSLayoutConstraint.activate([
            extraSpace.heightAnchor.constraint(equalToConstant: 40),
            extraSpace.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor),
            extraSpace.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor),
            extraSpace.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor)
        ])
        
        // Add a text field for the filter text
        alert.addTextField { textField in
            textField.placeholder = "Enter filter text"
            textField.clearButtonMode = .whileEditing
            textField.autocapitalizationType = .none
        }
        
        // Add action to add the filter
        alert.addAction(UIAlertAction(title: "Add Filter", style: .default) { _ in
            guard let filterText = alert.textFields?.first?.text, !filterText.isEmpty else { return }

            // Add filter based on selected type
            let filterType = filterTypes[segmentedControl.selectedSegmentIndex]

            // Add to the appropriate filter collection using ContentFilterManager
            var added = false

            switch filterType {
            case "Keyword":
                added = ContentFilterManager.shared.addKeywordFilter(filterText)
            case "Poster ID":
                added = ContentFilterManager.shared.addPosterFilter(filterText)
            case "Image Name":
                added = ContentFilterManager.shared.addImageFilter(filterText)
            default:
                break
            }

            if added {
                // Apply filtering to current view
                self.applyContentFiltering()

                // Show confirmation
                let confirmToast = UIAlertController(
                    title: nil,
                    message: "\(filterType) filter added: \"\(filterText)\"",
                    preferredStyle: .alert
                )
                self.present(confirmToast, animated: true)
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    confirmToast.dismiss(animated: true)
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /// Shows the filter management view
    private func showFilterManagementView() {
        // Create and navigate to the dedicated ContentFilterViewController
        if let contentFilterViewControllerClass = NSClassFromString("Channer.ContentFilterViewController") as? UIViewController.Type {
            let contentFilterVC = contentFilterViewControllerClass.init()
            navigationController?.pushViewController(contentFilterVC, animated: true)
        }
    }
    
    /// Shows an alert to filter content by keyword
    private func showFilterByKeywordAlert() {
        let alert = UIAlertController(title: "Filter by Keyword", message: "Enter a keyword to filter replies", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Keyword to filter"
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Filter", style: .default, handler: { _ in
            guard let keyword = alert.textFields?.first?.text, !keyword.isEmpty else { return }
            self.filterByKeyword(keyword)
        }))
        
        present(alert, animated: true)
    }
    
    /// Filters replies based on a keyword
    private func filterByKeyword(_ keyword: String) {
        let keywordLowercased = keyword.lowercased()
        for (index, reply) in threadReplies.enumerated() {
            if reply.string.lowercased().contains(keywordLowercased) {
                filteredReplyIndices.insert(index)
            }
        }
        
        debugReloadData(context: "Search filter update")
    }
    
    /// Toggles filter status for a specific reply
    private func toggleFilterForReply(at index: Int) {
        if filteredReplyIndices.contains(index) {
            filteredReplyIndices.remove(index)
        } else {
            filteredReplyIndices.insert(index)
        }
        debugReloadData(context: "Search filter update")
    }
    
    // MARK: - Refresh Status Management
    
    private func showRefreshStatus(interval: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshStatusView.isHidden = false
            self?.updateRefreshStatus()
            
            // Update table view insets to account for status bar
            if let self = self {
                var contentInset = self.tableView.contentInset
                contentInset.top = 44
                self.tableView.contentInset = contentInset
                self.tableView.scrollIndicatorInsets = contentInset
            }
        }
    }
    
    private func hideRefreshStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshStatusView.isHidden = true
            
            // Reset table view insets
            if let self = self {
                var contentInset = self.tableView.contentInset
                contentInset.top = 0
                self.tableView.contentInset = contentInset
                self.tableView.scrollIndicatorInsets = contentInset
            }
        }
    }
    
    private func updateRefreshStatus() {
        guard !refreshStatusView.isHidden else { return }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        var statusText = ""
        if let lastRefresh = lastRefreshTime {
            statusText = "Last refresh: \(formatter.string(from: lastRefresh))"
        }
        
        if let nextRefresh = nextRefreshTime {
            if !statusText.isEmpty { statusText += " | " }
            statusText += "Next: \(formatter.string(from: nextRefresh))"
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.refreshStatusLabel.text = statusText
        }
    }
    
    private func updateRefreshProgress() {
        guard !refreshStatusView.isHidden,
              let nextRefresh = nextRefreshTime else { return }
        
        let interval = UserDefaults.standard.integer(forKey: threadsAutoRefreshIntervalKey)
        guard interval > 0 else { return }
        
        let now = Date()
        let timeUntilRefresh = nextRefresh.timeIntervalSince(now)
        let progress = max(0, min(1, 1 - (timeUntilRefresh / TimeInterval(interval))))
        
        DispatchQueue.main.async { [weak self] in
            self?.refreshProgressView.setProgress(Float(progress), animated: true)
        }
    }
    
    // MARK: - Auto-refresh
    // Methods for handling automatic refresh of thread content
    
    private func setupAutoRefreshTimer() {
        // Stop any existing timer
        stopAutoRefreshTimer()
        
        // Get the refresh interval from settings
        let interval = UserDefaults.standard.integer(forKey: threadsAutoRefreshIntervalKey)
        
        // Only create timer if interval is greater than 0
        guard interval > 0 else { 
            hideRefreshStatus()
            return 
        }
        
        // Show refresh status
        showRefreshStatus(interval: interval)
        
        // Set next refresh time
        nextRefreshTime = Date().addingTimeInterval(TimeInterval(interval))
        updateRefreshStatus()
        
        // Create and schedule the timer
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            self?.refreshThreadContent()
        }
        
        // Also create a timer to update the progress view
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRefreshProgress()
        }
    }
    
    private func stopAutoRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        hideRefreshStatus()
    }
    
    @objc private func refreshThreadContent() {
        // Only refresh if not currently loading and not searching
        guard !isLoading && !isSearchActive else { return }
        
        // Check if user is actively interacting with the table
        guard !tableView.isDragging && !tableView.isDecelerating else { return }
        
        // Update refresh status
        lastRefreshTime = Date()
        nextRefreshTime = Date().addingTimeInterval(TimeInterval(UserDefaults.standard.integer(forKey: threadsAutoRefreshIntervalKey)))
        updateRefreshStatus()
        
        // Save current scroll position before reloading
        let savedOffset = tableView.contentOffset
        
        // Re-fetch thread data
        loadDataWithScrollPreservation(scrollOffset: savedOffset)
    }
    
    private func loadDataWithScrollPreservation(scrollOffset: CGPoint) {
        guard !threadNumber.isEmpty else {
            isLoading = false
            return
        }
        
        let urlString = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        
        let request = AF.request(urlString)
        request.responseData { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        self.processThreadData(json)
                        self.structureThreadReplies()
                        self.isLoading = false
                        self.tableView.reloadData()
                        
                        // Restore scroll position after reload
                        self.tableView.setContentOffset(scrollOffset, animated: false)
                    } catch {
                        print("JSON parsing error: \(error)")
                        self.handleLoadError()
                    }
                case .failure(let error):
                    print("Network error: \(error)")
                    self.handleLoadError()
                }
            }
        }
    }
    
    /// Filters replies similar to the selected one
    private func filterSimilarContent(to index: Int) {
        guard index < threadReplies.count else { return }
        
        let selectedText = threadReplies[index].string.lowercased()
        
        // Split content into words and find significant ones (longer than 3 chars)
        let words = selectedText.components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word -> String? in
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                return cleaned.count > 3 ? cleaned.lowercased() : nil
            }
        
        // Find most frequent words (basic implementation)
        var wordCounts: [String: Int] = [:]
        words.forEach { wordCounts[$0, default: 0] += 1 }
        
        // Get top 3 words for matching
        let significantWords = wordCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        // Filter replies containing those words
        for (replyIndex, reply) in threadReplies.enumerated() {
            let replyText = reply.string.lowercased()
            for word in significantWords where replyText.contains(word) {
                filteredReplyIndices.insert(replyIndex)
                break
            }
        }
        
        debugReloadData(context: "Search filter update")
    }
    
    /// Extracts keywords from a reply and presents them for filtering
    private func extractKeywords(from index: Int) {
        guard index < threadReplies.count else { return }
        
        let text = threadReplies[index].string.lowercased()
        
        // Extract potential keywords (words longer than 3 characters)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word -> String? in
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                return cleaned.count > 3 ? cleaned.lowercased() : nil
            }
        
        // Count word frequencies
        var wordCounts: [String: Int] = [:]
        words.forEach { wordCounts[$0, default: 0] += 1 }
        
        // Get top words by frequency (max 5)
        let topWords = wordCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        if topWords.isEmpty {
            let alert = UIAlertController(title: "No Keywords Found", message: "No significant keywords could be extracted from this reply.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Show alert with checkboxes for each word
        let alert = UIAlertController(title: "Select Keywords to Filter", message: "Choose which keywords to use for filtering:", preferredStyle: .alert)
        
        // We'll use a simple text field to display the keywords since UIAlertController doesn't support checkboxes
        alert.addTextField { textField in 
            textField.text = topWords.joined(separator: ", ")
            textField.isEnabled = false
        }
        
        // Add action to filter by all words
        alert.addAction(UIAlertAction(title: "Filter All", style: .default, handler: { _ in
            // Apply all keywords to filtering
            for word in topWords {
                self.filterByKeyword(word)
            }
        }))
        
        // Add actions for individual keywords
        for word in topWords {
            alert.addAction(UIAlertAction(title: "Filter: \(word)", style: .default, handler: { _ in
                self.filterByKeyword(word)
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /// Applies content filtering to the loaded posts
    /// Uses both legacy filters and advanced filters (regex, file type, country, trip code, time-based)
    private func applyContentFiltering() {
        // Clear existing filters before reapplying
        filteredReplyIndices.removeAll()

        let filterManager = ContentFilterManager.shared

        // Check if any filtering is enabled
        let legacyEnabled = filterManager.isFilteringEnabled()
        let advancedEnabled = filterManager.isAdvancedFilteringEnabled()

        if !legacyEnabled && !advancedEnabled {
            debugReloadData(context: "Search filter update")
            return
        }

        // Get legacy filters
        let legacyFilters = filterManager.getAllFilters()
        let hasLegacyFilters = !legacyFilters.keywords.isEmpty || !legacyFilters.posters.isEmpty || !legacyFilters.images.isEmpty

        // Get advanced filters
        let advancedFilters = filterManager.getEnabledAdvancedFilters()
        let hasAdvancedFilters = !advancedFilters.isEmpty

        // If no filters, skip filtering
        if !hasLegacyFilters && !hasAdvancedFilters {
            debugReloadData(context: "Search filter update")
            return
        }

        // Apply filters to each reply using PostMetadata
        for (index, _) in threadReplies.enumerated() {
            // Use PostMetadata if available, otherwise create basic metadata
            let metadata: PostMetadata
            if index < postMetadataList.count {
                metadata = postMetadataList[index]
            } else {
                // Fallback for older data without metadata
                let comment = threadReplies[index].string
                let imageUrl = index < threadRepliesImages.count ? threadRepliesImages[index] : nil
                let posterId = index < threadBoardReplyNumber.count ? threadBoardReplyNumber[index] : nil

                // Extract extension from URL
                var imageExt: String? = nil
                if let url = imageUrl {
                    if url.hasSuffix(".webm") { imageExt = ".webm" }
                    else if url.hasSuffix(".mp4") { imageExt = ".mp4" }
                    else if url.hasSuffix(".gif") { imageExt = ".gif" }
                    else if url.hasSuffix(".png") { imageExt = ".png" }
                    else if url.hasSuffix(".jpg") || url.hasSuffix(".jpeg") { imageExt = ".jpg" }
                }

                metadata = PostMetadata(
                    postNumber: posterId ?? "",
                    comment: comment,
                    posterId: nil,
                    tripCode: nil,
                    countryCode: nil,
                    countryName: nil,
                    timestamp: nil,
                    imageUrl: imageUrl,
                    imageExtension: imageExt,
                    imageName: nil
                )
            }

            // Check if post should be filtered using the centralized filter manager
            if filterManager.shouldFilter(post: metadata) {
                filteredReplyIndices.insert(index)
            }
        }

        // Reload table with filtered content
        debugReloadData(context: "Search filter update")
    }
    
    /// Clears all applied filters in the current view
    private func clearAllFilters() {
        // Clear local view filters
        filteredReplyIndices.removeAll()
        debugReloadData(context: "Search filter update")
    }
    @objc func refresh() {
        print("Refresh triggered")
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        threadBoardReplies.removeAll()
        filteredReplyIndices.removeAll() // Clear filters on refresh
        postMetadataList.removeAll() // Clear metadata on refresh
        replyCount = 0
        loadInitialData()
    }
    
    @objc func saveForOfflineReading() {
        guard !boardAbv.isEmpty && !threadNumber.isEmpty else { return }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: "Saving Thread",
            message: "Saving thread for offline reading...",
            preferredStyle: .alert
        )
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // Get category if thread is favorited
        var categoryId: String? = nil
        if FavoritesManager.shared.isFavorited(threadNumber: threadNumber) {
            let favorites = FavoritesManager.shared.loadFavorites()
            if let favorite = favorites.first(where: { $0.number == threadNumber }) {
                categoryId = favorite.categoryId
            }
        }
        
        // Cache thread with category
        ThreadCacheManager.shared.cacheThread(boardAbv: boardAbv, threadNumber: threadNumber, categoryId: categoryId) { success in
            DispatchQueue.main.async {
                // Dismiss loading alert
                self.dismiss(animated: true) {
                    // Show result alert
                    let resultAlert = UIAlertController(
                        title: success ? "Thread Saved" : "Error",
                        message: success ? "Thread has been saved for offline reading." : "Failed to save thread for offline reading.",
                        preferredStyle: .alert
                    )
                    resultAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(resultAlert, animated: true)
                }
            }
        }
    }
    
    @objc func removeFromOfflineCache() {
        guard !boardAbv.isEmpty && !threadNumber.isEmpty else { return }
        
        // Show confirmation alert
        let confirmAlert = UIAlertController(
            title: "Remove from Offline Cache",
            message: "Are you sure you want to remove this thread from your offline cache?",
            preferredStyle: .alert
        )
        
        confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
            // Remove from cache
            ThreadCacheManager.shared.removeFromCache(boardAbv: self.boardAbv, threadNumber: self.threadNumber)
            
            // Show confirmation
            let resultAlert = UIAlertController(
                title: "Thread Removed",
                message: "Thread has been removed from your offline cache.",
                preferredStyle: .alert
            )
            resultAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(resultAlert, animated: true)
        })
        
        present(confirmAlert, animated: true)
    }
    
    @objc private func down() {
        let lastRow = tableView.numberOfRows(inSection: 0) - 1
        let indexPath = IndexPath(row: lastRow, section: 0)
        tableView.scrollToRow(at: indexPath, at: .top, animated: false)
    }
    
    @objc private func openInBrowser() {
        guard !boardAbv.isEmpty && !threadNumber.isEmpty else { return }
        
        let urlString = "https://boards.4chan.org/\(boardAbv)/thread/\(threadNumber)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private func updateLoadingUI() {
        if isLoading {
            loadingIndicator.startAnimating()
            tableView.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            tableView.isHidden = false
        }
    }
    
    private func updateLoadingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isLoading {
                self.loadingIndicator.startAnimating()
                self.tableView.alpha = 0
            } else {
                self.loadingIndicator.stopAnimating()
                UIView.animate(withDuration: 0.3) {
                    self.tableView.alpha = 1
                }
            }
        }
    }
    
    private func processText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.hasPrefix(">>") {
                // Quoted reply reference (should be blue and clickable)
                let postNumber = String(trimmed.dropFirst(2))
                let displayText = line + "\n" // Add the newline explicitly for each line
                if let url = URL(string: "post://\(postNumber)") {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor.blue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: url
                    ]
                    result.append(NSAttributedString(string: displayText, attributes: attributes))
                } else {
                    // Fallback if URL creation fails
                    let normalAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: ThemeManager.shared.primaryTextColor
                    ]
                    result.append(NSAttributedString(string: displayText, attributes: normalAttributes))
                }
            } else if trimmed.hasPrefix(">") && !trimmed.hasPrefix(">>") {
                // Greentext (should have a green color)
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: ThemeManager.shared.greentextColor
                ]
                let displayText = line + "\n" // Add newline explicitly
                result.append(NSAttributedString(string: displayText, attributes: attributes))
            } else {
                // Normal text
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: ThemeManager.shared.primaryTextColor
                ]
                let displayText = line + "\n" // Add newline explicitly
                result.append(NSAttributedString(string: displayText, attributes: attributes))
            }
        }
        
        return result
    }
    
    // MARK: - UISearchBarDelegate Methods
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        searchBar.showsCancelButton = !searchText.isEmpty
        performSearch()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.isEmpty ?? true {
            searchBar.showsCancelButton = false
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        isSearchActive = false
        searchFilteredIndices.removeAll()
        debugReloadData(context: "Search filter update")
    }
    
    // MARK: - Search Methods
    private func performSearch() {
        searchFilteredIndices.removeAll()
        
        // If search text is empty, show all replies
        guard !searchText.isEmpty else {
            isSearchActive = false
            debugReloadData(context: "Search filter update")
            return
        }
        
        isSearchActive = true
        let searchTextLowercased = searchText.lowercased()
        
        // Search through all replies
        for (index, reply) in threadReplies.enumerated() {
            let replyText = reply.string.lowercased()
            if !replyText.contains(searchTextLowercased) {
                searchFilteredIndices.insert(index)
            }
        }
        
        debugReloadData(context: "Search filter update")
    }
    
}

// MARK: - UIButton Extension
/// Helper extension for button configuration
private extension UIButton {
    @discardableResult
    func apply(_ closure: (UIButton) -> Void) -> UIButton {
        closure(self)
        return self
    }
}

// MARK: - Keyboard Shortcuts Extension
// Keyboard shortcut methods have been moved earlier in the class

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Debug Helper Methods
extension threadRepliesTV {
    
    private func debugReloadData(context: String = "Unknown") {
        // Throttle reloads during scrolling or rapid updates
        if isScrolling {
            pendingReloadContext = context
            return
        }
        
        // Cancel any pending reload
        reloadTimer?.invalidate()
        pendingReloadContext = context
        
        // Batch multiple reload requests together with a small delay
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("🔄 RELOAD: \(self.pendingReloadContext ?? "Unknown")")
            
            // Clear height cache when reloading data
            self.cellHeightCache.removeAll()
            
            self.tableView.reloadData()
            self.pendingReloadContext = nil
        }
    }
}

// MARK: - Scroll Performance Optimization
extension threadRepliesTV {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
        lastScrollVelocity = 0
        print("📱 SCROLL: Started dragging")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Track scroll velocity for adaptive loading
        let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        lastScrollVelocity = velocity
        print("📱 SCROLL: Velocity = \(velocity), isScrolling = \(isScrolling)")
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollingDidEnd()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollingDidEnd()
        print("📱 SCROLL: Finished at offset \(Int(scrollView.contentOffset.y))")
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollingDidEnd()
    }
    
    private func scrollingDidEnd() {
        print("📱 SCROLL: Ending scroll, resetting state")
        isScrolling = false
        currentScrollLoads = 0 // Reset scroll load counter
        
        // Process any pending reload that was deferred during scrolling
        // Process any pending reload that was deferred during scrolling
        if let context = pendingReloadContext {
            debugReloadData(context: context)
        }
        
        // Load images for visible cells that were deferred during scrolling
        DispatchQueue.main.async { [weak self] in
            self?.loadPendingImages()
        }
    }
    
    private func loadPendingImages() {
        // Batch image loading to avoid overwhelming the system
        imageLoadTimer?.invalidate()
        imageLoadTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            let visibleIndexPaths = self.tableView.indexPathsForVisibleRows ?? []
            let pendingToLoad = visibleIndexPaths.filter { self.pendingImageLoads.contains($0) }
            
            if pendingToLoad.isEmpty {
                timer.invalidate()
                self.imageLoadTimer = nil
                return
            }
            
            // Load one image at a time to avoid blocking
            if let indexPath = pendingToLoad.first,
               let cell = self.tableView.cellForRow(at: indexPath) as? threadRepliesCell {
                self.pendingImageLoads.remove(indexPath)
                self.configureCellImage(cell: cell, at: indexPath)
            }
        }
    }
    
    private func configureCellImage(cell: threadRepliesCell, at indexPath: IndexPath) {
        guard indexPath.row < threadRepliesImages.count else { return }
        
        let imageURL = threadRepliesImages[indexPath.row]
        if !imageURL.isEmpty && imageURL != "https://i.4cdn.org/\(boardAbv)/" {
            configureImage(for: cell, with: imageURL)
        }
    }
    
    // MARK: - Throttled Scroll Loading
    private func loadImageDuringScroll(for cell: threadRepliesCell, with imageUrl: String) {
        currentScrollLoads += 1
        print("🚀 LOAD: Starting scroll load #\(currentScrollLoads) for: \(imageUrl)")
        
        // Check if high-quality thumbnails are enabled
        let useHighQualityThumbnails = UserDefaults.standard.bool(forKey: "channer_high_quality_thumbnails_enabled")
        
        // Generate thumbnail URL using same method as normal loading
        let thumbnailUrl = thumbnailURL(from: imageUrl, useHQ: useHighQualityThumbnails)
        print("🚀 LOAD: Thumbnail URL: \(thumbnailUrl)")
        
        guard let url = thumbnailUrl else {
            print("❌ LOAD: Invalid thumbnail URL")
            currentScrollLoads = max(0, currentScrollLoads - 1)
            return
        }
        
        // Store the high-quality URL for when the image is tapped (same as normal loading)
        cell.setImageURL(imageUrl)
        
        // Use same processor and options as normal loading but optimized for scroll
        // Use device corner radius for consistent look
        let deviceCornerRadius: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            deviceCornerRadius = window.layer.cornerRadius > 0 ? window.layer.cornerRadius : 39.0
        } else {
            deviceCornerRadius = 39.0 // Default for modern iOS devices
        }
        let processor = RoundCornerImageProcessor(cornerRadius: deviceCornerRadius)
        
        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage,
            .backgroundDecode,
            .callbackQueue(.mainAsync)
        ]

        // Configure button's imageView for proper aspect fill scaling (same as normal loading)
        cell.threadImage.imageView?.contentMode = .scaleAspectFill
        cell.threadImage.imageView?.clipsToBounds = true
        cell.threadImage.contentHorizontalAlignment = .fill
        cell.threadImage.contentVerticalAlignment = .fill

        // Use setImage like normal loading (not setBackgroundImage)
        cell.threadImage.kf.setImage(
            with: url,
            for: .normal,
            placeholder: UIImage(named: "loadingBoardImage"),
            options: options,
            completionHandler: { [weak self] result in
                let newCount = max(0, (self?.currentScrollLoads ?? 1) - 1)
                self?.currentScrollLoads = newCount

                switch result {
                case .success:
                    print("✅ LOAD: Completed scroll load, remaining: \(newCount)")
                    DispatchQueue.main.async {
                        cell.setNeedsLayout()
                    }
                case .failure(let error):
                    print("❌ LOAD: Failed scroll load: \(error), remaining: \(newCount)")
                }
            }
        )
    }
}
