import Foundation

/// The main entry point for the AppPanel SDK
public class AppPanel {
    /// Shared instance of AppPanel
    public static let shared = AppPanel()

    /// The current configuration
    var configuration: AppPanelConfiguration?

    /// Push notification manager
    public private(set) var push: AppPanelPush!

    /// Device manager for handling device ID
    private let deviceManager = AppPanelDeviceManager()

    /// The persistent device ID
    public private(set) var deviceId: UUID!

    /// The currently logged in user ID
    public private(set) var currentUserId: String?

    /// Network client for API communication
    private var networkClient: APIClient?

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

    func configure(apiKey: String, options: AppPanelOptions? = nil) {
        guard !apiKey.isEmpty else {
            AppPanelLogger.error("API Key cannot be empty")
            return
        }

        // Create configuration
        configuration = AppPanelConfiguration(
            apiKey: apiKey,
            options: options ?? AppPanelOptions()
        )

        // Initialize device ID (persistent across app installs)
        deviceId = deviceManager.getDeviceId()
        AppPanelLogger.info("Device ID: \(deviceId!)")

        // Initialize network client
        networkClient = APIClient(baseURL: configuration!.baseURL) { config in
            config.sessionConfiguration.httpAdditionalHeaders = [
                "X-AppPanel-SDK-Version": "1.0.0",
                "X-AppPanel-Platform": "iOS",
                "X-AppPanel-API-Key": apiKey,
            ]
        }

        // Register device with backend
        registerDevice()

        // Initialize push notifications
        push = AppPanelPush(configuration: configuration!)

        AppPanelLogger.info("AppPanel SDK configured successfully")
    }

    // MARK: - User Management

    // TODO: User login/logout endpoints not yet available
    // These will be implemented when the backend endpoints are ready

    /// Get the device ID
    public static func getDeviceId() -> UUID {
        return shared.deviceId
    }

    // MARK: - Private Methods

    private func registerDevice() {
        struct DevicePayload: Encodable {
            let device_id: String
        }

        let payload = DevicePayload(device_id: deviceId.uuidString.lowercased())

        Task {
            do {
                let request = Request<Void>(
                    path: "/v1/identify/device",
                    method: .post,
                    body: payload
                )
                _ = try await networkClient?.send(request)
                AppPanelLogger.debug("Device registered successfully")
            } catch {
                AppPanelLogger.error("Failed to register device", error: error)
            }
        }
    }

    /// Regenerate the device ID (this will break all associations)
    /// - Returns: The new device ID
    public static func regenerateDeviceId() -> UUID {
        return shared.regenerateDeviceId()
    }

    func regenerateDeviceId() -> UUID {
        guard isConfigured else {
            AppPanelLogger.error("Cannot regenerate device ID: SDK not configured")
            return deviceId
        }

        let oldDeviceIdString = deviceId.uuidString
        let newDeviceId = deviceManager.regenerateDeviceId()
        deviceId = newDeviceId

        AppPanelLogger.info("Regenerated device ID from \(oldDeviceIdString) to \(newDeviceId.uuidString)")

        // Register the new device ID with backend (fire-and-forget)
        struct DevicePayload: Encodable {
            let device_id: String
        }

        let payload = DevicePayload(device_id: newDeviceId.uuidString.lowercased())

        Task {
            do {
                let request = Request<Void>(
                    path: "/v1/identify/device",
                    method: .post,
                    body: payload
                )
                _ = try await networkClient?.send(request)
                AppPanelLogger.info("New device ID registered with backend")
            } catch {
                AppPanelLogger.error("Failed to register new device ID", error: error)
            }
        }

        // Push token will automatically include new device ID on next registration
        return newDeviceId
    }
}
