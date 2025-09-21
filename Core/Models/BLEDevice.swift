import Foundation
import CoreBluetooth

/// Represents a discovered Bluetooth Low Energy device
struct BLEDevice: Identifiable, Equatable {
    let id = UUID()
    let peripheral: CBPeripheral
    let advertisementData: [String: Any]
    let rssi: Int

    var name: String {
        return peripheral.name ??
               advertisementData[CBAdvertisementDataLocalNameKey] as? String ??
               NSLocalizedString("unknown_device", comment: "Unknown device name")
    }

    var address: String {
        return peripheral.identifier.uuidString
    }

    var signalStrengthText: String {
        return String(format: NSLocalizedString("signal_strength_format", comment: "Signal strength format"), rssi)
    }

    var signalStrength: SignalStrength {
        switch rssi {
        case -50...0:
            return .excellent
        case -60..<(-50):
            return .good
        case -70..<(-60):
            return .fair
        case -80..<(-70):
            return .weak
        default:
            return .noSignal
        }
    }

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}

enum SignalStrength: String, CaseIterable {
    case excellent = "excellent_signal"
    case good = "good_signal"
    case fair = "fair_signal"
    case weak = "weak_signal"
    case noSignal = "no_signal"

    var displayText: String {
        return NSLocalizedString(self.rawValue, comment: "Signal strength description")
    }
}