import UIKit
import Alamofire
import SwiftyJSON
import Kingfisher
import Foundation

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
    
    // Custom coding keys to include all properties
    enum CodingKeys: String, CodingKey {
        case number, stats, title, comment, imageUrl, boardAbv, replies, currentReplies, createdAt, hasNewReplies, categoryId, lastReplyTime, bumpIndex
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
    init(number: String, stats: String, title: String, comment: String, imageUrl: String, boardAbv: String, replies: Int, currentReplies: Int? = nil, createdAt: String, hasNewReplies: Bool = false, categoryId: String? = nil, lastReplyTime: Int? = nil, bumpIndex: Int? = nil) {
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
    }
}

class boardTV: UITableViewController, UISearchBarDelegate {
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
    
    // Search bar property
    private let searchBar = UISearchBar()
    private var searchText: String = ""

    // Image cache configuration
    private let imageCache = NSCache<NSString, UIImage>()
    private let prefetchQueue = OperationQueue()
    
    // Auto-refresh timer
    private var refreshTimer: Timer?
    private let boardsAutoRefreshIntervalKey = "channer_boards_auto_refresh_interval"
    private var lastRefreshTime: Date?
    private var nextRefreshTime: Date?
    
    // Refresh status indicator
    private let refreshStatusView = UIView()
    private let refreshStatusLabel = UILabel()
    private let refreshProgressView = UIProgressView(progressViewStyle: .default)
    private var refreshStatusHeight: NSLayoutConstraint?

