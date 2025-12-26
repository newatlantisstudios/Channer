import UIKit
import Alamofire
import SwiftyJSON
import LocalAuthentication
import Combine

private let reuseIdentifier = "boardTVCell"

class boardsTV: UITableViewController {

    // MARK: - Keyboard Shortcuts
    override var keyCommands: [UIKeyCommand]? {
        // Only provide shortcuts on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nextBoardCommand = UIKeyCommand(input: UIKeyCommand.inputDownArrow, 
                                               modifierFlags: [], 
                                               action: #selector(nextBoard),
                                               discoverabilityTitle: "Next Board")
            
            let previousBoardCommand = UIKeyCommand(input: UIKeyCommand.inputUpArrow, 
                                                  modifierFlags: [], 
                                                  action: #selector(previousBoard),
                                                  discoverabilityTitle: "Previous Board")
            
            let openSelectedBoardCommand = UIKeyCommand(input: "\r", 
                                                      modifierFlags: [], 
                                                      action: #selector(openSelectedBoard),
                                                      discoverabilityTitle: "Open Selected Board")
            
            return [nextBoardCommand, previousBoardCommand, openSelectedBoardCommand]
        }
        
        return nil
    }

    // MARK: - Properties
    /// Flag to track if we've already performed the initial startup navigation
    private var hasPerformedStartupNavigation = false
    
    /// Boards data (populated from BoardsService)
    var boardNames: [String] = []
    var boardsAbv: [String] = []
    
    private let faceIDEnabledKey = "channer_faceID_authentication_enabled"
    
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
        
        // Register for keyboard shortcuts notifications
        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(keyboardShortcutsToggled(_:)), 
                                             name: NSNotification.Name("KeyboardShortcutsToggled"), 
                                             object: nil)
        
        // Load cached boards and then fetch latest
        boardNames = BoardsService.shared.boardNames
        boardsAbv = BoardsService.shared.boardAbv
        sortBoardsAlphabetically()
        
        // Set theme background color for automatic light/dark mode support
        view.backgroundColor = ThemeManager.shared.backgroundColor
        tableView.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Register cell class
        tableView.register(boardsTVCell.self, forCellReuseIdentifier: reuseIdentifier)
        
        // Configure table view appearance
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = 60
        
        // Set backBarButtonItem to have just the arrow without text
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        // Add toolbox button that contains History, Favorites, Search, and Files
        let toolboxImage = UIImage(named: "toolbox")?.withRenderingMode(.alwaysTemplate).resized(to: CGSize(width: 22, height: 22))
        let toolboxButton = UIBarButtonItem(image: toolboxImage, style: .plain, target: self, action: #selector(showToolboxMenu))
        navigationItem.leftBarButtonItem = toolboxButton
        
        // Add notification bell button
        // Create bell icon with fixed size to match other nav bar buttons
        let bellImage = UIImage(systemName: "bell")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .regular))
        // Scale to exact size to ensure consistency
        let resizedBellImage = bellImage?.resized(to: CGSize(width: 22, height: 22))
        let notificationButton = UIBarButtonItem(image: resizedBellImage, style: .plain, target: self, action: #selector(showNotifications))
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

        // Fetch latest boards and refresh table on completion
        BoardsService.shared.fetchBoards { [weak self] in
            guard let self = self else { return }
            self.boardNames = BoardsService.shared.boardNames
            self.boardsAbv = BoardsService.shared.boardAbv
            self.sortBoardsAlphabetically()
            self.tableView.reloadData()
        }
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
        // Ensure this runs on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateNotificationBadge()
            }
            return
        }
        
        let unreadCount = NotificationManager.shared.getUnreadCount()
        
        if let notificationButton = navigationItem.rightBarButtonItems?.first(where: { $0.tag == 100 }) {
            // Create a properly sized icon
            let iconName: String
            
            if unreadCount > 0 {
                // Different approach based on iOS version
                if #available(iOS 16.0, *) {
                    // iOS 16+ can use system badge
                    iconName = unreadCount > 99 ? "bell.badge.fill" : "bell.badge"
                } else {
                    // Fallback for older iOS versions
                    iconName = "bell.badge.fill"
                }
                
                // Set tint color to indicate unread
                notificationButton.tintColor = .systemRed
            } else {
                iconName = "bell"
                notificationButton.tintColor = nil // Use default tint color
            }
            
            // Create and resize the icon consistently with other nav buttons
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            let baseImage = UIImage(systemName: iconName)?.withConfiguration(symbolConfig)
            let resizedImage = baseImage?.resized(to: CGSize(width: 22, height: 22))
            notificationButton.image = resizedImage
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
        
        // Downloaded action
        let filesAction = UIAlertAction(title: "Downloaded", style: .default) { [weak self] _ in
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
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return boardNames.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as? boardsTVCell else {
            let fallbackCell = UITableViewCell(style: .subtitle, reuseIdentifier: "FallbackCell")
            fallbackCell.selectionStyle = .none
            fallbackCell.textLabel?.text = boardNames[indexPath.row]
            fallbackCell.detailTextLabel?.text = "/" + boardsAbv[indexPath.row] + "/"
            return fallbackCell
        }

        // Configure the cell
        cell.boardNameLabel.text = boardNames[indexPath.row]
        cell.boardAbvLabel.text = "/" + boardsAbv[indexPath.row] + "/"
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    
    // MARK: - Keyboard Shortcuts
    
    /// Navigate to the next board
    @objc func nextBoard() {
        let selectedRow = tableView.indexPathForSelectedRow?.row ?? -1
        
        if selectedRow < boardNames.count - 1 {
            let nextIndexPath = IndexPath(row: selectedRow + 1, section: 0)
            tableView.selectRow(at: nextIndexPath, animated: true, scrollPosition: .middle)
        } else if boardNames.count > 0 {
            // Wrap around to the first row
            let firstIndexPath = IndexPath(row: 0, section: 0)
            tableView.selectRow(at: firstIndexPath, animated: true, scrollPosition: .top)
        }
    }
    
    /// Navigate to the previous board
    @objc func previousBoard() {
        let selectedRow = tableView.indexPathForSelectedRow?.row ?? boardNames.count
        
        if selectedRow > 0 {
            let prevIndexPath = IndexPath(row: selectedRow - 1, section: 0)
            tableView.selectRow(at: prevIndexPath, animated: true, scrollPosition: .middle)
        } else if boardNames.count > 0 {
            // Wrap around to the last row
            let lastIndexPath = IndexPath(row: boardNames.count - 1, section: 0)
            tableView.selectRow(at: lastIndexPath, animated: true, scrollPosition: .bottom)
        }
    }
    
    /// Open the currently selected board
    @objc func openSelectedBoard() {
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView(tableView, didSelectRowAt: selectedIndexPath)
        } else if boardNames.count > 0 {
            // If no row is selected, select the first one
            let firstIndexPath = IndexPath(row: 0, section: 0)
            tableView.selectRow(at: firstIndexPath, animated: true, scrollPosition: .top)
            tableView(tableView, didSelectRowAt: firstIndexPath)
        }
    }
    
    /// Called when keyboard shortcuts are toggled in settings
    @objc func keyboardShortcutsToggled(_ notification: Notification) {
        // This will trigger recreation of the keyCommands array
        self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
}
