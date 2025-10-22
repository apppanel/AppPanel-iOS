import Foundation

/// Represents a push notification from AppPanel
public struct AppPanelNotification {

    /// Unique identifier for the notification
    public let id: String?

    /// The notification title
    public let title: String?

    /// The notification body text
    public let body: String?

    /// The notification subtitle (iOS specific)
    public let subtitle: String?

    /// Badge number to display
    public let badge: Int?

    /// Sound to play
    public let sound: String?

    /// Category identifier for custom actions
    public let category: String?

    /// Thread identifier for grouping notifications
    public let threadId: String?

    /// Campaign ID if this notification is part of a campaign
    public let campaignId: String?

    /// Custom data payload
    public let data: [String: Any]?

    /// Deep link URL if provided
    public let deepLink: String?

    /// Image URL for rich notifications
    public let imageUrl: String?

    /// The original user info dictionary
    public let userInfo: [AnyHashable: Any]

    /// Initialize from APNs userInfo dictionary
    public init?(userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo

        // Parse APS payload
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                self.title = alert["title"] as? String
                self.body = alert["body"] as? String
                self.subtitle = alert["subtitle"] as? String
            } else if let alert = aps["alert"] as? String {
                self.title = nil
                self.body = alert
                self.subtitle = nil
            } else {
                self.title = nil
                self.body = nil
                self.subtitle = nil
            }

            self.badge = aps["badge"] as? Int
            self.sound = aps["sound"] as? String
            self.category = aps["category"] as? String
            self.threadId = aps["thread-id"] as? String
        } else {
            self.title = nil
            self.body = nil
            self.subtitle = nil
            self.badge = nil
            self.sound = nil
            self.category = nil
            self.threadId = nil
        }

        // Parse AppPanel custom data
        if let appPanel = userInfo["app_panel"] as? [String: Any] {
            self.id = appPanel["notification_id"] as? String
            self.campaignId = appPanel["campaign_id"] as? String
            self.deepLink = appPanel["deep_link"] as? String
            self.imageUrl = appPanel["image_url"] as? String
            self.data = appPanel["custom_data"] as? [String: Any]
        } else {
            self.id = userInfo["notification_id"] as? String
            self.campaignId = userInfo["campaign_id"] as? String
            self.deepLink = userInfo["deep_link"] as? String
            self.imageUrl = userInfo["image_url"] as? String
            self.data = userInfo["custom_data"] as? [String: Any]
        }
    }

    /// Check if this is a silent notification
    public var isSilent: Bool {
        return title == nil && body == nil && badge == nil && sound == nil
    }

    /// Check if this notification has rich media
    public var hasRichMedia: Bool {
        return imageUrl != nil
    }
}