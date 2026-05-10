import UIKit
import Alamofire
import SwiftyJSON
import Kingfisher
import Foundation
import Combine

// MARK: - Thread Model
/// Represents the data structure for a thread, conforming to Codable for easy serialization.
struct ThreadData: Codable {
    let number: String
    var stats: String
    let title: String
    let comment: String
    let imageUrl: String
    let boardAbv: String
    var replies: Int // Stored replies count
    var currentReplies: Int? // Latest replies count
    let createdAt: String
    var hasNewReplies: Bool = false // Flag to indicate new replies for badge display
    var categoryId: String? // Category ID for organizing favorites
    let lastReplyTime: Int? // Unix timestamp of last reply for sorting
    var bumpIndex: Int? // Original board bump order (position from top)
    var isDead: Bool = false // Flag to indicate thread no longer exists (404)

    // Custom coding keys to include all properties
    enum CodingKeys: String, CodingKey {
        case number, stats, title, comment, imageUrl, boardAbv, replies, currentReplies, createdAt, hasNewReplies, categoryId, lastReplyTime, bumpIndex, isDead
    }

    // Initializer from JSON
    init(from json: JSON, boardAbv: String) {
        self.boardAbv = boardAbv
        if let firstPost = json["posts"].array?.first {
            self.number = firstPost["no"].stringValue
            self.stats = "\(firstPost["replies"].stringValue)/\(firstPost["images"].stringValue)"
            self.title = firstPost["sub"].stringValue
            self.comment = firstPost["com"].stringValue
            self.replies = firstPost["replies"].intValue
            self.createdAt = firstPost["now"].stringValue
            if let tim = firstPost["tim"].int64, let ext = firstPost["ext"].string {
                self.imageUrl = "https://i.4cdn.org/\(boardAbv)/\(tim)\(ext)"
            } else {
                self.imageUrl = ""
            }
            // Last reply time is the timestamp of the last post in the thread
            if let lastPost = json["posts"].array?.last {
                self.lastReplyTime = lastPost["time"].int
            } else {
                self.lastReplyTime = firstPost["time"].int
            }
            self.bumpIndex = nil // This will be set based on position in board
        } else {
            self.number = ""
            self.stats = "0/0"
            self.title = ""
            self.comment = ""
            self.imageUrl = ""
            self.replies = 0
            self.createdAt = ""
            self.lastReplyTime = nil
            self.bumpIndex = nil
        }
    }

    // Default initializer
    init(number: String, stats: String, title: String, comment: String, imageUrl: String, boardAbv: String, replies: Int, createdAt: String, categoryId: String? = nil) {
        self.number = number
        self.stats = stats
        self.title = title
        self.comment = comment
        self.imageUrl = imageUrl
        self.boardAbv = boardAbv
        self.replies = replies
        self.createdAt = createdAt
        self.categoryId = categoryId
        self.lastReplyTime = nil
        self.bumpIndex = nil
    }
    
    // Extended initializer including all properties
    init(number: String, stats: String, title: String, comment: String, imageUrl: String, boardAbv: String, replies: Int, currentReplies: Int? = nil, createdAt: String, hasNewReplies: Bool = false, categoryId: String? = nil, lastReplyTime: Int? = nil, bumpIndex: Int? = nil, isDead: Bool = false) {
        self.number = number
        self.stats = stats
        self.title = title
        self.comment = comment
        self.imageUrl = imageUrl
        self.boardAbv = boardAbv
        self.replies = replies
        self.currentReplies = currentReplies
        self.createdAt = createdAt
        self.hasNewReplies = hasNewReplies
        self.categoryId = categoryId
        self.lastReplyTime = lastReplyTime
        self.bumpIndex = bumpIndex
        self.isDead = isDead
    }
}

/// Main view controller for displaying threads from a selected board
/// Supports thread searching, favorites management, and keyboard shortcuts on iPad
class boardTV: UITableViewController, UISearchBarDelegate, BottomToolbarSearchDismissHandling {
    
