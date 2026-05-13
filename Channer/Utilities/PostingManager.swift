import Foundation
import Alamofire

/// Manages post submission to 4chan
class PostingManager {

    static let shared = PostingManager()

    private let syncQueue = DispatchQueue(label: "com.channer.postingmanager.sync", attributes: .concurrent)

    /// Base URL for posting
    private let postingBaseURL = "https://sys.4chan.org"

    /// Last post time for rate limiting
    private var lastPostTime: Date?

    /// Minimum time between posts (in seconds)
    private let minimumPostInterval: TimeInterval = 30

    private init() {}

    // MARK: - Public Methods

    /// Submit a post to 4chan
    /// - Parameters:
    ///   - postData: The post data to submit
    ///   - completion: Callback with the result
    func submitPost(_ postData: PostData, completion: @escaping (Result<PostResult, PostingError>) -> Void) {
        guard BoardsService.shared.selectedSite.supportsPosting else {
            completion(.failure(.serverError("Posting is only supported on 4chan. Other imageboard sites are read-only.")))
            return
        }

        // Validate post data
        if let validationError = validatePost(postData) {
            completion(.failure(validationError))
            return
        }

        // Check rate limiting
        if let lastTime = lastPostTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumPostInterval {
                completion(.failure(.rateLimited))
                return
            }
        }

        // Build URL
        let url = "\(postingBaseURL)/\(postData.board)/post"

        // Generate deletion password
        let password = PostData.generatePassword()

        // Build headers with cookies
        var headers: HTTPHeaders = [
            "Referer": "https://boards.4chan.org/\(postData.board)/",
            "Origin": "https://boards.4chan.org"
        ]

        // Add cookie header
        if let cookieHeader = PassAuthManager.shared.getCookieHeader() {
            headers.add(name: "Cookie", value: cookieHeader)
        }

        debugLogPostRequest(postData, url: url, headers: headers)

