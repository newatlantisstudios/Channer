import UIKit
import Alamofire
import SwiftyJSON
import Kingfisher

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
        } else {
            self.number = ""
            self.stats = "0/0"
            self.title = ""
            self.comment = ""
            self.imageUrl = ""
            self.replies = 0
            self.createdAt = ""
        }
    }

    // Default initializer
    init(number: String, stats: String, title: String, comment: String, imageUrl: String, boardAbv: String, replies: Int, createdAt: String) {
        self.number = number
        self.stats = stats
        self.title = title
        self.comment = comment
        self.imageUrl = imageUrl
        self.boardAbv = boardAbv
        self.replies = replies
        self.createdAt = createdAt
    }
}

class boardTV: UITableViewController {
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
    private var isSearching = false
    var isHistoryView: Bool = false
    var isFavoritesView: Bool = false
    var boardPassed = false

    // Image cache configuration
    private let imageCache = NSCache<NSString, UIImage>()
    private let prefetchQueue = OperationQueue()

    // MARK: - Lifecycle Methods
    // Methods related to the view controller's lifecycle.

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remove the title
        // navigationItem.title = nil
        
        setupTableView()
        setupImageCache()
        setupLoadingIndicator()
        setupSortButton()
        setupSearchController()
        
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
            
            // Add "Clear All" button
            let clearAllButton = UIBarButtonItem(image: UIImage(named: "clearAll"), style: .plain, target: self, action: #selector(clearAllHistory))
            
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
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isFavoritesView {
            // Step 1: Verify and remove invalid favorites
            FavoritesManager.shared.verifyAndRemoveInvalidFavorites { [weak self] updatedFavorites in
                guard let self = self else { return }
                
                self.threadData = updatedFavorites
                self.filteredThreadData = updatedFavorites

                // Step 2: Update current replies after verification
                FavoritesManager.shared.updateCurrentReplies {
                    DispatchQueue.main.async {
                        self.tableView.reloadData() // Reload table view once, after all updates
                    }
                }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // We maintain the same UI regardless of size class now
    }
    
    // MARK: - UI Setup Methods
    // Methods that set up the UI components.

    // Home button removed in favor of standard navigation back button
    
    private func setupSortButton() {
        // Adds a sort button to the navigation bar, unless in history view.
        guard !isHistoryView else { return }
        
        let sortButton = UIBarButtonItem(image: UIImage(named: "sort"), style: .plain, target: self, action: #selector(sortButtonTapped))
        // Check if there are existing right bar button items
        if var rightBarButtonItems = navigationItem.rightBarButtonItems {
            rightBarButtonItems.append(sortButton)
            navigationItem.rightBarButtonItems = rightBarButtonItems
        } else {
            navigationItem.rightBarButtonItems = [sortButton]
        }
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
    
    private func setupSearchController() {
        // Sets up the search controller for searching threads.
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Title or Comment"
        navigationItem.searchController = searchController
        
        // Ensure the search bar stays visible when scrolling
        navigationItem.hidesSearchBarWhenScrolling = true
        
        definesPresentationContext = true
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
        let replyCountAction = UIAlertAction(title: "Highest Reply Count", style: .default) { _ in
            self.sortThreads(by: .replyCount)
        }
        let newestCreationAction = UIAlertAction(title: "Newest Creation", style: .default) { _ in
            self.sortThreads(by: .newestCreation)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
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
                            let pageThreads = threads.compactMap { threadJson in
                                let thread = ThreadData(from: threadJson, boardAbv: self.boardAbv)
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
            self.filteredThreadData = self.threadData
            self.tableView.reloadData()
        }
    }
    
    func loadFavorites() {
        // Loads favorite threads.
        print("boardTV - loadFavorites")
        threadData = FavoritesManager.shared.loadFavorites()
        filteredThreadData = threadData
    
        print("threadData")
        print(threadData)
        print("filteredThreadData")
        print(filteredThreadData)
    
        // Reload the table view after updating `threadData` and `filteredThreadData`
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    // MARK: - TableView DataSource Methods
    // UITableViewDataSource methods for populating the table view.

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredThreadData.count
    }
            
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "boardTVCell", for: indexPath) as! boardTVCell
        let thread = filteredThreadData[indexPath.row]
        // print("boardTV - cellForRowAt")
        // print(thread)
        
        cell.configure(with: thread, isHistoryView: isHistoryView, isFavoritesView: isFavoritesView)
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
    
    // MARK: - Sorting
    // Methods and types related to sorting threads.

    private enum SortOption {
        case replyCount
        case newestCreation
    }
    
    private func sortThreads(by option: SortOption) {
        // Sorts threads based on the selected sort option.
        switch option {
        case .replyCount:
            filteredThreadData.sort { $0.replies > $1.replies }
        case .newestCreation:
            filteredThreadData.sort { $0.createdAt > $1.createdAt }
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

// MARK: - UISearchResultsUpdating
// Extension updating the search results as the user types in the search bar.

extension boardTV: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        // Updates the search results based on the search text.
        guard let searchText = searchController.searchBar.text, !searchText.isEmpty else {
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