    // MARK: - Keyboard Shortcuts
    override var keyCommands: [UIKeyCommand]? {
        // Only provide shortcuts on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nextThreadCommand = UIKeyCommand(input: UIKeyCommand.inputDownArrow,
                                                 modifierFlags: [],
                                                 action: #selector(nextThread))
            nextThreadCommand.discoverabilityTitle = "Next Thread"
            
            let previousThreadCommand = UIKeyCommand(input: UIKeyCommand.inputUpArrow,
                                                     modifierFlags: [],
                                                     action: #selector(previousThread))
            previousThreadCommand.discoverabilityTitle = "Previous Thread"
            
            let openSelectedThreadCommand = UIKeyCommand(input: "\r",
                                                         modifierFlags: [],
                                                         action: #selector(openSelectedThread))
            openSelectedThreadCommand.discoverabilityTitle = "Open Selected Thread"
            
            let refreshThreadsCommand = UIKeyCommand(input: "r",
                                                     modifierFlags: .command,
                                                     action: #selector(refreshThreads))
            refreshThreadsCommand.discoverabilityTitle = "Refresh Threads"
            
            return [nextThreadCommand, previousThreadCommand, openSelectedThreadCommand, refreshThreadsCommand]
        }
        
        return nil
    }
    
    // MARK: - Keyboard Shortcut Methods
    
    /// Navigate to the next thread
    @objc func nextThread() {
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
    
    /// Navigate to the previous thread
    @objc func previousThread() {
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
    
    /// Open the selected thread
    @objc func openSelectedThread() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else {
            // If nothing is selected, select the first row and open it
            let firstIndexPath = IndexPath(row: 0, section: 0)
            tableView.selectRow(at: firstIndexPath, animated: false, scrollPosition: .none)
            tableView(tableView, didSelectRowAt: firstIndexPath)
            return
        }
        
        // Open the selected thread
        tableView(tableView, didSelectRowAt: selectedIndexPath)
    }
    
    /// Refresh threads
    @objc func refreshThreads() {
        // Trigger a refresh of the threads from the board
        refreshControl?.beginRefreshing()
        loadThreads() // Assuming loadThreads is the method that fetches threads
    }
    
    /// Called when keyboard shortcuts are toggled in settings
    @objc func keyboardShortcutsToggled(_ notification: Notification) {
        // This will trigger recreation of the keyCommands array
        self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    @objc private func thumbnailSizeDidChange() {
        tableView.reloadData()
    }
    
    // MARK: - Properties
    // This section contains properties and variables used throughout the class,
    // including data arrays, UI components, and flags.

    var boardName = ""
    var boardAbv = "a"
    var threadData: [ThreadData] = []
    var filteredThreadData: [ThreadData] = []
    private var isLoading = false
    private let totalPages = 10
    private var loadedPages = 0
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    var isSearching = false  // Changed from private to allow parent view controller to set this
    var isHistoryView: Bool = false
    var isFavoritesView: Bool = false
    var boardPassed = false
    
    // Search is launched from the More menu and rendered in the bottom toolbar.
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchBar: UISearchBar {
        searchController.searchBar
    }
    private var searchText: String = ""

    // Image cache configuration
    private let imageCache = NSCache<NSString, UIImage>()
    private let prefetchQueue = OperationQueue()

    // Performance: Cache filter results per thread to avoid expensive KVC lookups in cellForRowAt
    private var filteredThreadNumbers: Set<String> = []
    private var filterCacheValid = false
    
    // Auto-refresh timer
    private var refreshTimer: Timer?
    private var progressUpdateTimer: Timer?  // Separate timer for progress updates
    private let boardsAutoRefreshIntervalKey = "channer_boards_auto_refresh_interval"
    private var lastRefreshTime: Date?
    private var nextRefreshTime: Date?
    
    // Refresh status indicator
    private let refreshStatusView = UIView()
    private let refreshStatusLabel = UILabel()
    private let refreshProgressView = UIProgressView(progressViewStyle: .default)
    private var refreshStatusHeight: NSLayoutConstraint?
    private let threadsDisplayModeKey = ThreadViewControllerFactory.threadsDisplayModeKey
    private var moreBarButtonItem: UIBarButtonItem?

    // MARK: - Lifecycle Methods
    // Methods related to the view controller's lifecycle.

    deinit {
        // Clean up timers to prevent memory leaks
        refreshTimer?.invalidate()
        progressUpdateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register for keyboard shortcuts notifications
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(keyboardShortcutsToggled(_:)),
                                             name: NSNotification.Name("KeyboardShortcutsToggled"),
                                             object: nil)

        // Register for thumbnail size changes
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(thumbnailSizeDidChange),
                                             name: .thumbnailSizeDidChange,
                                             object: nil)
        
        print("=== boardTV viewDidLoad ===")
        print("Is favorites view: \(isFavoritesView)")
        print("Is searching: \(isSearching)")
        print("Thread data count: \(threadData.count)")
        print("Filtered thread data count: \(filteredThreadData.count)")
        
        // Remove the title
        // navigationItem.title = nil
        
        setupTableView()
        setupImageCache()
        setupLoadingIndicator()
        setupRefreshStatusIndicator()
        setupSortButton()
        
        // Only setup search if not in favorites view (favorites view has its own search)
        if !isFavoritesView {
            setupSearchBar()
        }
        
        // Configure back button to only show arrow, no text
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        // let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        // tapGesture.cancelsTouchesInView = false
        // tableView.addGestureRecognizer(tapGesture)
        
        if isFavoritesView {
                self.title = "Favorites"
                
                // Add long-press gesture recognizer for deleting favorites
                let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressForFavorite))
                tableView.addGestureRecognizer(longPressGesture)
        } else if isHistoryView {
            self.title = "History"

            // Add long-press gesture recognizer for deleting history items
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            tableView.addGestureRecognizer(longPressGesture)

            // Add "Clear All" button with resized image
            let clearAllImage = UIImage(named: "clearAll")?.withRenderingMode(.alwaysTemplate)
            let resizedClearAllImage = clearAllImage?.resized(to: CGSize(width: 22, height: 22))
            let clearAllButton = UIBarButtonItem(image: resizedClearAllImage, style: .plain, target: self, action: #selector(clearAllHistory))
            clearAllButton.tintColor = .black

            // Add "Clear All" button to existing right bar buttons (which includes sort button)
            if var rightButtons = navigationItem.rightBarButtonItems {
                rightButtons.insert(clearAllButton, at: 0)
                navigationItem.rightBarButtonItems = rightButtons
            } else {
                navigationItem.rightBarButtonItem = clearAllButton
            }

            // Verify and remove invalid history
            HistoryManager.shared.verifyAndRemoveInvalidHistory { updatedHistory in
                self.threadData = updatedHistory
                self.filteredThreadData = updatedHistory
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        } else {
            
            if boardPassed == false{
                //Startup board
                let userDefaultsKey = "defaultBoard"
                if let savedBoardAbv = UserDefaults.standard.string(forKey: userDefaultsKey) {
                    boardAbv = savedBoardAbv
                } else {
                    boardAbv = "a" // Replace with your app's default
                }
            }
            
            loadThreads()
            setupAutoRefreshTimer()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !isFavoritesView && !isHistoryView else { return }

        let currentMode = UserDefaults.standard.integer(forKey: threadsDisplayModeKey)
        guard currentMode == ThreadDisplayMode.catalog.rawValue else { return }

        let catalogVC = ThreadViewControllerFactory.makeBoardViewController(
            boardName: boardName,
            boardAbv: boardAbv,
            boardPassed: boardPassed
        )

        guard catalogVC is threadCatalogCV else { return }

        var viewControllers = navigationController?.viewControllers ?? []
        if let index = viewControllers.firstIndex(of: self) {
            viewControllers[index] = catalogVC
            navigationController?.setViewControllers(viewControllers, animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("=== boardTV viewWillAppear ===")
        print("Is favorites view: \(isFavoritesView)")
        print("Thread data count before: \(threadData.count)")
        print("Filtered thread data count before: \(filteredThreadData.count)")
        
        // Update search bar appearance when view appears
        if !isFavoritesView {
            updateSearchBarAppearance()
        }

        if isFavoritesView {
            print("Updating favorites data in viewWillAppear - this might override our search results!")
            print("Is searching: \(isSearching)")
            
            // Don't update data if we're actively searching - parent view will handle it
            if !isSearching {
                // Step 1: Verify and remove invalid favorites
                FavoritesManager.shared.verifyAndRemoveInvalidFavorites { [weak self] updatedFavorites in
                    guard let self = self else { return }
                    
                    print("Got updated favorites: \(updatedFavorites.count) items")
                    self.threadData = updatedFavorites
                    self.filteredThreadData = updatedFavorites

                    // Step 2: Update current replies after verification
                    FavoritesManager.shared.updateCurrentReplies {
                        DispatchQueue.main.async {
                            print("Reloading favorites data after thread status check")
                            self.loadFavorites()
                        }
                    }
                }
            } else {
                print("Skipping data update because search is active")
            }
        }
        
        // Restart auto-refresh timer when view appears
        setupAutoRefreshTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop auto-refresh timer when view disappears
        stopAutoRefreshTimer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // We maintain the same UI regardless of size class now
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateSearchBarAppearance()
        }
    }
    
    // MARK: - UI Setup Methods
    // Methods that set up the UI components.

    // Home button removed in favor of standard navigation back button
    
    private func setupSortButton() {
        // Adds board actions to the navigation bar.
        var buttons: [UIBarButtonItem] = []

        let moreImage = UIImage(named: "more")?.withRenderingMode(.alwaysTemplate)
        let resizedMoreImage = moreImage?.resized(to: CGSize(width: 22, height: 22))
        let moreButton = UIBarButtonItem(image: resizedMoreImage, style: .plain, target: self, action: #selector(showActionSheet))
        moreButton.tintColor = .black
        moreButton.accessibilityLabel = "More"
        moreBarButtonItem = moreButton
        buttons.append(moreButton)

        // Add new thread button for regular board view (not favorites or history)
        if !isFavoritesView && !isHistoryView {
            let newThreadImage = UIImage(systemName: "plus.square")
            let newThreadButton = UIBarButtonItem(image: newThreadImage, style: .plain, target: self, action: #selector(showNewThreadCompose))
            newThreadButton.tintColor = .black
            buttons.append(newThreadButton)
        }

        // Check if there are existing right bar button items
        if var rightBarButtonItems = navigationItem.rightBarButtonItems {
            rightBarButtonItems.append(contentsOf: buttons)
            navigationItem.rightBarButtonItems = rightBarButtonItems
        } else {
            navigationItem.rightBarButtonItems = buttons
        }
    }

    private func showCatalogGridSizeSettings() {
        let settingsVC = CatalogSettingsViewController()
        settingsVC.modalPresentationStyle = .popover
        settingsVC.preferredContentSize = CGSize(width: 400, height: 200)

        if let popover = settingsVC.popoverPresentationController {
            popover.delegate = self
            popover.channerAnchor(in: self, barButtonItem: moreBarButtonItem, permittedArrowDirections: .up)
        }

        present(settingsVC, animated: true)
    }

    @objc private func showActionSheet() {
        var primaryOptions: [BoardMoreOption] = [
            BoardMoreOption(title: "Search", subtitle: "Find text in threads", systemImageName: "magnifyingglass") { [weak self] in
                self?.showSearch()
            }
        ]
        
        if !searchText.isEmpty {
            primaryOptions.append(BoardMoreOption(title: "Clear Search", subtitle: "Return to the full board", systemImageName: "xmark.circle") { [weak self] in
                self?.clearSearch()
            })
        }
        
        var sortOptions: [BoardMoreOption]
        if isHistoryView {
            sortOptions = [
                BoardMoreOption(title: "Most Recently Visited", subtitle: "Show recent visits first", systemImageName: "clock.arrow.circlepath") { [weak self] in
                    self?.sortThreads(by: .visitedOrder)
                },
                BoardMoreOption(title: "Oldest Visited", subtitle: "Show older visits first", systemImageName: "clock") { [weak self] in
                    self?.sortHistoryThreadsByOldestVisited()
                },
                BoardMoreOption(title: "Highest Reply Count", subtitle: "Show most active threads first", systemImageName: "text.bubble") { [weak self] in
                    self?.sortThreads(by: .replyCount)
                },
                BoardMoreOption(title: "Newest Creation", subtitle: "Show newest threads first", systemImageName: "sparkles") { [weak self] in
                    self?.sortThreads(by: .newestCreation)
                }
            ]
        } else {
            sortOptions = [
                BoardMoreOption(title: "Bump Order", subtitle: "Use the board default order", systemImageName: "arrow.up.arrow.down") { [weak self] in
                    self?.sortThreads(by: .bumpOrder)
                },
                BoardMoreOption(title: "Last Reply", subtitle: "Show latest replies first", systemImageName: "arrow.clockwise") { [weak self] in
                    self?.sortThreads(by: .lastReply)
                },
                BoardMoreOption(title: "Highest Reply Count", subtitle: "Show most active threads first", systemImageName: "text.bubble") { [weak self] in
                    self?.sortThreads(by: .replyCount)
                },
                BoardMoreOption(title: "Newest Creation", subtitle: "Show newest threads first", systemImageName: "sparkles") { [weak self] in
                    self?.sortThreads(by: .newestCreation)
                }
            ]
        }
        
        let sections = [
            BoardMoreOptionsSection(title: nil, options: primaryOptions),
            BoardMoreOptionsSection(title: "Sort", options: sortOptions),
            BoardMoreOptionsSection(title: "Display", options: [
                BoardMoreOption(title: "Catalog Grid Size", subtitle: "Adjust catalog thumbnail layout", systemImageName: "square.grid.3x3") { [weak self] in
                    self?.showCatalogGridSizeSettings()
                }
            ])
        ]
        
        let optionsController = BoardMoreOptionsViewController(title: "Board Options", subtitle: boardOptionsSubtitle, sections: sections)
        optionsController.modalPresentationStyle = traitCollection.horizontalSizeClass == .regular ? .popover : .pageSheet
        
        if let sheet = optionsController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 18
        }
        
        if let popover = optionsController.popoverPresentationController {
            popover.channerAnchor(in: self, barButtonItem: moreBarButtonItem, permittedArrowDirections: .up)
        }
        
        present(optionsController, animated: true)
    }
    
    private var boardOptionsSubtitle: String {
        if isHistoryView {
            return "History"
        }
        
        if isFavoritesView {
            return "Favorites"
        }
        
        return "/\(boardAbv)/"
    }

    @objc private func showSearch() {
        updateSearchBarAppearance()

        if let navigationController = navigationController as? CatalystNavigationController {
            navigationController.showBottomToolbarSearch(searchController, owner: self)
        } else {
            navigationItem.searchController = searchController
            searchController.isActive = true
            searchBar.becomeFirstResponder()
        }
    }

    private func clearSearch() {
        searchBar.text = ""
        searchText = ""
        isSearching = false
        filteredThreadData = threadData
        tableView.reloadData()
    }

    func bottomToolbarSearchDidRequestDismissal() {
        clearSearch()
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
            refreshStatusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
    
    private func setupTableView() {
        // Configures the table view's appearance and behavior.
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
        tableView.prefetchDataSource = self

        // Register the custom cell
        tableView.register(boardTVCell.self, forCellReuseIdentifier: "boardTVCell")

        // Setup pull-to-refresh
        setupRefreshControl()
    }

    private func setupRefreshControl() {
        // Configures pull-to-refresh for the table view.
        let refresh = UIRefreshControl()
        refresh.tintColor = ThemeManager.shared.primaryTextColor
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        refreshControl = refresh
    }

    @objc private func handlePullToRefresh() {
        // Handles pull-to-refresh action based on view type.
        if isFavoritesView {
            // Refresh favorites data
            FavoritesManager.shared.verifyAndRemoveInvalidFavorites { [weak self] updatedFavorites in
                guard let self = self else { return }
                self.threadData = updatedFavorites
                self.filteredThreadData = updatedFavorites

                FavoritesManager.shared.updateCurrentReplies {
                    DispatchQueue.main.async {
                        self.loadFavorites()
                        self.refreshControl?.endRefreshing()
                    }
                }
            }
        } else if isHistoryView {
            // Refresh history data
            HistoryManager.shared.verifyAndRemoveInvalidHistory { [weak self] updatedHistory in
                guard let self = self else { return }
                self.threadData = updatedHistory
                self.filteredThreadData = updatedHistory
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                    self.tableView.reloadData()
                }
            }
        } else {
            // Refresh board threads
            loadThreads()
        }
    }
    
    private func setupLoadingIndicator() {
        // Sets up the loading indicator to show when data is loading.
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupImageCache() {
        // Configures the image cache for efficient image loading.
        imageCache.countLimit = 200 // Increased for multiple pages
        prefetchQueue.maxConcurrentOperationCount = 2
    }
    
    // Custom styled container for search bar (matches thread cell design)
    private var searchBarStyledContainer: UIView?

    private func setupSearchBar() {
        print("Setting up bottom toolbar search for boardTV")

        searchBar.delegate = self
        searchBar.placeholder = "Title or Comment"
        searchBar.searchBarStyle = .minimal
        searchBar.showsCancelButton = false

        searchBar.backgroundImage = UIImage()
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        searchBar.tintColor = ThemeManager.shared.primaryTextColor

        let textField = searchBar.searchTextField
        textField.backgroundColor = .clear
        textField.textColor = ThemeManager.shared.primaryTextColor
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.layer.cornerRadius = 0
        textField.layer.borderWidth = 0
        textField.borderStyle = .none
        textField.background = nil

        textField.attributedPlaceholder = NSAttributedString(
            string: "Title or Comment",
            attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.secondaryTextColor]
        )
        tableView.tableHeaderView = nil

        updateSearchBarAppearance()
    }
    
    private func updateSearchBarAppearance() {
        // Update main container background
        if let container = tableView.tableHeaderView {
            container.backgroundColor = ThemeManager.shared.backgroundColor
        }

        // Update styled container (matches thread cell design)
        if let styledContainer = searchBarStyledContainer {
            styledContainer.backgroundColor = ThemeManager.shared.cellBackgroundColor
            styledContainer.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        }

        // Update search bar colors
        searchBar.tintColor = ThemeManager.shared.primaryTextColor
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        searchBar.backgroundImage = UIImage()
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)

        // Update search text field (transparent, styled container provides background)
        let textField = searchBar.searchTextField
        textField.backgroundColor = .clear
        textField.textColor = ThemeManager.shared.primaryTextColor
        textField.tintColor = ThemeManager.shared.primaryTextColor
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.layer.cornerRadius = 0
        textField.layer.borderWidth = 0
        textField.borderStyle = .none
        textField.background = nil

        // Update placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: searchBar.placeholder ?? "Title or Comment",
            attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.secondaryTextColor]
        )
    }
    
    // MARK: - Actions
    // Methods that respond to user interactions.

    // showMasterView() method removed as we now use the default back button
    
    @objc private func clearAllHistory() {
        // Clears all browsing history.
        let alert = UIAlertController(title: "Clear History", message: "Are you sure you want to clear all history?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { _ in
            HistoryManager.shared.clearHistory() // Clear the history through the manager
            
            // Update table view
            self.threadData.removeAll()
            self.filteredThreadData.removeAll()
            self.tableView.reloadData()
        }))
        
        present(alert, animated: true, completion: nil)
    }

