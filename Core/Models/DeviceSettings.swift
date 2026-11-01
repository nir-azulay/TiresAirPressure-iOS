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
    var currentPressure: Double = 0.0
    var softwareVersion: String = ""
    var ipAddress: String = ""
    var simulationMode: Bool = false
    var pressureCalcMethod: Int = 1
    var sensorFullScalePSI: Double = 50.0
    var maxPressurePSI: Double = 50.0
    var maxValveOpenSec: Int = 120
    var accessPointPassword: String = "12345678"
    var hasAccessCode: Bool = false
    var accessCode: String = ""
    var clearAccessCode: Bool = false

    static func from(json: [String: Any]) -> DeviceSettings {
        var s = DeviceSettings()
        s.operationMode = intValue(json["operationMode"]) ?? 4
        let name = (stringValue(json["DeviceName"]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        s.deviceName = name.isEmpty ? "esp32-AirUpDownController" : name
        s.wifiSsid = stringValue(json["wifissid"]) ?? ""
        s.wifiPassword = stringValue(json["wifipassword"]) ?? ""
        let compPin = intValue(json["RelayCompressorPin"]) ?? 16
        s.relayCompressorPin = (1...39).contains(compPin) ? compPin : 16
        let freePin = intValue(json["RelayFreePin"]) ?? 17
        s.relayFreePin = (1...39).contains(freePin) ? freePin : 17
        let sensPin = intValue(json["SensorPin"]) ?? 34
        s.sensorPin = (32...39).contains(sensPin) ? sensPin : 34
        let maxSec = intValue(json["MaxSecForStatus"]) ?? 10
        s.maxSecForStatus = (1...300).contains(maxSec) ? maxSec : 10
        let v0 = doubleValue(json["SensorValueAt0PSI"]) ?? 410.0
        let v50 = doubleValue(json["SensorValueAt50PSI"]) ?? 3400.0
        if v0 >= 0 && v50 > 0 && v0 != v50 {
            s.sensorValueAt0PSI = v0
            s.sensorValueAt50PSI = v50
        } else {
            s.sensorValueAt0PSI = 410.0
            s.sensorValueAt50PSI = 3400.0
        }
        let waitSec = doubleValue(json["MessureWait"]) ?? 1.0
        s.measureWait = (0.2...60.0).contains(waitSec) ? waitSec : 1.0
        let prec = doubleValue(json["Precision"]) ?? 0.5
        s.precision = (0.1...10.0).contains(prec) ? prec : 0.5
        s.currentPressure = max(0.0, doubleValue(json["CurrentPressure"]) ?? 0.0)
        s.softwareVersion = stringValue(json["Software_VER"]) ?? ""
        s.ipAddress = stringValue(json["IP"]) ?? ""
        s.simulationMode = boolValue(json["SimulationMode"]) ?? false
        let method = intValue(json["PressureCalcMethod"]) ?? 1
        s.pressureCalcMethod = (method == 1 || method == 2) ? method : 1
        let fullScale = doubleValue(json["SensorFullScalePSI"]) ?? 50.0
        s.sensorFullScalePSI = (fullScale > 0 && fullScale <= 300.0) ? fullScale : 50.0
        let maxPsi = doubleValue(json["MaxPressurePSI"]) ?? 50.0
        s.maxPressurePSI = (maxPsi > 0 && maxPsi <= 200.0) ? maxPsi : 50.0
        let maxValveSec = intValue(json["MaxValveOpenSec"]) ?? 120
        s.maxValveOpenSec = (10...3600).contains(maxValveSec) ? maxValveSec : 120
        let apPwd = stringValue(json["AccessPointPassword"]) ?? "12345678"
        s.accessPointPassword = apPwd.count >= 8 ? apPwd : "12345678"
        s.hasAccessCode = boolValue(json["HasAccessCode"]) ?? false
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
            return L("adc_calibration", comment: "ADC Calibration")
        case .voltageCalibration:
            return L("voltage_calibration", comment: "Voltage Calibration")
        }
    }
}
