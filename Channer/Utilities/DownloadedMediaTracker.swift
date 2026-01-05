import Foundation

/// Tracks media that has been downloaded/saved to prevent duplicate downloads
/// Used for tracking saves to Photos library (file-based downloads can check filesystem directly)
class DownloadedMediaTracker {
    static let shared = DownloadedMediaTracker()

    private let savedMediaKey = "channer_saved_media_urls"
    private let syncQueue = DispatchQueue(label: "com.channer.downloadedmedia.sync", attributes: .concurrent)

    private init() {}

    // MARK: - Photos Library Tracking

    /// Checks if a media URL has already been saved to Photos
    func hasBeenSavedToPhotos(url: URL) -> Bool {
        return hasBeenSavedToPhotos(urlString: url.absoluteString)
    }

    /// Checks if a media URL string has already been saved to Photos
    func hasBeenSavedToPhotos(urlString: String) -> Bool {
        var result = false
        syncQueue.sync {
            let savedURLs = fetchSavedURLsFromDefaults()
            result = savedURLs.contains(urlString)
        }
        return result
    }

    /// Marks a media URL as saved to Photos
    func markAsSavedToPhotos(url: URL) {
        markAsSavedToPhotos(urlString: url.absoluteString)
    }

    /// Marks a media URL string as saved to Photos
    func markAsSavedToPhotos(urlString: String) {
        syncQueue.sync(flags: .barrier) {
            var savedURLs = fetchSavedURLsFromDefaults()

            // Don't add duplicates
            guard !savedURLs.contains(urlString) else { return }

            savedURLs.append(urlString)
            saveSavedURLs(savedURLs)
        }
    }

    /// Removes a media URL from the saved list (if user deletes from Photos)
    func removeFromSavedToPhotos(url: URL) {
        removeFromSavedToPhotos(urlString: url.absoluteString)
    }

    /// Removes a media URL string from the saved list
    func removeFromSavedToPhotos(urlString: String) {
        syncQueue.sync(flags: .barrier) {
            var savedURLs = fetchSavedURLsFromDefaults()
            savedURLs.removeAll { $0 == urlString }
            saveSavedURLs(savedURLs)
        }
    }

    /// Clears all saved media tracking data
    func clearAllSavedMediaTracking() {
        syncQueue.sync(flags: .barrier) {
            UserDefaults.standard.removeObject(forKey: savedMediaKey)
        }
    }

    // MARK: - File System Checks

    /// Checks if a file already exists at the given destination URL
    static func fileExists(at destinationURL: URL) -> Bool {
        return FileManager.default.fileExists(atPath: destinationURL.path)
    }

    /// Checks if a video already exists in the webm directory
    static func videoExistsInWebMDirectory(filename: String) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let webmDir = documentsPath.appendingPathComponent("webm", isDirectory: true)
        let destinationURL = webmDir.appendingPathComponent(filename)
        return fileExists(at: destinationURL)
    }

    /// Checks if a media file already exists in the images or media directory
    static func mediaExistsInDirectory(filename: String, folderName: String) -> Bool {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        let destinationURL = folderURL.appendingPathComponent(filename)
        return fileExists(at: destinationURL)
    }

    // MARK: - Private Methods

    private func fetchSavedURLsFromDefaults() -> [String] {
        return UserDefaults.standard.stringArray(forKey: savedMediaKey) ?? []
    }

    private func saveSavedURLs(_ urls: [String]) {
        UserDefaults.standard.set(urls, forKey: savedMediaKey)
    }
}
