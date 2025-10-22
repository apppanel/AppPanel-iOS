import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Manages push notifications for the AppPanel SDK
public class AppPanelPush: NSObject {

    // MARK: - Properties

    /// The delegate for push notification events
    public weak var delegate: AppPanelPushDelegate?

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
        super.init()

        // Set up token manager delegate
        tokenManager.delegate = self

        // Set up notification observers
        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
            delegate?.appPanelPush(self, didReceiveRegistrationToken: cachedToken)
        }
    }

    /// Set the APNs device token
    /// Call this from your AppDelegate's didRegisterForRemoteNotificationsWithDeviceToken method
    /// - Parameter deviceToken: The device token received from APNs
    public func setAPNsToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")

        // Register with AppPanel backend
        tokenManager.registerToken(apnsToken: tokenString)
    }

    /// Set the APNs device token from a string
    /// Alternative method if you already have the token as a string
    /// - Parameter tokenString: The device token string
    public func setAPNsToken(_ tokenString: String) {
        self.deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")

        // Register with AppPanel backend
        tokenManager.registerToken(apnsToken: tokenString)
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

    /// Handle a received push notification
    /// Call this from your notification delegate methods
    /// - Parameter userInfo: The notification payload
    public func handleNotification(_ userInfo: [AnyHashable: Any]) {
        AppPanelLogger.debug("Handling notification: \(userInfo)")

        // Parse and handle the notification
        if let notification = AppPanelNotification(userInfo: userInfo) {
            delegate?.appPanelPush(self, didReceiveNotification: notification)

            // Track notification received event
            trackNotificationReceived(notification)
        }
    }

    /// Handle notification response (when user taps on notification)
    /// - Parameters:
    ///   - response: The notification response
    ///   - completion: Completion handler
    @available(iOS 10.0, macOS 10.14, *)
    public func handleNotificationResponse(_ response: UNNotificationResponse, completion: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        AppPanelLogger.debug("Handling notification response: \(userInfo)")

        if let notification = AppPanelNotification(userInfo: userInfo) {
            // Track notification opened event
            trackNotificationOpened(notification)

            // Notify delegate
            delegate?.appPanelPush(self, didReceiveNotificationResponse: notification, actionIdentifier: response.actionIdentifier)
        }

        completion()
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        #if canImport(UIKit)
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func applicationDidBecomeActive() {
        // Refresh token if needed
        if isInitialized && pushToken == nil && deviceToken != nil {
            tokenManager.registerToken(apnsToken: deviceToken!)
        }
    }

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
}

// MARK: - AppPanelTokenManagerDelegate

extension AppPanelPush: AppPanelTokenManagerDelegate {
    func tokenManager(_ manager: AppPanelTokenManager, didReceiveToken token: String) {
        self.pushToken = token
        AppPanelLogger.info("Received AppPanel push token: \(token)")
        delegate?.appPanelPush(self, didReceiveRegistrationToken: token)
    }

    func tokenManager(_ manager: AppPanelTokenManager, didFailWithError error: Error) {
        AppPanelLogger.error("Token manager failed", error: error)
        delegate?.appPanelPush(self, didFailWithError: error)
    }
}