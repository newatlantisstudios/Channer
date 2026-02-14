import UIKit

/// Delegate protocol for category manager updates
protocol CategoryManagerDelegate: AnyObject {
    /// Called when categories are updated
    func categoriesDidUpdate()
}

/// Main view controller for managing categorized favorite threads
/// Provides tabbed interface for different favorite categories with search functionality
class CategorizedFavoritesViewController: UIViewController, CategoryManagerDelegate, UISearchResultsUpdating {
    
    // MARK: - Properties
    private let segmentedControl = UISegmentedControl()
    private let containerView = UIView()
    private var currentViewController: UIViewController?
    private var categories: [BookmarkCategory] = []
    private let favoritesManager = FavoritesManager.shared
    private var searchController: UISearchController!
    private var isSearching = false
    private var searchText = ""
    private var allFavorites: [ThreadData] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("=== CategorizedFavoritesViewController viewDidLoad ===")
        setupUI()
        loadCategories()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("=== viewWillAppear called ===")
        // Clear cache to load fresh data
        allFavorites = []
        
        // Reload categories in case they were updated
        loadCategories()
        
        // Refresh the current category view to ensure proper filtering
        if segmentedControl.selectedSegmentIndex != UISegmentedControl.noSegment {
            print("Refreshing current segment: \(segmentedControl.selectedSegmentIndex)")
            segmentChanged()
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.shared.backgroundColor
        title = "Favorites"

        // Add manage categories button to navigation bar
        let manageButton = UIBarButtonItem(
            image: UIImage(systemName: "folder.badge.gearshape"),
            style: .plain,
            target: self,
            action: #selector(showCategoryManager)
        )
        manageButton.accessibilityLabel = "Manage Categories"
        navigationItem.rightBarButtonItem = manageButton

        // Setup search controller
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search favorites..."
        searchController.searchBar.barTintColor = ThemeManager.shared.backgroundColor
        searchController.searchBar.tintColor = UIColor(hex: "#59a03b") ?? .systemGreen

        // Add search bar to navigation item
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        
        // Setup segmented control
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.backgroundColor = ThemeManager.shared.cellBackgroundColor
        segmentedControl.selectedSegmentTintColor = UIColor(hex: "#59a03b") ?? .systemGreen
        
        // Setup container view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = ThemeManager.shared.backgroundColor
        
        view.addSubview(segmentedControl)
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 44),
            
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadCategories() {
        print("=== loadCategories called ===")
        let previousSelection = segmentedControl.selectedSegmentIndex
        print("Previous selection: \(previousSelection)")
        
        categories = favoritesManager.getCategories()
        print("Loaded \(categories.count) categories")
        for (index, category) in categories.enumerated() {
            print("Category \(index): \(category.name) (ID: \(category.id))")
        }
        
        updateSegmentedControl()
        
        // Restore previous selection if valid, otherwise show first category
        if previousSelection != UISegmentedControl.noSegment && previousSelection < segmentedControl.numberOfSegments {
            segmentedControl.selectedSegmentIndex = previousSelection
            print("Restored selection to index: \(previousSelection)")
            segmentChanged()
        } else if segmentedControl.numberOfSegments > 0 {
            // Default to first category
            segmentedControl.selectedSegmentIndex = 0
            print("Set default selection to index 0 (first category)")
            updateFavoritesDisplay()
        }
    }
    
    private func updateSegmentedControl() {
        print("=== updateSegmentedControl called ===")
        print("Current selected index: \(segmentedControl.selectedSegmentIndex)")

        // Remove all segments
        segmentedControl.removeAllSegments()

        // Add a segment for each category
        for (index, category) in categories.enumerated() {
            print("Adding category segment: \(category.name) at index \(index)")
            segmentedControl.insertSegment(withTitle: category.name, at: index, animated: false)
        }

        print("Total segments: \(segmentedControl.numberOfSegments)")

        // If we had a selection, try to maintain it
        if segmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment && segmentedControl.numberOfSegments > 0 {
            segmentedControl.selectedSegmentIndex = 0
            print("Set default selection to index 0")
        }
    }
    
    // MARK: - Actions
    @objc private func segmentChanged() {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        print("=== segmentChanged called ===")
        print("Selected index: \(selectedIndex)")
        print("Available categories: \(categories.count)")

        updateFavoritesDisplay()
    }

