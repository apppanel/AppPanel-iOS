import Foundation
import Security

/// Manages secure storage for all AppPanel SDK data using Keychain
class AppPanelStorage {
    private let keychainService = "io.apppanel.sdk"

    // Storage keys
    private enum StorageKey: String {
        case deviceId = "app_panel_device_id"
        case pushToken = "app_panel_push_token"
        case apnsToken = "app_panel_apns_token"
        case tokenMapping = "app_panel_token_mapping"
    }

    // In-memory cache for quick access
    private var deviceIdCache: String?
    private var tokenCache: String?
    private var tokenMapping: [String: String] = [:] // APNs token -> AppPanel token

    init() {
        // Load token mapping from keychain
        loadTokenMapping()
    }

    // MARK: - Device ID Management

    /// Get or generate the device ID
    func getDeviceId() -> String {
        // Check cache first
        if let cached = deviceIdCache {
            return cached
        }

        // Try to load from keychain
        if let existingId = load(forKey: StorageKey.deviceId.rawValue) {
            deviceIdCache = existingId
            return existingId
        }

        // Generate new device ID
        let newId = UUID().uuidString.lowercased()
        saveDeviceId(newId)
        return newId
    }

    /// Save a device ID
    private func saveDeviceId(_ deviceId: String) {
        save(deviceId, forKey: StorageKey.deviceId.rawValue, accessible: kSecAttrAccessibleAlways)
        deviceIdCache = deviceId
    }

    /// Regenerate the device ID
    func regenerateDeviceId() -> String {
        let newId = UUID().uuidString.lowercased()
        saveDeviceId(newId)
        return newId
    }

    // MARK: - Token Management

    /// Save a push token
    func savePushToken(_ token: String, forAPNsToken apnsToken: String) {
        // Save to keychain
        save(token, forKey: StorageKey.pushToken.rawValue)
        save(apnsToken, forKey: StorageKey.apnsToken.rawValue)

        // Update mapping
        tokenMapping[apnsToken] = token
        saveTokenMapping()

        // Update cache
        tokenCache = token
    }

    /// Get the current push token
    func getCurrentPushToken() -> String? {
        if let cached = tokenCache {
            return cached
        }

        if let token = load(forKey: StorageKey.pushToken.rawValue) {
            tokenCache = token
            return token
        }

        return nil
    }

    /// Get push token for a specific APNs token
    func getPushToken(forAPNsToken apnsToken: String) -> String? {
        return tokenMapping[apnsToken]
    }

    /// Get the last stored APNs token
    func getLastAPNsToken() -> String? {
        return load(forKey: StorageKey.apnsToken.rawValue)
    }

    /// Clear token mapping for an old APNs token
    func clearTokenMapping(forAPNsToken apnsToken: String) {
        tokenMapping.removeValue(forKey: apnsToken)
        saveTokenMapping()
    }

    /// Delete a push token
    func deletePushToken(_ token: String) {
        // Remove from mapping
        tokenMapping.removeValue(forKey: token)
        saveTokenMapping()

        // Clear from keychain
        delete(forKey: StorageKey.pushToken.rawValue)
        delete(forKey: StorageKey.apnsToken.rawValue)

        // Clear cache
        tokenCache = nil
    }

    /// Clear all tokens
    func clearAll() {
        delete(forKey: StorageKey.pushToken.rawValue)
        delete(forKey: StorageKey.apnsToken.rawValue)
        delete(forKey: StorageKey.tokenMapping.rawValue)
        tokenCache = nil
        tokenMapping.removeAll()
    }

    // MARK: - Private Keychain Methods

    private func save(_ value: String, forKey key: String, accessible: CFString = kSecAttrAccessibleAfterFirstUnlock as CFString) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppPanelLogger.error("Failed to save to keychain: \(status)")
        }
    }

    private func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8)
        {
            return value
        }

        return nil
    }

    private func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Token Mapping

    private func loadTokenMapping() {
        guard let jsonString = load(forKey: StorageKey.tokenMapping.rawValue),
              let data = jsonString.data(using: .utf8) else { return }

        do {
            tokenMapping = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            AppPanelLogger.error("Failed to load token mapping", error: error)
        }
    }

    private func saveTokenMapping() {
        do {
            let data = try JSONEncoder().encode(tokenMapping)
            if let jsonString = String(data: data, encoding: .utf8) {
                save(jsonString, forKey: StorageKey.tokenMapping.rawValue)
            }
        } catch {
            AppPanelLogger.error("Failed to save token mapping", error: error)
        }
    }
}
