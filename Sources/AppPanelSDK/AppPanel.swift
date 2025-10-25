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

        // Register device with backend
        registerDevice()

        // Initialize push notifications
        self.push = AppPanelPush(configuration: configuration!)

        AppPanelLogger.info("AppPanel SDK configured successfully")
    }

    // MARK: - User Management
    // TODO: User login/logout endpoints not yet available
    // These will be implemented when the backend endpoints are ready

    /// Get the device ID
    public static func getDeviceId() -> String? {
        return shared.deviceId
    }

    // MARK: - Private Methods

    private func registerDevice() {
        guard let deviceId = deviceId else { return }

        let payload: [String: Any] = [
            "device_id": deviceId
        ]

        networkClient?.request(
            endpoint: "/v1/identify/device",
            method: .post,
            payload: payload
        ) { (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                AppPanelLogger.debug("Device registered successfully")
            case .failure(let error):
                AppPanelLogger.error("Failed to register device", error: error)
            }
        }
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

        // Register the new device ID with backend
        let payload: [String: Any] = [
            "device_id": newDeviceId
        ]

        networkClient?.request(
            endpoint: "/v1/identify/device",
            method: .post,
            payload: payload
        ) { (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                AppPanelLogger.info("New device ID registered with backend")
                completion(newDeviceId, nil)
            case .failure(let error):
                AppPanelLogger.error("Failed to register new device ID", error: error)
                // Still return the new ID as it's already saved locally
                completion(newDeviceId, error)
            }
        }

        // Push token will automatically include new device ID on next registration
    }
}