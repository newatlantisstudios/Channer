import Foundation
import Security

/// Simple Keychain wrapper for secure credential storage
class KeychainHelper {

    static let shared = KeychainHelper()

    private init() {}

    private let service = "com.channer.app"

    /// Save a string value to the Keychain
    /// - Parameters:
    ///   - value: The string to store
    ///   - key: The key to store it under
    /// - Returns: True if successful
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete any existing item first
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Load a string value from the Keychain
    /// - Parameter key: The key to load
    /// - Returns: The stored string, or nil if not found
    func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Delete a value from the Keychain
    /// - Parameter key: The key to delete
    /// - Returns: True if successful or item didn't exist
    @discardableResult
    func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
