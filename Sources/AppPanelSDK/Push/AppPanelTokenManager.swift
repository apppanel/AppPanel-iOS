import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// Manages token registration and lifecycle with the AppPanel backend
class AppPanelTokenManager {
    // MARK: - Properties

    private let configuration: AppPanelConfiguration
    private let networkClient: AppPanelNetworkClient
    private let storage: AppPanelStorage

    // MARK: - Initialization

    init(configuration: AppPanelConfiguration) {
        self.configuration = configuration
        networkClient = AppPanelNetworkClient(configuration: configuration)
        storage = AppPanelStorage()
    }

    // MARK: - Token Management

    /// Register an APNs token with the AppPanel backend
    func registerToken(apnsToken: String, completion: ((String?, Error?) -> Void)? = nil) {
        AppPanelLogger.debug("Registering APNs token with AppPanel backend")

        // Check if APNs token has changed
        let lastAPNsToken = storage.getLastAPNsToken()
        let tokenChanged = (lastAPNsToken != nil && lastAPNsToken != apnsToken) || lastAPNsToken == nil

        if tokenChanged {
            AppPanelLogger.info("APNs token has changed, will register new token")

            // Clear old token mappings if APNs token changed
            if let oldToken = lastAPNsToken {
                storage.clearTokenMapping(forAPNsToken: oldToken)
            }
        }

        // Only use cached token if APNs token hasn't changed
        if !tokenChanged, let cachedToken = storage.getPushToken(forAPNsToken: apnsToken) {
            AppPanelLogger.debug("Using cached AppPanel token (APNs token unchanged)")
            completion?(cachedToken, nil)
            return
        }

        // Prepare registration payload - simplified for new endpoint
        let payload: [String: Any] = [
            "device_id": AppPanel.shared.deviceId ?? "unknown",
            "apns_token": apnsToken
        ]

        // Make registration request
        networkClient.request(
            endpoint: "/v1/identify/device/apns",
            method: .post,
            payload: payload
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            guard let self = self else { return }

            switch result {
            case .success:
                // Store the APNs token locally
                self.storage.savePushToken(apnsToken, forAPNsToken: apnsToken)

                AppPanelLogger.info("APNs token registered successfully")
                completion?(apnsToken, nil)

            case let .failure(error):
                AppPanelLogger.error("Failed to register token", error: error)
                completion?(nil, error)
            }
        }
    }

    /// Delete a push token (unregister APNs token from device)
    func deleteToken(_ token: String, completion: @escaping (Bool, Error?) -> Void) {
        AppPanelLogger.debug("Deleting push token")

        // For the new endpoint, we just need to send device_id without apns_token
        let payload: [String: Any] = [
            "device_id": AppPanel.shared.deviceId ?? "unknown"
        ]

        networkClient.request(
            endpoint: "/v1/identify/device/apns",
            method: .delete,
            payload: payload
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                self?.storage.deletePushToken(token)
                completion(true, nil)
            case let .failure(error):
                completion(false, error)
            }
        }
    }

    // TODO: Topic subscription endpoints not yet available
    /*
    /// Subscribe to a topic
    func subscribeToTopic(topic: String, completion: @escaping (Bool, Error?) -> Void) {
        AppPanelLogger.debug("Subscribing to topic: \(topic)")

        // Get the current token
        guard let token = getCachedToken() else {
            completion(false, AppPanelError.tokenNotAvailable)
            return
        }

        let payload: [String: Any] = [
            "token": token,
            "topic": topic,
        ]

        networkClient.request(
            endpoint: "/v1/push/topics/subscribe",
            method: .post,
            payload: payload
        ) { (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                AppPanelLogger.info("Successfully subscribed to topic: \(topic)")
                completion(true, nil)
            case let .failure(error):
                AppPanelLogger.error("Failed to subscribe to topic", error: error)
                completion(false, error)
            }
        }
    }

    /// Unsubscribe from a topic
    func unsubscribeFromTopic(topic: String, completion: @escaping (Bool, Error?) -> Void) {
        AppPanelLogger.debug("Unsubscribing from topic: \(topic)")

        // Get the current token
        guard let token = getCachedToken() else {
            completion(false, AppPanelError.tokenNotAvailable)
            return
        }

        let payload: [String: Any] = [
            "token": token,
            "topic": topic,
        ]

        networkClient.request(
            endpoint: "/v1/push/topics/unsubscribe",
            method: .post,
            payload: payload
        ) { (result: Result<EmptyResponse, Error>) in
            switch result {
            case .success:
                AppPanelLogger.info("Successfully unsubscribed from topic: \(topic)")
                completion(true, nil)
            case let .failure(error):
                AppPanelLogger.error("Failed to unsubscribe from topic", error: error)
                completion(false, error)
            }
        }
    }

    /// Track an analytics event
    func trackEvent(event: String, properties: [String: Any]? = nil) {
        var payload: [String: Any] = ["event": event]
        if let properties = properties {
            payload["properties"] = properties
        }

        if let token = storage.getCurrentPushToken() {
            payload["token"] = token
        }

        networkClient.request(
            endpoint: "/v1/analytics/track",
            method: .post,
            payload: payload
        ) { (result: Result<EmptyResponse, Error>) in
            if case let .failure(error) = result {
                AppPanelLogger.error("Failed to track event: \(event)", error: error)
            }
        }
    }
    */

    /// Get cached token if available
    func getCachedToken() -> String? {
        return storage.getCurrentPushToken()
    }
}
