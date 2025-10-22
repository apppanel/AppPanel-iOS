import Foundation

/// The main entry point for the AppPanel SDK
public class AppPanel {

    /// Shared instance of AppPanel
    public static let shared = AppPanel()

    /// The current configuration
    internal var configuration: AppPanelConfiguration?

    /// Push notification manager
    public private(set) var push: AppPanelPush?

    /// Device manager for handling device ID
    private let deviceManager = AppPanelDeviceManager()

    /// The persistent device ID
    public private(set) var deviceId: String?

    /// The currently logged in user ID
    public private(set) var currentUserId: String?

    /// Network client for API communication
    private var networkClient: AppPanelNetworkClient?

    /// Indicates if the SDK has been configured
    public var isConfigured: Bool {
        return configuration != nil
    }

    /// Indicates if a user is currently logged in
    public var isLoggedIn: Bool {
        return currentUserId != nil
    }

    private init() {}

    /// Configure the AppPanel SDK
    /// - Parameters:
    ///   - apiKey: Your AppPanel API key
    ///   - options: Optional configuration parameters
    public static func configure(apiKey: String, options: AppPanelOptions? = nil) {
        shared.configure(apiKey: apiKey, options: options)
    }

    internal func configure(apiKey: String, options: AppPanelOptions? = nil) {
        guard !apiKey.isEmpty else {
            AppPanelLogger.error("API Key cannot be empty")
            return
        }

        // Create configuration
        self.configuration = AppPanelConfiguration(
            apiKey: apiKey,
            options: options ?? AppPanelOptions()
        )

        // Initialize device ID (persistent across app installs)
        self.deviceId = deviceManager.getDeviceId()
        AppPanelLogger.info("Device ID: \(deviceId!)")

        // Initialize network client
        self.networkClient = AppPanelNetworkClient(configuration: configuration!)

        // Initialize push notifications
        self.push = AppPanelPush(configuration: configuration!)

        AppPanelLogger.info("AppPanel SDK configured successfully")

        // Auto-initialize push if enabled
        if configuration?.options.autoInitializePush == true {
            push?.initialize()
        }
    }

    /// Reset the SDK configuration (mainly for testing)
    public static func reset() {
        shared.configuration = nil
        shared.push = nil
        shared.currentUserId = nil
        shared.networkClient = nil
        // Note: deviceId persists even after reset
    }

    // MARK: - User Management

    /// Login a user and bind them to the device ID
    /// - Parameters:
    ///   - userId: The unique user identifier
    ///   - completion: Completion handler with success status
    public static func login(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        shared.login(userId: userId, completion: completion)
    }

    internal func login(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        guard isConfigured else {
            completion(false, AppPanelError.notConfigured)
            return
        }

        guard !userId.isEmpty else {
            completion(false, AppPanelError.invalidConfiguration("User ID cannot be empty"))
            return
        }

        guard let deviceId = deviceId else {
            completion(false, AppPanelError.invalidConfiguration("Device ID not initialized"))
            return
        }

        AppPanelLogger.info("Logging in user: \(userId)")

        let payload: [String: Any] = [
            "user_id": userId,
            "device_id": deviceId
        ]

        networkClient?.request(
            endpoint: "/v1/users/login",
            method: .post,
            payload: payload
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                self?.currentUserId = userId
                AppPanelLogger.info("User logged in successfully: \(userId)")
                completion(true, nil)
            case .failure(let error):
                AppPanelLogger.error("Failed to login user", error: error)
                completion(false, error)
            }
        }
    }

    /// Logout the current user
    /// - Parameter completion: Completion handler with success status
    public static func logout(completion: @escaping (Bool, Error?) -> Void) {
        shared.logout(completion: completion)
    }

    internal func logout(completion: @escaping (Bool, Error?) -> Void) {
        guard isConfigured else {
            completion(false, AppPanelError.notConfigured)
            return
        }

        guard let userId = currentUserId else {
            AppPanelLogger.warning("No user logged in")
            completion(true, nil)
            return
        }

        guard let deviceId = deviceId else {
            completion(false, AppPanelError.invalidConfiguration("Device ID not initialized"))
            return
        }

        AppPanelLogger.info("Logging out user: \(userId)")

        let payload: [String: Any] = [
            "user_id": userId,
            "device_id": deviceId
        ]

        networkClient?.request(
            endpoint: "/v1/users/logout",
            method: .post,
            payload: payload
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                self?.currentUserId = nil
                AppPanelLogger.info("User logged out successfully")
                completion(true, nil)
            case .failure(let error):
                AppPanelLogger.error("Failed to logout user", error: error)
                completion(false, error)
            }
        }
    }

    /// Get the current logged in user ID
    public static func getCurrentUserId() -> String? {
        return shared.currentUserId
    }

    /// Get the device ID
    public static func getDeviceId() -> String? {
        return shared.deviceId
    }

    /// Regenerate the device ID (this will break all associations)
    /// - Parameter completion: Completion handler with the new device ID
    public static func regenerateDeviceId(completion: @escaping (String?, Error?) -> Void) {
        shared.regenerateDeviceId(completion: completion)
    }

    internal func regenerateDeviceId(completion: @escaping (String?, Error?) -> Void) {
        guard isConfigured else {
            completion(nil, AppPanelError.notConfigured)
            return
        }

        let oldDeviceId = deviceId
        let newDeviceId = deviceManager.regenerateDeviceId()
        self.deviceId = newDeviceId

        AppPanelLogger.info("Regenerated device ID from \(oldDeviceId ?? "nil") to \(newDeviceId)")

        // Notify backend of device ID change
        let payload: [String: Any] = [
            "old_device_id": oldDeviceId ?? "",
            "new_device_id": newDeviceId
        ]

        networkClient?.request(
            endpoint: "/v1/devices/regenerate",
            method: .post,
            payload: payload
        ) { (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                AppPanelLogger.info("Device ID regeneration synced with backend")
                completion(newDeviceId, nil)
            case .failure(let error):
                AppPanelLogger.error("Failed to sync device ID regeneration", error: error)
                // Still return the new ID as it's already saved locally
                completion(newDeviceId, error)
            }
        }

        // Push token will automatically include new device ID on next registration
    }
}