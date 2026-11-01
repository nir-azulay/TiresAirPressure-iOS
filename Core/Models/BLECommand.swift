import Foundation

struct BLEConstants {
    static let serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
    static let notifyCharacteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
    static let commandCharacteristicUUID = "e3223119-9445-4e96-a4a1-85358c4046a2"
    static let clientConfigDescriptorUUID = "00002902-0000-1000-8000-00805f9b34fb"

    static let mtuSize = 517
    static let scanTimeout: TimeInterval = 10.0
    static let connectionTimeout: TimeInterval = 10.0

    static let modeStop = 1
    static let modeInflate = 2
    static let modeDeflate = 3
    static let modeSettings = 4
}

enum BLECommand {
    case stop
    case startTargetPressure(targetPressure: Double)
    case updateSettings(DeviceSettings)
    case simulationMode(enabled: Bool)
    case requestSettings
    case requestStatus
    case debugMode(enabled: Bool)
    case authenticate(accessCode: String)
    case scanWifi(rescan: Bool)

    static let cmdStop = 1
    static let cmdStart = 2
    static let cmdUpdateSettings = 3
    static let cmdSimulationMode = 4
    static let cmdLogLevel = 5
    static let cmdGetSettings = 6
    static let cmdRequestStatus = 7
    static let cmdAuthenticate = 8
    static let cmdScanWifi = 9

    func toJSONData() -> Data? {
        var dict: [String: Any]

        switch self {
        case .stop:
            dict = [
                "command": BLECommand.cmdStop,
                "type": "command"
            ]

        case .startTargetPressure(let targetPressure):
            dict = [
                "command": BLECommand.cmdStart,
                "targetPressure": targetPressure,
                "type": "command"
            ]

        case .updateSettings(let settings):
            dict = [
                "command": BLECommand.cmdUpdateSettings,
                "DeviceName": settings.deviceName,
                "wifissid": settings.wifiSsid,
                "wifipassword": settings.wifiPassword,
                "RelayCompressorPin": settings.relayCompressorPin,
                "RelayFreePin": settings.relayFreePin,
                "SensorPin": settings.sensorPin,
                "MaxSecForStatus": settings.maxSecForStatus,
                "SensorValueAt0PSI": (settings.sensorValueAt0PSI * 1000).rounded() / 1000,
                "SensorValueAt50PSI": (settings.sensorValueAt50PSI * 1000).rounded() / 1000,
                "MessureWait": (settings.measureWait * 100).rounded() / 100,
                "Precision": (settings.precision * 100).rounded() / 100,
                "SimulationMode": settings.simulationMode,
                "PressureCalcMethod": settings.pressureCalcMethod,
                "SensorFullScalePSI": (settings.sensorFullScalePSI * 10).rounded() / 10,
                "MaxPressurePSI": (settings.maxPressurePSI * 10).rounded() / 10,
                "MaxValveOpenSec": settings.maxValveOpenSec,
                "AccessPointPassword": settings.accessPointPassword,
                "AccessCode": settings.accessCode,
                "ClearAccessCode": settings.clearAccessCode,
                "type": "settings"
            ]

        case .simulationMode(let enabled):
            dict = [
                "command": BLECommand.cmdSimulationMode,
                "enabled": enabled,
                "type": "command"
            ]

        case .requestSettings:
            dict = [
                "command": BLECommand.cmdGetSettings,
                "type": "command"
            ]

        case .requestStatus:
            dict = [
                "command": BLECommand.cmdRequestStatus,
                "type": "command"
            ]

        case .debugMode(let enabled):
            dict = [
                "command": 7,
                "enabled": enabled,
                "type": "command"
            ]

        case .authenticate(let accessCode):
            dict = [
                "command": BLECommand.cmdAuthenticate,
                "accessCode": accessCode,
                "type": "command"
            ]

        case .scanWifi(let rescan):
            dict = [
                "command": BLECommand.cmdScanWifi,
                "rescan": rescan,
                "type": "command"
            ]
        }

        return try? JSONSerialization.data(withJSONObject: dict, options: [])
    }
}
