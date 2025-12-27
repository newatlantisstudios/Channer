import UIKit
import UserNotifications
import Alamofire
import SwiftyJSON
import Kingfisher
import Combine
import BackgroundTasks

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
            // Refresh methods will be implemented in a future update
            print("Refresh action triggered for \(type(of: topViewController))")
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
        
        // Set default value for boards display mode if it doesn't exist
        let boardsDisplayModeKey = "channer_boards_display_mode"
        if UserDefaults.standard.object(forKey: boardsDisplayModeKey) == nil {
            UserDefaults.standard.set(0, forKey: boardsDisplayModeKey) // Default to grid view (0)
            UserDefaults.standard.synchronize()
            print("Initialized boards display mode to grid view (0)")
        } else {
            let mode = UserDefaults.standard.integer(forKey: boardsDisplayModeKey)
            print("Current boards display mode: \(mode == 0 ? "Grid" : "List")")
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

        // Register background tasks with BGTaskScheduler (iOS 13+)
        // Must be called before app finishes launching
        BackgroundTaskManager.shared.registerTasks()

        setupAppearance()
        setupMainWindow()
        setupNotifications(application)
        setupBackgroundRefresh(application)

        return true
    }

    /// Called when the application enters the background
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background tasks for thread refresh and watched posts checking
        BackgroundTaskManager.shared.scheduleAllTasks()
    }
    
    /// Called when the application is about to enter the foreground
    // Lifecycle methods have been removed as they were only needed for OLED theme handling
    
    // MARK: - Background Refresh
    private func setupBackgroundRefresh(_ application: UIApplication) {
        // Set minimum background fetch interval for legacy API
        // This is deprecated in iOS 13+ but kept as a fallback
        // Primary background refresh is now handled by BackgroundTaskManager using BGTaskScheduler
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }

    // Legacy background fetch handler (iOS 12 and earlier)
    // Primary background refresh is now handled by BackgroundTaskManager using BGTaskScheduler
    @available(iOS, deprecated: 13.0, message: "Use BGTaskScheduler via BackgroundTaskManager instead")
    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Legacy background fetch started")

        // Check if notifications are enabled
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "channer_notifications_enabled")
        if !notificationsEnabled {
            completionHandler(.noData)
            return
        }

        let dispatchGroup = DispatchGroup()
        var hasAnyUpdates = false

        // Check favorited threads for updates
        let favorites = FavoritesManager.shared.loadFavorites()
        if !favorites.isEmpty {
            dispatchGroup.enter()
            checkForThreadUpdates(favorites) { hasNewData in
                if hasNewData { hasAnyUpdates = true }
                dispatchGroup.leave()
            }
        }

        // Check watched posts for replies
        let watchedPosts = WatchedPostsManager.shared.getWatchedPosts()
        if !watchedPosts.isEmpty {
            dispatchGroup.enter()
            checkWatchedPostsForReplies(watchedPosts) { hasNewReplies in
                if hasNewReplies { hasAnyUpdates = true }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completionHandler(hasAnyUpdates ? .newData : .noData)
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

                            // Get thread title - try API response first, then fall back to stored favorite data
                            var threadTitle: String? = firstPost["sub"].string

                            // If no subject from API, use stored title from favorite
                            if threadTitle == nil || threadTitle?.isEmpty == true {
                                threadTitle = favorite.title.isEmpty ? nil : favorite.title
                            }

                            // If still no title, create one from the comment (first 50 chars)
                            if threadTitle == nil || threadTitle?.isEmpty == true {
                                let comment = favorite.comment
                                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                    .replacingOccurrences(of: "&quot;", with: "\"")
                                    .replacingOccurrences(of: "&amp;", with: "&")
                                    .replacingOccurrences(of: "&lt;", with: "<")
                                    .replacingOccurrences(of: "&gt;", with: ">")
                                    .replacingOccurrences(of: "&#039;", with: "'")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                if !comment.isEmpty {
                                    threadTitle = String(comment.prefix(50)) + (comment.count > 50 ? "..." : "")
                                }
                            }

                            // Add in-app notification
                            NotificationManager.shared.addThreadUpdateNotification(
                                boardAbv: favorite.boardAbv,
                                threadNo: favorite.number,
                                threadTitle: threadTitle,
                                newReplyCount: newReplies
                            )

                            // Update the app badge count
                            self.updateApplicationBadgeCount()

                            // Send a push notification if there are new replies
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

    private func checkWatchedPostsForReplies(_ watchedPosts: [WatchedPost], completion: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var hasNewReplies = false

        // Group watched posts by thread to minimize API calls
        var postsByThread: [String: [WatchedPost]] = [:]
        for post in watchedPosts {
            let key = "\(post.boardAbv)/\(post.threadNo)"
            if postsByThread[key] == nil {
                postsByThread[key] = []
            }
            postsByThread[key]?.append(post)
        }

        for (_, posts) in postsByThread {
            guard let firstPost = posts.first else { continue }

            dispatchGroup.enter()

            let url = "https://a.4cdn.org/\(firstPost.boardAbv)/thread/\(firstPost.threadNo).json"

            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }

                switch response.result {
                case .success(let data):
                    if let json = try? JSON(data: data),
                       let postsArray = json["posts"].array {
                        // Convert to format expected by WatchedPostsManager
                        var threadReplies: [NSAttributedString] = []
                        var replyNumbers: [String] = []

                        for postJson in postsArray {
                            let postNo = String(postJson["no"].intValue)
                            let postText = postJson["com"].stringValue
                            replyNumbers.append(postNo)
                            threadReplies.append(NSAttributedString(string: postText))
                        }

                        // Check for new replies (this creates notifications internally)
                        let newCount = WatchedPostsManager.shared.checkForNewReplies(
                            threadNo: firstPost.threadNo,
                            boardAbv: firstPost.boardAbv,
                            threadReplies: threadReplies,
                            replyNumbers: replyNumbers
                        )

                        if newCount > 0 {
                            hasNewReplies = true

                            // Send push notification for replies to user's posts
                            for post in posts {
                                let isUserPost = MyPostsManager.shared.isUserPost(
                                    postNo: post.postNo,
                                    threadNo: post.threadNo,
                                    boardAbv: post.boardAbv
                                )

                                if isUserPost {
                                    self.sendReplyNotification(
                                        postNo: post.postNo,
                                        threadNo: post.threadNo,
                                        boardAbv: post.boardAbv
                                    )
                                }
                            }

                            self.updateApplicationBadgeCount()
                        }
                    }
                case .failure:
                    break
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(hasNewReplies)
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
            "boardAbv": boardAbv,
            "notificationType": "threadUpdate"
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

    private func sendReplyNotification(postNo: String, threadNo: String, boardAbv: String) {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "channer_notifications_enabled")
        if !notificationsEnabled {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Reply to Your Post"
        content.body = "Someone replied to your post >>\(postNo) in /\(boardAbv)/\(threadNo)"
        content.sound = UNNotificationSound.default

        // Add thread information to the notification userInfo
        content.userInfo = [
            "threadNumber": threadNo,
            "boardAbv": boardAbv,
            "postNo": postNo,
            "notificationType": "myPostReply"
        ]

        // Create a unique identifier for this notification
        let identifier = "reply-\(boardAbv)-\(threadNo)-\(postNo)-\(Date().timeIntervalSince1970)"

        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending reply notification: \(error.localizedDescription)")
            } else {
                print("Reply notification scheduled for post \(postNo)")
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

        // Use NotificationManager's unread count for badge
        let notificationBadgeCount = NotificationManager.shared.getUnreadCount()

        // Update the application badge
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = notificationBadgeCount
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
        
        // Global keyboard shortcuts are handled by each view controller
    }
    
    
    // MARK: - Navigation Controller Setup
    /// Creates the main navigation controller that will be used as the root view controller.
    func createRootNavigationController() -> UINavigationController {
        // Check the user's preferred board display mode
        let boardsDisplayModeKey = "channer_boards_display_mode"
        let boardsDisplayMode = UserDefaults.standard.integer(forKey: boardsDisplayModeKey)
        
        // Create the appropriate view controller based on the display mode
        let rootViewController: UIViewController
        
        print("DEBUG: Creating root view controller with display mode: \(boardsDisplayMode)")
        print("DEBUG: UserDefaults value: \(UserDefaults.standard.object(forKey: boardsDisplayModeKey) ?? "nil")")
        
        // 0 = Grid View (Collection View), 1 = List View (Table View)
        if boardsDisplayMode == 0 {
            // Use collection view (grid layout)
            print("DEBUG: Using collection view (grid) for boards")
            rootViewController = boardsCV(collectionViewLayout: UICollectionViewFlowLayout())
        } else {
            // Use table view (list layout)
            print("DEBUG: Using table view (list) for boards")
            rootViewController = boardsTV()
        }
        
        // Create a UINavigationController with customized back button
        let navigationController = UINavigationController(rootViewController: rootViewController)
        
        // Set the default back button title to an empty string
        // This removes the text but keeps the back arrow
        navigationController.navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        return navigationController
    }
    
    // Helper method to construct the table view controller with error handling
    private func constructBoardsTableViewController() -> UIViewController? {
        // First try with module name
        if let moduleClass = NSClassFromString("Channer.boardsTV") as? UIViewController.Type {
            print("Found boardsTV class with module name")
            return moduleClass.init()
        }
        
        // Try without module name
        if let noModuleClass = NSClassFromString("boardsTV") as? UIViewController.Type {
            print("Found boardsTV class without module name")
            return noModuleClass.init()
        }
        
        // Try other common variations
        let otherPossibleNames = ["BoardsTV", "_TtC7Channer8boardsTV"]
        for className in otherPossibleNames {
            if let variantClass = NSClassFromString(className) as? UIViewController.Type {
                print("Found boardsTV using variant name: \(className)")
                return variantClass.init()
            }
        }
        
        // If we get here, we've failed to create the boardsTV instance
        print("All attempts to create boardsTV failed")
        return nil
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
    
    // MARK: - Background Download Session Handler
    /// Handles events for background URL session downloads
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        if identifier == "com.channer.backgroundDownload" {
            DownloadManagerService.shared.handleBackgroundSessionCompletion(handler: completionHandler)
            print("DEBUG: Handling background download session events")
        } else {
            completionHandler()
        }
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
