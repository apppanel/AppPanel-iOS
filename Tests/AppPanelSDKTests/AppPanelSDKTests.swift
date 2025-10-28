@testable import AppPanelSDK
import XCTest

final class AppPanelSDKTests: XCTestCase {
    func testSDKConfiguration() {
        // Test that SDK starts unconfigured
        XCTAssertFalse(AppPanel.shared.isConfigured)
        XCTAssertNil(AppPanel.shared.push)

        // Configure SDK
        AppPanel.configure(apiKey: "test-api-key")

        // Verify configuration
        XCTAssertTrue(AppPanel.shared.isConfigured)
        XCTAssertNotNil(AppPanel.shared.push)
    }

    func testConfigurationWithOptions() {
        let customURL = "https://test.apppanel.io"
        let options = AppPanelOptions(
            environment: .custom(customURL),
            enableDebugLogging: true,
            autoInitializePush: false,
            sessionTimeout: 900,
            maxRetryAttempts: 3
        )

        AppPanel.configure(apiKey: "test-api-key", options: options)

        XCTAssertTrue(AppPanel.shared.isConfigured)
        XCTAssertNotNil(AppPanel.shared.push)
        XCTAssertEqual(AppPanel.shared.configuration?.baseURL, URL(string: customURL))
        XCTAssertEqual(AppPanel.shared.configuration?.options.enableDebugLogging, true)
        XCTAssertEqual(AppPanel.shared.configuration?.options.sessionTimeout, 900)
        XCTAssertEqual(AppPanel.shared.configuration?.options.maxRetryAttempts, 10)
    }

    func testEmptyAPIKeyValidation() {
        // Configure with empty API key should fail
        AppPanel.configure(apiKey: "")
        XCTAssertFalse(AppPanel.shared.isConfigured)
        XCTAssertNil(AppPanel.shared.push)
    }

    func testNotificationParsing() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Test Title",
                    "body": "Test Body",
                    "subtitle": "Test Subtitle",
                ],
                "badge": 5,
                "sound": "default",
            ],
            "app_panel": [
                "notification_id": "12345",
                "campaign_id": "campaign_123",
                "deep_link": "myapp://home",
                "image_url": "https://example.com/image.jpg",
                "custom_data": [
                    "key": "value",
                ],
            ],
        ]

        guard let notification = AppPanelNotification(userInfo: userInfo) else {
            XCTFail("Should parse notification")
            return
        }

        XCTAssertEqual(notification.title, "Test Title")
        XCTAssertEqual(notification.body, "Test Body")
        XCTAssertEqual(notification.subtitle, "Test Subtitle")
        XCTAssertEqual(notification.badge, 5)
        XCTAssertEqual(notification.sound, "default")
        XCTAssertEqual(notification.id, "12345")
        XCTAssertEqual(notification.campaignId, "campaign_123")
        XCTAssertEqual(notification.deepLink, "myapp://home")
        XCTAssertEqual(notification.imageUrl, "https://example.com/image.jpg")
        XCTAssertNotNil(notification.data)
        XCTAssertFalse(notification.isSilent)
        XCTAssertTrue(notification.hasRichMedia)
    }

    func testSilentNotificationDetection() {
        let silentUserInfo: [AnyHashable: Any] = [
            "aps": [:],
            "custom_data": ["key": "value"],
        ]

        guard let notification = AppPanelNotification(userInfo: silentUserInfo) else {
            XCTFail("Should parse silent notification")
            return
        }

        XCTAssertTrue(notification.isSilent)
        XCTAssertFalse(notification.hasRichMedia)
    }

    func testErrorDescriptions() {
        let errors: [AppPanelError] = [
            .notConfigured,
            .invalidAPIKey,
            .tokenNotAvailable,
            .permissionDenied,
            .invalidResponse,
            .tokenExpired,
            .serverError(statusCode: 500, message: "Internal error"),
            .invalidConfiguration("Missing parameter"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
