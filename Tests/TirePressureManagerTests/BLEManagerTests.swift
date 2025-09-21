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
        // Given & When - BLEManager is initialized

        // Then
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertTrue(sut.discoveredDevices.isEmpty)
        XCTAssertNil(sut.connectedDeviceName)
        XCTAssertNil(sut.deviceStatus)
        XCTAssertFalse(sut.isScanning)
    }

    func testStartScanning() {
        // Given
        // BLE manager is in initial state

        // When
        sut.startScanning()

        // Then
        // Note: This would need to be mocked in a real test environment
        // For now, we test the state changes
        XCTAssertTrue(sut.isScanning || sut.connectionState == .bluetoothDisabled)
    }

    func testStopScanning() {
        // Given
        sut.startScanning()

        // When
        sut.stopScanning()

        // Then
        XCTAssertFalse(sut.isScanning)
    }

    func testInflationCommandGeneration() {
        // Given
        let targetPressure = 32.0

        // When
        let commandData = BLECommand.inflateToTarget(targetPressure)

        // Then
        XCTAssertNotNil(commandData)

        // Verify the JSON structure
        if let commandData = commandData,
           let json = try? JSONSerialization.jsonObject(with: commandData) as? [String: Any] {
            XCTAssertEqual(json["command"] as? String, "START_INFLATION")
            XCTAssertEqual(json["targetPressure"] as? Double, targetPressure)
            XCTAssertNotNil(json["timestamp"])
        } else {
            XCTFail("Failed to parse command JSON")
        }
    }

    func testDeflationCommandGeneration() {
        // Given
        let targetPressure = 28.0

        // When
        let commandData = BLECommand.deflateToTarget(targetPressure)

        // Then
        XCTAssertNotNil(commandData)

        // Verify the JSON structure
        if let commandData = commandData,
           let json = try? JSONSerialization.jsonObject(with: commandData) as? [String: Any] {
            XCTAssertEqual(json["command"] as? String, "START_DEFLATION")
            XCTAssertEqual(json["targetPressure"] as? Double, targetPressure)
            XCTAssertNotNil(json["timestamp"])
        } else {
            XCTFail("Failed to parse command JSON")
        }
    }

    func testDeviceStatusParsing() {
        // Given
        let deviceStatus = DeviceStatus(
            currentPressure: 30.5,
            targetPressure: 32.0,
            isInflating: true,
            isDeflating: false,
            batteryLevel: 85
        )

        // When & Then
        XCTAssertEqual(deviceStatus.currentPressure, 30.5)
        XCTAssertEqual(deviceStatus.targetPressure, 32.0)
        XCTAssertTrue(deviceStatus.isInflating)
        XCTAssertFalse(deviceStatus.isDeflating)
        XCTAssertEqual(deviceStatus.batteryLevel, 85)
        XCTAssertTrue(deviceStatus.isOperating)
        XCTAssertEqual(deviceStatus.operationMode, .inflating)

        // Test pressure difference
        XCTAssertEqual(deviceStatus.pressureDifference, -1.5, accuracy: 0.1)

        // Test formatted strings
        XCTAssertEqual(deviceStatus.formattedCurrentPressure, "30.5 PSI")
        XCTAssertEqual(deviceStatus.formattedTargetPressure, "32.0 PSI")
    }

    func testConnectionStates() {
        // Test all connection states
        let states: [ConnectionState] = [.disconnected, .scanning, .connecting, .connected, .bluetoothDisabled, .connectionError]

        for state in states {
            // Test display text exists
            XCTAssertFalse(state.displayText.isEmpty, "Display text should not be empty for state: \(state)")

            // Test connection properties
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