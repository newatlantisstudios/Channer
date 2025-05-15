import UIKit
import UserNotifications
import Alamofire
import SwiftyJSON
import Kingfisher

// MARK: - Thread Cache Manager
class ThreadCacheManager {
    
    // MARK: - Singleton Instance
    static let shared = ThreadCacheManager()
    
    // MARK: - Properties
    private let threadCacheKey = "cachedThreads"
    private let offlineEnabledKey = "channer_offline_reading_enabled"
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let fileManager = FileManager.default
    
    // In-memory cache
    private(set) var cachedThreads: [CachedThread] = []
    
    // MARK: - Initialization
    private init() {
        loadCachedThreads()
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(cloudStoreDidChange),
                                              name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, 
                                              object: iCloudStore)
    }
    
    // MARK: - Public Methods
    
    /// Checks if offline reading mode is enabled
    func isOfflineReadingEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: offlineEnabledKey)
    }
    
    /// Sets whether offline reading mode is enabled
    func setOfflineReadingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: offlineEnabledKey)
    }
    
    /// Saves a thread for offline reading
    func cacheThread(boardAbv: String, threadNumber: String, completion: @escaping (Bool) -> Void) {
        // Check if thread is already cached
        if isCached(boardAbv: boardAbv, threadNumber: threadNumber) {
            print("Thread already cached")
            completion(true)
            return
        }
        
        // Fetch thread data
        let urlString = "https://a.4cdn.org/\(boardAbv)/thread/\(threadNumber).json"
        
        AF.request(urlString).responseData { [weak self] response in
            guard let self = self else { 
                completion(false)
                return
            }
            
            switch response.result {
            case .success(let data):
                do {
                    // Parse JSON data
                    let json = try JSON(data: data)
                    
                    // Create cached thread model with thread data
                    let cachedThread = CachedThread(
                        boardAbv: boardAbv,
                        threadNumber: threadNumber,
                        threadData: data,
                        cachedImages: [],
                        cachedDate: Date()
                    )
                    
                    // Add to memory cache
                    self.cachedThreads.append(cachedThread)
                    
                    // Save to persistent storage
                    self.saveCachedThreads()
                    
                    // Start caching images
                    self.cacheImages(for: cachedThread, json: json)
                    
                    completion(true)
                } catch {
                    print("Error caching thread: \(error)")
                    completion(false)
                }
            case .failure(let error):
                print("Network error when caching thread: \(error)")
                completion(false)
            }
        }
    }
    
    /// Removes a thread from the cache
    func removeFromCache(boardAbv: String, threadNumber: String) {
        // Remove from memory cache
        cachedThreads.removeAll { $0.boardAbv == boardAbv && $0.threadNumber == threadNumber }
        
        // Delete any cached images
        deleteImageCache(boardAbv: boardAbv, threadNumber: threadNumber)
        
        // Save updated cache to persistent storage
        saveCachedThreads()
    }
    
    /// Checks if a thread is cached for offline reading
    func isCached(boardAbv: String, threadNumber: String) -> Bool {
        return cachedThreads.contains { $0.boardAbv == boardAbv && $0.threadNumber == threadNumber }
    }
    
    /// Retrieves cached thread data if available
    func getCachedThread(boardAbv: String, threadNumber: String) -> Data? {
        if let cachedThread = cachedThreads.first(where: { $0.boardAbv == boardAbv && $0.threadNumber == threadNumber }) {
            return cachedThread.threadData
        }
        return nil
    }
    
    /// Gets a list of all cached threads
    func getAllCachedThreads() -> [CachedThread] {
        return cachedThreads
    }
    
    /// Clears all cached threads
    func clearAllCachedThreads() {
        // Delete all image caches
        for thread in cachedThreads {
            deleteImageCache(boardAbv: thread.boardAbv, threadNumber: thread.threadNumber)
        }
        
        // Clear memory cache
        cachedThreads.removeAll()
        
        // Update persistent storage
        saveCachedThreads()
    }
    
    // MARK: - Private Methods
    
    private func loadCachedThreads() {
        if isICloudAvailable() {
            print("Loading cached threads from iCloud")
            if let data = iCloudStore.data(forKey: threadCacheKey),
               let loadedCache = try? JSONDecoder().decode([CachedThread].self, from: data) {
                cachedThreads = loadedCache
            }
        } else {
            print("Loading cached threads from local storage")
            if let data = UserDefaults.standard.data(forKey: threadCacheKey),
               let loadedCache = try? JSONDecoder().decode([CachedThread].self, from: data) {
                cachedThreads = loadedCache
            }
        }
    }
    
    private func saveCachedThreads() {
        do {
            let encodedData = try JSONEncoder().encode(cachedThreads)
            
            if isICloudAvailable() {
                print("Saving cached threads to iCloud")
                iCloudStore.set(encodedData, forKey: threadCacheKey)
                iCloudStore.synchronize()
            } else {
                print("Saving cached threads to local storage")
                UserDefaults.standard.set(encodedData, forKey: threadCacheKey)
            }
        } catch {
            print("Error encoding cached threads: \(error)")
        }
    }
    
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    @objc private func cloudStoreDidChange(_ notification: Notification) {
        loadCachedThreads()
    }
    
    private func cacheImages(for thread: CachedThread, json: JSON) {
        let posts = json["posts"].arrayValue
        var imageURLs: [URL] = []
        
        // Extract image URLs from the thread
        for post in posts {
            if let tim = post["tim"].string, let ext = post["ext"].string {
                let imageURLString = "https://i.4cdn.org/\(thread.boardAbv)/\(tim)\(ext)"
                if let url = URL(string: imageURLString) {
                    imageURLs.append(url)
                }
            }
        }
        
        // Cache each image
        cacheImages(urls: imageURLs, for: thread)
    }
    
    private func cacheImages(urls: [URL], for thread: CachedThread) {
        let prefetcher = ImagePrefetcher(urls: urls)
        
        // Just cache the URLs without using the completion handler
        prefetcher.start()
        
        // Update thread with the URLs we want to cache
        var updatedThread = thread
        updatedThread.cachedImages = urls.map { $0.absoluteString }
        
        // Update in memory cache
        if let index = self.cachedThreads.firstIndex(where: { 
            $0.boardAbv == thread.boardAbv && $0.threadNumber == thread.threadNumber 
        }) {
            self.cachedThreads[index] = updatedThread
            self.saveCachedThreads()
        }
    }
    
    private func deleteImageCache(boardAbv: String, threadNumber: String) {
        // Find the thread to get its cached images
        if let thread = cachedThreads.first(where: { $0.boardAbv == boardAbv && $0.threadNumber == threadNumber }) {
            // Create URLs from the cached image strings
            let imageURLs = thread.cachedImages.compactMap { URL(string: $0) }
            
            // Remove each image from the Kingfisher cache
            for url in imageURLs {
                KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
            }
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
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
        
        // Initialize the offline reading mode setting in ThreadCacheManager
        let isOfflineReadingEnabled = UserDefaults.standard.bool(forKey: offlineReadingEnabledKey)
        ThreadCacheManager.shared.setOfflineReadingEnabled(isOfflineReadingEnabled)
        
        // Check if user was using OLED Black theme (which has been removed)
        let themeKey = "channer_selected_theme_id"
        if let currentTheme = UserDefaults.standard.string(forKey: themeKey), currentTheme == "oled_black" {
            // Convert to Dark Purple theme instead
            UserDefaults.standard.set("dark_purple", forKey: themeKey)
            UserDefaults.standard.synchronize()
            print("Converted user from removed OLED Black theme to Dark Purple theme")
        }
        
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
    }
    
    // MARK: - Navigation Controller Setup
    /// Creates the main navigation controller that will be used as the root view controller.
    private func createRootNavigationController() -> UINavigationController {
        let boardsController = boardsCV(collectionViewLayout: UICollectionViewFlowLayout())
        boardsController.title = "Boards"
        
        // Create a UINavigationController with customized back button
        let navigationController = UINavigationController(rootViewController: boardsController)
        
        // Set the default back button title to an empty string
        // This removes the text but keeps the back arrow
        navigationController.navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        return navigationController
    }
}
