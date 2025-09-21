import Foundation

/// Represents the configuration settings for the tire pressure device
struct DeviceSettings: Codable, Equatable {
    let deviceName: String
    let wifiSettings: WiFiSettings?
    let hardwareSettings: HardwareSettings
    let calibrationSettings: CalibrationSettings
    let autoStart: Bool
    let bluetoothPinCode: String?

    init(
        deviceName: String = "TirePressureDevice",
        wifiSettings: WiFiSettings? = nil,
        hardwareSettings: HardwareSettings = HardwareSettings(),
        calibrationSettings: CalibrationSettings = CalibrationSettings(),
        autoStart: Bool = false,
        bluetoothPinCode: String? = nil
    ) {
        self.deviceName = deviceName
        self.wifiSettings = wifiSettings
        self.hardwareSettings = hardwareSettings
        self.calibrationSettings = calibrationSettings
        self.autoStart = autoStart
        self.bluetoothPinCode = bluetoothPinCode
    }
}

/// WiFi connection settings for the device
struct WiFiSettings: Codable, Equatable {
    let ssid: String
    let password: String?
    let signalStrength: Int?

    init(ssid: String, password: String? = nil, signalStrength: Int? = nil) {
        self.ssid = ssid
        self.password = password
        self.signalStrength = signalStrength
    }
}

/// Hardware pin configuration settings
struct HardwareSettings: Codable, Equatable {
    let relayCompressorPin: Int
    let relayFreePin: Int
    let sensorPin: Int

    init(
        relayCompressorPin: Int = 2,
        relayFreePin: Int = 3,
        sensorPin: Int = 34
    ) {
        self.relayCompressorPin = relayCompressorPin
        self.relayFreePin = relayFreePin
        self.sensorPin = sensorPin
    }
}

/// Pressure sensor calibration settings
struct CalibrationSettings: Codable, Equatable {
    let sensorValueAt0PSI: Double
    let sensorValueAt50PSI: Double
    let precisionPSI: Double
    let maxSecForStatus: Int
    let measureWaitTime: Int
    let pressureCalcMethod: PressureCalcMethod

    init(
        sensorValueAt0PSI: Double = 0.5,
        sensorValueAt50PSI: Double = 4.5,
        precisionPSI: Double = 0.5,
        maxSecForStatus: Int = 30,
        measureWaitTime: Int = 2,
        pressureCalcMethod: PressureCalcMethod = .adcCalibration
    ) {
        self.sensorValueAt0PSI = sensorValueAt0PSI
        self.sensorValueAt50PSI = sensorValueAt50PSI
        self.precisionPSI = precisionPSI
        self.maxSecForStatus = maxSecForStatus
        self.measureWaitTime = measureWaitTime
        self.pressureCalcMethod = pressureCalcMethod
    }
}

/// Method used for pressure calculation
enum PressureCalcMethod: String, Codable, CaseIterable {
    case adcCalibration = "adc_calibration"
    case voltageCalibration = "voltage_calibration"

    var displayText: String {
        switch self {
        case .adcCalibration:
            return NSLocalizedString("adc_calibration", comment: "ADC calibration method")
        case .voltageCalibration:
            return NSLocalizedString("voltage_calibration", comment: "Voltage calibration method")
        }
    }
}

/// Response structure for device settings requests
struct DeviceSettingsResponse: Codable, Equatable {
    let settings: DeviceSettings
    let status: String
    let timestamp: Date

    init(settings: DeviceSettings, status: String = "success", timestamp: Date = Date()) {
        self.settings = settings
        self.status = status
        self.timestamp = timestamp
    }
}