    @objc private func handleLongPressForFavorite(gestureRecognizer: UILongPressGestureRecognizer) {
        // Handles long-press gesture on favorites to delete them.
        guard isFavoritesView else { return }
        
        let location = gestureRecognizer.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: location), gestureRecognizer.state == .began {
            let threadToDelete = filteredThreadData[indexPath.row]
            
            let alert = UIAlertController(
                title: "Delete Favorite",
                message: "Are you sure you want to remove this favorite?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                // Remove from FavoritesManager
                FavoritesManager.shared.removeFavorite(threadNumber: threadToDelete.number, boardAbv: threadToDelete.boardAbv)
                
                // Remove from local data sources
                self.filteredThreadData.remove(at: indexPath.row)
                if let index = self.threadData.firstIndex(where: { $0.number == threadToDelete.number }) {
                    self.threadData.remove(at: index)
                }
                
                // Update table view
                if self.filteredThreadData.isEmpty {
                    self.tableView.reloadData()
                } else {
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }))
            
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func sortHistoryThreadsByOldestVisited() {
        let historyThreads = HistoryManager.shared.getHistoryThreads()
        filteredThreadData.sort { thread1, thread2 in
            let index1 = historyThreads.firstIndex(where: { $0.number == thread1.number && $0.boardAbv == thread1.boardAbv }) ?? 0
            let index2 = historyThreads.firstIndex(where: { $0.number == thread2.number && $0.boardAbv == thread2.boardAbv }) ?? 0
            return index1 < index2
        }
        tableView.reloadData()
    }

