import XCTest
import CoreBluetooth
@testable import TirePressureManager

@MainActor
final class BLEManagerTests: XCTestCase {
    var sut: BLEManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = BLEManager()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    func testInitialState() {
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertTrue(sut.discoveredDevices.isEmpty)
        XCTAssertNil(sut.connectedDeviceName)
        XCTAssertNil(sut.deviceStatus)
        XCTAssertFalse(sut.isScanning)
    }

    func testStartScanning() {
        sut.startScanning()
        XCTAssertTrue(sut.isScanning || sut.connectionState == .bluetoothDisabled)
    }

    func testStopScanning() {
        sut.startScanning()
        sut.stopScanning()
        XCTAssertFalse(sut.isScanning)
    }

    func testStopCommandGeneration() {
        let command = BLECommand.stop
        let data = command.toJSONData()
        XCTAssertNotNil(data)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["command"] as? Int, 1)
            XCTAssertEqual(json["type"] as? String, "command")
        } else {
            XCTFail("Failed to parse command JSON")
        }
    }

    func testStartTargetPressureCommandGeneration() {
        let targetPressure = 32.0
        let command = BLECommand.startTargetPressure(targetPressure: targetPressure)
        let data = command.toJSONData()
        XCTAssertNotNil(data)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["command"] as? Int, 2)
            XCTAssertEqual(json["targetPressure"] as? Double, targetPressure)
            XCTAssertEqual(json["type"] as? String, "command")
        } else {
            XCTFail("Failed to parse command JSON")
        }
    }

    func testDebugModeCommandGeneration() {
        let command = BLECommand.debugMode(enabled: true)
        let data = command.toJSONData()
        XCTAssertNotNil(data)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["command"] as? Int, 7)
            XCTAssertEqual(json["enabled"] as? Bool, true)
            XCTAssertEqual(json["type"] as? String, "command")
        } else {
            XCTFail("Failed to parse command JSON")
        }
    }

    func testRequestSettingsCommandGeneration() {
        let command = BLECommand.requestSettings
        let data = command.toJSONData()
        XCTAssertNotNil(data)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["command"] as? Int, 6)
            XCTAssertEqual(json["type"] as? String, "command")
        } else {
            XCTFail("Failed to parse command JSON")
        }
    }

    func testDeviceStatusModel() {
        let status = DeviceStatus(
            pressure: 30.5,
            operationMode: DeviceStatus.modeInflate,
            rawADC: 1850,
            voltage: 1.234
        )

        XCTAssertEqual(status.pressure, 30.5)
        XCTAssertEqual(status.operationMode, DeviceStatus.modeInflate)
        XCTAssertTrue(status.isInflating)
        XCTAssertFalse(status.isDeflating)
        XCTAssertTrue(status.isOperating)
        XCTAssertEqual(status.rawADC, 1850)
        XCTAssertEqual(status.voltage, 1.234)
        XCTAssertEqual(status.formattedPressure, "30.5 PSI")
    }

    func testDeviceStatusPreserveDebugValues() {
        let previous = DeviceStatus(pressure: 28.0, operationMode: 1, rawADC: 1900, voltage: 1.5)
        let newStatus = DeviceStatus(pressure: 29.0, operationMode: 1, rawADC: nil, voltage: nil)
        let preserved = newStatus.preservingDebugValues(from: previous)

        XCTAssertEqual(preserved.pressure, 29.0)
        XCTAssertEqual(preserved.rawADC, 1900)
        XCTAssertEqual(preserved.voltage, 1.5)
    }

    func testDeviceSettingsFromJSON() {
        let json: [String: Any] = [
            "DeviceName": "TestDevice",
            "wifissid": "MyWiFi",
            "wifipassword": "secret",
            "RelayCompressorPin": 2,
            "RelayFreePin": 3,
            "SensorPin": 34,
            "MaxSecForStatus": 30,
            "SensorValueAt0PSI": "0.228",
            "SensorValueAt50PSI": 2.853,
            "MessureWait": 2.0,
            "Precision": 1.0,
            "BTPinCode": "1234",
            "SimulationMode": false,
            "PressureCalcMethod": 1,
            "operationMode": 4,
            "CurrentPressure": 0.0
        ]

        let settings = DeviceSettings.from(json: json)
        XCTAssertEqual(settings.deviceName, "TestDevice")
        XCTAssertEqual(settings.wifiSsid, "MyWiFi")
        XCTAssertEqual(settings.sensorValueAt0PSI, 0.228, accuracy: 0.001)
        XCTAssertEqual(settings.sensorValueAt50PSI, 2.853, accuracy: 0.001)
        XCTAssertEqual(settings.pressureCalcMethod, 1)
        XCTAssertFalse(settings.simulationMode)
    }

    func testUpdateSettingsCommandGeneration() {
        var settings = DeviceSettings()
        settings.deviceName = "TestDevice"
        settings.sensorValueAt0PSI = 0.228
        settings.sensorValueAt50PSI = 2.853

        let command = BLECommand.updateSettings(settings)
        let data = command.toJSONData()
        XCTAssertNotNil(data)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["command"] as? Int, 3)
            XCTAssertEqual(json["type"] as? String, "settings")
            XCTAssertEqual(json["DeviceName"] as? String, "TestDevice")
            XCTAssertEqual(json["SensorValueAt0PSI"] as? Double ?? 0, 0.228, accuracy: 0.001)
            XCTAssertEqual(json["SensorValueAt50PSI"] as? Double ?? 0, 2.853, accuracy: 0.001)
        } else {
            XCTFail("Failed to parse settings command JSON")
        }
    }

    func testConnectionStates() {
        let states: [ConnectionState] = [.disconnected, .scanning, .connecting, .connected, .bluetoothDisabled, .connectionError]

        for state in states {
            XCTAssertFalse(state.displayText.isEmpty, "Display text should not be empty for state: \(state)")

            switch state {
            case .connected:
                XCTAssertTrue(state.isConnected)
                XCTAssertFalse(state.canScan)
            case .disconnected:
                XCTAssertFalse(state.isConnected)
                XCTAssertTrue(state.canScan)
            default:
                XCTAssertFalse(state.isConnected)
            }
        }
    }
}
