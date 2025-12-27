import UIKit

/// View controller for managing hidden boards
/// Allows users to select which boards should be hidden from the Home Screen
class HiddenBoardsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    // MARK: - Properties
    private var boardNames: [String] = []
    private var boardCodes: [String] = []
    private var filteredBoardNames: [String] = []
    private var filteredBoardCodes: [String] = []
    private var isSearching = false

    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let headerLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Hidden Boards"
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // Load boards from BoardsService
        boardNames = BoardsService.shared.boardNames
        boardCodes = BoardsService.shared.boardAbv
        sortBoardsAlphabetically()

        // Initialize filtered arrays
        filteredBoardNames = boardNames
        filteredBoardCodes = boardCodes

        setupNavigationBar()
        setupHeader()
        setupSearchBar()
        setupTableView()

        // Fetch latest boards
        BoardsService.shared.fetchBoards { [weak self] in
            guard let self = self else { return }
            self.boardNames = BoardsService.shared.boardNames
            self.boardCodes = BoardsService.shared.boardAbv
            self.sortBoardsAlphabetically()
            self.filteredBoardNames = self.boardNames
            self.filteredBoardCodes = self.boardCodes
            self.tableView.reloadData()
            self.updateHeader()
        }

        // Register for hidden boards changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hiddenBoardsChanged),
            name: HiddenBoardsManager.hiddenBoardsChangedNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup
    private func setupNavigationBar() {
        // Add "Show All" button to unhide all boards
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Show All",
            style: .plain,
            target: self,
            action: #selector(showAllTapped)
        )
    }

    private func setupHeader() {
        headerLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        headerLabel.textColor = .secondaryLabel
        headerLabel.textAlignment = .center
        headerLabel.numberOfLines = 0
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        updateHeader()

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func setupSearchBar() {
        searchBar.placeholder = "Search boards..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BoardCell")
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateHeader() {
        let hiddenCount = HiddenBoardsManager.shared.hiddenBoardsCount
        if hiddenCount == 0 {
            headerLabel.text = "Tap a board to hide it from the Home Screen"
        } else {
            headerLabel.text = "\(hiddenCount) board\(hiddenCount == 1 ? "" : "s") hidden. Tap to toggle visibility."
        }
    }

    private func sortBoardsAlphabetically() {
        let combinedBoards = zip(boardNames, boardCodes).map { ($0, $1) }
        let sortedBoards = combinedBoards.sorted { $0.0 < $1.0 }
        boardNames = sortedBoards.map { $0.0 }
        boardCodes = sortedBoards.map { $0.1 }
    }

    // MARK: - Actions
    @objc private func showAllTapped() {
        let hiddenCount = HiddenBoardsManager.shared.hiddenBoardsCount

        if hiddenCount == 0 {
            let alert = UIAlertController(
                title: "No Hidden Boards",
                message: "There are no hidden boards to show.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(
            title: "Show All Boards",
            message: "This will unhide all \(hiddenCount) hidden board\(hiddenCount == 1 ? "" : "s"). Are you sure?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Show All", style: .default) { [weak self] _ in
            HiddenBoardsManager.shared.showAllBoards()
            self?.tableView.reloadData()
            self?.updateHeader()

            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        })

        present(alert, animated: true)
    }

    @objc private func hiddenBoardsChanged() {
        tableView.reloadData()
        updateHeader()
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredBoardNames.count : boardNames.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BoardCell", for: indexPath)

        let names = isSearching ? filteredBoardNames : boardNames
        let codes = isSearching ? filteredBoardCodes : boardCodes

        guard indexPath.row < names.count && indexPath.row < codes.count else {
            return cell
        }

        let boardName = names[indexPath.row]
        let boardCode = codes[indexPath.row]
        let isHidden = HiddenBoardsManager.shared.isBoardHidden(boardCode)

        var content = cell.defaultContentConfiguration()
        content.text = "\(boardName)"
        content.secondaryText = "/\(boardCode)/"
        content.secondaryTextProperties.color = .secondaryLabel

        // Style based on hidden state
        if isHidden {
            content.textProperties.color = .secondaryLabel
            content.image = UIImage(systemName: "eye.slash")
            content.imageProperties.tintColor = .systemRed
        } else {
            content.textProperties.color = .label
            content.image = UIImage(systemName: "eye")
            content.imageProperties.tintColor = .systemGreen
        }

        cell.contentConfiguration = content
        cell.backgroundColor = ThemeManager.shared.backgroundColor
        cell.selectionStyle = .default

        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let codes = isSearching ? filteredBoardCodes : boardCodes
        guard indexPath.row < codes.count else { return }

        let boardCode = codes[indexPath.row]
        HiddenBoardsManager.shared.toggleBoard(boardCode)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Reload the specific row with animation
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateHeader()
    }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredBoardNames = boardNames
            filteredBoardCodes = boardCodes
        } else {
            isSearching = true
            let searchTextLowercased = searchText.lowercased()

            // Filter by both board name and code
            let filteredIndices = boardNames.indices.filter { index in
                boardNames[index].lowercased().contains(searchTextLowercased) ||
                boardCodes[index].lowercased().contains(searchTextLowercased)
            }

            filteredBoardNames = filteredIndices.map { boardNames[$0] }
            filteredBoardCodes = filteredIndices.map { boardCodes[$0] }
        }

        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
