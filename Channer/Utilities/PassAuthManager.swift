import Foundation
import Alamofire

/// Manages 4chan Pass authentication and cookie storage
class PassAuthManager {

    static let shared = PassAuthManager()

    private let keychainTokenKey = "channer_pass_token"
    private let keychainPINKey = "channer_pass_pin"
    private let passIdCookieKey = "channer_pass_id_cookie"
    private let passEnabledKey = "channer_pass_enabled"

    private let authURL = "https://sys.4chan.org/auth"

    /// Authentication status
    enum AuthStatus: Int {
        case notAuthenticated = 0
        case success = 1
        case authenticated = 2
        case error = -1
        case loggedOut = 4
    }

    /// Result of login attempt
    struct LoginResult {
        let success: Bool
        let message: String?
    }

    private init() {
        setupiCloudObserver()
        // Try to restore pass_id from iCloud if not available locally
        restorePassFromiCloud()
    }

    // MARK: - iCloud Sync

    private func setupiCloudObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataChanged),
            name: ICloudSyncManager.iCloudSyncCompletedNotification,
            object: nil
        )
    }

    @objc private func iCloudDataChanged() {
        // Restore pass credentials when iCloud sync completes
        restorePassFromiCloud()
    }

    private func restorePassFromiCloud() {
        // Only restore if we don't have a local pass_id
        guard getPassIdCookie() == nil else { return }

        if let cloudPassId = ICloudSyncManager.shared.loadPassCredentials() {
            UserDefaults.standard.set(cloudPassId, forKey: passIdCookieKey)
            UserDefaults.standard.set(true, forKey: passEnabledKey)
            print("Restored pass_id from iCloud")
        }
    }

    // MARK: - Credential Management

    /// Check if user has stored credentials
    var hasCredentials: Bool {
        return KeychainHelper.shared.load(keychainTokenKey) != nil &&
               KeychainHelper.shared.load(keychainPINKey) != nil
    }

    /// Check if user is currently authenticated (has valid pass_id cookie)
    var isAuthenticated: Bool {
        return UserDefaults.standard.bool(forKey: passEnabledKey) &&
               getPassIdCookie() != nil
    }

    /// Get the stored pass_id cookie value
    func getPassIdCookie() -> String? {
        return UserDefaults.standard.string(forKey: passIdCookieKey)
    }

    /// Save credentials to Keychain
    func saveCredentials(token: String, pin: String) {
        KeychainHelper.shared.save(token, forKey: keychainTokenKey)
        KeychainHelper.shared.save(pin, forKey: keychainPINKey)
    }

    /// Get stored token
    func getToken() -> String? {
        return KeychainHelper.shared.load(keychainTokenKey)
    }

    /// Clear all credentials and cookies
    func clearCredentials() {
        KeychainHelper.shared.delete(keychainTokenKey)
        KeychainHelper.shared.delete(keychainPINKey)
        UserDefaults.standard.removeObject(forKey: passIdCookieKey)
        UserDefaults.standard.set(false, forKey: passEnabledKey)

        // Clear from iCloud
        ICloudSyncManager.shared.clearPassCredentials()

        // Clear cookies from shared cookie storage
        if let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://sys.4chan.org")!) {
            for cookie in cookies {
                if cookie.name == "pass_id" || cookie.name == "pass_enabled" {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
        }
    }

    // MARK: - Authentication

    /// Attempt to login with stored credentials
    /// - Parameter completion: Callback with login result
    func login(completion: @escaping (LoginResult) -> Void) {
        guard let token = KeychainHelper.shared.load(keychainTokenKey),
              let pin = KeychainHelper.shared.load(keychainPINKey) else {
            completion(LoginResult(success: false, message: "No credentials stored"))
            return
        }

        login(token: token, pin: pin, longLogin: true, completion: completion)
    }

    /// Attempt to login with provided credentials
    /// - Parameters:
    ///   - token: 4chan Pass token (10 characters)
    ///   - pin: 4chan Pass PIN
    ///   - longLogin: If true, cookie lasts 1 year instead of 1 day
    ///   - completion: Callback with login result
    func login(token: String, pin: String, longLogin: Bool = true, completion: @escaping (LoginResult) -> Void) {
        // Validate token length
        guard token.count == 10 else {
            completion(LoginResult(success: false, message: "Token must be exactly 10 characters"))
            return
        }

        guard !pin.isEmpty else {
            completion(LoginResult(success: false, message: "PIN is required"))
            return
        }

        // Build form parameters
        var parameters: [String: String] = [
            "id": token,
            "pin": pin
        ]

        if longLogin {
            parameters["long_login"] = "1"
        }

        // Set headers to request JSON response
        let headers: HTTPHeaders = [
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "https://sys.4chan.org/auth",
            "Origin": "https://sys.4chan.org"
        ]

        AF.request(authURL,
                   method: .post,
                   parameters: parameters,
                   encoder: URLEncodedFormParameterEncoder.default,
                   headers: headers)
        .responseData { [weak self] response in
            guard let self = self else { return }

            // DEBUG: Print response info
            print("=== PassAuthManager LOGIN DEBUG ===")
            print("HTTP Status Code: \(response.response?.statusCode ?? -1)")
            print("Response Headers: \(response.response?.allHeaderFields ?? [:])")

            switch response.result {
            case .success(let data):
                let rawString = String(data: data, encoding: .utf8) ?? "(unable to decode)"
                print("Raw Response (\(data.count) bytes): \(rawString)")

                // Try to parse JSON response
                if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                   let json = jsonObject as? [String: Any],
                   let status = json["status"] as? Int {
                    let message = json["message"] as? String
                    print("JSON Parsed - Status: \(status), Message: \(message ?? "nil")")

                    if status == AuthStatus.success.rawValue {
                        // Extract cookies from response
                        self.extractAndStoreCookies(from: response.response)
                        // Save credentials for future use
                        self.saveCredentials(token: token, pin: pin)
                        print("Login SUCCESS - cookies extracted and credentials saved")
                        completion(LoginResult(success: true, message: nil))
                    } else {
                        print("Login FAILED - status: \(status)")
                        completion(LoginResult(success: false, message: message ?? "Authentication failed"))
                    }
                } else {
                    // Try to parse HTML error response
                    let htmlString = String(data: data, encoding: .utf8) ?? ""
                    print("JSON parsing failed, trying HTML parse")
                    print("HTML Content: \(htmlString.prefix(500))")

                    // Check if HTML contains success indicators
                    if htmlString.contains("Success") || htmlString.contains("authorized") {
                        print("HTML contains success message - extracting cookies")
                        self.extractAndStoreCookies(from: response.response)
                        self.saveCredentials(token: token, pin: pin)
                        completion(LoginResult(success: true, message: nil))
                    } else {
                        let errorMessage = self.parseHTMLError(htmlString) ?? "Unknown error"
                        print("HTML Error parsed: \(errorMessage)")
                        completion(LoginResult(success: false, message: errorMessage))
                    }
                }

            case .failure(let error):
                print("Network FAILURE: \(error.localizedDescription)")
                completion(LoginResult(success: false, message: error.localizedDescription))
            }
            print("=== END LOGIN DEBUG ===")
        }
    }

    /// Logout - clear cookies and credentials
    func logout(completion: @escaping (Bool) -> Void) {
        let headers: HTTPHeaders = [
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "https://sys.4chan.org/auth",
            "Origin": "https://sys.4chan.org"
        ]

        let parameters = ["logout": "1"]

        AF.request(authURL,
                   method: .post,
                   parameters: parameters,
                   encoder: URLEncodedFormParameterEncoder.default,
                   headers: headers)
        .response { [weak self] _ in
            self?.clearCredentials()
            completion(true)
        }
    }

    // MARK: - Cookie Management

    /// Extract pass_id and pass_enabled cookies from response
    private func extractAndStoreCookies(from response: HTTPURLResponse?) {
        print("=== extractAndStoreCookies DEBUG ===")
        guard let headerFields = response?.allHeaderFields as? [String: String],
              let url = response?.url else {
            print("ERROR: No header fields or URL in response")
            return
        }

        print("URL: \(url)")
        print("Header Fields: \(headerFields)")

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        print("Cookies found: \(cookies.count)")

        var foundPassId = false
        var foundPassEnabled = false

        for cookie in cookies {
            print("Cookie: \(cookie.name) = \(cookie.value.prefix(20))... (domain: \(cookie.domain))")
            if cookie.name == "pass_id" {
                UserDefaults.standard.set(cookie.value, forKey: passIdCookieKey)
                // Also add to shared cookie storage for future requests
                HTTPCookieStorage.shared.setCookie(cookie)
                // Sync to iCloud for cross-device access
                ICloudSyncManager.shared.savePassCredentials(passId: cookie.value)
                foundPassId = true
                print("  -> Saved pass_id cookie (synced to iCloud)")
            } else if cookie.name == "pass_enabled" {
                UserDefaults.standard.set(cookie.value == "1", forKey: passEnabledKey)
                HTTPCookieStorage.shared.setCookie(cookie)
                foundPassEnabled = true
                print("  -> Saved pass_enabled cookie")
            }
        }

        print("Found pass_id: \(foundPassId), Found pass_enabled: \(foundPassEnabled)")
        print("=== END extractAndStoreCookies DEBUG ===")
    }

    /// Create cookies for posting requests
    func getPostingCookies() -> [HTTPCookie] {
        var cookies: [HTTPCookie] = []

        if let passId = getPassIdCookie() {
            // Create pass_id cookie for 4chan.org
            if let cookie = HTTPCookie(properties: [
                .name: "pass_id",
                .value: passId,
                .domain: ".4chan.org",
                .path: "/",
                .secure: "TRUE"
            ]) {
                cookies.append(cookie)
            }

            // Also for 4channel.org
            if let cookie = HTTPCookie(properties: [
                .name: "pass_id",
                .value: passId,
                .domain: ".4channel.org",
                .path: "/",
                .secure: "TRUE"
            ]) {
                cookies.append(cookie)
            }
        }

        // Add pass_enabled cookie
        if isAuthenticated {
            if let cookie = HTTPCookie(properties: [
                .name: "pass_enabled",
                .value: "1",
                .domain: ".4chan.org",
                .path: "/"
            ]) {
                cookies.append(cookie)
            }

            if let cookie = HTTPCookie(properties: [
                .name: "pass_enabled",
                .value: "1",
                .domain: ".4channel.org",
                .path: "/"
            ]) {
                cookies.append(cookie)
            }
        }

        return cookies
    }

    /// Get cookie header string for posting
    func getCookieHeader() -> String? {
        guard let passId = getPassIdCookie() else { return nil }
        return "pass_id=\(passId); pass_enabled=1"
    }

    // MARK: - Helpers

    /// Parse error message from HTML response
    private func parseHTMLError(_ html: String) -> String? {
        // Look for error message in HTML
        // Common patterns: <span class="error">message</span> or plain text errors
        if let range = html.range(of: "(?<=<span[^>]*class=\"?error\"?[^>]*>)[^<]+", options: .regularExpression) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find any text between <body> tags if it's a simple error page
        if let bodyStart = html.range(of: "<body>"),
           let bodyEnd = html.range(of: "</body>") {
            let content = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
            let stripped = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty && stripped.count < 200 {
                return stripped
            }
        }

        return nil
    }
}