    @objc private func showNewThreadCompose() {
        let composeVC = ComposeViewController(board: boardAbv, threadNumber: 0, quoteText: nil)
        composeVC.delegate = self
        let navController = CatalystNavigationController(rootViewController: composeVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }

    @objc private func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        // Handles long-press gesture on history items to delete them.
        guard isHistoryView else { return }
        
        let location = gestureRecognizer.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: location), gestureRecognizer.state == .began {
            
            let alert = UIAlertController(title: "Delete Thread", message: "Are you sure you want to delete this thread from history?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                // Remove the thread from data sources
                let threadToDelete = self.filteredThreadData[indexPath.row]
                HistoryManager.shared.removeThreadFromHistory(threadToDelete)
                
                // Remove from both filteredThreadData and threadData
                self.filteredThreadData.remove(at: indexPath.row)
                if let index = self.threadData.firstIndex(where: { $0.number == threadToDelete.number && $0.boardAbv == threadToDelete.boardAbv }) {
                    self.threadData.remove(at: index)
                }
                
                // Update table view
                if self.filteredThreadData.isEmpty {
                    self.tableView.reloadData()
                } else {
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }))
            
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Data Loading Methods
    // Methods responsible for loading data, such as threads and favorites.

    private func loadThreads() {
        // Loads threads from the server.
        guard !isLoading else {
            refreshControl?.endRefreshing()
            return
        }

        isLoading = true
        loadingIndicator.startAnimating()

        // Record board visit for statistics
        StatisticsManager.shared.recordBoardVisit(boardAbv: boardAbv)
    
        let dispatchGroup = DispatchGroup()
        var newThreadData: [ThreadData] = []
        var errors: [Error] = []
    
        let serialQueue = DispatchQueue(label: "com.channer.threadDataQueue")
    
        for page in 1...totalPages {
            dispatchGroup.enter()
    
            let url = "https://a.4cdn.org/\(boardAbv)/\(page).json"
    
            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }
    
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        if let threads = json["threads"].array {
                            let pageThreads = threads.enumerated().compactMap { (index, threadJson) in
                                var thread = ThreadData(from: threadJson, boardAbv: self.boardAbv)
                                // Set bump index based on position in board (0 = top/newest bump)
                                thread.bumpIndex = (page - 1) * threads.count + index
                                return thread.number.isEmpty ? nil : thread
                            }
    
                            serialQueue.sync {
                                newThreadData.append(contentsOf: pageThreads)
                            }
                        }
                    } catch {
                        serialQueue.sync {
                            errors.append(error)
                        }
                    }
    
