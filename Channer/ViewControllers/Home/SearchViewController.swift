import UIKit
import Alamofire
import SwiftyJSON

/// View controller for searching threads across boards
/// Provides thread search functionality with board filtering and result display
class SearchViewController: UIViewController {

    // MARK: - Properties
    private static let isMacCatalyst: Bool = {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }()

    private enum DisplayMode: Int {
        case results = 0
        case history = 1
        case saved = 2
    }

    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let segmentedControl = UISegmentedControl(items: ["Results", "History", "Saved"])
    private let emptyStateLabel = UILabel()

    private var searchResults: [ThreadData] = []
    private var searchHistory: [SearchManager.SearchItem] = []
    private var savedSearches: [SearchManager.SavedSearch] = []
    private var displayMode: DisplayMode = .results
    private var activeFilters = SearchFilters()

    private var currentBoard: String?
    private var isSearching = false
    private var activeSearchToken = UUID()
    private var isLoadingBoards = false
    private var didCancelBoardLoading = false
    private var boardButton: UIBarButtonItem!
    private var filtersButton: UIBarButtonItem!
    private var saveButton: UIBarButtonItem!
    private var lastNavBarDebugWidth: CGFloat = 0
    private var didLogNavBarHierarchy = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadHistoryAndSaved()
        updateEmptyState()
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

        // Focus on search immediately (skip on Mac Catalyst to avoid transition clashes)
        if !Self.isMacCatalyst {
            searchController.searchBar.becomeFirstResponder()
        }

        reloadHistoryAndSaved()
        updateEmptyState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.navigationController?.navigationBar.layoutIfNeeded()
            self.debugLogNavBarLayout(context: "viewDidAppear")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeaderLayout()
        debugLogNavBarLayoutIfNeeded()
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

        // Setup progress UI
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.textAlignment = .center
        progressLabel.textColor = ThemeManager.shared.secondaryTextColor
        progressLabel.font = .systemFont(ofSize: 14)
        progressLabel.numberOfLines = 2
        progressLabel.isHidden = true

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = ThemeManager.shared.cellBackgroundColor
        progressView.progressTintColor = ThemeManager.shared.primaryTextColor
        progressView.isHidden = true

        // Setup segmented control
        segmentedControl.selectedSegmentIndex = DisplayMode.results.rawValue
        segmentedControl.addTarget(self, action: #selector(displayModeChanged), for: .valueChanged)

        // Setup empty state label
        emptyStateLabel.textColor = ThemeManager.shared.secondaryTextColor
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.font = .systemFont(ofSize: 16)
        emptyStateLabel.numberOfLines = 0
        tableView.backgroundView = emptyStateLabel

        // Add to view
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        view.addSubview(progressLabel)
        view.addSubview(progressView)

        // Setup constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            progressLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
            progressLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            progressLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        // Add navigation items
        boardButton = UIBarButtonItem(title: "All Boards", style: .plain, target: self, action: #selector(selectBoard))
        saveButton = makeSaveButton()
        filtersButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), style: .plain, target: self, action: #selector(openFilters))
        boardButton.tag = 1000
        saveButton.tag = 1001
        filtersButton.tag = 1002
        navigationItem.rightBarButtonItems = [boardButton, saveButton, filtersButton]
        updateSaveButtonAvailability()
        updateFiltersButtonState()
        debugLogBarButtonSetup()

        configureTableHeader()
    }

