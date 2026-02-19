import Foundation

struct DeviceSettings: Equatable {
    var operationMode: Int = 4
    var deviceName: String = ""
    var wifiSsid: String = ""
    var wifiPassword: String = ""
    var relayCompressorPin: Int = 0
    var relayFreePin: Int = 0
    var sensorPin: Int = 0
    var maxSecForStatus: Int = 30
    var sensorValueAt0PSI: Double = 0.228
    var sensorValueAt50PSI: Double = 2.853
    var measureWait: Double = 2.0
    var precision: Double = 1.0
    var btPinCode: String = "1234"
    var currentPressure: Double = 0.0
    var softwareVersion: String = ""
    var ipAddress: String = ""
    var simulationMode: Bool = false
    var pressureCalcMethod: Int = 1

    static func from(json: [String: Any]) -> DeviceSettings {
        var s = DeviceSettings()
        s.operationMode = json["operationMode"] as? Int ?? 4
        s.deviceName = stringValue(json["DeviceName"]) ?? ""
        s.wifiSsid = stringValue(json["wifissid"]) ?? ""
        s.wifiPassword = stringValue(json["wifipassword"]) ?? ""
        s.relayCompressorPin = intValue(json["RelayCompressorPin"]) ?? 0
        s.relayFreePin = intValue(json["RelayFreePin"]) ?? 0
        s.sensorPin = intValue(json["SensorPin"]) ?? 0
        s.maxSecForStatus = intValue(json["MaxSecForStatus"]) ?? 30
        s.sensorValueAt0PSI = doubleValue(json["SensorValueAt0PSI"]) ?? 0.228
        s.sensorValueAt50PSI = doubleValue(json["SensorValueAt50PSI"]) ?? 2.853
        s.measureWait = doubleValue(json["MessureWait"]) ?? 2.0
        s.precision = doubleValue(json["Precision"]) ?? 1.0
        s.btPinCode = stringValue(json["BTPinCode"]) ?? "1234"
        s.currentPressure = doubleValue(json["CurrentPressure"]) ?? 0.0
        s.softwareVersion = stringValue(json["Software_VER"]) ?? ""
        s.ipAddress = stringValue(json["IP"]) ?? ""
        s.simulationMode = boolValue(json["SimulationMode"]) ?? false
        s.pressureCalcMethod = intValue(json["PressureCalcMethod"]) ?? 1
        return s
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? Double { return Int(n) }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? Int { return n != 0 }
        if let s = value as? String { return s.lowercased() == "true" || s == "1" }
        return nil
    }
}

enum PressureCalcMethod: Int, CaseIterable {
    case adcCalibration = 1
    case voltageCalibration = 2

    var displayText: String {
        switch self {
        case .adcCalibration:
            return NSLocalizedString("adc_calibration", comment: "ADC Calibration")
        case .voltageCalibration:
            return NSLocalizedString("voltage_calibration", comment: "Voltage Calibration")
        }
    }
}
