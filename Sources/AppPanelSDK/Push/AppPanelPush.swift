import Foundation
import UserNotifications

/// Manages push notifications for the AppPanel SDK
public class AppPanelPush {
    // MARK: - Properties

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

        // Register with AppPanel backend (fire-and-forget)
        tokenManager.registerToken(apnsToken: tokenString) { _, _ in }
    }

    /// Set the APNs device token from a string
    /// Alternative method if you already have the token as a string
    /// - Parameter tokenString: The device token string
    public func setAPNsToken(_ tokenString: String) {
        deviceToken = tokenString
        AppPanelLogger.debug("APNs token received: \(tokenString)")

        // Register with AppPanel backend (fire-and-forget)
        tokenManager.registerToken(apnsToken: tokenString) { _, _ in }
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
