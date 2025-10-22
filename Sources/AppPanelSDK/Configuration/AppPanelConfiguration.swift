import Foundation

/// Configuration for the AppPanel SDK
internal struct AppPanelConfiguration {
    /// The API key for authentication
    let apiKey: String

    /// Configuration options
    let options: AppPanelOptions

    /// Base URL for the AppPanel API
    var baseURL: URL {
        return options.customBaseURL ?? URL(string: "https://api.apppanel.io")!
    }

    init(apiKey: String, options: AppPanelOptions) {
        self.apiKey = apiKey
        self.options = options
    }
}

/// Options for configuring the AppPanel SDK
public struct AppPanelOptions {
    /// Custom base URL for the API (for testing or on-premise deployments)
    public var customBaseURL: URL?

    /// Enable verbose logging
    public var enableDebugLogging: Bool = false

    /// Automatically initialize push notifications on SDK configuration
    public var autoInitializePush: Bool = true

    /// Session timeout in seconds
    public var sessionTimeout: TimeInterval = 3600

    /// Maximum retry attempts for failed requests
    public var maxRetryAttempts: Int = 3

    public init(
        customBaseURL: URL? = nil,
        enableDebugLogging: Bool = false,
        autoInitializePush: Bool = true,
        sessionTimeout: TimeInterval = 3600,
        maxRetryAttempts: Int = 3
    ) {
        self.customBaseURL = customBaseURL
        self.enableDebugLogging = enableDebugLogging
        self.autoInitializePush = autoInitializePush
        self.sessionTimeout = sessionTimeout
        self.maxRetryAttempts = maxRetryAttempts
    }
}