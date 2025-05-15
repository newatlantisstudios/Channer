import Foundation
import Alamofire
import SwiftyJSON
import Kingfisher

/// A manager for caching thread data and content for offline reading
class ThreadCacheManager {
    
    // MARK: - Singleton Instance
    static let shared = ThreadCacheManager()
    
    // MARK: - Properties
    private let threadCacheKey = "cachedThreads"
    private let offlineEnabledKey = "offlineReadingEnabled"
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
        let prefetcher = ImagePrefetcher(urls: urls) { skippedResources, failedResources, completedResources in
            print("Cached \(completedResources.count) images for thread \(thread.threadNumber)")
            
            // Update cached thread with list of cached image URLs
            var updatedThread = thread
            updatedThread.cachedImages = completedResources.map { $0.url.absoluteString }
            
            // Update in memory cache
            if let index = self.cachedThreads.firstIndex(where: { 
                $0.boardAbv == thread.boardAbv && $0.threadNumber == thread.threadNumber 
            }) {
                self.cachedThreads[index] = updatedThread
                self.saveCachedThreads()
            }
        }
        
        prefetcher.start()
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
    
    /// Gets the cache directory path for a specific thread
    private func getCacheDirectoryPath(boardAbv: String, threadNumber: String) -> URL? {
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let threadCacheDirectory = cachesDirectory.appendingPathComponent("ThreadCache/\(boardAbv)/\(threadNumber)")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: threadCacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: threadCacheDirectory, withIntermediateDirectories: true)
                return threadCacheDirectory
            } catch {
                print("Error creating thread cache directory: \(error)")
                return nil
            }
        }
        
        return threadCacheDirectory
    }
}

// MARK: - Data Models

/// Represents a thread cached for offline reading
struct CachedThread: Codable {
    let boardAbv: String
    let threadNumber: String
    let threadData: Data
    var cachedImages: [String]
    let cachedDate: Date
    
    // Helper to get basic thread info for UI
    func getThreadInfo() -> ThreadData? {
        do {
            let json = try JSON(data: threadData)
            if let posts = json["posts"].array, let firstPost = posts.first {
                // Extract info from the first post
                let number = String(describing: firstPost["no"])
                let comment = firstPost["com"].stringValue
                let imageTimestamp = firstPost["tim"].stringValue
                let imageExt = firstPost["ext"].stringValue
                let imageURL = "https://i.4cdn.org/\(boardAbv)/\(imageTimestamp)\(imageExt)"
                let replyCount = posts.count - 1
                let imageCount = posts.filter { $0["tim"].exists() }.count
                
                return ThreadData(
                    number: number,
                    stats: "\(replyCount)/\(imageCount)",
                    title: "",
                    comment: comment,
                    imageUrl: imageURL,
                    boardAbv: boardAbv,
                    replies: replyCount,
                    createdAt: ""
                )
            }
        } catch {
            print("Error parsing cached thread data: \(error)")
        }
        return nil
    }
}