    @objc private func showCategoryManager() {
        let categoryManagerVC = CategoryManagerViewController()
        categoryManagerVC.delegate = self
        let navController = UINavigationController(rootViewController: categoryManagerVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }
    
    // MARK: - CategoryManagerDelegate
    func categoriesDidUpdate() {
        loadCategories()
    }
    
    // MARK: - Display Methods
    
    private func displayFavorites(_ favorites: [ThreadData], title: String) {
        print("=== displayFavorites called ===")
        print("Title: \(title)")
        print("Displaying \(favorites.count) favorites")
        
        // Remove current view controller if any
        if let current = currentViewController {
            print("Removing current view controller of type: \(type(of: current))")
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
            currentViewController = nil // Important: Set to nil after removal
        }
        
        // Check if we have favorites
        guard !favorites.isEmpty else {
            print("No favorites to display, showing empty state")
            showEmptyState(for: title)
            return
        }
        
        // Create board table view controller
        let boardVC = boardTV()
        boardVC.title = title
        boardVC.threadData = favorites
        boardVC.filteredThreadData = favorites
        boardVC.isFavoritesView = true
        boardVC.isSearching = isSearching  // Pass our search state to the board view controller
        
        print("Created boardVC with \(boardVC.threadData.count) threads and \(boardVC.filteredThreadData.count) filtered threads")
        print("BoardVC isSearching: \(boardVC.isSearching)")
        
        // Add as child view controller
        addChild(boardVC)
        boardVC.view.frame = containerView.bounds
        boardVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight] // Ensure proper autoresizing
        containerView.addSubview(boardVC.view)
        boardVC.didMove(toParent: self)
        
        currentViewController = boardVC
        
        // Force layout update
        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()
        
        // Refresh table view
        DispatchQueue.main.async {
            print("Reloading table view on main thread")
            boardVC.tableView.reloadData()
            print("Table view reloaded - Number of rows: \(boardVC.tableView.numberOfRows(inSection: 0))")
        }
    }
    
    private func showEmptyState(for title: String) {
        print("=== showEmptyState called for: \(title) ===")
        // Remove current view controller if any
        if let current = currentViewController {
            print("Removing current view controller for empty state")
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
            currentViewController = nil
        }
        
        // Create empty state view
        let emptyView = UIView()
        emptyView.backgroundColor = ThemeManager.shared.backgroundColor
        emptyView.frame = containerView.bounds
        emptyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let label = UILabel()
        if isSearching {
            label.text = "No search results in \(title.replacingOccurrences(of: " - Search Results", with: ""))"
        } else {
            label.text = "No favorites in \(title)"
        }
        label.textColor = ThemeManager.shared.secondaryTextColor
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        emptyView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor)
        ])
        
        // Create a simple view controller to hold the empty state
        let emptyVC = UIViewController()
        emptyVC.view = emptyView
        
        addChild(emptyVC)
        containerView.addSubview(emptyVC.view)
        emptyVC.didMove(toParent: self)
        
        currentViewController = emptyVC
        
        print("Empty state shown for: \(title)")
    }
    
    // MARK: - UISearchResultsUpdating
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text ?? ""
        isSearching = !searchText.isEmpty
        
        print("=== updateSearchResults called ===")
        print("Search text: '\(searchText)'")
        print("Is searching: \(isSearching)")
        print("Search controller active: \(searchController.isActive)")
        
        updateFavoritesDisplay()
    }
    
    // MARK: - Search and Filter
    private func updateFavoritesDisplay() {
        print("=== updateFavoritesDisplay called ===")
        
        // Load all favorites if needed
        if allFavorites.isEmpty {
            print("Loading all favorites...")
            allFavorites = favoritesManager.loadFavorites()
            print("Loaded \(allFavorites.count) total favorites")
            for (index, fav) in allFavorites.prefix(3).enumerated() {
                print("Favorite \(index): Thread \(fav.number) - Title: '\(fav.title)' - Board: \(fav.boardAbv) - Comment: '\(fav.comment.prefix(50))...'")
            }
        }
        
        var favoritesToDisplay: [ThreadData] = []
        let selectedIndex = segmentedControl.selectedSegmentIndex
        print("Selected segment index: \(selectedIndex)")

        // Get favorites based on selected category
        if selectedIndex >= 0 && selectedIndex < categories.count {
            let categoryId = categories[selectedIndex].id
            let categoryName = categories[selectedIndex].name
            favoritesToDisplay = allFavorites.filter { $0.categoryId == categoryId }
            print("Showing category '\(categoryName)' (ID: \(categoryId)): \(favoritesToDisplay.count) items")
        }
        
        // Apply search filter if needed
        if isSearching {
            print("Applying search filter for text: '\(searchText)'")
            let beforeFilterCount = favoritesToDisplay.count
            favoritesToDisplay = favoritesToDisplay.filter { thread in
                let titleMatch = thread.title.localizedCaseInsensitiveContains(searchText)
                let commentMatch = thread.comment.localizedCaseInsensitiveContains(searchText)
                let boardMatch = thread.boardAbv.localizedCaseInsensitiveContains(searchText)
                let numberMatch = thread.number.contains(searchText)
                
                let matches = titleMatch || commentMatch || boardMatch || numberMatch
                
                if matches {
                    print("Match found - Thread \(thread.number): title=\(titleMatch), comment=\(commentMatch), board=\(boardMatch), number=\(numberMatch)")
                }
                
                return matches
            }
            print("Filtered from \(beforeFilterCount) to \(favoritesToDisplay.count) items")
        }
        
        print("Final count to display: \(favoritesToDisplay.count) favorites")
        displayFavorites(favoritesToDisplay, title: getDisplayTitle())
    }
    
    private func getDisplayTitle() -> String {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        var title = "Favorites"

        if selectedIndex >= 0 && selectedIndex < categories.count {
            title = categories[selectedIndex].name
        }

        if isSearching {
            title += " - Search Results"
        }

        return title
    }
}