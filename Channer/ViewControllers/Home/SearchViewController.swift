import UIKit
import Alamofire
import SwiftyJSON

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
        // TODO: Implement board selection
        // For now, just toggle between all boards and a specific board
        if let currentBoard = currentBoard {
            self.currentBoard = nil
            navigationItem.rightBarButtonItem?.title = "All Boards"
        } else {
            // Show board selection dialog
            showBoardSelectionDialog()
        }
    }
    
    private func showBoardSelectionDialog() {
        let alert = UIAlertController(title: "Select Board", message: nil, preferredStyle: .actionSheet)
        
        // Get board list from home view controller
        let boardsAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]
        
        // Sort boards alphabetically
        let sortedBoards = boardsAbv.sorted()
        
        // Add most popular boards at the top
        let popularBoards = ["b", "pol", "v", "g", "a", "tv", "sp", "int"]
        
        // Add separator
        alert.addAction(UIAlertAction(title: "Popular Boards", style: .default, handler: nil))
        alert.actions.last?.isEnabled = false
        
        for board in popularBoards {
            alert.addAction(UIAlertAction(title: "/\(board)/", style: .default) { _ in
                self.currentBoard = board
                self.navigationItem.rightBarButtonItem?.title = "/\(board)/"
            })
        }
        
        // Add separator 
        alert.addAction(UIAlertAction(title: "All Boards", style: .default, handler: nil))
        alert.actions.last?.isEnabled = false
        
        alert.addAction(UIAlertAction(title: "All Boards", style: .default) { _ in
            self.currentBoard = nil
            self.navigationItem.rightBarButtonItem?.title = "All Boards"
        })
        
        // Add all sorted boards
        alert.addAction(UIAlertAction(title: "Alphabetical", style: .default, handler: nil))
        alert.actions.last?.isEnabled = false
        
        for board in sortedBoards {
            alert.addAction(UIAlertAction(title: "/\(board)/", style: .default) { _ in
                self.currentBoard = board
                self.navigationItem.rightBarButtonItem?.title = "/\(board)/"
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
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
        let boards = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]
        
        var allResults: [ThreadData] = []
        let searchGroup = DispatchGroup()
        
        for board in boards {
            searchGroup.enter()
            SearchManager.shared.performSearch(query: query, boardAbv: board) { results in
                DispatchQueue.main.async {
                    allResults.append(contentsOf: results)
                    searchGroup.leave()
                }
            }
        }
        
        searchGroup.notify(queue: .main) { [weak self] in
            self?.loadingIndicator.stopAnimating()
            self?.searchResults = allResults.sorted { $0.replies > $1.replies } // Sort by popularity
            self?.isSearching = false
            
            if allResults.isEmpty {
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
        cell.textLabel?.numberOfLines = 0 // Allow multiline text
        cell.detailTextLabel?.textColor = .systemGray
        
        let result = searchResults[indexPath.row]
        cell.textLabel?.text = result.title.isEmpty ? "Thread #\(result.number)" : result.title
        cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
        
        // Show stats and first bit of content
        let preview = result.comment
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
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