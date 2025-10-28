import Foundation

/// Identifies which network environment the SDK should target.
public enum NetworkEnvironment: Encodable, CustomStringConvertible {
    /// Default: Uses the standard latest environment.
    case release
    /// **WARNING**: Uses a release candidate environment. This is not meant for a production environment.
    case releaseCandidate
    /// **WARNING**: Uses the nightly build environment. This is not meant for a production environment.
    case developer
    /// **WARNING**: Uses a custom environment. This is not meant for a production environment.
    case custom(String)

    public var description: String {
        switch self {
        case .release:
            return "release"
        case .releaseCandidate:
            return "releaseCandidate"
        case .developer:
            return "developer"
        case .custom:
            return "custom"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .release:
            try container.encode("release")
        case .releaseCandidate:
            try container.encode("releaseCandidate")
        case .developer:
            try container.encode("developer")
        case let .custom(domain):
            try container.encode(domain)
        }
    }

    private var fallbackURL: URL {
        URL(string: "https://api.apppanel.io")!
    }

    var baseURL: URL {
        if case let .custom(domain) = self {
            if let url = URL(string: domain), url.scheme != nil {
                return url
            }
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = baseHost
        components.port = port

        return components.url ?? fallbackURL
    }

    var scheme: String {
        switch self {
        case .release, .releaseCandidate, .developer:
            return "https"
        case let .custom(domain):
            if let url = URL(string: domain) {
                return url.scheme ?? "https"
            }
            return "https"
        }
    }

    var port: Int? {
        switch self {
        case let .custom(domain):
            if let url = URL(string: domain) {
                return url.port
            }
            return nil
        default:
            return nil
        }
    }

    var hostDomain: String {
        switch self {
        case .release:
            return "apppanel.io"
        case .releaseCandidate:
            return "apppanelcanary.io"
        case .developer:
            return "apppanel.dev"
        case let .custom(domain):
            if let url = URL(string: domain),
               let host = url.host
            {
                return host
            }
            return domain
        }
    }

    var baseHost: String {
        switch self {
        case .custom:
            return hostDomain
        default:
            return "api.\(hostDomain)"
        }
    }
}

/// Configuration for the AppPanel SDK
struct AppPanelConfiguration {
    /// The API key for authentication
    let apiKey: String

    /// Configuration options
    let options: AppPanelOptions

    /// Base URL for the AppPanel API
    var baseURL: URL {
        return options.environment.baseURL
    }

    init(apiKey: String, options: AppPanelOptions) {
        self.apiKey = apiKey
        self.options = options
    }
}

/// Options for configuring the AppPanel SDK
public struct AppPanelOptions {
    /// Network environment the SDK should target.
    public var environment: NetworkEnvironment

    /// Enable verbose logging
    public var enableDebugLogging: Bool = false

    /// Session timeout in seconds
    public var sessionTimeout: TimeInterval = 3600

    public init(
        environment: NetworkEnvironment = .release,
        enableDebugLogging: Bool = false,
        autoInitializePush _: Bool = true,
        sessionTimeout: TimeInterval = 3600
    ) {
        self.environment = environment
        self.enableDebugLogging = enableDebugLogging
        self.sessionTimeout = sessionTimeout
    }
}
