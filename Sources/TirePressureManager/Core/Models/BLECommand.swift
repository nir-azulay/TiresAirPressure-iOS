import Foundation

/// Represents commands that can be sent to the tire pressure device via BLE
enum BLECommand: String, CaseIterable {
    case startInflation = "START_INFLATION"
    case startDeflation = "START_DEFLATION"
    case stopOperation = "STOP_OPERATION"
    case getStatus = "GET_STATUS"
    case getSettings = "GET_SETTINGS"
    case setSettings = "SET_SETTINGS"
    case calibrate = "CALIBRATE"
    case reset = "RESET"

    /// Convert command to JSON data for transmission
    func toJSONData(parameters: [String: Any] = [:]) -> Data? {
        var commandDict: [String: Any] = [
            "command": self.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        // Add parameters if provided
        for (key, value) in parameters {
            commandDict[key] = value
        }

        return try? JSONSerialization.data(withJSONObject: commandDict, options: [])
    }

    /// Create inflation command with target pressure
    static func inflateToTarget(_ pressure: Double) -> Data? {
        return BLECommand.startInflation.toJSONData(parameters: ["targetPressure": pressure])
    }

    /// Create deflation command with target pressure
    static func deflateToTarget(_ pressure: Double) -> Data? {
        return BLECommand.startDeflation.toJSONData(parameters: ["targetPressure": pressure])
    }

    /// Create settings update command
    static func updateSettings(_ settings: DeviceSettings) -> Data? {
        do {
            let settingsData = try JSONEncoder().encode(settings)
            let settingsDict = try JSONSerialization.jsonObject(with: settingsData, options: [])
            return BLECommand.setSettings.toJSONData(parameters: ["settings": settingsDict])
        } catch {
            return nil
        }
    }
}

/// Constants for BLE service and characteristic UUIDs
struct BLEConstants {
    // Service UUID - matches Android app
    static let serviceUUID = "12345678-1234-1234-1234-123456789abc"

    // Characteristic UUIDs
    static let commandCharacteristicUUID = "87654321-4321-4321-4321-210987654321"
    static let notifyCharacteristicUUID = "11223344-5566-7788-99aa-bbccddeeff00"

    // Device name filter
    static let deviceNamePrefix = "TirePressure"

    // Connection timeouts
    static let connectionTimeout: TimeInterval = 10.0
    static let scanTimeout: TimeInterval = 30.0
}