import Foundation
import os

/// Internal logging utility for the AppPanel SDK
class AppPanelLogger {
    private static let subsystem = "io.apppanel.sdk"
    private static let category = "AppPanel"

    private static var isDebugEnabled: Bool {
        return AppPanel.shared.configuration?.options.enableDebugLogging ?? false
    }

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugEnabled else { return }
        let fileName = (file as NSString).lastPathComponent
        log(level: .debug, "[\(fileName):\(line)] \(function) - \(message)")
    }

    static func info(_ message: String) {
        log(level: .info, message)
    }

    static func warning(_ message: String) {
        log(level: .default, message)
    }

    static func error(_ message: String, error: Error? = nil) {
        if let error = error {
            log(level: .error, "\(message) - Error: \(error.localizedDescription)")
        } else {
            log(level: .error, message)
        }
    }

    static func critical(_ message: String, error: Error? = nil) {
        if let error = error {
            log(level: .fault, "\(message) - Error: \(error.localizedDescription)")
        } else {
            log(level: .fault, message)
        }
    }

    private static func log(level: OSLogType, _ message: String) {
        if #available(iOS 14.0, macOS 11.0, *) {
            let logger = Logger(subsystem: subsystem, category: category)
            switch level {
            case .debug:
                logger.debug("\(message)")
            case .info:
                logger.info("\(message)")
            case .default:
                logger.notice("\(message)")
            case .error:
                logger.error("\(message)")
            case .fault:
                logger.critical("\(message)")
            default:
                logger.log("\(message)")
            }
        } else {
            // Fallback for older OS versions
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: category), type: level, message)
        }
    }
}
