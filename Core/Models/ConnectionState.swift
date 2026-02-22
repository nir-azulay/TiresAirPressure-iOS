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
            return L("disconnected", comment: "Disconnected")
        case .scanning:
            return L("scanning", comment: "Scanning")
        case .connecting:
            return L("connecting", comment: "Connecting")
        case .connected:
            return L("connected", comment: "Connected")
        case .bluetoothDisabled:
            return L("bluetooth_disabled", comment: "Bluetooth Disabled")
        case .connectionError:
            return L("connection_error", comment: "Connection Error")
        }
    }
}
