import Foundation

/// HTTP methods
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// Network client for AppPanel API communication
class AppPanelNetworkClient {
    private let configuration: AppPanelConfiguration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: AppPanelConfiguration) {
        self.configuration = configuration

        // Configure URLSession
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        sessionConfig.waitsForConnectivity = true

        // Add default headers
        sessionConfig.httpAdditionalHeaders = [
            "X-AppPanel-SDK-Version": "1.0.0",
            "X-AppPanel-Platform": "iOS",
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]

        session = URLSession(configuration: sessionConfig)

        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Make a network request to the AppPanel API
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        payload: [String: Any]? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Build URL
        guard let url = URL(string: endpoint, relativeTo: configuration.baseURL) else {
            completion(.failure(AppPanelError.invalidConfiguration("Invalid endpoint: \(endpoint)")))
            return
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add API key header
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        // Add payload if provided
        if let payload = payload {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                completion(.failure(error))
                return
            }
        }

        // Log request if debug is enabled
        if configuration.options.enableDebugLogging {
            AppPanelLogger.debug("Request: \(method.rawValue) \(url.absoluteString)")
            if let payload = payload {
                AppPanelLogger.debug("Payload: \(payload)")
            }
        }

        // Perform request with retry logic
        performRequest(request, retryCount: 0, maxRetries: configuration.options.maxRetryAttempts, completion: completion)
    }

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        retryCount: Int,
        maxRetries: Int,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            // Handle network error
            if let error = error {
                if retryCount < maxRetries {
                    // Retry with exponential backoff
                    let delay = pow(2.0, Double(retryCount))
                    AppPanelLogger.debug("Retrying request after \(delay) seconds (attempt \(retryCount + 1)/\(maxRetries))")

                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequest(request, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(AppPanelError.networkError(error)))
                    }
                }
                return
            }

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(AppPanelError.invalidResponse))
                }
                return
            }

            // Log response if debug is enabled
            if self.configuration.options.enableDebugLogging {
                AppPanelLogger.debug("Response: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    AppPanelLogger.debug("Body: \(responseString)")
                }
            }

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200 ... 299:
                // Success
                guard let data = data else {
                    // Handle empty response
                    if T.self == EmptyResponse.self {
                        DispatchQueue.main.async {
                            completion(.success(EmptyResponse() as! T))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(AppPanelError.invalidResponse))
                        }
                    }
                    return
                }

                do {
                    let decoded = try self.decoder.decode(T.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(decoded))
                    }
                } catch {
                    AppPanelLogger.error("Failed to decode response", error: error)
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }

            case 401:
                // Unauthorized - Invalid API key
                DispatchQueue.main.async {
                    completion(.failure(AppPanelError.invalidAPIKey))
                }

            case 403:
                // Forbidden - Token expired
                DispatchQueue.main.async {
                    completion(.failure(AppPanelError.tokenExpired))
                }

            case 429:
                // Rate limited - Retry with backoff
                if retryCount < maxRetries {
                    let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String
                    let delay = Double(retryAfter ?? "5") ?? 5.0

                    AppPanelLogger.debug("Rate limited, retrying after \(delay) seconds")

                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequest(request, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(AppPanelError.serverError(statusCode: 429, message: "Rate limit exceeded")))
                    }
                }

            case 500 ... 599:
                // Server error - Retry
                if retryCount < maxRetries {
                    let delay = pow(2.0, Double(retryCount))
                    AppPanelLogger.debug("Server error, retrying after \(delay) seconds")

                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequest(request, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                    }
                } else {
                    let message = self.extractErrorMessage(from: data)
                    DispatchQueue.main.async {
                        completion(.failure(AppPanelError.serverError(statusCode: httpResponse.statusCode, message: message)))
                    }
                }

            default:
                // Other errors
                let message = self.extractErrorMessage(from: data)
                DispatchQueue.main.async {
                    completion(.failure(AppPanelError.serverError(statusCode: httpResponse.statusCode, message: message)))
                }
            }
        }

        task.resume()
    }

    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["message"] as? String ?? json["error"] as? String
            }
        } catch {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }
}

// Empty response for endpoints that don't return data
struct EmptyResponse: Codable {}
