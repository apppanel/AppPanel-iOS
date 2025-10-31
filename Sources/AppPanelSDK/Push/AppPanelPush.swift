import Foundation
import UserNotifications

public class AppPanelPush {
    /// Stored APNs token to avoid redundant registrations
    private var deviceToken: String?

    /// Token manager for handling token lifecycle
    private let tokenManager: AppPanelTokenManager

    /// Configuration
    private let configuration: AppPanelConfiguration

    // MARK: - Initialization

    init(configuration: AppPanelConfiguration) {
        self.configuration = configuration
        tokenManager = AppPanelTokenManager(configuration: configuration)
    }

    /// Set the APNs device token
    /// Call this from your AppDelegate's didRegisterForRemoteNotificationsWithDeviceToken method
    /// - Parameter deviceToken: The device token received from APNs
    public func setAPNsToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")
        tokenManager.registerToken(apnsToken: tokenString)
    }

    /// Set the APNs device token from a string
    /// Alternative method if you already have the token as a string
    /// - Parameter tokenString: The device token string
    public func setAPNsToken(_ tokenString: String) {
        deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")
        tokenManager.registerToken(apnsToken: tokenString)
    }
}
