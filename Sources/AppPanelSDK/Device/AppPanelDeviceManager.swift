import Foundation

/// Manages the persistent device ID for the AppPanel SDK
class AppPanelDeviceManager {

    private let storage = AppPanelStorage()

    /// Get or generate the device ID
    func getDeviceId() -> UUID {
        let deviceId = storage.getDeviceId()
        AppPanelLogger.debug("Device ID: \(deviceId)")
        return deviceId
    }

    /// Regenerate the device ID (user-initiated)
    func regenerateDeviceId() -> UUID {
        let newId = storage.regenerateDeviceId()
        AppPanelLogger.info("Regenerated device ID: \(newId)")
        return newId
    }
}