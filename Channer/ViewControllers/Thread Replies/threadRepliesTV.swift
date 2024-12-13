import UIKit
import Alamofire
import Kingfisher
import SwiftyJSON

// MARK: - Thread Replies Table View Controller
class threadRepliesTV: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {
    
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
    
    // MARK: - Loading Indicator
    /// UI components for displaying a loading indicator
    private lazy var loadingContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .systemBackground
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
    var totalImagesInThread: Int = 0
    
    // Storage for thread view
    private var threadRepliesOld = [NSAttributedString]()
    private var threadBoardReplyNumberOld = [String]()
    private var threadRepliesImagesOld = [String]()
    
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
        
        setupLoadingIndicator()
        setupNavigationItems()
        checkIfFavorited()
        loadInitialData()

        
        // Table constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // table above input bar
        ])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        /// Marks the thread as seen in the favorites list when the view disappears, ensuring the reply count is updated.
        /// - Uses `threadNumber` to identify the thread and calls `markThreadAsSeen` in `FavoritesManager`.
        /// This ensures that the thread is no longer highlighted as having new replies in the favorites view.
        if !threadNumber.isEmpty { // Use threadNumber instead of threadID
            FavoritesManager.shared.markThreadAsSeen(threadID: threadNumber)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = false
        
        // Ensure navigation bar is properly configured
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.backgroundColor = .systemBackground
        
        // Ensure view is visible
        view.isHidden = false
        tableView.isHidden = false
        
    }
    
    // MARK: - UI Setup Methods
    /// Methods to set up the UI components and appearance
    private func setupTableView() {
        // Clear background
        view.backgroundColor = .white
        tableView.backgroundColor = .white
        
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
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
        
        // Configure table view properties
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 172
    }
    
    private func setupUI() {
        // Configure view and table view
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
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
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
        
        // Configure navigation bar
        navigationController?.navigationBar.backgroundColor = .systemBackground
        navigationController?.view.backgroundColor = .systemBackground
        
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
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
        
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
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
        
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
    
    // MARK: - Navigation Item Setup Methods
    /// Methods to configure navigation bar items and actions
    private func setupNavigationItems() {
        // Create the Favorites button
        favoriteButton = UIBarButtonItem(image: UIImage(named: isThreadFavorited ? "favoriteFilled" : "favorite"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(toggleFavorite))
        
        // Create the Gallery button
        let galleryButton = UIBarButtonItem(image: UIImage(named: "gallery"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(showGallery))
        
        // Create the More button
        let moreButton = UIBarButtonItem(image: UIImage(named: "more"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(showActionSheet))
        
        // Set the buttons in the navigation bar
        navigationItem.rightBarButtonItems = [moreButton, galleryButton, favoriteButton!]
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
            if imageUrlString.contains(".webm") {
                return URL(string: imageUrlString.replacingOccurrences(of: ".webm", with: "s.jpg"))
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
        return isLoading ? 0 : threadReplies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //print("Configuring cell at index: \(indexPath.row)")
        //print("threadReplies count: \(threadReplies.count)")
        
        guard indexPath.row < threadReplies.count else {
            print("Index out of bounds: \(indexPath.row)")
            return UITableViewCell() // Placeholder to avoid crashing
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! threadRepliesCell
        
        // Set up the reply button's target-action
        //cell.reply.tag = indexPath.row
        //cell.reply.addTarget(self, action: #selector(replyButtonTapped(_:)), for: .touchUpInside)
        
        // Set the text view delegate to self
        cell.replyTextDelegate = self
        
        // Debug: Start of cell configuration
        //print("Debug: Configuring cell at row \(indexPath.row)")
        
        if threadReplies.isEmpty {
            //print("Debug: No replies available, showing loading text")
            cell.configure(withImage: false,
                           text: NSAttributedString(string: "Loading..."),
                           boardNumber: "")
        } else {
            let imageUrl = threadRepliesImages[indexPath.row]
            let hasImage = imageUrl != "https://i.4cdn.org/\(boardAbv)/"
            let attributedText = threadReplies[indexPath.row]
            let boardNumber = threadBoardReplyNumber[indexPath.row]
            
            // Debug: Content of the reply
            //print("Debug: Configuring cell with image: \(hasImage), text: \(attributedText.string), boardNumber: \(boardNumber)")
            
            // Configure the cell with text and other details
            cell.configure(withImage: hasImage,
                           text: attributedText,
                           boardNumber: boardNumber)
            
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
                cell.threadImage.tag = indexPath.row
                cell.threadImage.addTarget(self, action: #selector(threadContentOpen), for: .touchUpInside)
            }
            
            // Configure reply button visibility
            if let replies = threadBoardReplies[boardNumber], !replies.isEmpty {
                //print("Debug: Found \(replies.count) replies for boardNumber \(boardNumber), showing thread button")
                cell.thread.isHidden = false
                cell.thread.tag = indexPath.row
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
        
        // Perform network request
        AF.request(urlString).responseData { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch response.result {
                case .success(let data):
                    do {
                        // Parse JSON response
                        let json = try JSON(data: data)
                        //print(json)
                        self.processThreadData(json)
                        self.structureThreadReplies()
                        self.isLoading = false
                        //print("Data loaded successfully. Thread count: \(self.threadReplies.count)") // Debug print
                        //print(self.threadReplies)
                        
                        
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
        }
    }
    
    private func loadData() {
        guard !threadNumber.isEmpty else {
            isLoading = false
            return
        }
        
        let urlString = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        
        AF.request(urlString).responseData { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        //print("threadRepliesTV - JSON")
                        //print(json)
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
    
    private func processThreadData(_ json: JSON) {
        // Get reply count
        replyCount = Int(json["posts"][0]["replies"].stringValue) ?? 0
        
        // Handle case with no replies
        if replyCount == 0 {
            processPost(json["posts"][0], index: 0)
            replyCount = 1
            structureThreadReplies()
            return
        }
        
        // Process all posts in the thread
        let posts = json["posts"].arrayValue
        for post in posts {
            processPost(post, index: posts.firstIndex(of: post) ?? 0)
        }
        
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
        } else {
            print("Adding favorite for thread: \(threadNumber)")
            let favorite = createThreadDataForFavorite()
            FavoritesManager.shared.addFavorite(favorite)
        }
        
        updateFavoriteButton()
        print("Favorite button updated.")
    }
    
    private func createThreadDataForFavorite() -> ThreadData {
        return ThreadData(
            number: threadNumber,
            stats: "\(replyCount)/\(totalImagesInThread)",
            title: title ?? "",
            comment: threadReplies.first?.string ?? "",
            imageUrl: threadRepliesImages.first ?? "",
            boardAbv: boardAbv,
            replies: replyCount,
            createdAt: "" // Populate if necessary
        )
    }
    
    private func updateFavoriteButton() {
        let isFavorited = FavoritesManager.shared.isFavorited(threadNumber: threadNumber)
        favoriteButton?.image = UIImage(named: isFavorited ? "favoriteFilled" : "favorite")
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
                        .foregroundColor: UIColor.black,
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
                    .foregroundColor: UIColor.black,
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
                    .foregroundColor: UIColor.black
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
        if imageUrl.contains(".webm") {
            finalUrl = imageUrl.replacingOccurrences(of: ".webm", with: "s.jpg")
        } else {
            finalUrl = imageUrl
        }
        
        guard let url = URL(string: finalUrl) else {
            print("Debug: Invalid URL: \(finalUrl)")
            cell.threadImage.setBackgroundImage(UIImage(named: "loadingBoardImage"), for: .normal)
            return
        }
        
        KingfisherManager.shared.retrieveImage(with: url) { result in
            switch result {
            case .success(let value):
                //print("Debug: Successfully loaded image for URL: \(url), size: \(value.image.size)")
                cell.threadImage.setBackgroundImage(value.image, for: .normal)
            case .failure(let error):
                //print("Debug: Failed to load image for URL: \(url), error: \(error)")
                cell.threadImage.setBackgroundImage(UIImage(named: "loadingBoardImage"), for: .normal)
            }
            
            // Recalculate layout after image loads
            DispatchQueue.main.async {
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
            }
        }
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
    @objc func refresh() {
        print("Refresh triggered")
        threadReplies.removeAll()
        threadBoardReplyNumber.removeAll()
        threadRepliesImages.removeAll()
        threadBoardReplies.removeAll()
        replyCount = 0
        loadInitialData()
    }
    
    @objc private func down() {
        let lastRow = tableView.numberOfRows(inSection: 0) - 1
        let indexPath = IndexPath(row: lastRow, section: 0)
        tableView.scrollToRow(at: indexPath, at: .top, animated: false)
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
                        .foregroundColor: UIColor.black
                    ]
                    result.append(NSAttributedString(string: displayText, attributes: normalAttributes))
                }
            } else if trimmed.hasPrefix(">") && !trimmed.hasPrefix(">>") {
                // Greentext (should have a green color)
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(red: 120/255, green: 153/255, blue: 34/255, alpha: 1.0)
                ]
                let displayText = line + "\n" // Add newline explicitly
                result.append(NSAttributedString(string: displayText, attributes: attributes))
            } else {
                // Normal text
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.black
                ]
                let displayText = line + "\n" // Add newline explicitly
                result.append(NSAttributedString(string: displayText, attributes: attributes))
            }
        }
        
        return result
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