                case .failure(let error):
                    serialQueue.sync {
                        errors.append(error)
                    }
                }
            }
        }
    
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
    
            self.isLoading = false
            self.loadingIndicator.stopAnimating()
            self.refreshControl?.endRefreshing()
    
            if !errors.isEmpty {
                print("Errors loading threads: \(errors)")
            }
    
            // Deduplicate threads since a thread can briefly appear on multiple pages while the board is updating
            let dedupedThreads = newThreadData.reduce(into: [String: ThreadData]()) { result, thread in
                if let existing = result[thread.number] {
                    let existingReplies = existing.currentReplies ?? existing.replies
                    let newReplies = thread.currentReplies ?? thread.replies
                    let existingBump = existing.bumpIndex ?? Int.max
                    let newBump = thread.bumpIndex ?? Int.max
                    
                    // Keep the version that is higher on the board (lower bump index) or has fresher reply data
                    if newBump < existingBump || newReplies > existingReplies {
                        result[thread.number] = thread
                    }
                } else {
                    result[thread.number] = thread
                }
            }

            self.threadData = Array(dedupedThreads.values).sorted { Int($0.number) ?? 0 > Int($1.number) ?? 0 }
            
            self.filteredThreadData = self.applyContentFilters(to: self.threadData)

            self.updateFilterCache()
            self.tableView.reloadData()
        }
    }

    func loadFavorites() {
        // Loads favorite threads.
        print("boardTV - loadFavorites")
        threadData = FavoritesManager.shared.loadFavorites()
        filteredThreadData = applyContentFilters(to: threadData)

        // Update filter cache and reload the table view
        updateFilterCache()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    /// Performance: Compute and cache which threads match content filters
    /// Call this after loading data to avoid expensive KVC lookups in cellForRowAt
    private func updateFilterCache() {
        filteredThreadNumbers.removeAll()

        let manager = ContentFilterManager.shared
        guard manager.isFilteringEnabled() || manager.isAdvancedFilteringEnabled() else {
            filterCacheValid = true
            return
        }

        for thread in filteredThreadData {
            let metadata = postMetadata(for: thread)
            if manager.filterResult(for: metadata).isFiltered {
                filteredThreadNumbers.insert(thread.number)
            }
        }

        filterCacheValid = true
    }

    private func applyContentFilters(to threads: [ThreadData]) -> [ThreadData] {
        let manager = ContentFilterManager.shared
        guard manager.isFilteringEnabled() || manager.isAdvancedFilteringEnabled() else {
            return threads
        }

        let visibleThreads = threads.compactMap { thread in
            let result = manager.filterResult(for: postMetadata(for: thread))
            return result.isFiltered && !result.showStub ? nil : thread
        }
        guard visibleThreads.contains(where: { manager.filterResult(for: postMetadata(for: $0)).pinToTop }) else {
            return visibleThreads
        }

        return visibleThreads.sorted { lhs, rhs in
            let lhsResult = manager.filterResult(for: postMetadata(for: lhs))
            let rhsResult = manager.filterResult(for: postMetadata(for: rhs))
            if lhsResult.pinToTop != rhsResult.pinToTop {
                return lhsResult.pinToTop
            }
            return (lhs.bumpIndex ?? Int.max) < (rhs.bumpIndex ?? Int.max)
        }
    }

    private func postMetadata(for thread: ThreadData) -> PostMetadata {
        let ext = URL(string: thread.imageUrl)?.pathExtension
        return PostMetadata(
            postNumber: thread.number,
            comment: thread.comment,
            timestamp: thread.lastReplyTime,
            imageUrl: thread.imageUrl.isEmpty ? nil : thread.imageUrl,
            imageExtension: ext.map { ".\($0)" },
            boardAbv: thread.boardAbv,
            threadNumber: thread.number,
            subject: thread.title.isEmpty ? nil : thread.title,
            name: nil,
            isOP: true,
            isTopThread: (thread.bumpIndex ?? Int.max) == 0
        )
    }

    // MARK: - TableView DataSource Methods
    // UITableViewDataSource methods for populating the table view.

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = filteredThreadData.count
        print("=== boardTV numberOfRowsInSection called ===")
        print("Thread data count: \(threadData.count)")
        print("Filtered thread data count: \(count)")
        print("Is searching: \(isSearching)")
        print("Is favorites view: \(isFavoritesView)")
        return count
    }
            
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "boardTVCell", for: indexPath) as! boardTVCell
        let thread = filteredThreadData[indexPath.row]

        // Performance: Use cached filter results instead of expensive KVC lookup on every cell
        let isFiltered = filteredThreadNumbers.contains(thread.number)

        cell.configure(with: thread, isHistoryView: isHistoryView, isFavoritesView: isFavoritesView, isFiltered: isFiltered)
        configureImage(for: cell, with: thread.imageUrl)

        return cell
    }

    // MARK: - TableView Delegate Methods
    // UITableViewDelegate methods for handling table view interactions.

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thread = filteredThreadData[indexPath.row]
        let url = "https://a.4cdn.org/\(thread.boardAbv)/thread/\(thread.number).json"
    
        //print("Selected thread at index \(indexPath.row): \(thread)")
    
        // Add the selected thread to history (if not already in history or favorites view)
        if !isHistoryView && !isFavoritesView {
            HistoryManager.shared.addThreadToHistory(thread)
            print("Thread added to history.")
        }
    
        // Show loading indicator overlay
        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = .systemBackground
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(indicator)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
        indicator.startAnimating()
    
        // Load thread data
        AF.request(url).response { response in
            DispatchQueue.main.async {
                loadingView.removeFromSuperview()
            }
    
            guard let data = response.data,
                  let json = try? JSON(data: data),
                  !json["posts"].isEmpty else {
                print("Thread not available or invalid response.")
                self.handleThreadUnavailable(at: indexPath, thread: thread)
                return
            }
    
            // Instantiate threadRepliesTV view controller
            let vc = threadRepliesTV()
    
            vc.boardAbv = thread.boardAbv
            vc.threadNumber = thread.number
            vc.totalImagesInThread = thread.stats.components(separatedBy: "/").last.flatMap { Int($0) } ?? 0
    
            // Handle navigation - same behavior on all devices
            self.navigationController?.pushViewController(vc, animated: true)
            print("Pushed threadRepliesTV on navigation stack.")
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard isFavoritesView else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completionHandler in
            guard let self = self else {
                completionHandler(false)
                return
            }

            let threadToDelete = self.filteredThreadData[indexPath.row]

            // Remove from FavoritesManager
            FavoritesManager.shared.removeFavorite(threadNumber: threadToDelete.number, boardAbv: threadToDelete.boardAbv)

            // Remove from local data sources
            self.filteredThreadData.remove(at: indexPath.row)
            if let index = self.threadData.firstIndex(where: { $0.number == threadToDelete.number && $0.boardAbv == threadToDelete.boardAbv }) {
                self.threadData.remove(at: index)
            }

            // Update table view
            if self.filteredThreadData.isEmpty {
                self.tableView.reloadData()
            } else {
                self.tableView.deleteRows(at: [indexPath], with: .fade)
            }

            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    // MARK: - Helper Methods
    // Helper methods used throughout the class.

    private func extractFirstNumber(from stats: String) -> Int? {
        // Extracts the first number from a stats string.
        let components = stats.split(separator: "/")
        guard let firstComponent = components.first, let number = Int(firstComponent) else {
            return nil
        }
        return number
    }
    
    private func configureImage(for cell: boardTVCell, with urlString: String) {
        // Configures the image for a table view cell.
        if urlString.isEmpty {
            cell.topicImage.kf.cancelDownloadTask()
            cell.displayedImageURL = nil
            cell.topicImage.image = UIImage(named: "loadingBoardImage")
            return
        }

        let finalUrl: String
        if urlString.hasSuffix(".webm") || urlString.hasSuffix(".mp4") {
            let components = urlString.components(separatedBy: "/")
            if let last = components.last {
                let fileExtension = urlString.hasSuffix(".webm") ? ".webm" : ".mp4"
                let base = last.replacingOccurrences(of: fileExtension, with: "")
                finalUrl = urlString.replacingOccurrences(of: last, with: "\(base)s.jpg")
            } else {
                finalUrl = urlString
            }
        } else {
            finalUrl = urlString
        }

        guard let url = URL(string: finalUrl) else {
            cell.topicImage.kf.cancelDownloadTask()
            cell.displayedImageURL = nil
            cell.topicImage.image = UIImage(named: "loadingBoardImage")
            return
        }

        if cell.displayedImageURL == url, cell.topicImage.image != nil {
            return
        }

        cell.topicImage.kf.cancelDownloadTask()
        let placeholderImage: UIImage?
        if cell.displayedImageURL == url {
            placeholderImage = cell.topicImage.image ?? UIImage(named: "loadingBoardImage")
        } else {
            placeholderImage = UIImage(named: "loadingBoardImage")
        }

        // Performance: Remove RoundCornerImageProcessor - the UIImageView already has cornerRadius set
        // Also removed cacheOriginalImage to avoid caching both original and processed versions
        let options: KingfisherOptionsInfo = [
            .transition(.fade(0.2)),
            .scaleFactor(UIScreen.main.scale),
            .memoryCacheExpiration(.days(1)),
            .diskCacheExpiration(.days(7)),
            .backgroundDecode,
            .loadDiskFileSynchronously
        ]

        cell.topicImage.kf.setImage(
            with: url,
            placeholder: placeholderImage,
            options: options
        ) { result in
            switch result {
            case .success:
                cell.displayedImageURL = url
            case .failure:
                cell.displayedImageURL = nil
            }
        }
    }
    
    private func handleThreadUnavailable(at indexPath: IndexPath, thread: ThreadData) {
        // Mark thread as dead so it won't be rechecked
        if self.isFavoritesView {
            FavoritesManager.shared.markThreadAsDead(threadNumber: thread.number, boardAbv: thread.boardAbv)
        }

        // Handles the case when a thread is unavailable.
        DispatchQueue.main.async {
            if self.isFavoritesView {
                let hasCachedVersion = ThreadCacheManager.shared.isCached(boardAbv: thread.boardAbv, threadNumber: thread.number)
                let alert = UIAlertController(
                    title: "Thread Unavailable",
                    message: hasCachedVersion
                        ? "This thread is no longer available. A cached version is available for viewing."
                        : "This thread is no longer available.",
                    preferredStyle: .alert
                )

                if hasCachedVersion {
                    alert.addAction(UIAlertAction(title: "View Cached Version", style: .default, handler: { _ in
                        let vc = threadRepliesTV()
                        vc.boardAbv = thread.boardAbv
                        vc.threadNumber = thread.number
                        vc.forceLoadFromCache = true
                        vc.totalImagesInThread = thread.stats.components(separatedBy: "/").last.flatMap { Int($0) } ?? 0
                        self.navigationController?.pushViewController(vc, animated: true)
                    }))
                }

                alert.addAction(UIAlertAction(title: "Remove Favorite", style: .destructive, handler: { _ in
                    FavoritesManager.shared.removeFavorite(threadNumber: thread.number, boardAbv: thread.boardAbv)
                    self.filteredThreadData.remove(at: indexPath.row)
                    if let index = self.threadData.firstIndex(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
                        self.threadData.remove(at: index)
                    }
                    if self.filteredThreadData.isEmpty {
                        self.tableView.reloadData()
                    } else {
                        self.tableView.deleteRows(at: [indexPath], with: .fade)
                    }
                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            } else if self.isHistoryView {
                let alert = UIAlertController(title: "Thread Unavailable", message: "This thread is no longer available.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    HistoryManager.shared.verifyAndRemoveInvalidHistory { updatedHistory in
                        self.threadData = updatedHistory
                        self.filteredThreadData = updatedHistory
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Thread Unavailable", message: "This thread is no longer available.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    self.filteredThreadData.remove(at: indexPath.row)
                    if let index = self.threadData.firstIndex(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
                        self.threadData.remove(at: index)
                    }
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                        self.refreshThreadList()
                    }
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func refreshThreadList() {
        // Refreshes the list of threads.
        guard !isFavoritesView && !isHistoryView else { return } // Only refresh in default view
        threadData.removeAll()
        filteredThreadData.removeAll()
        tableView.reloadData()
        loadThreads() // Re-fetch threads
    }
    
    // MARK: - Auto-refresh
    // Methods for handling automatic refresh of board content
    
    private func setupAutoRefreshTimer() {
        // Stop any existing timer
        stopAutoRefreshTimer()
        
        // Only set up timer for board views, not favorites or history
        guard !isFavoritesView && !isHistoryView else { 
            hideRefreshStatus()
            return 
        }
        
        // Get the refresh interval from settings
        let interval = UserDefaults.standard.integer(forKey: boardsAutoRefreshIntervalKey)
        
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
            self?.refreshBoardContent()
        }

        // Invalidate any existing progress timer before creating a new one
        progressUpdateTimer?.invalidate()
        progressUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRefreshProgress()
        }
    }
    
    private func stopAutoRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        progressUpdateTimer?.invalidate()
        progressUpdateTimer = nil
        hideRefreshStatus()
    }
    
    @objc private func refreshBoardContent() {
        // Only refresh if not currently loading and not searching
        guard !isLoading && !isSearching else { return }
        
        // Save current scroll position
        let currentOffset = tableView.contentOffset
        
        // Check if user is actively scrolling
        guard !tableView.isDragging && !tableView.isDecelerating else { return }
        
        // Update refresh status
        lastRefreshTime = Date()
        nextRefreshTime = Date().addingTimeInterval(TimeInterval(UserDefaults.standard.integer(forKey: boardsAutoRefreshIntervalKey)))
        updateRefreshStatus()
        
        // Reload the threads
        loadThreads()
        
        // Restore scroll position after reload
        DispatchQueue.main.async { [weak self] in
            self?.tableView.setContentOffset(currentOffset, animated: false)
        }
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
        
        let interval = UserDefaults.standard.integer(forKey: boardsAutoRefreshIntervalKey)
        guard interval > 0 else { return }
        
        let now = Date()
        let timeUntilRefresh = nextRefresh.timeIntervalSince(now)
        let progress = max(0, min(1, 1 - (timeUntilRefresh / TimeInterval(interval))))
        
        DispatchQueue.main.async { [weak self] in
            self?.refreshProgressView.setProgress(Float(progress), animated: true)
        }
    }
    
    // Keyboard shortcut methods have been moved earlier in the class
    
    @objc func refreshTable() {
        // Refresh all threads
        if !isLoading {
            // Save current scroll position
            let currentOffset = tableView.contentOffset
            
            // Reload the threads
            threadData.removeAll()
            filteredThreadData.removeAll()
            tableView.reloadData()
            loadThreads()
            
            // Restore scroll position after reload
            DispatchQueue.main.async { [weak self] in
                self?.tableView.setContentOffset(currentOffset, animated: false)
            }
        }
    }
    
    // MARK: - Sorting
    // Methods and types related to sorting threads.

    private enum SortOption {
        case replyCount
        case newestCreation
        case bumpOrder
        case lastReply
        case visitedOrder  // For history view - most recently visited first
    }
    
    private func sortThreads(by option: SortOption) {
        // Sorts threads based on the selected sort option.
        switch option {
        case .replyCount:
            filteredThreadData.sort { $0.replies > $1.replies }
        case .newestCreation:
            filteredThreadData.sort { $0.createdAt > $1.createdAt }
        case .bumpOrder:
            // Sort by thread board position (bump index), newer threads first
            filteredThreadData.sort { 
                // If bump index is available, use it; otherwise fall back to thread number
                if let bump1 = $0.bumpIndex, let bump2 = $1.bumpIndex {
                    return bump1 < bump2  // Lower index = higher on page
                }
                // Fall back to thread number if bump index not available
                return Int($0.number) ?? 0 > Int($1.number) ?? 0 
            }
        case .lastReply:
            // Sort by last reply time, most recent first
            filteredThreadData.sort {
                // If lastReplyTime is available, use it
                if let time1 = $0.lastReplyTime, let time2 = $1.lastReplyTime {
                    return time1 > time2  // Most recent replies first
                }
                // Fall back to reply count if last reply time not available
                return $0.replies > $1.replies
            }
        case .visitedOrder:
            // Restore original history order (most recently visited last in history array)
            // History is stored in insertion order, so we reverse to show most recent first
            let historyThreads = HistoryManager.shared.getHistoryThreads()
            filteredThreadData.sort { thread1, thread2 in
                let index1 = historyThreads.firstIndex(where: { $0.number == thread1.number && $0.boardAbv == thread1.boardAbv }) ?? 0
                let index2 = historyThreads.firstIndex(where: { $0.number == thread2.number && $0.boardAbv == thread2.boardAbv }) ?? 0
                return index1 > index2  // Higher index = more recently visited
            }
        }
        tableView.reloadData()
    }
}

private struct BoardMoreOptionsSection {
    let title: String?
    var options: [BoardMoreOption]
}

private struct BoardMoreOption {
    let title: String
    let subtitle: String?
    let systemImageName: String
    let isDestructive: Bool
    let action: () -> Void

    init(title: String, subtitle: String?, systemImageName: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemImageName = systemImageName
        self.isDestructive = isDestructive
        self.action = action
    }
}

private final class BoardMoreOptionsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let headerTitle: String
    private let headerSubtitle: String
    private let sections: [BoardMoreOptionsSection]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(title: String, subtitle: String, sections: [BoardMoreOptionsSection]) {
        self.headerTitle = title
        self.headerSubtitle = subtitle
        self.sections = sections
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 390, height: estimatedContentHeight)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureHeader()
        configureTableView()
        layoutOptions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preferredContentSize = CGSize(width: 390, height: estimatedContentHeight)
    }

    private var estimatedContentHeight: CGFloat {
        let rows = sections.reduce(0) { $0 + $1.options.count }
        let sectionChrome = CGFloat(sections.count) * 44
        return min(720, 88 + CGFloat(rows) * 64 + sectionChrome)
    }

    private func configureView() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
    }

    private func configureHeader() {
        titleLabel.text = headerTitle
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = ThemeManager.shared.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = headerSubtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = ThemeManager.shared.secondaryTextColor
        subtitleLabel.adjustsFontForContentSizeCategory = true
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.separatorColor = ThemeManager.shared.cellBorderColor.withAlphaComponent(0.35)
        tableView.rowHeight = 64
        tableView.estimatedRowHeight = 64
        tableView.alwaysBounceVertical = false

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 8
        }
    }

    private func layoutOptions() {
        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerStack)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].options.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = ThemeManager.shared.secondaryTextColor
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "BoardMoreOptionCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ??
            UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let option = sections[indexPath.section].options[indexPath.row]
        let textColor = option.isDestructive ? UIColor.systemRed : ThemeManager.shared.primaryTextColor
        let iconColor = option.isDestructive ? UIColor.systemRed : ThemeManager.shared.cellBorderColor

        cell.textLabel?.text = option.title
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = textColor
        cell.textLabel?.adjustsFontForContentSizeCategory = true

        cell.detailTextLabel?.text = option.subtitle
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = ThemeManager.shared.secondaryTextColor
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true

        cell.imageView?.image = UIImage(systemName: option.systemImageName)
        cell.imageView?.tintColor = iconColor
        cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
        cell.selectedBackgroundView = selectedBackgroundView()
        cell.accessoryType = .none
        cell.tintColor = iconColor
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = sections[indexPath.section].options[indexPath.row]
        dismiss(animated: true) {
            option.action()
        }
    }

    private func selectedBackgroundView() -> UIView {
        let view = UIView()
        view.backgroundColor = ThemeManager.shared.cellBorderColor.withAlphaComponent(0.18)
        return view
    }
}

