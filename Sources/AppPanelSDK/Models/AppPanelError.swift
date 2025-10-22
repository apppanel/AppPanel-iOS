import Foundation

/// Errors that can occur in the AppPanel SDK
public enum AppPanelError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case tokenNotAvailable
    case permissionDenied
    case networkError(Error)
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case tokenExpired
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AppPanel SDK is not configured. Call AppPanel.configure() first."
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .tokenNotAvailable:
            return "Push token is not available. Ensure push notifications are properly configured."
        case .permissionDenied:
            return "Push notification permission denied by user"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .tokenExpired:
            return "Push token has expired"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}