    private func makeSaveButton() -> UIBarButtonItem {
        let preferredImage = UIImage(systemName: "bookmark.badge.plus")
            ?? UIImage(systemName: "bookmark")
        if let image = preferredImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(saveSearch))
        }
        return UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveSearch))
    }

    // MARK: - Actions

    @objc private func selectBoard() {
        // Show board selection dialog
        showBoardSelectionDialog()
    }

    private func showBoardSelectionDialog() {
        prepareForModalPresentation { [weak self] in
            self?.showBoardSelectionDialogInternal()
        }
    }

    private func showBoardSelectionDialogInternal() {
        if BoardsService.shared.boardAbv.isEmpty {
            guard !isLoadingBoards else { return }
            isLoadingBoards = true
            didCancelBoardLoading = false
            let loadingAlert = makeLoadingBoardsAlert()
            present(loadingAlert, animated: true)
            BoardsService.shared.fetchBoards { [weak self] in
                guard let self else { return }
                self.isLoadingBoards = false
                if self.didCancelBoardLoading {
                    self.didCancelBoardLoading = false
                    return
                }
                let hasBoards = !BoardsService.shared.boardAbv.isEmpty
                loadingAlert.dismiss(animated: true) {
                    if hasBoards {
                        self.showBoardSelectionDialog()
                    } else {
                        self.presentBoardsLoadFailedAlert()
                    }
                }
            }
            return
        }
        presentBoardPicker()
    }

    private func makeLoadingBoardsAlert() -> UIAlertController {
        let alert = UIAlertController(title: "Loading Boards", message: "\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.isLoadingBoards = false
            self?.didCancelBoardLoading = true
        })
        return alert
    }

    private func presentBoardsLoadFailedAlert() {
        let alert = UIAlertController(
            title: "Boards Unavailable",
            message: "Couldn't load boards. Check your connection and try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        prepareForModalPresentation { [weak self] in
            self?.present(alert, animated: true)
        }
    }

    private func presentBoardPicker() {
        let boards = BoardsService.shared.boards
        let picker = BoardPickerViewController(boards: boards, selectedBoard: currentBoard)
        picker.delegate = self
        let navController = UINavigationController(rootViewController: picker)
        let idiom = UIDevice.current.userInterfaceIdiom
        let usePopover: Bool
#if targetEnvironment(macCatalyst)
        usePopover = false
#else
        usePopover = (idiom == .pad)
#endif
        if usePopover {
            navController.modalPresentationStyle = .popover
            navController.preferredContentSize = CGSize(width: 360, height: 520)
            if let popover = navController.popoverPresentationController {
                popover.barButtonItem = boardButton
                popover.permittedArrowDirections = .any
            }
        } else {
            navController.modalPresentationStyle = .formSheet
            navController.preferredContentSize = CGSize(width: 360, height: 520)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            self.present(navController, animated: true)
        }
        BoardsService.shared.fetchBoards()
    }

    private func prepareForModalPresentation(_ completion: @escaping () -> Void) {
        view.endEditing(true)
        searchController.searchBar.resignFirstResponder()

        let wasSearchActive = searchController.isActive
        if wasSearchActive {
            searchController.isActive = false
            if let coordinator = searchController.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { _ in
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            } else {
                let delay: TimeInterval
#if targetEnvironment(macCatalyst)
                delay = 0.15
#else
                delay = UIDevice.current.userInterfaceIdiom == .mac ? 0.15 : 0
#endif
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    completion()
                }
            }
            return
        }

        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    @objc private func displayModeChanged() {
        guard let mode = DisplayMode(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        displayMode = mode
        reloadHistoryAndSaved()
        updateEmptyState()
    }

    @objc private func openFilters() {
        prepareForModalPresentation { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let filtersVC = SearchFiltersViewController(filters: self.activeFilters)
            filtersVC.delegate = self
            let navController = UINavigationController(rootViewController: filtersVC)
            self.present(navController, animated: true)
        }
    }

    @objc private func saveSearch() {
        guard let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            return
        }
        promptToSaveSearch(query: query, boardAbv: currentBoard)
    }

    private func configureTableHeader() {
        let headerHeight: CGFloat = 44
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: headerHeight))
        headerView.backgroundColor = ThemeManager.shared.backgroundColor

        if Self.isMacCatalyst {
            segmentedControl.apportionsSegmentWidthsByContent = true
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.setContentHuggingPriority(.required, for: .horizontal)
            segmentedControl.setContentCompressionResistancePriority(.required, for: .horizontal)
            headerView.addSubview(segmentedControl)
            NSLayoutConstraint.activate([
                segmentedControl.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
                segmentedControl.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                segmentedControl.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 16),
                segmentedControl.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -16)
            ])
        } else {
            segmentedControl.frame = headerView.bounds.insetBy(dx: 16, dy: 6)
            segmentedControl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            headerView.addSubview(segmentedControl)
        }

        tableView.tableHeaderView = headerView
    }

    private func updateTableHeaderLayout() {
        guard let headerView = tableView.tableHeaderView else { return }
        if headerView.frame.width != tableView.bounds.width {
            headerView.frame.size.width = tableView.bounds.width
            if !Self.isMacCatalyst {
                segmentedControl.frame = headerView.bounds.insetBy(dx: 16, dy: 6)
            }
            tableView.tableHeaderView = headerView
        }
    }

    private func debugLogNavBarLayoutIfNeeded() {
        guard let navBar = navigationController?.navigationBar else { return }
        let width = navBar.bounds.width
        guard width != lastNavBarDebugWidth else { return }
        lastNavBarDebugWidth = width
        debugLogNavBarLayout(context: "viewDidLayoutSubviews")
    }

    private func debugLogNavBarLayout(context: String) {
#if DEBUG
        guard let navBar = navigationController?.navigationBar else { return }
        let rightItems = navigationItem.rightBarButtonItems ?? []
        print("=== SearchViewController nav bar layout (\(context)) ===")
        print("Nav bar frame: \(navBar.frame) bounds: \(navBar.bounds)")
        if let searchBar = navigationItem.searchController?.searchBar {
            print("Search bar frame: \(searchBar.frame) bounds: \(searchBar.bounds) intrinsic: \(searchBar.intrinsicContentSize)")
        }
        print("Right items: \(rightItems.count)")
        for (index, item) in rightItems.enumerated() {
            let title = item.title ?? "<no title>"
            let imageName = item.image?.accessibilityIdentifier ?? item.image?.description ?? "<no image>"
            let width = item.width
            let customViewDesc = item.customView.map { "\($0)" } ?? "<none>"
            let matchesBoard = item === boardButton
            let matchesSave = item === saveButton
            let matchesFilters = item === filtersButton
            if let view = item.value(forKey: "view") as? UIView {
                let frame = view.frame
                let bounds = view.bounds
                let intrinsic = view.intrinsicContentSize
                print("Item \(index): title=\(title) width=\(width) tag=\(item.tag) board=\(matchesBoard) save=\(matchesSave) filters=\(matchesFilters) customView=\(customViewDesc)")
                print("Item \(index): view frame=\(frame) bounds=\(bounds) intrinsic=\(intrinsic) image=\(imageName)")
            } else {
                print("Item \(index): title=\(title) width=\(width) tag=\(item.tag) board=\(matchesBoard) save=\(matchesSave) filters=\(matchesFilters) customView=\(customViewDesc) view=<nil> image=\(imageName)")
            }
        }

        if !didLogNavBarHierarchy {
            didLogNavBarHierarchy = true
            print("--- Nav bar subview hierarchy (first 4 levels) ---")
            debugLogNavBarHierarchy(navBar, depth: 0, maxDepth: 4)
        }
#else
        _ = context
#endif
    }

