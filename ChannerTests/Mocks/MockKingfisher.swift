//
//  MockKingfisher.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation
import UIKit
import Kingfisher

/// Mock implementation of Kingfisher components for testing image operations
class MockKingfisher {

    // MARK: - Shared Instance

    static let shared = MockKingfisher()

    // MARK: - Storage

    private var cachedImages: [String: UIImage] = [:]
    private var downloadedImages: [String: UIImage] = [:]

    // MARK: - Tracking

    private(set) var prefetchCallCount: Int = 0
    private(set) var prefetchedURLs: [URL] = []
    private(set) var downloadCallCount: Int = 0
    private(set) var downloadedURLs: [URL] = []
    private(set) var cacheStoreCallCount: Int = 0
    private(set) var cacheRetrieveCallCount: Int = 0

    // MARK: - Configuration

    var shouldFailDownload: Bool = false
    var downloadError: Error?
    var downloadDelay: TimeInterval = 0

    // MARK: - Mock Image Prefetcher

    class MockImagePrefetcher {
        weak var mockKingfisher: MockKingfisher?
        private let urls: [URL]

        init(urls: [URL], mockKingfisher: MockKingfisher = .shared) {
            self.urls = urls
            self.mockKingfisher = mockKingfisher
        }

        func start() {
            mockKingfisher?.prefetchCallCount += 1
            mockKingfisher?.prefetchedURLs.append(contentsOf: urls)

            // Simulate prefetching
            for url in urls {
                _ = mockKingfisher?.retrieveImage(from: url)
            }
        }

        func stop() {
            // No-op for mock
        }
    }

    // MARK: - Mock Image Cache

    class MockImageCache {
        weak var mockKingfisher: MockKingfisher?

        init(mockKingfisher: MockKingfisher = .shared) {
            self.mockKingfisher = mockKingfisher
        }

        func store(_ image: UIImage, forKey key: String, toDisk: Bool = true, completionHandler: (() -> Void)? = nil) {
            mockKingfisher?.cacheStoreCallCount += 1
            mockKingfisher?.cachedImages[key] = image
            completionHandler?()
        }

        func retrieveImage(forKey key: String, completionHandler: @escaping (Result<UIImage?, Error>) -> Void) {
            mockKingfisher?.cacheRetrieveCallCount += 1

            if let image = mockKingfisher?.cachedImages[key] {
                completionHandler(.success(image))
            } else {
                completionHandler(.success(nil))
            }
        }

        func isCached(forKey key: String) -> Bool {
            return mockKingfisher?.cachedImages[key] != nil
        }

        func removeImage(forKey key: String, completionHandler: (() -> Void)? = nil) {
            mockKingfisher?.cachedImages.removeValue(forKey: key)
            completionHandler?()
        }

        func clearCache(completionHandler: (() -> Void)? = nil) {
            mockKingfisher?.cachedImages.removeAll()
            completionHandler?()
        }
    }

    // MARK: - Image Retrieval

    func retrieveImage(from url: URL, completionHandler: ((Result<UIImage, Error>) -> Void)? = nil) -> UIImage? {
        downloadCallCount += 1
        downloadedURLs.append(url)

        // Check cache first
        let key = url.absoluteString
        if let cachedImage = cachedImages[key] {
            completionHandler?(.success(cachedImage))
            return cachedImage
        }

        // Simulate download
        if shouldFailDownload {
            let error = downloadError ?? NSError(domain: "MockKingfisher", code: -1, userInfo: nil)
            if downloadDelay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + downloadDelay) {
                    completionHandler?(.failure(error))
                }
            } else {
                completionHandler?(.failure(error))
            }
            return nil
        }

        // Create mock image
        let image = createMockImage(for: url)
        downloadedImages[key] = image
        cachedImages[key] = image

        if downloadDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + downloadDelay) {
                completionHandler?(.success(image))
            }
        } else {
            completionHandler?(.success(image))
        }

        return image
    }

    // MARK: - Image Prefetching

    func createPrefetcher(urls: [URL]) -> MockImagePrefetcher {
        return MockImagePrefetcher(urls: urls, mockKingfisher: self)
    }

    // MARK: - Cache Operations

    func storeImage(_ image: UIImage, forKey key: String) {
        cacheStoreCallCount += 1
        cachedImages[key] = image
    }

    func retrieveImageFromCache(forKey key: String) -> UIImage? {
        cacheRetrieveCallCount += 1
        return cachedImages[key]
    }

    func removeImageFromCache(forKey key: String) {
        cachedImages.removeValue(forKey: key)
    }

    func clearCache() {
        cachedImages.removeAll()
        downloadedImages.removeAll()
    }

    func isCached(forKey key: String) -> Bool {
        return cachedImages[key] != nil
    }

    // MARK: - Helper Methods

    private func createMockImage(for url: URL) -> UIImage {
        // Create a simple colored image for testing
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        // Use URL hash to create consistent color
        let hash = abs(url.absoluteString.hashValue)
        let red = CGFloat((hash >> 16) & 0xFF) / 255.0
        let green = CGFloat((hash >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hash & 0xFF) / 255.0

        UIColor(red: red, green: green, blue: blue, alpha: 1.0).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        cachedImages.removeAll()
        downloadedImages.removeAll()
        prefetchCallCount = 0
        prefetchedURLs.removeAll()
        downloadCallCount = 0
        downloadedURLs.removeAll()
        cacheStoreCallCount = 0
        cacheRetrieveCallCount = 0
        shouldFailDownload = false
        downloadError = nil
        downloadDelay = 0
    }

    /// Pre-populate cache with images for testing
    func preloadCache(with images: [String: UIImage]) {
        cachedImages.merge(images) { (_, new) in new }
    }

    /// Check if URL was prefetched
    func wasPrefetched(url: URL) -> Bool {
        return prefetchedURLs.contains(url)
    }

    /// Check if URL was downloaded
    func wasDownloaded(url: URL) -> Bool {
        return downloadedURLs.contains(url)
    }

    /// Get all cached keys
    func allCachedKeys() -> [String] {
        return Array(cachedImages.keys)
    }

    /// Get cache count
    var cacheCount: Int {
        return cachedImages.count
    }
}

// MARK: - Mock KingfisherManager

class MockKingfisherManager {
    static let shared = MockKingfisherManager()

    let cache = MockKingfisher.MockImageCache()
    private let mockKingfisher = MockKingfisher.shared

    func retrieveImage(
        with url: URL,
        completionHandler: @escaping (Result<UIImage, Error>) -> Void
    ) {
        _ = mockKingfisher.retrieveImage(from: url, completionHandler: completionHandler)
    }

    func retrieveImage(
        with url: URL,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil
    ) {
        _ = mockKingfisher.retrieveImage(from: url) { result in
            switch result {
            case .success(let image):
                let retrieveResult = RetrieveImageResult(
                    image: image,
                    cacheType: .none,
                    source: .network(url)
                )
                completionHandler?(.success(retrieveResult))
            case .failure(let error):
                let kfError = KingfisherError.requestError(reason: .taskCancelled(task: nil, token: nil))
                completionHandler?(.failure(kfError))
            }
        }
    }
}

// MARK: - UIImageView Extension for Testing

extension UIImageView {
    /// Mock version of kf.setImage for testing
    func mockSetImage(with url: URL, placeholder: UIImage? = nil, completionHandler: ((Result<UIImage, Error>) -> Void)? = nil) {
        image = placeholder
        _ = MockKingfisher.shared.retrieveImage(from: url) { result in
            switch result {
            case .success(let image):
                self.image = image
                completionHandler?(.success(image))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
}
