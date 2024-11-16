import UIKit
import Alamofire
import SwiftyJSON
import Kingfisher

// MARK: - Thread Model
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

class boardTV: UITableViewController, UISearchBarDelegate {
    // Properties
        var boardName = ""
        var boardAbv = ""
        var threadData: [ThreadData] = []
        var filteredThreadData: [ThreadData] = []
        private var isLoading = false
        private let totalPages = 10
        private var loadedPages = 0
        private let loadingIndicator = UIActivityIndicatorView(style: .medium)
        private var isSearching = false
        
        var isHistoryView: Bool = false
    var isFavoritesView: Bool = false
    
    // Image cache configuration
       private let imageCache = NSCache<NSString, UIImage>()
       private let prefetchQueue = OperationQueue()
       
       // Search bar
       private let searchBar: UISearchBar = {
           let sb = UISearchBar()
           sb.placeholder = "Search by title or comment"
           return sb
       }()
       
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupImageCache()
        setupLoadingIndicator()
        setupSearchBar()
        setupSortButton()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tapGesture)
        
        if isFavoritesView {
            self.title = "Favorites"
            
            // Verify and remove invalid favorites
            FavoritesManager.shared.verifyAndRemoveInvalidFavorites { updatedFavorites in
                self.threadData = updatedFavorites
                self.filteredThreadData = updatedFavorites
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            
            // Add long-press gesture recognizer for deleting favorites
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressForFavorite))
            tableView.addGestureRecognizer(longPressGesture)
        } else if isHistoryView {
            self.title = "History"
            
            // Add "Clear All" button
            let clearAllButton = UIBarButtonItem(image: UIImage(named: "clearAll"), style: .plain, target: self, action: #selector(clearAllHistory))
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
            self.title = "/\(boardAbv)/"
            loadThreads()
        }
    }
    
    @objc private func clearAllHistory() {
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
    
    func loadFavorites() {
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

    @objc private func handleLongPressForFavorite(gestureRecognizer: UILongPressGestureRecognizer) {
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

    
    @objc private func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }
    
    private func setupSortButton() {
            let sortButton = UIBarButtonItem(image: UIImage(named: "sort"), style: .plain, target: self, action: #selector(sortButtonTapped))
            navigationItem.rightBarButtonItem = sortButton
        }
        
        @objc private func sortButtonTapped() {
            let alertController = UIAlertController(title: "Sort Threads", message: nil, preferredStyle: .actionSheet)
            
            let replyCountAction = UIAlertAction(title: "Reply Count", style: .default) { _ in
                self.sortThreads(by: .replyCount)
            }
            let newestCreationAction = UIAlertAction(title: "Newest Creation", style: .default) { _ in
                self.sortThreads(by: .newestCreation)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alertController.addAction(replyCountAction)
            alertController.addAction(newestCreationAction)
            alertController.addAction(cancelAction)
            
            present(alertController, animated: true, completion: nil)
        }
        
        private enum SortOption {
            case replyCount
            case newestCreation
        }
        
        private func sortThreads(by option: SortOption) {
            switch option {
            case .replyCount:
                filteredThreadData.sort { $0.replies > $1.replies }
            case .newestCreation:
                filteredThreadData.sort { $0.createdAt > $1.createdAt }
            }
            tableView.reloadData()
        }
    
    @objc private func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
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
        
    private func setupTableView() {
            tableView.backgroundColor = .systemBackground
            tableView.separatorStyle = .none
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 172
            tableView.prefetchDataSource = self
        }
    
    private func setupLoadingIndicator() {
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(loadingIndicator)
            
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
        
        private func setupImageCache() {
            imageCache.countLimit = 200 // Increased for multiple pages
            prefetchQueue.maxConcurrentOperationCount = 2
        }
        
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.returnKeyType = .done  // Set return key type to Done
        navigationItem.titleView = searchBar
    }
            
    private func loadThreads() {
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
    
    // MARK: - TableView DataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return filteredThreadData.count
        }
        
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "boardTVCell", for: indexPath) as! boardTVCell
        let thread = filteredThreadData[indexPath.row]
        //print("boardTV - cellForRowAt")
        //print(thread)
        
        // Configure stats under the topicImage
        if isHistoryView {
            cell.topicStats.isHidden = true // Hide topicStats if it is the history view
        } else {
            cell.topicStats.isHidden = false
            cell.topicStats.text = thread.stats
        }

        if isFavoritesView {
            if let currentReplies = thread.currentReplies,
               currentReplies > thread.replies {
                cell.topicCell?.image = UIImage(named: "topicCellNewData")
            } else {
                cell.topicCell?.image = UIImage(named: "topicCell")
            }
        }

        // Set up other cell components (text, image, etc.)
        let formattedComment = formatText(thread.comment)
        let formattedTitle = thread.title

        if formattedTitle.isEmpty || formattedTitle == "null" {
            cell.topicTextTitle.isHidden = true
            cell.topicTextNoTitle.isHidden = false
            cell.topicTitle.isHidden = true
            cell.topicTextNoTitle.attributedText = formattedComment
        } else {
            cell.topicTextTitle.isHidden = false
            cell.topicTextNoTitle.isHidden = true
            cell.topicTitle.isHidden = false
            cell.topicTextTitle.attributedText = formattedComment
            cell.topicTitle.text = formattedTitle // Use plain text
        }

        configureImage(for: cell, with: thread.imageUrl)

        return cell
    }

    private func extractFirstNumber(from stats: String) -> Int? {
        // Split stats by the slash ("/") and return the first part as an integer
        let components = stats.split(separator: "/")
        guard let firstComponent = components.first, let number = Int(firstComponent) else {
            return nil
        }
        return number
    }
    
    private func configureImage(for cell: boardTVCell, with urlString: String) {
            if urlString.isEmpty {
                cell.topicImage.image = UIImage(named: "loadingBoardImage")
                return
            }
            
            let finalUrl: String
            if urlString.hasSuffix(".webm") {
                let components = urlString.components(separatedBy: "/")
                if let last = components.last {
                    let base = last.replacingOccurrences(of: ".webm", with: "")
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thread = filteredThreadData[indexPath.row]
        let url = "https://a.4cdn.org/\(thread.boardAbv)/thread/\(thread.number).json"

        // Add the selected thread to history
        if !isHistoryView && !isFavoritesView {
            HistoryManager.shared.addThreadToHistory(thread)
        }
        if isFavoritesView {
                var updatedThread = thread
                updatedThread.replies = thread.currentReplies ?? thread.replies
                FavoritesManager.shared.updateFavorite(thread: updatedThread)
        }

        // Display loading view
        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = .systemBackground
        loadingView.tag = 999
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
        navigationController?.view.addSubview(loadingView)
        indicator.startAnimating()

        // Attempt to load the thread data
        AF.request(url).response { response in
            // Remove loading view
            loadingView.removeFromSuperview()

            // Check for an error or empty data
            if let error = response.error {
                print("Error loading thread: \(error)")
                self.handleThreadUnavailable(at: indexPath, thread: thread)
                return
            }

            guard let data = response.data, let json = try? JSON(data: data), !json["posts"].isEmpty else {
                print("Thread not available or invalid response.")
                self.handleThreadUnavailable(at: indexPath, thread: thread)
                return
            }

            // Proceed with thread data
            guard let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "threadRepliesTV") as? threadRepliesTV else {
                return
            }

            vc.boardAbv = thread.boardAbv
            vc.threadNumber = thread.number
            vc.totalImagesInThread = thread.stats.components(separatedBy: "/").last.flatMap { Int($0) } ?? 0 // Extract image count from stats
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func handleThreadUnavailable(at indexPath: IndexPath, thread: ThreadData) {
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
        guard !isFavoritesView && !isHistoryView else { return } // Only refresh in default view
        threadData.removeAll()
        filteredThreadData.removeAll()
        tableView.reloadData()
        loadThreads() // Re-fetch threads
    }

    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredThreadData = threadData
        } else {
            isSearching = true
            filteredThreadData = threadData.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.comment.localizedCaseInsensitiveContains(searchText)
            }
        }
        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        isSearching = false
        filteredThreadData = threadData
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()  // Dismiss the keyboard when Done is pressed
    }
    // MARK: - Helper Methods
    private func formatText(_ text: String) -> NSAttributedString {
        var formattedText = text
        
        // First handle all replacements except spoiler tags
        let replacements = [
            "<br>": "\n",
            "&#039;": "'",
            "&gt;": ">",
            "&quot;": "\"",
            "<wbr>": "",
            "&amp;": "&",
            "<a[^>]+>": "",
            "</a>": "",
            "<span[^>]+>": "",
            "</span>": ""
        ]
        
        for (key, value) in replacements {
            if key.contains("[^>]+") {
                if let regex = try? NSRegularExpression(pattern: key, options: []) {
                    formattedText = regex.stringByReplacingMatches(
                        in: formattedText,
                        options: [],
                        range: NSRange(location: 0, length: formattedText.count),
                        withTemplate: value
                    )
                }
            } else {
                formattedText = formattedText.replacingOccurrences(of: key, with: value)
            }
        }
        
        let attributedString = NSMutableAttributedString(string: "")
        
        // Split by spoiler tags and process each part
        let components = formattedText.components(separatedBy: "<s>")
        
        // Default text attributes with 14pt font
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        // Greentext attributes with 14pt font
        let greentextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
        ]
        
        // Spoiler attributes with 14pt font
        let spoilerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black,
            .backgroundColor: UIColor.black
        ]
        
        for (index, component) in components.enumerated() {
            if index == 0 {
                // First component is never a spoiler
                let normalText = component.replacingOccurrences(of: "</s>", with: "")
                // Process greentext for non-spoiler text
                let lines = normalText.components(separatedBy: "\n")
                for line in lines {
                    if line.hasPrefix(">") {
                        attributedString.append(NSAttributedString(string: line + "\n", attributes: greentextAttributes))
                    } else {
                        attributedString.append(NSAttributedString(string: line + "\n", attributes: defaultAttributes))
                    }
                }
            } else {
                // For subsequent components, split by closing spoiler tag
                let spoilerParts = component.components(separatedBy: "</s>")
                if spoilerParts.count > 0 {
                    // Spoiler text
                    if let spoilerText = spoilerParts.first {
                        // Process greentext within spoiler
                        let lines = spoilerText.components(separatedBy: "\n")
                        for line in lines {
                            attributedString.append(NSAttributedString(string: line + "\n", attributes: spoilerAttributes))
                        }
                    }
                    
                    // Non-spoiler text (after closing tag)
                    if spoilerParts.count > 1 {
                        let normalText = spoilerParts[1]
                        // Process greentext for text after spoiler
                        let lines = normalText.components(separatedBy: "\n")
                        for line in lines {
                            if line.hasPrefix(">") {
                                attributedString.append(NSAttributedString(string: line + "\n", attributes: greentextAttributes))
                            } else {
                                attributedString.append(NSAttributedString(string: line + "\n", attributes: defaultAttributes))
                            }
                        }
                    }
                }
            }
        }
        
        // Remove any extra newlines that might have been added
        let finalString = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAttributedString = NSMutableAttributedString(string: finalString)
        
        // Copy attributes from the original string, ensuring font size is preserved
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { (attrs, range, _) in
            let intersectingRange = NSIntersectionRange(range, NSRange(location: 0, length: finalString.count))
            if intersectingRange.length > 0 {
                var newAttributes = attrs
                // Ensure font size is 14pt
                if attrs[.font] is UIFont {
                    newAttributes[.font] = UIFont.systemFont(ofSize: 14)
                }
                for (key, value) in newAttributes {
                    finalAttributedString.addAttribute(key, value: value, range: intersectingRange)
                }
            }
        }
        
        return finalAttributedString
    }
            
}

// MARK: - UITableViewDataSourcePrefetching
extension boardTV: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let limitedPaths = Array(indexPaths.prefix(5))
        
        let urls = limitedPaths.compactMap { indexPath -> URL? in
            guard indexPath.row < threadData.count else { return nil }
            let imageUrl = threadData[indexPath.row].imageUrl
            if imageUrl.hasSuffix(".webm") {
                let components = imageUrl.components(separatedBy: "/")
                if let last = components.last {
                    let base = last.replacingOccurrences(of: ".webm", with: "")
                    return URL(string: imageUrl.replacingOccurrences(of: last, with: "\(base)s.jpg"))
                }
            }
            return URL(string: imageUrl)
        }
        
        ImagePrefetcher(urls: urls, options: [.backgroundDecode]).start()
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // Cancel any ongoing prefetch operations
    }
}