    // MARK: - Lifecycle Methods
    // Methods related to the view controller's lifecycle.

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        // Only setup search bar if not in favorites view (favorites view has its own search)
        if !isFavoritesView {
            setupSearchBar()
            // Force table to reload to show search bar
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
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
            
            // Add "Clear All" button with resized image
            let clearAllImage = UIImage(named: "clearAll")?.withRenderingMode(.alwaysTemplate)
            let resizedClearAllImage = clearAllImage?.resized(to: CGSize(width: 22, height: 22))
            let clearAllButton = UIBarButtonItem(image: resizedClearAllImage, style: .plain, target: self, action: #selector(clearAllHistory))
            
            // Add "Clear All" button to the right side
            navigationItem.rightBarButtonItem = clearAllButton
            
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
                            print("Reloading table view in viewWillAppear")
                            self.tableView.reloadData() // Reload table view once, after all updates
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
        // Adds a sort button to the navigation bar, unless in history view.
        guard !isHistoryView else { return }
        
        let sortImage = UIImage(named: "sort")?.withRenderingMode(.alwaysTemplate)
        let resizedSortImage = sortImage?.resized(to: CGSize(width: 22, height: 22))
        let sortButton = UIBarButtonItem(image: resizedSortImage, style: .plain, target: self, action: #selector(sortButtonTapped))
        // Check if there are existing right bar button items
        if var rightBarButtonItems = navigationItem.rightBarButtonItems {
            rightBarButtonItems.append(sortButton)
            navigationItem.rightBarButtonItems = rightBarButtonItems
        } else {
            navigationItem.rightBarButtonItems = [sortButton]
        }
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
    
    private func setupSearchBar() {
        // Sets up the search bar for searching threads.
        print("Setting up search bar for boardTV")
        
        // Configure search bar first
        searchBar.delegate = self
        searchBar.placeholder = "Title or Comment"
        searchBar.searchBarStyle = .default  // Changed from .minimal to .default for better visibility
        searchBar.showsCancelButton = false
        
        // Style the search text field directly
        searchBar.searchTextField.backgroundColor = ThemeManager.shared.cellBackgroundColor
        searchBar.searchTextField.textColor = ThemeManager.shared.primaryTextColor
        searchBar.searchTextField.font = UIFont.systemFont(ofSize: 16)
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBar.searchTextField.layer.borderWidth = 1
        searchBar.searchTextField.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Title or Comment",
            attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.secondaryTextColor]
        )
        
        // Style the search bar
        searchBar.tintColor = ThemeManager.shared.primaryTextColor
        searchBar.barTintColor = ThemeManager.shared.backgroundColor
        searchBar.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Remove borders and background images
        searchBar.backgroundImage = UIImage()
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar.layer.borderWidth = 0
        searchBar.layer.borderColor = UIColor.clear.cgColor
        
        // Style the search field
        if let searchField = searchBar.value(forKey: "searchField") as? UITextField {
            searchField.backgroundColor = ThemeManager.shared.cellBackgroundColor
            searchField.textColor = ThemeManager.shared.primaryTextColor
            searchField.tintColor = ThemeManager.shared.primaryTextColor
            searchField.layer.cornerRadius = 8
            searchField.clipsToBounds = true
            searchField.font = UIFont.systemFont(ofSize: 16)
            
            // Style the placeholder
            if let placeholderLabel = searchField.value(forKey: "placeholderLabel") as? UILabel {
                placeholderLabel.textColor = ThemeManager.shared.secondaryTextColor
                placeholderLabel.font = UIFont.systemFont(ofSize: 16)
            }
        }
        
        // Set search bar directly as table header
        searchBar.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 56)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Create container view with proper sizing
        let searchBarContainer = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 56))
        searchBarContainer.backgroundColor = ThemeManager.shared.backgroundColor
        searchBarContainer.addSubview(searchBar)
        
        // Use auto layout for search bar within container
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: searchBarContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: searchBarContainer.bottomAnchor)
        ])
        
        // Set container as table header
        tableView.tableHeaderView = searchBarContainer
        searchBar.sizeToFit()
        
        // Update appearance
        updateSearchBarAppearance()
    }
    
    private func updateSearchBarAppearance() {
        // Update container background
        if let container = tableView.tableHeaderView {
            container.backgroundColor = ThemeManager.shared.backgroundColor
        }
        
        // Update search bar colors
        searchBar.tintColor = ThemeManager.shared.primaryTextColor
        searchBar.barTintColor = ThemeManager.shared.backgroundColor
        searchBar.backgroundColor = ThemeManager.shared.backgroundColor
        searchBar.backgroundImage = UIImage()
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        
        // Remove borders
        searchBar.layer.borderWidth = 0
        searchBar.layer.borderColor = UIColor.clear.cgColor
        
        // Update search text field directly
        searchBar.searchTextField.backgroundColor = ThemeManager.shared.cellBackgroundColor
        searchBar.searchTextField.textColor = ThemeManager.shared.primaryTextColor
        searchBar.searchTextField.tintColor = ThemeManager.shared.primaryTextColor
        searchBar.searchTextField.font = UIFont.systemFont(ofSize: 16)
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBar.searchTextField.layer.borderWidth = 1
        searchBar.searchTextField.layer.borderColor = ThemeManager.shared.cellBorderColor.cgColor
        searchBar.searchTextField.clipsToBounds = true
        
        // Update placeholder
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
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
                FavoritesManager.shared.removeFavorite(threadNumber: threadToDelete.number)
                
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
    
    @objc private func sortButtonTapped() {
        // Presents sorting options when the sort button is tapped.
        let alertController = UIAlertController(title: "Sort", message: nil, preferredStyle: .actionSheet)
        
        // Add sorting actions
        let bumpOrderAction = UIAlertAction(title: "Bump Order", style: .default) { _ in
            self.sortThreads(by: .bumpOrder)
        }
        let lastReplyAction = UIAlertAction(title: "Last Reply", style: .default) { _ in
            self.sortThreads(by: .lastReply)
        }
        let replyCountAction = UIAlertAction(title: "Highest Reply Count", style: .default) { _ in
            self.sortThreads(by: .replyCount)
        }
        let newestCreationAction = UIAlertAction(title: "Newest Creation", style: .default) { _ in
            self.sortThreads(by: .newestCreation)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(bumpOrderAction)
        alertController.addAction(lastReplyAction)
        alertController.addAction(replyCountAction)
        alertController.addAction(newestCreationAction)
        alertController.addAction(cancelAction)
        
        // iPad-specific popover configuration
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?.first { $0.action == #selector(sortButtonTapped) }
            popoverController.permittedArrowDirections = .up
        }
        
        // Present the alert controller
        present(alertController, animated: true, completion: nil)
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
    
            self.threadData = newThreadData.sorted { Int($0.number) ?? 0 > Int($1.number) ?? 0 }
            
            // Apply content filtering if enabled
            if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
               let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
               let isFilteringEnabled = manager.perform(NSSelectorFromString("isFilteringEnabled"))?.takeUnretainedValue() as? Bool,
               isFilteringEnabled {
                
                // Get keyword filters through KVC
                if let getAllFilters = manager.perform(NSSelectorFromString("getAllFilters"))?.takeUnretainedValue() as? (keywords: [String], posters: [String], images: [String]),
                   !getAllFilters.keywords.isEmpty {
                    
                    let keywordFilters = getAllFilters.keywords
                    self.filteredThreadData = self.threadData.filter { thread in
                        let threadContent = (thread.title + " " + thread.comment).lowercased()
                        return !keywordFilters.contains { threadContent.contains($0.lowercased()) }
                    }
                } else {
                    self.filteredThreadData = self.threadData
                }
            } else {
                self.filteredThreadData = self.threadData
            }
            
            self.tableView.reloadData()
        }
    }
    
    func loadFavorites() {
        // Loads favorite threads.
        print("boardTV - loadFavorites")
        threadData = FavoritesManager.shared.loadFavorites()
        
        // Apply content filtering if enabled
        if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
           let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
           let isFilteringEnabled = manager.perform(NSSelectorFromString("isFilteringEnabled"))?.takeUnretainedValue() as? Bool,
           isFilteringEnabled {
            
            // Get keyword filters through KVC
            if let getAllFilters = manager.perform(NSSelectorFromString("getAllFilters"))?.takeUnretainedValue() as? (keywords: [String], posters: [String], images: [String]),
               !getAllFilters.keywords.isEmpty {
                
                let keywordFilters = getAllFilters.keywords
                filteredThreadData = threadData.filter { thread in
                    let threadContent = (thread.title + " " + thread.comment).lowercased()
                    return !keywordFilters.contains { threadContent.contains($0.lowercased()) }
                }
            } else {
                filteredThreadData = threadData
            }
        } else {
            filteredThreadData = threadData
        }
    
        // Reload the table view after updating `threadData` and `filteredThreadData`
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
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
        
        // Check if content filtering is enabled
        var isFiltered = false
        
        if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
           let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject,
           let isFilteringEnabled = manager.perform(NSSelectorFromString("isFilteringEnabled"))?.takeUnretainedValue() as? Bool,
           isFilteringEnabled,
           let getAllFilters = manager.perform(NSSelectorFromString("getAllFilters"))?.takeUnretainedValue() as? (keywords: [String], posters: [String], images: [String]) {
            
            let threadContent = (thread.title + " " + thread.comment).lowercased()
            isFiltered = getAllFilters.keywords.contains { threadContent.contains($0.lowercased()) }
        }
        
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
            cell.topicImage.image = UIImage(named: "loadingBoardImage")
            return
        }
        
        // Updated corner radius from 15 to 8
        let options: KingfisherOptionsInfo = [
            .transition(.fade(0.2)),
            .processor(RoundCornerImageProcessor(cornerRadius: 8)),
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage,
            .memoryCacheExpiration(.days(1)),
            .diskCacheExpiration(.days(7)),
            .backgroundDecode
        ]
        
        cell.topicImage.kf.setImage(
            with: url,
            placeholder: UIImage(named: "loadingBoardImage"),
            options: options
        )
    }
    
    private func handleThreadUnavailable(at indexPath: IndexPath, thread: ThreadData) {
        // Handles the case when a thread is unavailable.
        let alert = UIAlertController(title: "Thread Unavailable", message: "This thread is no longer available.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            // Remove thread from favorites, history, or refresh if in default view
            if self.isFavoritesView {
                FavoritesManager.shared.verifyAndRemoveInvalidFavorites { updatedFavorites in
                    self.threadData = updatedFavorites
                    self.filteredThreadData = updatedFavorites
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            } else if self.isHistoryView {
                HistoryManager.shared.verifyAndRemoveInvalidHistory { updatedHistory in
                    self.threadData = updatedHistory
                    self.filteredThreadData = updatedHistory
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            } else {
                // Remove from local data sources
                self.filteredThreadData.remove(at: indexPath.row)
                if let index = self.threadData.firstIndex(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
                    self.threadData.remove(at: index)
                }
    
                // Update table view and refresh thread list
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshThreadList()
                }
            }
        }))
        present(alert, animated: true, completion: nil)
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
    
    // MARK: - Sorting
    // Methods and types related to sorting threads.

    private enum SortOption {
        case replyCount
        case newestCreation
        case bumpOrder
        case lastReply
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
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSourcePrefetching
// Extension implementing prefetching methods for table view cells.

extension boardTV: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // Prefetches data for upcoming table view cells.
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
