import UIKit
import UserNotifications
import Alamofire
import SwiftyJSON
import Kingfisher
import Combine

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - Keyboard Shortcut Actions
    @objc func navigateToHome() {
        // Navigate to home tab
        if let tabBarController = window?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 0 // Assuming home is the first tab
        }
    }
    
    @objc func navigateToBoards() {
        // Navigate to boards tab
        if let tabBarController = window?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 1 // Assuming boards is the second tab
        }
    }
    
    @objc func navigateToFavorites() {
        // Navigate to favorites tab
        if let tabBarController = window?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 2 // Assuming favorites is the third tab
        }
    }
    
    @objc func navigateToHistory() {
        // Navigate to history tab
        if let tabBarController = window?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 3 // Assuming history is the fourth tab
        }
    }
    
    @objc func navigateToSettings() {
        // Navigate to settings tab
        if let tabBarController = window?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 4 // Assuming settings is the fifth tab
        }
    }
    
    @objc func refreshContent() {
        // Refresh current content
        if let navigationController = window?.rootViewController as? UINavigationController,
           let topViewController = navigationController.topViewController {
            
            // Check the type of the top view controller and call appropriate refresh method
            if let boardsVC = topViewController as? boardsCV {
                boardsVC.refreshBoards()
            } else if let boardTV = topViewController as? boardTV {
                boardTV.refreshThreads()
            } else if let threadRepliesTV = topViewController as? threadRepliesTV {
                threadRepliesTV.refreshReplies()
            }
        }
    }
    
    // MARK: - Properties
    /// The main application window.
    var window: UIWindow?
    
    // MARK: - UIApplicationDelegate Methods
    /// Called when the application has finished launching.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {       
        // Set default value for FaceID setting if it doesn't exist
        let faceIDKey = "channer_faceID_authentication_enabled"
        if UserDefaults.standard.object(forKey: faceIDKey) == nil {
            UserDefaults.standard.set(true, forKey: faceIDKey)
            UserDefaults.standard.synchronize()
        }
        
        // Set default value for keyboard shortcuts if it doesn't exist
        let keyboardShortcutsKey = "keyboardShortcutsEnabled"
        if UserDefaults.standard.object(forKey: keyboardShortcutsKey) == nil {
            UserDefaults.standard.set(true, forKey: keyboardShortcutsKey)
            UserDefaults.standard.synchronize()
        }
        
        // Set default value for notification preferences if it doesn't exist
        let notificationsEnabledKey = "channer_notifications_enabled"
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: notificationsEnabledKey)
            UserDefaults.standard.synchronize()
        }
        
        // Set default value for offline reading if it doesn't exist
        let offlineReadingEnabledKey = "channer_offline_reading_enabled"
        if UserDefaults.standard.object(forKey: offlineReadingEnabledKey) == nil {
            UserDefaults.standard.set(false, forKey: offlineReadingEnabledKey)
            UserDefaults.standard.synchronize()
        }
        
        // Set default value for launch with startup board if it doesn't exist
        let launchWithStartupBoardKey = "channer_launch_with_startup_board"
        if UserDefaults.standard.object(forKey: launchWithStartupBoardKey) == nil {
            UserDefaults.standard.set(false, forKey: launchWithStartupBoardKey)
            UserDefaults.standard.synchronize()
        }
        
        // Initialize the offline reading mode setting in ThreadCacheManager
        let isOfflineReadingEnabled = UserDefaults.standard.bool(forKey: offlineReadingEnabledKey)
        ThreadCacheManager.shared.setOfflineReadingEnabled(isOfflineReadingEnabled)
        
        // Cache all existing favorites for offline reading if offline mode is enabled
        if isOfflineReadingEnabled {
            FavoritesManager.shared.cacheAllFavorites { successCount, failureCount in
                print("Cached \(successCount) favorites for offline reading, \(failureCount) failed")
            }
        }
        
        // Check if user was using OLED Black theme (which has been removed)
        let themeKey = "channer_selected_theme_id"
        if let currentTheme = UserDefaults.standard.string(forKey: themeKey), currentTheme == "oled_black" {
            // Convert to Dark Purple theme instead
            UserDefaults.standard.set("dark_purple", forKey: themeKey)
            UserDefaults.standard.synchronize()
            print("Converted user from removed OLED Black theme to Dark Purple theme")
        }
        
        // Migrate content filters from old format to new ContentFilterManager
        migrateContentFilters()
        
        setupAppearance()
        setupMainWindow()
        setupNotifications(application)
        setupBackgroundRefresh(application)
        
        return true
    }
    
    /// Called when the application is about to enter the foreground
    // Lifecycle methods have been removed as they were only needed for OLED theme handling
    
    // MARK: - Background Refresh
    private func setupBackgroundRefresh(_ application: UIApplication) {
        // Set minimum background fetch interval
        // Note: This is deprecated in iOS 13+ but we're using it for compatibility
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    // Background fetch handler
    @available(iOS, deprecated: 13.0, message: "Use BGProcessingTask instead")
    func application(_ application: UIApplication, 
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Background fetch started")
        
        // Check if notifications are enabled
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "channer_notifications_enabled")
        if !notificationsEnabled {
            completionHandler(.noData)
            return
        }
        
        // Only refresh favorites if there are any
        let favorites = FavoritesManager.shared.loadFavorites()
        if favorites.isEmpty {
            completionHandler(.noData)
            return
        }
        
        checkForThreadUpdates(favorites) { hasNewData in
            completionHandler(hasNewData ? .newData : .noData)
        }
    }
    
    private func checkForThreadUpdates(_ favorites: [ThreadData], completion: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var hasUpdates = false
        
        for favorite in favorites {
            dispatchGroup.enter()
            
            let url = "https://a.4cdn.org/\(favorite.boardAbv)/thread/\(favorite.number).json"
            
            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }
                
                switch response.result {
                case .success(let data):
                    if let json = try? JSON(data: data),
                       let firstPost = json["posts"].array?.first {
                        // Get the current reply count
                        let currentReplies = firstPost["replies"].intValue
                        
                        // Check if there are new replies
                        let storedReplies = favorite.replies
                        if currentReplies > storedReplies {
                            // We have new replies
                            hasUpdates = true
                            
                            // Calculate number of new replies
                            let newReplies = currentReplies - storedReplies
                            
                            // Update the thread in favorites with new reply count and set hasNewReplies flag
                            var updatedThread = favorite
                            updatedThread.currentReplies = currentReplies
                            updatedThread.hasNewReplies = true
                            FavoritesManager.shared.updateFavorite(thread: updatedThread)
                            
                            // Update the app badge count
                            self.updateApplicationBadgeCount()
                            
                            // Send a notification if there are new replies
                            self.sendThreadUpdateNotification(
                                threadNumber: favorite.number,
                                boardAbv: favorite.boardAbv,
                                newReplies: newReplies
                            )
                        }
                    }
                case .failure:
                    // Failed to check this thread, skip it
                    break
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(hasUpdates)
        }
    }
    
    // MARK: - Notifications Setup
    private func setupNotifications(_ application: UIApplication) {
        // Set the notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request authorization for notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
    }
    
    private func sendThreadUpdateNotification(threadNumber: String, boardAbv: String, newReplies: Int) {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "channer_notifications_enabled")
        if !notificationsEnabled {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Thread Update"
        content.body = "Thread /\(boardAbv)/\(threadNumber) has \(newReplies) new \(newReplies == 1 ? "reply" : "replies")"
        content.sound = UNNotificationSound.default
        
        // Add thread information to the notification userInfo
        content.userInfo = [
            "threadNumber": threadNumber,
            "boardAbv": boardAbv
        ]
        
        // Create a unique identifier for this notification
        let identifier = "thread-\(boardAbv)-\(threadNumber)-\(Date().timeIntervalSince1970)"
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for thread \(threadNumber)")
            }
        }
    }
    
    // MARK: - Badge Management
    private func updateApplicationBadgeCount() {
        // Only update if notifications are enabled
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "channer_notifications_enabled")
        if !notificationsEnabled {
            UIApplication.shared.applicationIconBadgeNumber = 0
            return
        }
        
        // Count the number of threads with new replies
        let favorites = FavoritesManager.shared.loadFavorites()
        let threadsWithNewReplies = favorites.filter { $0.hasNewReplies }
        let badgeCount = threadsWithNewReplies.count
        
        // Update the application badge
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
        }
    }
    
    // MARK: - Appearance Setup
    /// Sets up the global appearance for UI elements.
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ThemeManager.shared.backgroundColor
        
        // Apply the appearance settings to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }
    }
    
    // MARK: - Window Setup
    /// Sets up the main application window and root view controller.
    private func setupMainWindow() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = createRootNavigationController()
        window?.makeKeyAndVisible()
        
        // Register keyboard shortcuts
        KeyboardShortcutManager.shared.registerGlobalShortcuts(window: window!)
    }
    
    // MARK: - Global Keyboard Shortcut Actions
    
    @objc func navigateToHome() {
        // Navigate to the home screen
        if let navController = window?.rootViewController as? UINavigationController {
            // Pop to root or navigate to home
            navController.popToRootViewController(animated: true)
        }
    }
    
    @objc func navigateToBoards() {
        // Navigate to boards screen
        if let navController = window?.rootViewController as? UINavigationController {
            // Create and push boards view controller
            let boardsVC = boardsCV()
            navController.pushViewController(boardsVC, animated: true)
        }
    }
    
    @objc func navigateToFavorites() {
        // Navigate to favorites screen
        if let navController = window?.rootViewController as? UINavigationController {
            // Create and push favorites view controller
            let favoritesVC = CategorizedFavoritesViewController()
            navController.pushViewController(favoritesVC, animated: true)
        }
    }
    
    @objc func navigateToHistory() {
        // Navigate to history screen
        if let navController = window?.rootViewController as? UINavigationController {
            // Create and push history view controller
            let historyVC = HistoryManager()
            navController.pushViewController(historyVC, animated: true)
        }
    }
    
    @objc func navigateToSettings() {
        // Navigate to settings screen
        if let navController = window?.rootViewController as? UINavigationController {
            // Create and push settings view controller
            let settingsVC = settings()
            navController.pushViewController(settingsVC, animated: true)
        }
    }
    
    @objc func refreshContent() {
        // Refresh current content
        // This is a generic refresh that can be implemented by the current view controller
        NotificationCenter.default.post(name: NSNotification.Name("RefreshContentNotification"), object: nil)
    }
    
    // MARK: - Navigation Controller Setup
    /// Creates the main navigation controller that will be used as the root view controller.
    private func createRootNavigationController() -> UINavigationController {
        let boardsController = boardsCV(collectionViewLayout: UICollectionViewFlowLayout())
        
        // Create a UINavigationController with customized back button
        let navigationController = UINavigationController(rootViewController: boardsController)
        
        // Set the default back button title to an empty string
        // This removes the text but keeps the back arrow
        navigationController.navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        return navigationController
    }
    
    // MARK: - Content Filter Migration
    /// Migrates old content filters to the new ContentFilterManager
    private func migrateContentFilters() {
        // Check if migration has already happened
        let migrationKey = "content_filters_migrated"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        // Get old filters from UserDefaults
        if let oldFilters = UserDefaults.standard.stringArray(forKey: "content_filters") {
            // Migrate each filter to the new keyword filters
            if let utilContentFilterManager = NSClassFromString("Channer.ContentFilterManager") as? NSObject.Type,
               let manager = utilContentFilterManager.value(forKeyPath: "shared") as? NSObject {
                for filter in oldFilters {
                    _ = manager.perform(NSSelectorFromString("addKeywordFilter:"), with: filter)
                }
            }
            
            print("Migrated \(oldFilters.count) content filters to new ContentFilterManager")
            
            // Mark as migrated
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    /// Called when a notification is delivered while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    /// Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract thread information from notification
        if let threadNumber = userInfo["threadNumber"] as? String,
           let boardAbv = userInfo["boardAbv"] as? String {
            print("User tapped notification for thread /\(boardAbv)/\(threadNumber)")
            navigateToThread(boardAbv: boardAbv, threadNumber: threadNumber)
        }
        
        completionHandler()
    }
    
    // MARK: - Navigation Helper
    private func navigateToThread(boardAbv: String, threadNumber: String) {
        // Get the current navigation controller
        guard let window = window,
              let navigationController = window.rootViewController as? UINavigationController else {
            print("Could not find navigation controller")
            return
        }
        
        // Pop to root to ensure clean navigation state
        navigationController.popToRootViewController(animated: false)
        
        // Create and push the thread view controller
        let threadVC = threadRepliesTV()
        threadVC.boardAbv = boardAbv
        threadVC.threadNumber = threadNumber
        
        // Get thread info from favorites if available
        let favorites = FavoritesManager.shared.loadFavorites()
        if let favoriteThread = favorites.first(where: { $0.number == threadNumber && $0.boardAbv == boardAbv }) {
            threadVC.totalImagesInThread = favoriteThread.stats.components(separatedBy: "/").last.flatMap { Int($0) } ?? 0
        }
        
        // Push the thread view controller
        navigationController.pushViewController(threadVC, animated: true)
        
        // Clear the "hasNewReplies" flag for this thread
        if var thread = favorites.first(where: { $0.number == threadNumber && $0.boardAbv == boardAbv }) {
            thread.hasNewReplies = false
            FavoritesManager.shared.updateFavorite(thread: thread)
            updateApplicationBadgeCount()
        }
    }
}
