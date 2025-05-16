import UIKit

// Delegate protocol for category manager
protocol CategoryManagerDelegate: AnyObject {
    func categoriesDidUpdate()
}

class CategorizedFavoritesViewController: UIViewController, CategoryManagerDelegate {
    
    // MARK: - Properties
    private let segmentedControl = UISegmentedControl()
    private let containerView = UIView()
    private var currentViewController: UIViewController?
    private var categories: [BookmarkCategory] = []
    private let favoritesManager = FavoritesManager.shared
    
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
        
        // Add right navigation button for category management
        let categoryButton = UIBarButtonItem(image: UIImage(systemName: "folder.badge.gear"), 
                                           style: .plain, 
                                           target: self, 
                                           action: #selector(openCategoryManager))
        navigationItem.rightBarButtonItem = categoryButton
        
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
        
        // Restore previous selection if valid, otherwise show "All"
        if previousSelection != UISegmentedControl.noSegment && previousSelection < segmentedControl.numberOfSegments {
            segmentedControl.selectedSegmentIndex = previousSelection
            print("Restored selection to index: \(previousSelection)")
            segmentChanged()
        } else {
            // Default to "All" tab
            segmentedControl.selectedSegmentIndex = 0
            print("Set default selection to index 0 (All)")
            showAllFavorites()
        }
    }
    
    private func updateSegmentedControl() {
        print("=== updateSegmentedControl called ===")
        print("Current selected index: \(segmentedControl.selectedSegmentIndex)")
        
        // Remove all segments
        segmentedControl.removeAllSegments()
        
        // Add "All" segment at the beginning (index 0)
        segmentedControl.insertSegment(withTitle: "All", at: 0, animated: false)
        
        // Add a segment for each category after "All"
        for (index, category) in categories.enumerated() {
            print("Adding category segment: \(category.name) at index \(index + 1)")
            segmentedControl.insertSegment(withTitle: category.name, at: index + 1, animated: false)
        }
        
        print("Total segments: \(segmentedControl.numberOfSegments)")
        
        // If we had a selection, try to maintain it
        if segmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment && segmentedControl.numberOfSegments > 0 {
            segmentedControl.selectedSegmentIndex = 0
            print("Set default selection to index 0 (All)")
        }
    }
    
    // MARK: - Actions
    @objc private func segmentChanged() {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        print("=== segmentChanged called ===")
        print("Selected index: \(selectedIndex)")
        print("Available categories: \(categories.count)")
        
        if selectedIndex == 0 {
            // "All" segment selected (now at index 0)
            print("All tab selected")
            showAllFavorites()
        } else if selectedIndex > 0 && selectedIndex - 1 < categories.count {
            // Specific category selected (offset by 1 because "All" is at index 0)
            let categoryIndex = selectedIndex - 1
            print("Category tab selected: \(categories[categoryIndex].name)")
            showFavorites(for: categories[categoryIndex])
        } else {
            print("Invalid selection index: \(selectedIndex)")
        }
    }
    
    @objc private func openCategoryManager() {
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
    private func showFavorites(for category: BookmarkCategory) {
        print("Showing favorites for category: \(category.name) (ID: \(category.id))")
        let favorites = favoritesManager.getFavorites(for: category.id)
        print("Found \(favorites.count) favorites in category \(category.name)")
        displayFavorites(favorites, title: category.name)
    }
    
    private func showAllFavorites() {
        print("=== showAllFavorites called ===")
        let allFavorites = favoritesManager.loadFavorites()
        print("All favorites count: \(allFavorites.count)")
        for favorite in allFavorites {
            print("Favorite thread \(favorite.number) - Board: \(favorite.boardAbv) - Category: \(favorite.categoryId ?? "nil")")
        }
        displayFavorites(allFavorites, title: "All Favorites")
    }
    
    private func displayFavorites(_ favorites: [ThreadData], title: String) {
        print("=== displayFavorites called ===")
        print("Title: \(title)")
        print("Displaying \(favorites.count) favorites")
        
        // Remove current view controller if any
        if let current = currentViewController {
            print("Removing current view controller")
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
        
        print("Created boardVC with \(boardVC.threadData.count) threads")
        
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
            print("Reloading table view")
            boardVC.tableView.reloadData()
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
        label.text = "No favorites in \(title)"
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
}