        // Upload with multipart form data
        AF.upload(multipartFormData: { multipartFormData in
            // Required fields
            multipartFormData.append("regist".data(using: .utf8)!, withName: "mode")
            multipartFormData.append(String(postData.resto).data(using: .utf8)!, withName: "resto")
            multipartFormData.append(password.data(using: .utf8)!, withName: "pwd")

            // Comment (required)
            multipartFormData.append(postData.comment.data(using: .utf8)!, withName: "com")

            // Optional fields
            if let name = postData.name, !name.isEmpty {
                multipartFormData.append(name.data(using: .utf8)!, withName: "name")
            }

            if let email = postData.email, !email.isEmpty {
                multipartFormData.append(email.data(using: .utf8)!, withName: "email")
            }

            if let subject = postData.subject, !subject.isEmpty {
                multipartFormData.append(subject.data(using: .utf8)!, withName: "sub")
            }

            // Image upload
            if let imageData = postData.imageData,
               let filename = postData.imageFilename,
               let mimeType = postData.imageMimeType {
                multipartFormData.append(imageData, withName: "upfile", fileName: filename, mimeType: mimeType)
            }

            // Spoiler flag
            if postData.spoiler {
                multipartFormData.append("on".data(using: .utf8)!, withName: "spoiler")
            }

            if let captchaChallenge = postData.captchaChallenge, !captchaChallenge.isEmpty {
                multipartFormData.append(captchaChallenge.data(using: .utf8)!, withName: "t-challenge")
            }

            if let captchaResponse = postData.captchaResponse, !captchaResponse.isEmpty {
                multipartFormData.append(captchaResponse.data(using: .utf8)!, withName: "t-response")
            }

        }, to: url, headers: headers)
        .responseData { [weak self] response in
            self?.handlePostResponse(response, completion: completion)
        }
    }

    /// Submit a reply to a thread
    /// - Parameters:
    ///   - board: Board abbreviation
    ///   - threadNumber: Thread number to reply to
    ///   - comment: Reply comment text
    ///   - name: Optional poster name
    ///   - email: Optional email/options
    ///   - imageData: Optional image data
    ///   - imageFilename: Optional image filename
    ///   - imageMimeType: Optional image MIME type
    ///   - spoiler: Whether to spoiler the image
    ///   - captchaChallenge: Captcha challenge id for non-Pass posting
    ///   - captchaResponse: Captcha response for non-Pass posting
    ///   - completion: Callback with result
    func submitReply(
        board: String,
        threadNumber: Int,
        comment: String,
        name: String? = nil,
        email: String? = nil,
        imageData: Data? = nil,
        imageFilename: String? = nil,
        imageMimeType: String? = nil,
        spoiler: Bool = false,
        captchaChallenge: String? = nil,
        captchaResponse: String? = nil,
        completion: @escaping (Result<PostResult, PostingError>) -> Void
    ) {
        let postData = PostData(
            board: board,
            resto: threadNumber,
            name: name,
            email: email,
            subject: nil,
            comment: comment,
            imageData: imageData,
            imageFilename: imageFilename,
            imageMimeType: imageMimeType,
            spoiler: spoiler,
            captchaChallenge: captchaChallenge,
            captchaResponse: captchaResponse
        )

        submitPost(postData, completion: completion)
    }

    /// Submit a new thread
    /// - Parameters:
    ///   - board: Board abbreviation
    ///   - subject: Thread subject
    ///   - comment: Thread comment text
    ///   - name: Optional poster name
    ///   - email: Optional email/options
    ///   - imageData: Required image data
    ///   - imageFilename: Image filename
    ///   - imageMimeType: Image MIME type
    ///   - spoiler: Whether to spoiler the image
    ///   - captchaChallenge: Captcha challenge id for non-Pass posting
    ///   - captchaResponse: Captcha response for non-Pass posting
    ///   - completion: Callback with result
    func submitNewThread(
        board: String,
        subject: String?,
        comment: String,
        name: String? = nil,
        email: String? = nil,
        imageData: Data,
        imageFilename: String,
        imageMimeType: String,
        spoiler: Bool = false,
        captchaChallenge: String? = nil,
        captchaResponse: String? = nil,
        completion: @escaping (Result<PostResult, PostingError>) -> Void
    ) {
        let postData = PostData(
            board: board,
            resto: 0,
            name: name,
            email: email,
            subject: subject,
            comment: comment,
            imageData: imageData,
            imageFilename: imageFilename,
            imageMimeType: imageMimeType,
            spoiler: spoiler,
            captchaChallenge: captchaChallenge,
            captchaResponse: captchaResponse
        )

        submitPost(postData, completion: completion)
    }

    /// Delete a post or only its attached image using 4chan's deletion form.
    /// - Parameters:
    ///   - board: Board abbreviation.
    ///   - postNumber: Post number to delete.
    ///   - password: Deletion password used when the post was submitted.
    ///   - imageOnly: Whether to delete only the attached image.
    ///   - completion: Callback with the deletion result.
    func deletePost(
        board: String,
        postNumber: String,
        password: String,
        imageOnly: Bool,
        completion: @escaping (Result<Void, PostingError>) -> Void
    ) {
        guard !board.isEmpty, !postNumber.isEmpty else {
            completion(.failure(.invalidBoard))
            return
        }

        let url = "\(postingBaseURL)/\(board)/imgboard.php"

        var headers: HTTPHeaders = [
            "Referer": "https://boards.4chan.org/\(board)/",
            "Origin": "https://boards.4chan.org"
        ]

        if let cookieHeader = PassAuthManager.shared.getCookieHeader() {
            headers.add(name: "Cookie", value: cookieHeader)
        }

        var parameters: [String: String] = [
            "mode": "usrdel",
            "pwd": password,
            postNumber: "delete"
        ]

        if imageOnly {
            parameters["onlyimgdel"] = "on"
        }

        AF.request(url, method: .post, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default, headers: headers)
            .responseString { response in
                switch response.result {
                case .success(let htmlString):
                    if let errorMessage = PostingResponseParser.errorMessage(from: htmlString) {
                        completion(.failure(.serverError(errorMessage)))
                        return
                    }

                    if htmlString.lowercased().contains("banned") {
                        completion(.failure(.banned))
                        return
                    }

                    completion(.success(()))

                case .failure(let error):
                    completion(.failure(.networkError(error)))
                }
            }
    }

    // MARK: - Private Methods

    /// Validate post data before submission
    private func validatePost(_ postData: PostData) -> PostingError? {
        // Check board
        if postData.board.isEmpty {
            return .invalidBoard
        }

        // Check comment (allow empty if image is attached)
        if postData.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           postData.imageData == nil {
            return .emptyComment
        }

        // Check image for new threads (most boards require it)
        if postData.isNewThread && postData.imageData == nil {
            return .imageRequired
        }

        // Check image size (4MB limit for most boards)
        if let imageData = postData.imageData {
            let maxSize = 4 * 1024 * 1024 // 4MB
            if imageData.count > maxSize {
                return .imageTooLarge
            }
        }

        if !PassAuthManager.shared.isAuthenticated {
            let challenge = postData.captchaChallenge?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if challenge.isEmpty {
                return .captchaRequired
            }
        }

        return nil
    }

    /// Handle the response from the posting request
    private func handlePostResponse(
        _ response: AFDataResponse<Data>,
        completion: @escaping (Result<PostResult, PostingError>) -> Void
    ) {
        switch response.result {
        case .success(let data):
            // Parse HTML response
            let htmlString = String(data: data, encoding: .utf8) ?? ""

            print("=== PostingManager RESPONSE DEBUG ===")
            print("Request URL: \(response.request?.url?.absoluteString ?? "nil")")
            print("Final URL: \(response.response?.url?.absoluteString ?? "nil")")
            print("HTTP Status: \(response.response?.statusCode ?? -1)")
            print("MIME Type: \(response.response?.mimeType ?? "nil")")
            print("Response bytes: \(data.count)")
            print("Response chars: \(htmlString.count)")
            print("Response headers: \(PostingDebugFormatter.redactedHeaders(response.response?.allHeaderFields))")
            print("HTML title: \(PostingResponseParser.title(from: htmlString) ?? "nil")")
            print("Parser isErrorPage: \(PostingResponseParser.isErrorPage(htmlString))")
            print("Parser success: \(String(describing: PostingResponseParser.success(from: htmlString)))")
            print("Parser errorMessage: \(PostingResponseParser.errorMessage(from: htmlString) ?? "nil")")
            print("Response preview: \(PostingDebugFormatter.redactedPreview(htmlString, limit: 2000))")
            print("=== END RESPONSE DEBUG ===")

            // Check if 4chan explicitly marks this as an error page via JS variable
            // 4chan returns full board pages with is_error = "true" on post failure
            let isErrorPage = PostingResponseParser.isErrorPage(htmlString)

            if !isErrorPage {
                // Only check for success if this is NOT an error page.
                // 4chan's current success page uses title "Post successful!" and body text:
                // "thread:<threadNumber>,no:<postNumber>".
                if let success = PostingResponseParser.success(from: htmlString) {
                    lastPostTime = Date()
                    if success.isNewThread {
                        completion(.success(PostResult.success(threadNumber: success.threadNumber)))
                    } else {
                        completion(.success(PostResult.success(postNumber: success.postNumber)))
                    }
                    return
                }
            }

            // Check for error message
            if let errorMessage = PostingResponseParser.errorMessage(from: htmlString) {
                let msg = errorMessage.lowercased()
                if msg.contains("banned") {
                    completion(.failure(.banned))
                } else if msg.contains("captcha") || msg.contains("verification") {
                    completion(.failure(.invalidCaptcha))
                } else if msg.contains("wait") || msg.contains("flood") {
                    completion(.failure(.rateLimited))
                } else if msg.contains("closed") {
                    completion(.failure(.threadClosed))
                } else if msg.contains("archived") {
                    completion(.failure(.threadArchived))
                } else {
                    completion(.failure(.serverError(errorMessage)))
                }
                return
            }

            // If we know it's an error but couldn't extract the message
            if isErrorPage {
                completion(.failure(.serverError("Post failed. Check your 4chan Pass authentication and try again.")))
                return
            }

            // Unknown response
            completion(.failure(.serverError("Unknown server response")))

        case .failure(let error):
            print("=== PostingManager RESPONSE DEBUG ===")
            print("Request URL: \(response.request?.url?.absoluteString ?? "nil")")
            print("HTTP Status: \(response.response?.statusCode ?? -1)")
            print("MIME Type: \(response.response?.mimeType ?? "nil")")
            print("Response headers: \(PostingDebugFormatter.redactedHeaders(response.response?.allHeaderFields))")
            if let data = response.data, let htmlString = String(data: data, encoding: .utf8) {
                print("Response bytes: \(data.count)")
                print("Response chars: \(htmlString.count)")
                print("Response preview: \(PostingDebugFormatter.redactedPreview(htmlString, limit: 2000))")
            }
            print("Network error: \(error)")
            print("=== END RESPONSE DEBUG ===")
            completion(.failure(.networkError(error)))
        }
    }

    private func debugLogPostRequest(_ postData: PostData, url: String, headers: HTTPHeaders) {
        let headerSummary = headers.map { header -> String in
            if header.name.caseInsensitiveCompare("Cookie") == .orderedSame {
                return "\(header.name): [redacted \(header.value.count) chars]"
            }
            return "\(header.name): \(header.value)"
        }.joined(separator: ", ")

        var fieldSummary: [String] = [
            "mode=regist",
            "resto=\(postData.resto)",
            "pwd=[redacted]",
            "com=[\(postData.comment.count) chars]"
        ]

        if let name = postData.name, !name.isEmpty {
            fieldSummary.append("name=[\(name.count) chars]")
        }
        if let email = postData.email, !email.isEmpty {
            fieldSummary.append("email=\(PostingDebugFormatter.safeShortValue(email, limit: 80))")
        }
        if let subject = postData.subject, !subject.isEmpty {
            fieldSummary.append("sub=[\(subject.count) chars]")
        }
        if let imageData = postData.imageData {
            let filename = postData.imageFilename ?? "nil"
            let mimeType = postData.imageMimeType ?? "nil"
            fieldSummary.append("upfile=\(filename) \(mimeType) \(imageData.count) bytes")
        }
        if postData.spoiler {
            fieldSummary.append("spoiler=on")
        }
        if let captchaChallenge = postData.captchaChallenge, !captchaChallenge.isEmpty {
            fieldSummary.append("t-challenge=[redacted \(captchaChallenge.count) chars]")
        }
        if let captchaResponse = postData.captchaResponse, !captchaResponse.isEmpty {
            fieldSummary.append("t-response=[redacted \(captchaResponse.count) chars]")
        }

        print("=== PostingManager REQUEST DEBUG ===")
        print("URL: \(url)")
        print("Board: /\(postData.board)/")
        print("Resto: \(postData.resto)")
        print("Is new thread: \(postData.isNewThread)")
        print("Pass authenticated: \(PassAuthManager.shared.isAuthenticated)")
        print("Has cookie header: \(headers.contains { $0.name.caseInsensitiveCompare("Cookie") == .orderedSame })")
        print("Headers: \(headerSummary)")
        print("Multipart fields: \(fieldSummary.joined(separator: ", "))")
        print("=== END REQUEST DEBUG ===")
    }

    // MARK: - Helper Methods

    /// Get MIME type for image file extension
    static func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webm":
            return "video/webm"
        case "mp4", "m4v":
            return "video/mp4"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }
}

