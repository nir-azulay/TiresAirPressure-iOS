import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case bluetoothDisabled
    case connectionError

    var isConnected: Bool { self == .connected }

    var canScan: Bool { self == .disconnected }

    var displayText: String {
        switch self {
        case .disconnected:
            return NSLocalizedString("disconnected", comment: "Disconnected")
        case .scanning:
            return NSLocalizedString("scanning", comment: "Scanning")
        case .connecting:
            return NSLocalizedString("connecting", comment: "Connecting")
        case .connected:
            return NSLocalizedString("connected", comment: "Connected")
        case .bluetoothDisabled:
            return NSLocalizedString("bluetooth_disabled", comment: "Bluetooth Disabled")
        case .connectionError:
            return NSLocalizedString("connection_error", comment: "Connection Error")
        }
    }
}
