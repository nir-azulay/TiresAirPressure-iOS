import Foundation

/// Represents the current state of the Bluetooth connection
enum ConnectionState: String, CaseIterable {
    case disconnected = "Disconnected"
    case scanning = "Scanning"
    case connecting = "Connecting"
    case connected = "Connected"
    case bluetoothDisabled = "Bluetooth Disabled"
    case connectionError = "Connection Error"

    var isConnected: Bool {
        return self == .connected
    }

    var canScan: Bool {
        return self == .disconnected
    }

    var displayText: String {
        switch self {
        case .disconnected:
            return NSLocalizedString("disconnected", comment: "Device disconnected")
        case .scanning:
            return NSLocalizedString("scanning", comment: "Scanning for devices")
        case .connecting:
            return NSLocalizedString("connecting", comment: "Connecting to device")
        case .connected:
            return NSLocalizedString("connected", comment: "Device connected")
        case .bluetoothDisabled:
            return NSLocalizedString("bluetooth_disabled", comment: "Bluetooth is disabled")
        case .connectionError:
            return NSLocalizedString("connection_error", comment: "Connection error occurred")
        }
    }
}