import UIKit
import Alamofire
import SwiftyJSON

/// View controller for searching threads across boards
/// Provides thread search functionality with board filtering and result display
class SearchViewController: UIViewController {
    
    // MARK: - Properties
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    private var searchResults: [ThreadData] = []
    
    private var currentBoard: String?
    private var isSearching = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Configure navigation bar appearance to match theme
        // This prevents color flash when navigating to/from this view
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ThemeManager.shared.backgroundColor
        appearance.titleTextAttributes = [.foregroundColor: ThemeManager.shared.primaryTextColor]

        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.navigationController?.navigationBar.standardAppearance = appearance
                self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
                self.navigationController?.navigationBar.compactAppearance = appearance
            }, completion: nil)
        } else {
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance = appearance
        }

        // Focus on search immediately
        searchController.searchBar.becomeFirstResponder()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Search"
        view.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Setup search controller
        searchController.searchResultsUpdater = nil  // Disable live search
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "Search threads..."
        searchController.searchBar.barTintColor = ThemeManager.shared.backgroundColor
        searchController.searchBar.tintColor = ThemeManager.shared.primaryTextColor
        searchController.searchBar.returnKeyType = .search
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = ThemeManager.shared.primaryTextColor
        
        // Setup empty state label
        let emptyLabel = UILabel()
        emptyLabel.text = "Enter search terms and press Search"
        emptyLabel.textColor = ThemeManager.shared.secondaryTextColor
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.numberOfLines = 0
        tableView.backgroundView = emptyLabel
        
        // Add to view
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add right bar button for board selection
        let boardButton = UIBarButtonItem(title: "All Boards", style: .plain, target: self, action: #selector(selectBoard))
        navigationItem.rightBarButtonItem = boardButton
    }
    
    // MARK: - Actions
    
    @objc private func selectBoard() {
        // Show board selection dialog
        showBoardSelectionDialog()
    }
    
    private func showBoardSelectionDialog() {
        let alert = UIAlertController(title: "Select Board", message: nil, preferredStyle: .actionSheet)
        
        // Load cached boards and refresh later when latest arrives
        let names = BoardsService.shared.boardNames
        let abvs = BoardsService.shared.boardAbv
        let combined = zip(names, abvs).map { ($0, $1) }.sorted { $0.0 < $1.0 }
        
        alert.addAction(UIAlertAction(title: "All Boards", style: .default) { _ in
            self.currentBoard = nil
            self.navigationItem.rightBarButtonItem?.title = "All Boards"
        })
        alert.actions.last?.isEnabled = true
        
        for (title, code) in combined {
            alert.addAction(UIAlertAction(title: "\(title) (/\(code)/)", style: .default) { _ in
                self.currentBoard = code
                self.navigationItem.rightBarButtonItem?.title = "/\(code)/"
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
        
        // Fetch latest boards and rebuild the sheet next time
        BoardsService.shared.fetchBoards()
    }
    
    // MARK: - Search Implementation
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = "Enter search terms and press Search"
            emptyLabel.textColor = ThemeManager.shared.secondaryTextColor
            emptyLabel.textAlignment = .center
            emptyLabel.font = .systemFont(ofSize: 16)
            tableView.backgroundView = emptyLabel
            searchResults = []
            tableView.reloadData()
            return
        }
        
        // Show loading indicator
        tableView.backgroundView = nil
        loadingIndicator.startAnimating()
        isSearching = true
        searchResults = []
        tableView.reloadData()
        
        if currentBoard == nil {
            // Search all boards
            searchAllBoards(query: query)
        } else {
            // Search specific board
            SearchManager.shared.performSearch(query: query, boardAbv: currentBoard) { [weak self] results in
                DispatchQueue.main.async {
                    self?.loadingIndicator.stopAnimating()
                    self?.searchResults = results
                    self?.isSearching = false
                    
                    if results.isEmpty {
                        let emptyLabel = UILabel()
                        emptyLabel.text = "No results found"
                        emptyLabel.textColor = ThemeManager.shared.secondaryTextColor
                        emptyLabel.textAlignment = .center
                        emptyLabel.font = .systemFont(ofSize: 16)
                        self?.tableView.backgroundView = emptyLabel
                    } else {
                        self?.tableView.backgroundView = nil
                    }
                    
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    private func searchAllBoards(query: String) {
        let boards = BoardsService.shared.boardAbv

        // Handle case where boards haven't loaded yet
        guard !boards.isEmpty else {
            loadingIndicator.stopAnimating()
            isSearching = false
            let emptyLabel = UILabel()
            emptyLabel.text = "Loading boards... Please try again."
            emptyLabel.textColor = ThemeManager.shared.secondaryTextColor
            emptyLabel.textAlignment = .center
            emptyLabel.font = .systemFont(ofSize: 16)
            tableView.backgroundView = emptyLabel
            // Trigger boards fetch for next attempt
            BoardsService.shared.fetchBoards()
            return
        }

        // Use a thread-safe approach with a serial queue for collecting results
        let resultsQueue = DispatchQueue(label: "com.channer.searchResults")
        var allResults: [ThreadData] = []
        let searchGroup = DispatchGroup()

        // Add to search history once for the all-boards search
        SearchManager.shared.addToHistory(query, boardAbv: nil)

        for board in boards {
            searchGroup.enter()
            SearchManager.shared.searchBoard(board: board, query: query) { results in
                resultsQueue.async {
                    allResults.append(contentsOf: results)
                    searchGroup.leave()
                }
            }
        }

        searchGroup.notify(queue: .main) { [weak self] in
            // Read results safely
            let finalResults = resultsQueue.sync { allResults }

            self?.loadingIndicator.stopAnimating()
            self?.searchResults = finalResults.sorted { $0.replies > $1.replies } // Sort by popularity
            self?.isSearching = false

            if finalResults.isEmpty {
                let emptyLabel = UILabel()
                emptyLabel.text = "No results found"
                emptyLabel.textColor = ThemeManager.shared.secondaryTextColor
                emptyLabel.textAlignment = .center
                emptyLabel.font = .systemFont(ofSize: 16)
                self?.tableView.backgroundView = emptyLabel
            } else {
                self?.tableView.backgroundView = nil
            }

            self?.tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SearchCell")
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0 // Allow multiline text
        cell.detailTextLabel?.textColor = .systemGray
        
        let result = searchResults[indexPath.row]
        cell.textLabel?.text = result.title.isEmpty ? "Thread #\(result.number)" : result.title
        cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        
        // Show stats and first bit of content - strip HTML tags and decode entities
        let preview = result.comment
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortPreview = String(preview.prefix(100))
        
        cell.detailTextLabel?.text = "/\(result.boardAbv)/ • \(result.stats) • \(shortPreview)..."
        
        cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle search result selection
        let result = searchResults[indexPath.row]
        
        // Navigate to the thread
        let threadRepliesVC = threadRepliesTV()
        threadRepliesVC.boardAbv = result.boardAbv
        threadRepliesVC.threadNumber = result.number
        threadRepliesVC.title = result.title.isEmpty ? "Thread #\(result.number)" : result.title
        navigationController?.pushViewController(threadRepliesVC, animated: true)
    }
    
}


// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }
        searchBar.resignFirstResponder() // Dismiss keyboard
        performSearch(query: query)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchResults = []
        tableView.reloadData()
        let emptyLabel = UILabel()
        emptyLabel.text = "Enter search terms and press Search"
        emptyLabel.textColor = ThemeManager.shared.secondaryTextColor
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 16)
        tableView.backgroundView = emptyLabel
    }
}
