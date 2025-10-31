import Foundation
#if canImport(UIKit)
    import UIKit
#endif

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
}
