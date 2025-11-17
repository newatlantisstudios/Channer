//
//  MockAlamofireSession.swift
//  ChannerTests
//
//  Created for unit testing
//

import Foundation
import Alamofire
import SwiftyJSON

/// Mock implementation of Alamofire Session for testing network requests
/// Allows stubbing responses and testing network error scenarios
class MockAlamofireSession {

    // MARK: - Response Stubs

    private var stubbedResponses: [String: MockResponse] = [:]
    private var defaultResponse: MockResponse?

    // MARK: - Request Tracking

    private(set) var requestHistory: [MockRequest] = []
    var requestCount: Int { return requestHistory.count }

    // MARK: - Configuration

    var shouldFail: Bool = false
    var failureError: AFError?
    var responseDelay: TimeInterval = 0

    // MARK: - Mock Types

    struct MockRequest {
        let url: String
        let method: HTTPMethod
        let parameters: Parameters?
        let headers: HTTPHeaders?
        let timestamp: Date

        init(url: String, method: HTTPMethod, parameters: Parameters? = nil, headers: HTTPHeaders? = nil) {
            self.url = url
            self.method = method
            self.parameters = parameters
            self.headers = headers
            self.timestamp = Date()
        }
    }

    struct MockResponse {
        let statusCode: Int
        let data: Data?
        let json: JSON?
        let headers: [String: String]
        let error: Error?

        init(statusCode: Int = 200, data: Data? = nil, json: JSON? = nil, headers: [String: String] = [:], error: Error? = nil) {
            self.statusCode = statusCode
            self.data = data
            self.json = json
            self.headers = headers
            self.error = error
        }

        // Convenience initializers
        static func success(json: JSON, statusCode: Int = 200) -> MockResponse {
            return MockResponse(statusCode: statusCode, json: json)
        }

        static func success(data: Data, statusCode: Int = 200) -> MockResponse {
            return MockResponse(statusCode: statusCode, data: data)
        }

        static func failure(error: Error, statusCode: Int = 500) -> MockResponse {
            return MockResponse(statusCode: statusCode, error: error)
        }

        static func notFound() -> MockResponse {
            return MockResponse(statusCode: 404)
        }
    }

    // MARK: - Stubbing Methods

    /// Stub a response for a specific URL
    func stubResponse(for url: String, response: MockResponse) {
        stubbedResponses[url] = response
    }

    /// Stub a response for a URL pattern (contains matching)
    func stubResponse(forURLContaining pattern: String, response: MockResponse) {
        stubbedResponses[pattern] = response
    }

    /// Set default response for any unstubbed URL
    func setDefaultResponse(_ response: MockResponse) {
        defaultResponse = response
    }

    /// Clear all stubs
    func clearStubs() {
        stubbedResponses.removeAll()
        defaultResponse = nil
    }

    // MARK: - Request Simulation

