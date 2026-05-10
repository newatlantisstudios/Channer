import Foundation
import SwiftyJSON

/// Helper class for processing thread data with content filtering
class ThreadDataHelper {
    
    // MARK: - Static Methods
    
    /// Applies content filtering to thread JSON data
    /// - Parameter threadData: Raw thread JSON data to filter
    /// - Returns: Filtered thread data or original data if filtering fails/disabled
    static func applyContentFiltering(to threadData: Data) -> Data? {
        // Only apply filtering if it's enabled
        if !ContentFilterManager.shared.isFilteringEnabled() && !ContentFilterManager.shared.isAdvancedFilteringEnabled() {
            return threadData
        }
        
        do {
            // Parse the JSON data
            let json = try JSON(data: threadData)
            let filteredJSON = filterPosts(in: json)
            return try filteredJSON.rawData()
        } catch {
            print("Error applying content filtering: \(error)")
            return threadData // Return original data if filtering fails
        }
    }
    
    /// Determines if a thread should be hidden based on content filters
    /// - Parameters:
    ///   - boardAbv: Board abbreviation
    ///   - threadNumber: Thread ID number
    ///   - threadJSON: Parsed thread JSON data
    /// - Returns: True if thread should be filtered/hidden, false otherwise
    static func shouldFilterThread(boardAbv: String, threadNumber: String, threadJSON: JSON) -> Bool {
        // Only check filtering if it's enabled
        if !ContentFilterManager.shared.isFilteringEnabled() && !ContentFilterManager.shared.isAdvancedFilteringEnabled() {
            return false
        }
        
        let firstPost = threadJSON["posts"].array?.first ?? threadJSON
        let metadata = postMetadata(
            from: firstPost,
            boardAbv: boardAbv,
            threadNumber: threadNumber,
            isOP: true,
            isTopThread: true
        )
        return ContentFilterManager.shared.filterResult(for: metadata).isFiltered
    }
    
    /// Applies content filtering to a collection of thread JSON objects
    /// - Parameter threads: Array of thread JSON objects to filter
    /// - Returns: Filtered array with unwanted threads removed
    static func applyFiltering(to threads: [JSON]) -> [JSON] {
        // Only apply filtering if it's enabled
        if !ContentFilterManager.shared.isFilteringEnabled() && !ContentFilterManager.shared.isAdvancedFilteringEnabled() {
            return threads
        }
        
        return threads.filter { thread in
            let boardAbv = thread["board"].stringValue
            let post = thread["posts"].array?.first ?? thread
            let threadNumber = post["no"].stringValue
            return !shouldFilterThread(boardAbv: boardAbv, threadNumber: threadNumber, threadJSON: thread)
        }
    }

    static func filterPosts(in json: JSON, boardAbv: String? = nil, threadNumber: String? = nil) -> JSON {
        var filteredJSON = json
        let posts = json["posts"].arrayValue
        guard !posts.isEmpty else { return json }

        let resolvedBoard = boardAbv ?? json["board"].string
        let resolvedThread = threadNumber ?? posts.first?["no"].stringValue
        let metadata = posts.enumerated().map { index, post in
            postMetadata(
                from: post,
                boardAbv: resolvedBoard,
                threadNumber: resolvedThread,
                isOP: index == 0,
                isTopThread: index == 0
            )
        }

        let results = ContentFilterManager.shared.filterResults(for: metadata)
        var outputPosts: [Any] = []
        for (index, post) in posts.enumerated() {
            let postNo = metadata[index].postNumber
            guard let result = results[postNo], result.isFiltered else {
                outputPosts.append(post.object)
                continue
            }

            if result.showStub {
                var stub = post
                let reason = result.reasons.joined(separator: " & ")
                stub["com"].string = reason.isEmpty ? "Filtered" : "Filtered: \(reason)"
                stub["filename"].string = nil
                stub["tim"].int = nil
                stub["ext"].string = nil
                outputPosts.append(stub.object)
            }
        }
        filteredJSON["posts"].arrayObject = outputPosts
        return filteredJSON
    }

    static func postMetadata(
        from post: JSON,
        boardAbv: String?,
        threadNumber: String?,
        isOP: Bool,
        isTopThread: Bool = false
    ) -> PostMetadata {
        let ext = post["ext"].string
        let filename = post["filename"].string
        let displayFilename: String?
        if let filename = filename, let ext = ext {
            displayFilename = "\(filename)\(ext)"
        } else {
            displayFilename = filename
        }

        let imageURL: String?
        if let boardAbv = boardAbv,
           let tim = post["tim"].int64,
           let ext = ext {
            imageURL = "https://i.4cdn.org/\(boardAbv)/\(tim)\(ext)"
        } else {
            imageURL = nil
        }

        let dimensions: String?
        if let width = post["w"].int, let height = post["h"].int {
            dimensions = "\(width)x\(height)"
        } else {
            dimensions = nil
        }

        let fileSize = post["fsize"].int.map { "\($0)" }

        return PostMetadata(
            postNumber: post["no"].stringValue,
            comment: post["com"].stringValue,
            posterId: post["id"].string?.nilIfEmpty,
            tripCode: post["trip"].string?.nilIfEmpty,
            countryCode: post["country"].string?.nilIfEmpty,
            countryName: post["country_name"].string?.nilIfEmpty,
            timestamp: post["time"].int,
            imageUrl: imageURL,
            imageExtension: ext,
            imageName: displayFilename,
            fileHash: post["md5"].string?.nilIfEmpty,
            boardAbv: boardAbv,
            threadNumber: threadNumber,
            subject: post["sub"].string?.nilIfEmpty,
            name: post["name"].string?.nilIfEmpty,
            email: post["email"].string?.nilIfEmpty,
            capcode: post["capcode"].string?.nilIfEmpty,
            passDate: post["since4pass"].string?.nilIfEmpty,
            imageDimensions: dimensions,
            imageFileSize: fileSize,
            isOP: isOP,
            isTopThread: isTopThread
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}