#if DEBUG
    private func debugLogNavBarHierarchy(_ view: UIView, depth: Int, maxDepth: Int) {
        guard depth <= maxDepth else { return }
        let indent = String(repeating: "  ", count: depth)
        let className = String(describing: type(of: view))
        let frame = view.frame
        let bounds = view.bounds
        let intrinsic = view.intrinsicContentSize
        print("\(indent)\(className) frame=\(frame) bounds=\(bounds) intrinsic=\(intrinsic)")
        for subview in view.subviews {
            debugLogNavBarHierarchy(subview, depth: depth + 1, maxDepth: maxDepth)
        }
    }
#endif

    private func debugLogBarButtonSetup() {
#if DEBUG
        guard Self.isMacCatalyst else { return }
        let saveImage = saveButton.image?.description ?? "<nil>"
        let filterImage = filtersButton.image?.description ?? "<nil>"
        print("=== SearchViewController bar button setup ===")
        print("boardButton title=\(boardButton.title ?? "<nil>") image=\(boardButton.image?.description ?? "<nil>") tag=\(boardButton.tag)")
        print("saveButton title=\(saveButton.title ?? "<nil>") image=\(saveImage) tag=\(saveButton.tag)")
        print("filtersButton title=\(filtersButton.title ?? "<nil>") image=\(filterImage) tag=\(filtersButton.tag)")
#endif
    }

    private func setDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
        segmentedControl.selectedSegmentIndex = mode.rawValue
        tableView.reloadData()
        updateEmptyState()
    }

    private func reloadHistoryAndSaved() {
        refreshHistoryAndSavedLists()
        tableView.reloadData()
    }

    private func refreshHistoryAndSavedLists() {
        searchHistory = SearchManager.shared.getSearchHistory()
        savedSearches = SearchManager.shared.getSavedSearches()
    }

    private func updateEmptyState() {
        if isSearching {
            tableView.backgroundView = nil
            return
        }

        switch displayMode {
        case .results:
            let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if query.isEmpty {
                emptyStateLabel.text = "Enter search terms and press Search"
                tableView.backgroundView = emptyStateLabel
            } else if searchResults.isEmpty {
                emptyStateLabel.text = "No results found"
                tableView.backgroundView = emptyStateLabel
            } else {
                tableView.backgroundView = nil
            }
        case .history:
            if searchHistory.isEmpty {
                emptyStateLabel.text = "No recent searches"
                tableView.backgroundView = emptyStateLabel
            } else {
                tableView.backgroundView = nil
            }
        case .saved:
            if savedSearches.isEmpty {
                emptyStateLabel.text = "No saved searches"
                tableView.backgroundView = emptyStateLabel
            } else {
                tableView.backgroundView = nil
            }
        }
    }

    private func updateSaveButtonAvailability() {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        saveButton.isEnabled = !query.isEmpty
    }

    private func updateFiltersButtonState() {
        filtersButton.tintColor = activeFilters.isActive ? ThemeManager.shared.alertColor : ThemeManager.shared.primaryTextColor
    }

    private func applyFilters(_ filters: SearchFilters) {
        activeFilters = filters.normalized()
        updateFiltersButtonState()
    }

    private func updateBoardSelection(_ board: String?) {
        currentBoard = board
        boardButton.title = board.map { "/\($0)/" } ?? "All Boards"
    }

    private func filtersSummary(_ filters: SearchFilters?) -> String? {
        guard let filters, filters.isActive else { return nil }
        var parts: [String] = []
        if filters.requiresImages {
            parts.append("Images")
        }
        if let minReplies = filters.minReplies {
            parts.append("Min replies \(minReplies)")
        }
        if !filters.fileTypes.isEmpty {
            parts.append("Types: \(filters.fileTypes.joined(separator: ","))")
        }
        return parts.joined(separator: ", ")
    }

    private func promptToSaveSearch(query: String, boardAbv: String?) {
        let alert = UIAlertController(title: "Save Search", message: "Name this search", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Name (optional)"
            textField.text = query
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = SearchManager.shared.saveSearch(
                query,
                name: name?.isEmpty == false ? name : nil,
                boardAbv: boardAbv,
                filters: self.activeFilters.isActive ? self.activeFilters : nil
            )
            self.reloadHistoryAndSaved()
            self.setDisplayMode(.saved)
        })
        present(alert, animated: true)
    }

    private func promptToRenameSavedSearch(_ search: SearchManager.SavedSearch) {
        let alert = UIAlertController(title: "Rename Search", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Name"
            textField.text = search.name
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !newName.isEmpty else { return }
            var updated = search
            updated.name = newName
            SearchManager.shared.updateSavedSearch(updated)
            self.reloadHistoryAndSaved()
            self.updateEmptyState()
        })
        present(alert, animated: true)
    }

    // MARK: - Search Implementation
    private func performSearch(query: String, recordHistory: Bool = true) {
        updateSaveButtonAvailability()
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            loadingIndicator.stopAnimating()
            hideProgressUI()
            isSearching = false
            activeSearchToken = UUID()
            updateEmptyState()
            return
        }

        // Show loading indicator
        tableView.backgroundView = nil
        loadingIndicator.startAnimating()
        isSearching = true
        searchResults = []
        tableView.reloadData()
        setDisplayMode(.results)
        let searchToken = UUID()
        activeSearchToken = searchToken
        let appliedFilters = activeFilters.isActive ? activeFilters : nil

        if currentBoard == nil {
            showProgressUI()
            SearchManager.shared.performSearch(query: query, boardAbv: nil, filters: appliedFilters, recordHistory: recordHistory, progress: { [weak self] progress in
                guard let self = self, self.activeSearchToken == searchToken else { return }
                self.updateProgress(progress)
            }) { [weak self] results in
                DispatchQueue.main.async {
                    guard let self = self, self.activeSearchToken == searchToken else { return }
                    self.loadingIndicator.stopAnimating()
                    self.hideProgressUI()
                    self.searchResults = results.sorted { $0.replies > $1.replies }
                    self.isSearching = false

                    self.refreshHistoryAndSavedLists()
                    self.tableView.reloadData()
                    self.updateEmptyState()
                }
            }
        } else {
            hideProgressUI()
            // Search specific board
            SearchManager.shared.performSearch(query: query, boardAbv: currentBoard, filters: appliedFilters, recordHistory: recordHistory) { [weak self] results in
                DispatchQueue.main.async {
                    guard let self = self, self.activeSearchToken == searchToken else { return }
                    self.loadingIndicator.stopAnimating()
                    self.searchResults = results
                    self.isSearching = false

                    self.refreshHistoryAndSavedLists()
                    self.tableView.reloadData()
                    self.updateEmptyState()
                }
            }
        }
    }

    private func showProgressUI() {
        progressLabel.text = "Preparing search..."
        progressView.progress = 0
        progressLabel.isHidden = false
        progressView.isHidden = false
    }

    private func hideProgressUI() {
        progressLabel.isHidden = true
        progressView.isHidden = true
    }

    private func updateProgress(_ progress: SearchManager.SearchProgress) {
        switch progress.phase {
        case .loadingBoards:
            progressLabel.text = "Loading boards..."
            progressView.progress = 0
        case .searching:
            let boardSuffix: String
            if let board = progress.currentBoard {
                boardSuffix = " • /\(board)/"
            } else {
                boardSuffix = ""
            }
            progressLabel.text = "Searching \(progress.completedBoards)/\(progress.totalBoards) boards\(boardSuffix)"
            if progress.totalBoards > 0 {
                progressView.progress = Float(progress.completedBoards) / Float(progress.totalBoards)
            } else {
                progressView.progress = 0
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch displayMode {
        case .results:
            return searchResults.count
        case .history:
            return searchHistory.count
        case .saved:
            return savedSearches.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch displayMode {
        case .results:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell")
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SearchResultCell")
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

            cell.detailTextLabel?.text = "/\(result.boardAbv)/ • \(result.createdAt) • \(result.stats) • \(shortPreview)..."

            cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
            return cell
        case .history:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell")
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: "HistoryCell")
            let item = searchHistory[indexPath.row]
            cell.textLabel?.text = item.query
            cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
            cell.detailTextLabel?.textColor = .systemGray
            let boardText = item.boardAbv.map { "/\($0)/" } ?? "All Boards"
            cell.detailTextLabel?.text = "\(boardText) • \(dateFormatter.string(from: item.timestamp))"
            cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
            cell.accessoryType = .disclosureIndicator
            return cell
        case .saved:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SavedCell")
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SavedCell")
            let search = savedSearches[indexPath.row]
            cell.textLabel?.text = search.name
            cell.textLabel?.textColor = ThemeManager.shared.primaryTextColor
            cell.detailTextLabel?.textColor = .systemGray
            var detailParts: [String] = [search.query]
            let boardText = search.boardAbv.map { "/\($0)/" } ?? "All Boards"
            detailParts.append(boardText)
            if let filtersText = filtersSummary(search.filters) {
                detailParts.append(filtersText)
            }
            cell.detailTextLabel?.text = detailParts.joined(separator: " • ")
            cell.backgroundColor = ThemeManager.shared.cellBackgroundColor
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch displayMode {
        case .results:
            // Handle search result selection
            let result = searchResults[indexPath.row]

            // Navigate to the thread
            let threadRepliesVC = threadRepliesTV()
            threadRepliesVC.boardAbv = result.boardAbv
            threadRepliesVC.threadNumber = result.number
            threadRepliesVC.title = result.title.isEmpty ? "Thread #\(result.number)" : result.title
            navigationController?.pushViewController(threadRepliesVC, animated: true)
        case .history:
            let item = searchHistory[indexPath.row]
            applyFilters(activeFilters)
            updateBoardSelection(item.boardAbv)
            searchController.searchBar.text = item.query
            searchController.searchBar.resignFirstResponder()
            performSearch(query: item.query)
        case .saved:
            let saved = savedSearches[indexPath.row]
            let filtersToApply = saved.filters ?? SearchFilters()
            applyFilters(filtersToApply)
            updateBoardSelection(saved.boardAbv)
            searchController.searchBar.text = saved.query
            searchController.searchBar.resignFirstResponder()
            performSearch(query: saved.query)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch displayMode {
        case .results:
            return nil
        case .history:
            let item = searchHistory[indexPath.row]
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                SearchManager.shared.removeFromHistory(item.id)
                self?.reloadHistoryAndSaved()
                self?.updateEmptyState()
                completion(true)
            }
            let saveAction = UIContextualAction(style: .normal, title: "Save") { [weak self] _, _, completion in
                self?.promptToSaveSearch(query: item.query, boardAbv: item.boardAbv)
                completion(true)
            }
            saveAction.backgroundColor = ThemeManager.shared.alertColor
            return UISwipeActionsConfiguration(actions: [deleteAction, saveAction])
        case .saved:
            let saved = savedSearches[indexPath.row]
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                SearchManager.shared.deleteSavedSearch(saved.id)
                self?.reloadHistoryAndSaved()
                self?.updateEmptyState()
                completion(true)
            }
            let renameAction = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, completion in
                self?.promptToRenameSavedSearch(saved)
                completion(true)
            }
            renameAction.backgroundColor = ThemeManager.shared.alertColor
            return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
        }
    }

}


// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateSaveButtonAvailability()
        if !isSearching {
            updateEmptyState()
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }
        searchBar.resignFirstResponder() // Dismiss keyboard
        performSearch(query: query)
        updateSaveButtonAvailability()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchResults = []
        tableView.reloadData()
        loadingIndicator.stopAnimating()
        hideProgressUI()
        isSearching = false
        activeSearchToken = UUID()
        updateSaveButtonAvailability()
        updateEmptyState()
    }
}

// MARK: - SearchFiltersViewControllerDelegate
extension SearchViewController: SearchFiltersViewControllerDelegate {
    func searchFiltersViewController(_ controller: SearchFiltersViewController, didUpdate filters: SearchFilters) {
        applyFilters(filters)
        if let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty {
            performSearch(query: query, recordHistory: false)
        } else {
            updateEmptyState()
        }
    }
}

// MARK: - BoardPickerViewControllerDelegate
extension SearchViewController: BoardPickerViewControllerDelegate {
    func boardPickerViewController(_ controller: BoardPickerViewController, didSelect boardAbv: String?) {
        updateBoardSelection(boardAbv)
    }
}
