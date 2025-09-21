import Foundation

/// Represents the current status of the tire pressure device
struct DeviceStatus: Codable, Equatable {
    let currentPressure: Double
    let targetPressure: Double?
    let isInflating: Bool
    let isDeflating: Bool
    let batteryLevel: Int?
    let timestamp: Date
    let deviceId: String?

    init(
        currentPressure: Double,
        targetPressure: Double? = nil,
        isInflating: Bool = false,
        isDeflating: Bool = false,
        batteryLevel: Int? = nil,
        timestamp: Date = Date(),
        deviceId: String? = nil
    ) {
        self.currentPressure = currentPressure
        self.targetPressure = targetPressure
        self.isInflating = isInflating
        self.isDeflating = isDeflating
        self.batteryLevel = batteryLevel
        self.timestamp = timestamp
        self.deviceId = deviceId
    }

    var isOperating: Bool {
        return isInflating || isDeflating
    }

    var operationMode: OperationMode {
        if isInflating {
            return .inflating
        } else if isDeflating {
            return .deflating
        } else {
            return .idle
        }
    }

    var pressureDifference: Double? {
        guard let target = targetPressure else { return nil }
        return currentPressure - target
    }

    var formattedCurrentPressure: String {
        return String(format: "%.1f PSI", currentPressure)
    }

    var formattedTargetPressure: String {
        guard let target = targetPressure else { return "" }
        return String(format: "%.1f PSI", target)
    }
}

enum OperationMode: String, CaseIterable {
    case idle = "idle"
    case inflating = "inflating"
    case deflating = "deflating"

    var displayText: String {
        switch self {
        case .idle:
            return ""
        case .inflating:
            return NSLocalizedString("mode_inflating", comment: "Device is inflating")
        case .deflating:
            return NSLocalizedString("mode_deflating", comment: "Device is deflating")
        }
    }
}