    /// Simulate a request and return stubbed response
    func simulateRequest(
        url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<JSON, Error>) -> Void
    ) {
        // Track request
        let request = MockRequest(url: url, method: method, parameters: parameters, headers: headers)
        requestHistory.append(request)

        // Simulate delay
        if responseDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + responseDelay) {
                self.executeResponse(for: url, completion: completion)
            }
        } else {
            executeResponse(for: url, completion: completion)
        }
    }

    /// Simulate a data request
    func simulateDataRequest(
        url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // Track request
        let request = MockRequest(url: url, method: method, parameters: parameters, headers: headers)
        requestHistory.append(request)

        // Simulate delay
        if responseDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + responseDelay) {
                self.executeDataResponse(for: url, completion: completion)
            }
        } else {
            executeDataResponse(for: url, completion: completion)
        }
    }

    private func executeResponse(for url: String, completion: @escaping (Result<JSON, Error>) -> Void) {
        // Check for failure
        if shouldFail {
            let error = failureError ?? AFError.sessionTaskFailed(error: NSError(domain: "MockError", code: -1, userInfo: nil))
            completion(.failure(error))
            return
        }

        // Find matching stub
        let response = findResponse(for: url)

        // Return error if specified
        if let error = response.error {
            completion(.failure(error))
            return
        }

        // Return JSON
        if let json = response.json {
            completion(.success(json))
            return
        }

        // Try to parse data as JSON
        if let data = response.data {
            do {
                let json = try JSON(data: data)
                completion(.success(json))
            } catch {
                completion(.failure(error))
            }
            return
        }

        // Return empty JSON
        completion(.success(JSON()))
    }

    private func executeDataResponse(for url: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Check for failure
        if shouldFail {
            let error = failureError ?? AFError.sessionTaskFailed(error: NSError(domain: "MockError", code: -1, userInfo: nil))
            completion(.failure(error))
            return
        }

        // Find matching stub
        let response = findResponse(for: url)

        // Return error if specified
        if let error = response.error {
            completion(.failure(error))
            return
        }

        // Return data
        if let data = response.data {
            completion(.success(data))
            return
        }

        // Try to convert JSON to data
        if let json = response.json {
            do {
                let data = try json.rawData()
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
            return
        }

        // Return empty data
        completion(.success(Data()))
    }

    private func findResponse(for url: String) -> MockResponse {
        // Exact match
        if let response = stubbedResponses[url] {
            return response
        }

        // Pattern matching (contains)
        for (pattern, response) in stubbedResponses {
            if url.contains(pattern) {
                return response
            }
        }

        // Default response
        if let defaultResponse = defaultResponse {
            return defaultResponse
        }

        // Fallback to 404
        return MockResponse.notFound()
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        stubbedResponses.removeAll()
        requestHistory.removeAll()
        defaultResponse = nil
        shouldFail = false
        failureError = nil
        responseDelay = 0
    }

    /// Get requests matching URL pattern
    func requests(forURLContaining pattern: String) -> [MockRequest] {
        return requestHistory.filter { $0.url.contains(pattern) }
    }

    /// Check if a request was made
    func didMakeRequest(to url: String, method: HTTPMethod = .get) -> Bool {
        return requestHistory.contains { $0.url == url && $0.method == method }
    }

    /// Get last request
    var lastRequest: MockRequest? {
        return requestHistory.last
    }

    /// Get request at index
    func request(at index: Int) -> MockRequest? {
        guard index < requestHistory.count else { return nil }
        return requestHistory[index]
    }
}

// MARK: - Test Data Helpers

extension MockAlamofireSession {

    /// Create mock thread list JSON response
    static func mockThreadListJSON(threadCount: Int = 5) -> JSON {
        var threads: [[String: Any]] = []

        for i in 1...threadCount {
            threads.append([
                "no": 123456 + i,
                "sub": "Test Thread \(i)",
                "com": "Test comment \(i)",
                "tim": 1234567890 + i,
                "replies": 10 + i,
                "images": 5 + i
            ])
        }

        return JSON(["threads": [["threads": threads]]])
    }

    /// Create mock thread replies JSON response
    static func mockThreadRepliesJSON(replyCount: Int = 10) -> JSON {
        var posts: [[String: Any]] = []

        // OP post
        posts.append([
            "no": 123456,
            "sub": "Test Thread",
            "com": "Original post content",
            "tim": 1234567890,
            "filename": "image",
            "ext": ".jpg"
        ])

        // Replies
        for i in 1...replyCount {
            posts.append([
                "no": 123456 + i,
                "com": "Reply \(i) content",
                "tim": 1234567890 + i
            ])
        }

        return JSON(["posts": posts])
    }

    /// Create mock board list JSON
    static func mockBoardListJSON() -> JSON {
        let boards = [
            ["board": "g", "title": "Technology"],
            ["board": "v", "title": "Video Games"],
            ["board": "a", "title": "Anime & Manga"]
        ]

        return JSON(["boards": boards])
    }
}