struct ParsedPostingSuccess: Equatable {
    let threadNumber: Int
    let postNumber: Int

    var isNewThread: Bool {
        threadNumber == postNumber
    }
}

enum PostingResponseParser {
    static func title(from html: String) -> String? {
        guard let captures = firstMatch(in: html, pattern: "(?is)<title[^>]*>\\s*(.*?)\\s*</title>"),
              let title = captures.first?.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .decodingHTMLEntities(),
              !title.isEmpty else {
            return nil
        }

        return title
    }

    static func isErrorPage(_ html: String) -> Bool {
        html.contains("is_error") &&
            (html.contains("is_error = \"true\"") || html.contains("is_error=\"true\""))
    }

    /// Parse 4chan success responses and redirects.
    static func success(from html: String) -> ParsedPostingSuccess? {
        // Current 4chan success page:
        // <title>Post successful!</title> ... thread:12345,no:67890
        if let captures = firstMatch(in: html, pattern: "thread:(\\d+),no:(\\d+)"),
           let threadNumber = Int(captures[0]),
           let postNumber = Int(captures[1]) {
            return ParsedPostingSuccess(threadNumber: threadNumber, postNumber: postNumber)
        }

        // Meta refresh / JavaScript redirects:
        // https://boards.4chan.org/g/thread/12345#p67890
        if let captures = firstMatch(in: html, pattern: "thread/(\\d+)#p(\\d+)"),
           let threadNumber = Int(captures[0]),
           let postNumber = Int(captures[1]) {
            return ParsedPostingSuccess(threadNumber: threadNumber, postNumber: postNumber)
        }

        // New-thread redirects may omit the post anchor.
        if let captures = firstMatch(in: html, pattern: "thread/(\\d+)(?:[\"'\\s<>]|$)"),
           let threadNumber = Int(captures[0]) {
            return ParsedPostingSuccess(threadNumber: threadNumber, postNumber: threadNumber)
        }

        return nil
    }

