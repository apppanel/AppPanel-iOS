import Foundation

/// Delegate protocol for AppPanel push notification events
public protocol AppPanelPushDelegate: AnyObject {

    /// Called when a registration token is received
    /// - Parameters:
    ///   - push: The AppPanelPush instance
    ///   - token: The registration token
    func appPanelPush(_ push: AppPanelPush, didReceiveRegistrationToken token: String)

    /// Called when a push notification is received
    /// - Parameters:
    ///   - push: The AppPanelPush instance
    ///   - notification: The received notification
    func appPanelPush(_ push: AppPanelPush, didReceiveNotification notification: AppPanelNotification)

    /// Called when a push notification is tapped by the user
    /// - Parameters:
    ///   - push: The AppPanelPush instance
    ///   - notification: The notification that was tapped
    ///   - actionIdentifier: The action identifier if a custom action was performed
    func appPanelPush(_ push: AppPanelPush, didReceiveNotificationResponse notification: AppPanelNotification, actionIdentifier: String)

    /// Called when an error occurs
    /// - Parameters:
    ///   - push: The AppPanelPush instance
    ///   - error: The error that occurred
    func appPanelPush(_ push: AppPanelPush, didFailWithError error: Error)
}

// Default implementations (all optional)
public extension AppPanelPushDelegate {
    func appPanelPush(_ push: AppPanelPush, didReceiveNotification notification: AppPanelNotification) {}

    func appPanelPush(_ push: AppPanelPush, didReceiveNotificationResponse notification: AppPanelNotification, actionIdentifier: String) {}

    func appPanelPush(_ push: AppPanelPush, didFailWithError error: Error) {}
}