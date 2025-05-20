import UIKit
import Alamofire
import Kingfisher
import SwiftyJSON
import SystemConfiguration
import Foundation

// No need to import KeyboardShortcutManager as it's in the same project

// MARK: - Reachability (Network Connectivity)
class Reachability {
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


// MARK: - Thread Replies Table View Controller
class threadRepliesTV: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UISearchBarDelegate {
    
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
        
        // Search bar setup
        setupSearchBar()
        
        // Table view setup
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.allowsSelection = true
        tableView.register(threadRepliesCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
        
        // Add long press gesture recognizer for filtering
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        tableView.addGestureRecognizer(longPressGesture)
        
        setupLoadingIndicator()
        setupRefreshStatusIndicator()
        setupNavigationItems()
        checkIfFavorited()
        loadInitialData()
        setupAutoRefreshTimer()

        
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
        
        // Ensure navigation bar is properly configured
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.backgroundColor = ThemeManager.shared.backgroundColor
        
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
        
        // Ensure proper view hierarchy
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.isTranslucent = true
            navigationBar.barTintColor = .systemBackground
        }
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
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first(where: { $0.action == #selector(showActionSheet) })
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Present the action sheet
        present(actionSheet, animated: true, completion: nil)
    }
    
    @objc private func showGallery() {
        print("Gallery button tapped.")
        
        // Map valid image URLs
        let imageUrls = threadRepliesImages.compactMap { imageUrlString -> URL? in
            guard let url = URL(string: imageUrlString) else { return nil }
            if url.absoluteString == "https://i.4cdn.org/\(boardAbv)/" { return nil }
            if imageUrlString.hasSuffix(".webm") || imageUrlString.hasSuffix(".mp4") {
                let components = imageUrlString.components(separatedBy: "/")
                if let last = components.last {
                    let fileExtension = imageUrlString.hasSuffix(".webm") ? ".webm" : ".mp4"
                    let base = last.replacingOccurrences(of: fileExtension, with: "")
                    return URL(string: imageUrlString.replacingOccurrences(of: last, with: "\(base)s.jpg"))
                }
                return nil
            }
            return url
        }
        
        print("Filtered image URLs: \(imageUrls)")
        
        // Instantiate the gallery view controller
        let galleryVC = ImageGalleryVC(images: imageUrls)
        print("GalleryVC instantiated.")
        
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
        //print("Configuring cell at index: \(indexPath.row)")
        //print("threadReplies count: \(threadReplies.count)")
        
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
                //print("Debug: Configuring image with URL: \(imageUrl)")
                configureImage(for: cell, with: imageUrl)
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
        
        // Force layout to calculate cell height
        cell.layoutIfNeeded()
        //print("Debug: Cell at index \(indexPath.row) height after layout: \(cell.frame.size.height)")
        
        return cell
    }
    
    // MARK: - Data Loading Methods
    /// Methods to handle data fetching and processing
    var shouldLoadFullThread: Bool = true
    
    private func loadInitialData() {
        // If shouldLoadFullThread is false, do not reload data
        guard shouldLoadFullThread else {
            isLoading = false
            print("Loading initial data...")
            print("Reply count: \(replyCount), Thread replies: \(threadReplies.count)")
            tableView.reloadData()
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
                        self.isLoading = false
                        
                        // Reload table view and stop loading indicator
                        self.loadingIndicator.stopAnimating()
                        self.tableView.reloadData()
                        self.onViewReady?()
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
                self.isLoading = false
                
                // Cache thread if offline reading is enabled
                if ThreadCacheManager.shared.isOfflineReadingEnabled() && 
                   ThreadCacheManager.shared.isCached(boardAbv: self.boardAbv, threadNumber: self.threadNumber) {
                    print("Thread was successfully loaded and is already cached")
                }
                
                // Reload table view and stop loading indicator
                self.loadingIndicator.stopAnimating()
                self.tableView.reloadData()
                self.onViewReady?()
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
                self.isLoading = false
                self.tableView.reloadData()
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
        // Clear existing data before processing
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        threadBoardReplies.removeAll()
        originalTexts.removeAll()
        
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
    }
    
    private func processPost(_ post: JSON, index: Int) {
        // Extract the board reply number
        threadBoardReplyNumber.append(String(describing: post["no"]))
        
        // Extract the image URL
        let imageTimestamp = post["tim"].stringValue
        let imageExtension = post["ext"].stringValue
        let imageURL = "https://i.4cdn.org/\(boardAbv)/\(imageTimestamp)\(imageExtension)"
        threadRepliesImages.append(imageURL)
        
        // Extract and process the comment text
        let comment = post["com"].stringValue
        
        // Store the original unprocessed text for toggling spoilers later
        originalTexts.append(comment)
        //print("Raw comment: \(comment)")
        
        // Format the comment text with spoiler visibility
        let formattedComment = TextFormatter.formatText(comment, showSpoilers: showSpoilers)
        //print("Formatted comment: \(formattedComment)")
        threadReplies.append(formattedComment)
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
            favoriteButton.image = UIImage(named: favoriteImageName)
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
        tableView.reloadData()
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
    private func configureImage(for cell: threadRepliesCell, with imageUrl: String) {
        //print("Debug: Starting image configuration for URL: \(imageUrl)")
        
        let finalUrl: String
        if imageUrl.hasSuffix(".webm") || imageUrl.hasSuffix(".mp4") {
            let components = imageUrl.components(separatedBy: "/")
            if let last = components.last {
                let fileExtension = imageUrl.hasSuffix(".webm") ? ".webm" : ".mp4"
                let base = last.replacingOccurrences(of: fileExtension, with: "")
                finalUrl = imageUrl.replacingOccurrences(of: last, with: "\(base)s.jpg")
            } else {
                finalUrl = imageUrl
            }
        } else {
            finalUrl = imageUrl
        }
        
        guard let url = URL(string: finalUrl) else {
            print("Debug: Invalid URL: \(finalUrl)")
            cell.threadImage.setBackgroundImage(UIImage(named: "loadingBoardImage"), for: .normal)
            return
        }
        
        // Load image with Kingfisher using the same style as catalog view
        let processor = RoundCornerImageProcessor(cornerRadius: 8)
        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .transition(.fade(0.2)),
            .cacheOriginalImage
        ]
        
        cell.threadImage.kf.setBackgroundImage(
            with: url,
            for: .normal,
            placeholder: UIImage(named: "loadingBoardImage"),
            options: options,
            completionHandler: { result in
                switch result {
                case .success(_):
                    //print("Debug: Successfully loaded image for URL: \(url)")
                    // Recalculate layout after image loads
                    DispatchQueue.main.async {
                        cell.setNeedsLayout()
                        cell.layoutIfNeeded()
                        self.tableView.beginUpdates()
                        self.tableView.endUpdates()
                    }
                case .failure(let error):
                    //print("Debug: Failed to load image for URL: \(url), error: \(error)")
                    break
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
        
        if selectedImageURL.pathExtension.lowercased() == "webm" {
            // Create WebMViewController for video
            let webmVC = WebMViewController()
            webmVC.videoURL = selectedImageURL.absoluteString
            print("Navigating to WebMViewController.")
            
            // Handle navigation stack
            if let navController = navigationController {
                navController.pushViewController(webmVC, animated: true)
            } else {
                // Fallback to modal presentation for iPhones
                let navController = UINavigationController(rootViewController: webmVC)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }
        } else {
            // Create urlWeb for images
            let urlWebVC = urlWeb()
            urlWebVC.images = [selectedImageURL]
            urlWebVC.currentIndex = 0
            urlWebVC.enableSwipes = false
            print("Navigating to urlWeb for image display.")
            
            // Handle navigation stack
            if let navController = navigationController {
                navController.pushViewController(urlWebVC, animated: true)
            } else {
                // Fallback to modal presentation for iPhones
                let navController = UINavigationController(rootViewController: urlWebVC)
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
        
        tableView.reloadData()
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
        tableView.reloadData()
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
        var isEnabled = false
        if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
           let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
           let isFilteringEnabled = manager.perform(NSSelectorFromString("isFilteringEnabled"))?.takeUnretainedValue() as? Bool {
            isEnabled = isFilteringEnabled
        }
        
        let toggleTitle = isEnabled ? "Disable All Filtering" : "Enable All Filtering"
        
        filterAlert.addAction(UIAlertAction(title: toggleTitle, style: .default, handler: { _ in
            if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
               let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject {
                _ = manager.perform(NSSelectorFromString("setFilteringEnabled:"), with: !isEnabled)
            }
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
            
            // Add to the appropriate filter collection
            var added = false
            
            if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
               let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject {
                
                switch filterType {
                case "Keyword":
                    added = manager.perform(NSSelectorFromString("addKeywordFilter:"), with: filterText) != nil
                case "Poster ID":
                    added = manager.perform(NSSelectorFromString("addPosterFilter:"), with: filterText) != nil
                case "Image Name":
                    added = manager.perform(NSSelectorFromString("addImageFilter:"), with: filterText) != nil
                default:
                    break
                }
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
        
        tableView.reloadData()
    }
    
    /// Toggles filter status for a specific reply
    private func toggleFilterForReply(at index: Int) {
        if filteredReplyIndices.contains(index) {
            filteredReplyIndices.remove(index)
        } else {
            filteredReplyIndices.insert(index)
        }
        tableView.reloadData()
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
        
        tableView.reloadData()
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
    private func applyContentFiltering() {
        // Clear existing filters before reapplying
        filteredReplyIndices.removeAll()
        
        // Check if content filtering is enabled
        var isFilteringEnabled = false
        if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
           let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
           let isEnabled = manager.perform(NSSelectorFromString("isFilteringEnabled"))?.takeUnretainedValue() as? Bool {
            isFilteringEnabled = isEnabled
        }
        
        if !isFilteringEnabled {
            tableView.reloadData()
            return
        }
        
        // Get filters from ContentFilterManager
        var keywordFilters: [String] = []
        var posterFilters: [String] = []
        var imageFilters: [String] = []
        
        if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
           let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
           let getAllFilters = manager.perform(NSSelectorFromString("getAllFilters"))?.takeUnretainedValue() as? (keywords: [String], posters: [String], images: [String]) {
            keywordFilters = getAllFilters.keywords
            posterFilters = getAllFilters.posters
            imageFilters = getAllFilters.images
        }
        
        // If no filters, skip filtering
        if keywordFilters.isEmpty && posterFilters.isEmpty && imageFilters.isEmpty {
            tableView.reloadData()
            return
        }
        
        // Apply filters to each reply
        for (index, reply) in threadReplies.enumerated() {
            let plainText = reply.string.lowercased()
            let posterId = threadBoardReplyNumber[index]
            let imageUrl = threadRepliesImages[index].lowercased()
            
            // Check keyword filters
            for filter in keywordFilters {
                if plainText.contains(filter.lowercased()) {
                    filteredReplyIndices.insert(index)
                    break
                }
            }
            
            // Check poster ID filters if not already filtered
            if !filteredReplyIndices.contains(index) {
                for filter in posterFilters {
                    if posterId.contains(filter) {
                        filteredReplyIndices.insert(index)
                        break
                    }
                }
            }
            
            // Check image filename filters if not already filtered
            if !filteredReplyIndices.contains(index) && !imageUrl.isEmpty {
                for filter in imageFilters {
                    if imageUrl.contains(filter.lowercased()) {
                        filteredReplyIndices.insert(index)
                        break
                    }
                }
            }
        }
        
        // Reload table with filtered content
        tableView.reloadData()
    }
    
    /// Clears all applied filters in the current view
    private func clearAllFilters() {
        // Clear local view filters
        filteredReplyIndices.removeAll()
        tableView.reloadData()
    }
    @objc func refresh() {
        print("Refresh triggered")
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        threadBoardReplies.removeAll()
        filteredReplyIndices.removeAll() // Clear filters on refresh
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
        tableView.reloadData()
    }
    
    // MARK: - Search Methods
    private func performSearch() {
        searchFilteredIndices.removeAll()
        
        // If search text is empty, show all replies
        guard !searchText.isEmpty else {
            isSearchActive = false
            tableView.reloadData()
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
        
        tableView.reloadData()
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

