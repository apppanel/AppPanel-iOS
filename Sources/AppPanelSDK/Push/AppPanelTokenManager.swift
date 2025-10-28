import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// Manages token registration and lifecycle with the AppPanel backend
class AppPanelTokenManager {
    private let configuration: AppPanelConfiguration
    private let networkClient: APIClient
    private let storage: AppPanelStorage

    init(configuration: AppPanelConfiguration) {
        self.configuration = configuration
        networkClient = APIClient(baseURL: configuration.baseURL) { config in
            config.sessionConfiguration.httpAdditionalHeaders = [
                "X-AppPanel-SDK-Version": "1.0.0",
                "X-AppPanel-Platform": "iOS",
                "X-AppPanel-API-Key": configuration.apiKey,
            ]
        }
        storage = AppPanelStorage()
    }

    /// Register an APNs token with the AppPanel backend
    func registerToken(apnsToken: String) {
        AppPanelLogger.debug("Registering APNs token with AppPanel")

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
        if !tokenChanged {
            AppPanelLogger.debug("Using cached AppPanel token (APNs token unchanged)")
            return
        }

        // Prepare registration payload - simplified for new endpoint
        struct TokenPayload: Encodable {
            let device_id: String
            let apns_token: String
        }

        let payload = TokenPayload(
            device_id: AppPanel.shared.deviceId.uuidString.lowercased(),
            apns_token: apnsToken
        )

        // Make registration request
        Task { [weak self] in
            guard let self = self else { return }

            do {
                let request = Request<Void>(
                    path: "/v1/identify/device/apns",
                    method: .post,
                    body: payload
                )
                _ = try await self.networkClient.send(request)

                // Store the APNs token locally
                self.storage.savePushToken(apnsToken, forAPNsToken: apnsToken)

                AppPanelLogger.info("APNs token registered successfully")
            } catch {
                AppPanelLogger.error("Failed to register token", error: error)
            }
        }
    }

    /// Delete a push token (unregister APNs token from device)
    func deleteToken(_ token: String, completion: @escaping (Bool, Error?) -> Void) {
        AppPanelLogger.debug("Deleting push token")

        // For the new endpoint, we just need to send device_id without apns_token
        struct DeletePayload: Encodable {
            let device_id: String
        }

        let payload = DeletePayload(device_id: AppPanel.shared.deviceId.uuidString.lowercased())

        Task { [weak self] in
            guard let self = self else { return }

            do {
                let request = Request<Void>(
                    path: "/v1/identify/device/apns",
                    method: .delete,
                    body: payload
                )
                _ = try await self.networkClient.send(request)

                self.storage.deletePushToken(token)
                completion(true, nil)
            } catch {
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