    /// Parse error response to extract error message.
    static func errorMessage(from html: String) -> String? {
        // Pattern 1: Extract full content from <span id="errmsg">...</span>
        // 4chan wraps error messages in this span, which may contain inner HTML like <br>, <a>, etc.
        if let startRange = html.range(of: "id=\"errmsg\""),
           let tagClose = html.range(of: ">", range: startRange.upperBound..<html.endIndex),
           let endRange = html.range(of: "</span>", range: tagClose.upperBound..<html.endIndex) {
            let content = String(html[tagClose.upperBound..<endRange.lowerBound])
            let stripped = content.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .decodingHTMLEntities()
            if !stripped.isEmpty {
                return stripped
            }
        }

        // Pattern 2: <font color=red><b>Error: message</b></font>
        if let range = html.range(of: "(?<=<b>Error:)[^<]+", options: .regularExpression) {
            return String(html[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .decodingHTMLEntities()
        }

        // Pattern 3: <b>Error</b>: message or <b>Error:</b> message
        if let range = html.range(of: "<b>Error:?</b>:?\\s*([^<]+)", options: .regularExpression) {
            let match = String(html[range])
            let stripped = match.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "Error:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                return stripped.decodingHTMLEntities()
            }
        }

        // Pattern 4: Cloudflare or CDN block pages
        if html.lowercased().contains("cloudflare") || html.lowercased().contains("access denied") {
            return "Request blocked by Cloudflare. Try opening 4chan in Safari first."
        }

        // Pattern 5: Extract error from body for simple error pages
        if html.lowercased().contains("error") && !html.contains("is_error") {
            if let bodyStart = html.range(of: "<body"),
               let bodyEnd = html.range(of: "</body>") {
                let content = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
                let stripped = content.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if stripped.count < 300 {
                    return stripped.decodingHTMLEntities()
                }
            }
        }

        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges > 1 else {
            return nil
        }

        var captures: [String] = []
        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            captures.append(String(text[range]))
        }

        return captures
    }
}