// MARK: - UITableViewDataSourcePrefetching
// Extension implementing prefetching methods for table view cells.

extension boardTV: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // Prefetches data for upcoming table view cells.
        if !MediaPrefetchManager.shared.shouldPrefetchMedia(boardAbv: boardAbv) { return }
        let limitedPaths = Array(indexPaths.prefix(5))
        
        let urls = limitedPaths.compactMap { indexPath -> URL? in
            guard indexPath.row < threadData.count else { return nil }
            let imageUrl = threadData[indexPath.row].imageUrl
            if imageUrl.hasSuffix(".webm") || imageUrl.hasSuffix(".mp4") {
                let components = imageUrl.components(separatedBy: "/")
                if let last = components.last {
                    let fileExtension = imageUrl.hasSuffix(".webm") ? ".webm" : ".mp4"
                    let base = last.replacingOccurrences(of: fileExtension, with: "")
                    return URL(string: imageUrl.replacingOccurrences(of: last, with: "\(base)s.jpg"))
                }
            }
            return URL(string: imageUrl)
        }
        
        ImagePrefetcher(urls: urls, options: [.backgroundDecode]).start()
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // Cancels prefetching for cells that are no longer needed.
        // Cancel any ongoing prefetch operations
    }
}

// MARK: - UISearchBarDelegate
// Extension implementing search bar delegate methods.

extension boardTV {
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
        isSearching = false
        filteredThreadData = threadData
        tableView.reloadData()
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            isSearching = false
            filteredThreadData = threadData
            tableView.reloadData()
            return
        }
        
        isSearching = true
        filteredThreadData = threadData.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.comment.localizedCaseInsensitiveContains(searchText)
        }
        tableView.reloadData()
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension boardTV: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

// MARK: - ComposeViewControllerDelegate
extension boardTV: ComposeViewControllerDelegate {
    func composeViewControllerDidPost(_ controller: ComposeViewController, postNumber: Int?) {
        // Refresh the board to show the new thread
        loadThreads()

        // Show success message
        let message = postNumber != nil ? "Thread #\(postNumber!) created successfully" : "Thread created successfully"
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func composeViewControllerDidCancel(_ controller: ComposeViewController) {
        // No action needed
    }

    func composeViewControllerDidMinimize(_ controller: ComposeViewController) {
        // No action needed for board view
    }
}
