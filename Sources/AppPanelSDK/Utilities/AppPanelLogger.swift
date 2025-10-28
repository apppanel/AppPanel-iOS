//
//  AppPanelLogger.swift
//  AppPanelSDK
//
//  Created by AppPanel Team
//

import Foundation

// MARK: - Log Level

public enum LogLevel: Int, CustomStringConvertible {
    case debug = 0
    case info = 1
    case warn = 2
    case error = 3
    case none = 999

    public var description: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warn:
            return "WARN"
        case .error:
            return "ERROR"
        case .none:
            return "NONE"
        }
    }

    var descriptionEmoji: String {
        switch self {
        case .debug:
            return "🔍"
        case .info:
            return "ℹ️"
        case .warn:
            return "⚠️"
        case .error:
            return "❌"
        case .none:
            return ""
        }
    }
}

// MARK: - Loggable Protocol

protocol Loggable {
    static func shouldPrint(logLevel: LogLevel) -> Bool

    static func debug(
        logLevel: LogLevel,
        message: String?,
        info: [String: Any]?,
        error: Swift.Error?
    )
}

extension Loggable {
    static func debug(
        logLevel: LogLevel,
        message: String? = nil,
        info: [String: Any]? = nil,
        error: Swift.Error? = nil
    ) {
        debug(
            logLevel: logLevel,
            message: message,
            info: info,
            error: error
        )
    }
}

// MARK: - Logger Implementation

enum AppPanelLogger: Loggable {
    static func shouldPrint(logLevel: LogLevel) -> Bool {
        var currentLogLevel: LogLevel

        if let options = AppPanel.shared.configuration?.options {
            currentLogLevel = options.enableDebugLogging ? .debug : .info
        } else {
            currentLogLevel = .info
        }

        if currentLogLevel == .none {
            return false
        }

        return logLevel.rawValue >= currentLogLevel.rawValue
    }

    static func debug(
        logLevel: LogLevel,
        message: String? = nil,
        info: [String: Any]? = nil,
        error: Swift.Error? = nil
    ) {
        Task.detached(priority: .utility) {
            guard shouldPrint(logLevel: logLevel) else {
                return
            }

            // Only create expensive debug strings if we're actually going to print
            var dumping: [String: Any] = [:]

            if let info = info {
                dumping["info"] = info
            }

            if let error = error {
                dumping["error"] = error
            }

            var name = "\(Date().isoString) \(logLevel.descriptionEmoji) [AppPanel] - \(logLevel.description)"

            if let message = message {
                name += ": \(message)"
            }

            if dumping.isEmpty {
                print(name)
            } else {
                dump(
                    dumping,
                    name: name,
                    indent: 0,
                    maxDepth: 100,
                    maxItems: 100
                )
            }
        }
    }
}

// MARK: - Convenience Methods

extension AppPanelLogger {
    static func debug(_ message: String, info: [String: Any]? = nil) {
        debug(logLevel: .debug, message: message, info: info, error: nil)
    }

    static func info(_ message: String, info: [String: Any]? = nil) {
        debug(logLevel: .info, message: message, info: info, error: nil)
    }

    static func warn(_ message: String, info: [String: Any]? = nil) {
        debug(logLevel: .warn, message: message, info: info, error: nil)
    }

    static func error(_ message: String, error: Swift.Error? = nil, info: [String: Any]? = nil) {
        debug(logLevel: .error, message: message, info: info, error: error)
    }
}

// MARK: - Date Extension

extension Date {
    var isoString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

// MARK: - Error Extension

extension Swift.Error {
    var safeLocalizedDescription: String {
        return localizedDescription
    }
}