enum PostingDebugFormatter {
    static func redactedHeaders(_ headers: [AnyHashable: Any]?) -> String {
        guard let headers = headers else { return "nil" }

        return headers
            .map { key, value -> String in
                let name = String(describing: key)
                if name.caseInsensitiveCompare("Set-Cookie") == .orderedSame ||
                    name.caseInsensitiveCompare("Cookie") == .orderedSame {
                    return "\(name): [redacted]"
                }

                return "\(name): \(value)"
            }
            .sorted()
            .joined(separator: ", ")
    }

    static func redactedPreview(_ text: String, limit: Int) -> String {
        var preview = text
        preview = preview.replacingOccurrences(
            of: "(?i)(pass_id|pass_enabled|pass_hash|cf_clearance|__cf_bm|4chan_pass|t-challenge|t-response|g-recaptcha-response|recaptcha_[a-z_]+)([\"'\\s:=]+)([^\"'&<>\\s]+)",
            with: "$1$2[redacted]",
            options: .regularExpression
        )
        preview = preview.replacingOccurrences(
            of: "(?i)(Set-Cookie:\\s*)[^\\n\\r]+",
            with: "$1[redacted]",
            options: .regularExpression
        )
        preview = preview.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if preview.count > limit {
            return String(preview.prefix(limit)) + "... [truncated \(preview.count - limit) chars]"
        }

        return preview
    }

    static func safeShortValue(_ value: String, limit: Int) -> String {
        let normalized = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count > limit {
            return String(normalized.prefix(limit)) + "...[\(normalized.count - limit) more chars]"
        }

        return normalized
    }
}
