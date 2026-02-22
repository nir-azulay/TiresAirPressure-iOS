import Foundation

struct DeviceStatus: Equatable {
    let pressure: Double
    let operationMode: Int
    let rawADC: Int?
    let voltage: Double?

    static let modeStop = 1
    static let modeInflate = 2
    static let modeDeflate = 3

    var isInflating: Bool { operationMode == DeviceStatus.modeInflate }
    var isDeflating: Bool { operationMode == DeviceStatus.modeDeflate }
    var isOperating: Bool { isInflating || isDeflating }

    var formattedPressure: String {
        String(format: "%.1f PSI", pressure)
    }

    var operationModeText: String {
        switch operationMode {
        case DeviceStatus.modeInflate:
            return L("mode_inflating", comment: "Inflating")
        case DeviceStatus.modeDeflate:
            return L("mode_deflating", comment: "Deflating")
        default:
            return ""
        }
    }

    func preservingDebugValues(from previous: DeviceStatus?) -> DeviceStatus {
        DeviceStatus(
            pressure: pressure,
            operationMode: operationMode,
            rawADC: rawADC ?? previous?.rawADC,
            voltage: voltage ?? previous?.voltage
        )
    }
}
