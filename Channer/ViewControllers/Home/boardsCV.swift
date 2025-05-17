import UIKit
import Alamofire
import SwiftyJSON
import LocalAuthentication

private let reuseIdentifier = "boardCell"
private let faceIDEnabledKey = "channer_faceID_authentication_enabled"

class boardsCV: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties
    /// Flag to track if we've already performed the initial startup navigation
    private var hasPerformedStartupNavigation = false
    
    /// An array containing the full names of the boards.
    var boardNames = ["Anime & Manga", "Anime/Cute", "Anime/Wallpapers", "Mecha", "Cosplay & EGL", "Cute/Male", "Flash", "Transportation", "Otaku Culture", "Video Games", "Video Game Generals", "Pokémon", "Retro Games", "Comics & Cartoons", "Technology", "Television & Film", "Weapons", "Auto", "Animals & Nature", "Traditional Games", "Sports", "Alternative Sports", "Science & Math", "History & Humanities", "International", "Outdoors", "Toys", "Oekaki", "Papercraft & Origami", "Photography", "Food & Cooking", "Artwork/Critique", "Wallpapers/General", "Literature", "Music", "Fashion", "3DCG", "Graphic Design", "Do-It-Yourself", "Worksafe GIF", "Quests", "Business & Finance", "Travel", "Fitness", "Paranormal", "Advice", "LGBT", "Pony", "Current News", "Worksafe Requests", "Very Important Posts", "Random", "ROBOT9001", "Politically Incorrect", "International/Random", "Cams & Meetups", "Shit 4chan Says", "Sexy Beautiful Women", "Hardcore", "Handsome Men", "Hentai", "Ecchi", "Yuri", "Hentai/Alternative", "Yaoi", "Torrents", "High Resolution", "Adult GIF", "Adult Cartoons", "Adult Requests"]
    
    /// An array containing the abbreviated names of the boards.
    var boardsAbv = ["a", "c", "w", "m", "cgl", "cm", "f", "n", "jp", "v", "vg", "vp", "vr", "co", "g", "tv", "k", "o", "an", "tg", "sp", "asp", "sci", "his", "int", "out", "toy", "i", "po", "p", "ck", "ic", "wg", "lit", "mu", "fa", "3", "gd", "diy", "wsg", "qst", "biz", "trv", "fit", "x", "adv", "lgbt", "mlp", "news", "wsr", "vip", "b", "r9k", "pol", "bant", "soc", "s4s", "s", "hc", "hm", "h", "e", "u", "d", "y", "t", "hr", "gif", "aco", "r"]
    
    // MARK: - Authentication
    /// Authenticates the user using Face ID or Touch ID.
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let defaults = UserDefaults.standard
        
        // Make sure we're reading the latest data
        defaults.synchronize()
        
        // Get authentication setting
        let isAuthenticationEnabled = defaults.bool(forKey: faceIDEnabledKey)
        
        // If authentication is disabled, bypass FaceID
        if !isAuthenticationEnabled {
            print("FaceID authentication bypassed - setting is OFF")
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        // Otherwise proceed with normal FaceID authentication
        print("Proceeding with FaceID authentication - setting is ON")
        performBiometricAuthentication(completion: completion)
    }
    
    /// Performs the actual biometric authentication
    private func performBiometricAuthentication(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if Face ID/Touch ID is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access this feature."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // Fallback if Face ID/Touch ID is not available
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Biometric Authentication Unavailable",
                    message: "Face ID/Touch ID is not available on this device. You can disable the authentication requirement in Settings.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let rootViewController = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    rootViewController.present(alert, animated: true, completion: nil)
                }
                
                completion(false)
            }
        }
    }

    // MARK: - View Lifecycle
    
    /// Sorts the boards alphabetically by name while maintaining name-abbreviation pairs
    private func sortBoardsAlphabetically() {
        // Create array of tuples with board name and abbreviation
        let combinedBoards = zip(boardNames, boardsAbv).map { ($0, $1) }
        
        // Sort the combined array by board name
        let sortedBoards = combinedBoards.sorted { $0.0 < $1.0 }
        
        // Update the original arrays with sorted values
        boardNames = sortedBoards.map { $0.0 }
        boardsAbv = sortedBoards.map { $0.1 }
        
        // Print confirmation
        print("Boards sorted alphabetically")
    }
    
    /// Called after the controller's view is loaded into memory.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Sort boards alphabetically
        sortBoardsAlphabetically()
        
        // Set theme background color for automatic light/dark mode support
        collectionView.backgroundColor = ThemeManager.shared.backgroundColor

        // Ensure the collection view is using a UICollectionViewFlowLayout
        if collectionView.collectionViewLayout as? UICollectionViewFlowLayout == nil {
            collectionView.collectionViewLayout = UICollectionViewFlowLayout()
        }

        // Register cell
        collectionView.register(boardCVCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Set backBarButtonItem to have just the arrow without text
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        // Add toolbox button that contains History, Favorites, Search, and Files
        let toolboxButton = UIBarButtonItem(image: UIImage(systemName: "tray.2"), style: .plain, target: self, action: #selector(showToolboxMenu))
        navigationItem.leftBarButtonItem = toolboxButton
        
        // Add notification bell button
        let notificationButton = UIBarButtonItem(image: UIImage(systemName: "bell"), style: .plain, target: self, action: #selector(showNotifications))
        notificationButton.tag = 100 // Tag for updating badge later
        
        // Add settings button
        let settingsImage = UIImage(named: "setting")?.withRenderingMode(.alwaysTemplate)
        let resizedSettingsImage = settingsImage?.resized(to: CGSize(width: 22, height: 22))
        let settingsButton = UIBarButtonItem(image: resizedSettingsImage, style: .plain, target: self, action: #selector(openSettings))
        
        // Set both buttons as right bar button items
        navigationItem.rightBarButtonItems = [settingsButton, notificationButton]
        
        // Register for UserDefaults changes notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Register for notification updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotificationBadge),
            name: .notificationAdded,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotificationBadge),
            name: .notificationRead,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotificationBadge),
            name: .notificationRemoved,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotificationBadge),
            name: .notificationDataChanged,
            object: nil
        )
        
        // Update initial badge count
        updateNotificationBadge()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if we should navigate to the startup board
        let shouldLaunchWithStartupBoard = UserDefaults.standard.bool(forKey: "channer_launch_with_startup_board")
        
        // Only perform startup navigation once and only if this is the root controller
        if !hasPerformedStartupNavigation &&
           shouldLaunchWithStartupBoard,
           let defaultBoard = UserDefaults.standard.string(forKey: "defaultBoard"),
           let index = boardsAbv.firstIndex(of: defaultBoard),
           navigationController?.viewControllers.count == 1 {
            
            // Mark that we've performed the startup navigation
            hasPerformedStartupNavigation = true
            
            // Navigate to the default board
            let vc = boardTV()
            vc.boardName = boardNames[index]
            vc.boardAbv = boardsAbv[index]
            vc.title = "/" + boardsAbv[index] + "/"
            vc.boardPassed = true
            
            navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // Log when UserDefaults changes
        let isFaceIDEnabled = UserDefaults.standard.bool(forKey: faceIDEnabledKey)
        print("UserDefaults changed notification - FaceID enabled: \(isFaceIDEnabled)")
    }
    
    /// Called to notify the view controller that its view is about to layout its subviews.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        configureCollectionViewLayout()
    }
    
    /// Called when the view controller's trait collection changes.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Check if orientation, size class, or device type changed
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
           previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass ||
           previousTraitCollection?.userInterfaceIdiom != traitCollection.userInterfaceIdiom {
            // Update layout for the new conditions
            configureCollectionViewLayout()
            // Force collection view to redraw with new layout
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    // MARK: - Navigation Actions
    /// Opens the files list after successful authentication.
    @objc func openFilesList() {
        authenticateUser { [weak self] isAuthenticated in
            guard let self = self else { return }
            guard isAuthenticated else {
                let alert = UIAlertController(title: "Authentication Failed", message: "Unable to authenticate. Access denied.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            // Proceed with opening files list
            let filesVC = FilesListVC()
            self.navigationController?.pushViewController(filesVC, animated: true)
            
        }
    }
    
    /// Navigates to the settings view, where the user can configure app preferences such as the default board.
    /// Navigates to the settings view, where the user can configure app preferences such as the default board.
    @objc private func openSettings() {
        let settingsVC = settings() // Instantiate settings view controller programmatically
        settingsVC.title = "Settings" // Set the title for the navigation bar
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    /// Opens the history view after successful authentication.
    @objc func openHistory() {
        authenticateUser { [weak self] isAuthenticated in
            guard isAuthenticated else {
                let alert = UIAlertController(title: "Authentication Failed", message: "Unable to authenticate. Access denied.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
                return
            }
            
            // Proceed with opening history
            guard let self = self else { return }
            let historyThreads = HistoryManager.shared.getHistoryThreads()
            if historyThreads.isEmpty {
                let alert = UIAlertController(title: "No Threads", message: "There are no threads in your history.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }

            let vc = boardTV()
            vc.isHistoryView = true
            vc.threadData = historyThreads
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    /// Shows the favorites view after successful authentication.
    @objc private func showFavorites() {
        authenticateUser { [weak self] isAuthenticated in
            guard isAuthenticated else {
                let alert = UIAlertController(title: "Authentication Failed", message: "Unable to authenticate. Access denied.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
                return
            }
            
            // Proceed with opening favorites
            guard let self = self else { return }
            FavoritesManager.shared.verifyAndRemoveInvalidFavorites { updatedFavorites in
                // Use the new categorized favorites view controller
                let categorizedFavoritesVC = CategorizedFavoritesViewController()
                self.navigationController?.pushViewController(categorizedFavoritesVC, animated: true)
            }
        }
    }
    
    /// Opens the search view controller.
    @objc private func openSearch() {
        let searchVC = SearchViewController()
        navigationController?.pushViewController(searchVC, animated: true)
    }
    
    /// Shows the notifications view controller
    @objc private func showNotifications() {
        let notificationsVC = NotificationsViewController()
        let navController = UINavigationController(rootViewController: notificationsVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }
    
    /// Updates the notification badge count
    @objc private func updateNotificationBadge() {
        let unreadCount = NotificationManager.shared.getUnreadCount()
        
        if let notificationButton = navigationItem.rightBarButtonItems?.first(where: { $0.tag == 100 }) {
            if unreadCount > 0 {
                // Create a custom badge with count
                let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
                
                // Different approach based on iOS version
                if #available(iOS 16.0, *) {
                    // iOS 16+ can use system badge
                    if unreadCount > 99 {
                        notificationButton.image = UIImage(systemName: "bell.badge.fill", withConfiguration: configuration)
                    } else {
                        notificationButton.image = UIImage(systemName: "bell.badge", withConfiguration: configuration)
                    }
                } else {
                    // Fallback for older iOS versions
                    notificationButton.image = UIImage(systemName: "bell.badge.fill", withConfiguration: configuration)
                }
                
                // Set tint color to indicate unread
                notificationButton.tintColor = .systemRed
            } else {
                // Show normal bell icon
                let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
                notificationButton.image = UIImage(systemName: "bell", withConfiguration: configuration)
                notificationButton.tintColor = nil // Use default tint color
            }
        }
    }
    
    /// Shows the toolbox menu with History, Favorites, Search, and Files options
    @objc private func showToolboxMenu() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Standard size for menu icons to match system icons
        let iconSize = CGSize(width: 22, height: 22)
        
        // History action
        let historyAction = UIAlertAction(title: "History", style: .default) { [weak self] _ in
            self?.openHistory()
        }
        let historyImage = UIImage(named: "history")?.withRenderingMode(.alwaysTemplate).resized(to: iconSize)
        historyAction.setValue(historyImage, forKey: "image")
        
        // Favorites action
        let favoritesAction = UIAlertAction(title: "Favorites", style: .default) { [weak self] _ in
            self?.showFavorites()
        }
        let favoritesImage = UIImage(named: "favorite")?.withRenderingMode(.alwaysTemplate).resized(to: iconSize)
        favoritesAction.setValue(favoritesImage, forKey: "image")
        
        // Search action
        let searchAction = UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            self?.openSearch()
        }
        // System images are already the correct size
        searchAction.setValue(UIImage(systemName: "magnifyingglass"), forKey: "image")
        
        // Files action
        let filesAction = UIAlertAction(title: "Files", style: .default) { [weak self] _ in
            self?.openFilesList()
        }
        let filesImage = UIImage(named: "files")?.withRenderingMode(.alwaysTemplate).resized(to: iconSize)
        filesAction.setValue(filesImage, forKey: "image")
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        // Add actions to alert controller
        alertController.addAction(historyAction)
        alertController.addAction(favoritesAction)
        alertController.addAction(searchAction)
        alertController.addAction(filesAction)
        alertController.addAction(cancelAction)
        
        // For iPad, set the popover presentation controller
        if let popover = alertController.popoverPresentationController {
            popover.barButtonItem = navigationItem.leftBarButtonItem
        }
        
        // Present the alert controller
        present(alertController, animated: true)
    }
    
    // MARK: - UICollectionView Data Source
    /// Returns the number of sections in the collection view.
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    /// Returns the number of items in the specified section.
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return boardNames.count
    }
    
    /// Configures and returns the cell for the item at the specified index path.
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? boardCVCell else {
            fatalError("Failed to dequeue boardCVCell")
        }

        // Configure the cell
        cell.boardName.text = boardNames[indexPath.row] // Ensure this array has valid strings
        cell.boardNameAbv.text = "/" + boardsAbv[indexPath.row] + "/" // Ensure this array matches `boardNames`
        cell.boardImage.image = UIImage(named: "boardSquare") // Replace with your actual image logic

        return cell
    }
    
    // MARK: - UICollectionView Delegate
    /// Handles the selection of an item in the collection view.
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(indexPath.row)
        guard indexPath.row < boardNames.count else {
            print("Index \(indexPath.row) out of bounds for boardNames array.")
            return
        }

        // Instantiate boardTV
        let vc = boardTV()

        // Configure boardTV with selected category
        vc.boardName = boardNames[indexPath.row]
        vc.boardAbv = boardsAbv[indexPath.row]
        vc.title = "/" + boardsAbv[indexPath.row] + "/"
        vc.boardPassed = true
        
        // Use the navigation controller on all devices
        if let navController = navigationController {
            navController.pushViewController(vc, animated: true)
        } else {
            // Fallback to modal presentation if navigation controller is not available
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    /// Returns the minimum spacing between items in the same row.
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        return isPad ? 8 : 10 // Match the spacing in `configureCollectionViewLayout`
    }

    /// Returns the minimum spacing between lines of items in the grid.
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        return isPad ? 8 : 10 // Match the spacing in `configureCollectionViewLayout`
    }
    
    /// Returns the size for the item at the specified index path.
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard collectionViewLayout is UICollectionViewFlowLayout else {
            return CGSize(width: 85, height: 85) // Default size
        }
        
        // Use the same calculation logic as in configureCollectionViewLayout
        let isPad = traitCollection.userInterfaceIdiom == .pad
        
        // Smaller spacing for iPad to fit more cells
        let interItemSpacing: CGFloat = isPad ? 8 : 10
        let sectionInset: CGFloat = isPad ? 8 : 10
        let collectionViewWidth = collectionView.bounds.width
        let numberOfColumns: CGFloat
        
        if isPad {
            // Increased number of columns for iPad to fit more cells
            if collectionViewWidth > 1000 {  // Larger iPads (Pro 12.9")
                numberOfColumns = 8
            } else if collectionViewWidth > 800 {  // Medium iPads (10.5", 11")
                numberOfColumns = 7
            } else {  // Smaller iPads (9.7", iPad mini)
                numberOfColumns = 6
            }
        } else {
            // iPhone layout
            if collectionViewWidth > 400 {  // Larger iPhones in landscape
                numberOfColumns = 4
            } else {  // Standard iPhone layout
                numberOfColumns = 3
            }
        }
        
        let availableWidth = collectionViewWidth - (2 * sectionInset) - (interItemSpacing * (numberOfColumns - 1))
        let cellWidth = floor(availableWidth / numberOfColumns)
        
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    /// Configures the layout of the collection view.
    private func configureCollectionViewLayout() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }

        // Define spacing based on device type
        let isPad = traitCollection.userInterfaceIdiom == .pad
        
        // Smaller spacing for iPad to fit more cells
        let interItemSpacing: CGFloat = isPad ? 8 : 10  // Horizontal space between cells
        let lineSpacing: CGFloat = isPad ? 8 : 10       // Vertical space between rows
        
        // Define section insets - smaller for iPad
        let sectionInset: CGFloat = isPad ? 8 : 10
        
        // Get the collection view's width
        let collectionViewWidth = collectionView.bounds.width
        
        // Determine number of columns based on device and screen width
        let numberOfColumns: CGFloat
        
        if isPad {
            // Increased number of columns for iPad to fit more cells
            if collectionViewWidth > 1000 {  // Larger iPads (Pro 12.9")
                numberOfColumns = 8
            } else if collectionViewWidth > 800 {  // Medium iPads (10.5", 11")
                numberOfColumns = 7
            } else {  // Smaller iPads (9.7", iPad mini)
                numberOfColumns = 6
            }
        } else {
            // iPhone layout
            if collectionViewWidth > 400 {  // Larger iPhones in landscape
                numberOfColumns = 4
            } else {  // Standard iPhone layout
                numberOfColumns = 3
            }
        }
        
        // Calculate cell width to fill the screen with the desired number of columns
        let availableWidth = collectionViewWidth - (2 * sectionInset) - (interItemSpacing * (numberOfColumns - 1))
        let cellWidth = floor(availableWidth / numberOfColumns)
        
        // Keep cell height equal to width for square cells
        let cellHeight = cellWidth
        
        // Configure layout
        layout.itemSize = CGSize(width: cellWidth, height: cellHeight)
        layout.minimumInteritemSpacing = interItemSpacing
        layout.minimumLineSpacing = lineSpacing
        layout.sectionInset = UIEdgeInsets(
            top: sectionInset,
            left: sectionInset,
            bottom: sectionInset,
            right: sectionInset
        )
    }
}
