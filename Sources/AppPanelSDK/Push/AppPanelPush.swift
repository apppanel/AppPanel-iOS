import Foundation
import UserNotifications

/// Manages push notifications for the AppPanel SDK
public class AppPanelPush {

    // MARK: - Properties

    /// The current device push token
    public private(set) var deviceToken: String?

    /// The current AppPanel push token (mapped from APNs token)
    public private(set) var pushToken: String?

    /// Token manager for handling token lifecycle
    private let tokenManager: AppPanelTokenManager

    /// Configuration
    private let configuration: AppPanelConfiguration

    /// Indicates if push notifications are initialized
    public private(set) var isInitialized: Bool = false

    // MARK: - Initialization

    internal init(configuration: AppPanelConfiguration) {
        self.configuration = configuration
        self.tokenManager = AppPanelTokenManager(configuration: configuration)
    }

    // MARK: - Public Methods

    /// Initialize push notifications
    /// Note: This does not request permissions. The app must handle permission requests.
    public func initialize() {
        guard !isInitialized else {
            AppPanelLogger.warning("Push notifications already initialized")
            return
        }

        AppPanelLogger.info("Initializing AppPanel Push Notifications")
        isInitialized = true

        // Check if we already have a cached token
        if let cachedToken = tokenManager.getCachedToken() {
            self.pushToken = cachedToken
        }
    }

    /// Set the APNs device token
    /// Call this from your AppDelegate's didRegisterForRemoteNotificationsWithDeviceToken method
    /// - Parameters:
    ///   - deviceToken: The device token received from APNs
    ///   - completion: Optional completion handler called with the AppPanel token or error
    public func setAPNsToken(_ deviceToken: Data, completion: ((String?, Error?) -> Void)? = nil) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")

        // Register with AppPanel backend
        tokenManager.registerToken(apnsToken: tokenString) { [weak self] token, error in
            if let token = token {
                self?.pushToken = token
            }
            completion?(token, error)
        }
    }

    /// Set the APNs device token from a string
    /// Alternative method if you already have the token as a string
    /// - Parameters:
    ///   - tokenString: The device token string
    ///   - completion: Optional completion handler called with the AppPanel token or error
    public func setAPNsToken(_ tokenString: String, completion: ((String?, Error?) -> Void)? = nil) {
        self.deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")

        // Register with AppPanel backend
        tokenManager.registerToken(apnsToken: tokenString) { [weak self] token, error in
            if let token = token {
                self?.pushToken = token
            }
            completion?(token, error)
        }
    }

    /// Get the current push token
    /// - Parameter completion: Completion handler with the token or error
    public func getToken(completion: @escaping (String?, Error?) -> Void) {
        if let token = pushToken {
            completion(token, nil)
        } else if let deviceToken = deviceToken {
            // Try to register if we have APNs token but no AppPanel token
            tokenManager.registerToken(apnsToken: deviceToken) { [weak self] token, error in
                self?.pushToken = token
                completion(token, error)
            }
        } else {
            completion(nil, AppPanelError.tokenNotAvailable)
        }
    }

    /// Get the current push token synchronously
    /// Returns nil if token is not available yet
    public func getToken() -> String? {
        return pushToken
    }

    /// Delete the current push token (for logout scenarios)
    public func deleteToken(completion: @escaping (Bool, Error?) -> Void) {
        guard let token = pushToken else {
            completion(true, nil)
            return
        }

        tokenManager.deleteToken(token) { [weak self] success, error in
            if success {
                self?.pushToken = nil
                self?.deviceToken = nil
            }
            completion(success, error)
        }
    }

    // TODO: Topic subscription endpoints not yet available
    /*
    /// Subscribe to a topic for targeted messaging
    /// - Parameters:
    ///   - topic: The topic name to subscribe to
    ///   - completion: Completion handler with success status
    public func subscribeToTopic(_ topic: String, completion: @escaping (Bool, Error?) -> Void) {
        // Token check is now handled internally by tokenManager
        tokenManager.subscribeToTopic(topic: topic, completion: completion)
    }

    /// Unsubscribe from a topic
    /// - Parameters:
    ///   - topic: The topic name to unsubscribe from
    ///   - completion: Completion handler with success status
    public func unsubscribeFromTopic(_ topic: String, completion: @escaping (Bool, Error?) -> Void) {
        // Token check is now handled internally by tokenManager
        tokenManager.unsubscribeFromTopic(topic: topic, completion: completion)
    }
    */

    /// Parse a received push notification
    /// Call this from your UNUserNotificationCenterDelegate methods
    /// - Parameter userInfo: The notification payload from APNs
    /// - Returns: The parsed AppPanelNotification object, or nil if not an AppPanel notification
    public func parseNotification(_ userInfo: [AnyHashable: Any]) -> AppPanelNotification? {
        AppPanelLogger.debug("Parsing notification: \(userInfo)")

        // Parse the notification
        guard let notification = AppPanelNotification(userInfo: userInfo) else {
            AppPanelLogger.warning("Failed to parse notification from userInfo")
            return nil
        }

        // TODO: Analytics tracking not yet available
        // trackNotificationReceived(notification)

        return notification
    }

    /// Parse a notification response (when user taps on notification)
    /// Call this from your UNUserNotificationCenterDelegate didReceive response method
    /// - Parameter response: The UNNotificationResponse from the system delegate
    /// - Returns: The parsed AppPanelNotification and action identifier, or nil if not an AppPanel notification
    @available(iOS 10.0, macOS 10.14, *)
    public func parseNotificationResponse(_ response: UNNotificationResponse) -> (notification: AppPanelNotification, actionIdentifier: String)? {
        let userInfo = response.notification.request.content.userInfo
        AppPanelLogger.debug("Parsing notification response: \(userInfo)")

        guard let notification = AppPanelNotification(userInfo: userInfo) else {
            AppPanelLogger.warning("Failed to parse notification response")
            return nil
        }

        // TODO: Analytics tracking not yet available
        // trackNotificationOpened(notification)

        return (notification, response.actionIdentifier)
    }

    // TODO: Analytics tracking not yet available
    /*
    private func trackNotificationReceived(_ notification: AppPanelNotification) {
        // Send analytics event for notification received
        tokenManager.trackEvent(
            event: "notification_received",
            properties: [
                "notification_id": notification.id ?? "",
                "campaign_id": notification.campaignId ?? ""
            ]
        )
    }

    private func trackNotificationOpened(_ notification: AppPanelNotification) {
        // Send analytics event for notification opened
        tokenManager.trackEvent(
            event: "notification_opened",
            properties: [
                "notification_id": notification.id ?? "",
                "campaign_id": notification.campaignId ?? ""
            ]
        )
    }
    */
}

