import XCTest
import SwiftUI
import UIKit
@testable import TirePressureManager

@MainActor
final class SettingsManagerTests: XCTestCase {
    var sut: SettingsManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        sut = SettingsManager()
    }

    override func tearDownWithError() throws {
        sut = nil
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        try super.tearDownWithError()
    }

    func testInitialSettings() {
        XCTAssertEqual(sut.displayMode, .dark)
        XCTAssertEqual(sut.language, .system)
        XCTAssertFalse(sut.simulationMode)
        XCTAssertFalse(sut.debugMode)
        XCTAssertFalse(sut.presetPressures.isEmpty)
        XCTAssertEqual(sut.presetPressures, [8, 10, 12, 16, 20, 30, 38, 40])
        XCTAssertNil(sut.lastConnectedDeviceId)
    }

    func testAddPresetPressure() {
        sut.removePresetPressure(40.0)
        let countAfterRemove = sut.presetPressures.count
        let newPressure = 45.0

        sut.addPresetPressure(newPressure)

        XCTAssertEqual(sut.presetPressures.count, countAfterRemove + 1)
        XCTAssertTrue(sut.presetPressures.contains(newPressure))
        XCTAssertTrue(sut.presetPressures.isSorted())
    }

    func testAddDuplicatePressure() {
        let existingPressure = sut.presetPressures.first ?? 8.0
        let initialCount = sut.presetPressures.count

        sut.addPresetPressure(existingPressure)

        XCTAssertEqual(sut.presetPressures.count, initialCount)
    }

    func testRemovePresetPressure() {
        let pressureToRemove = 38.0
        let initialCount = sut.presetPressures.count

        sut.removePresetPressure(pressureToRemove)

        XCTAssertEqual(sut.presetPressures.count, initialCount - 1)
        XCTAssertFalse(sut.presetPressures.contains(pressureToRemove))
    }

    func testCannotRemoveBelowMinimum() {
        while sut.presetPressures.count > sut.minPressureCount {
            if let pressure = sut.presetPressures.last {
                sut.removePresetPressure(pressure)
            }
        }

        let minimumCount = sut.presetPressures.count
        XCTAssertEqual(minimumCount, sut.minPressureCount)

        if let pressure = sut.presetPressures.first {
            sut.removePresetPressure(pressure)
        }

        XCTAssertEqual(sut.presetPressures.count, minimumCount)
        XCTAssertFalse(sut.canRemovePresetPressure)
    }

    func testDebugModePersistence() {
        XCTAssertFalse(sut.debugMode)

        sut.updateDebugMode(true)
        XCTAssertTrue(sut.debugMode)

        let loaded = UserDefaults.standard.bool(forKey: "debugMode")
        XCTAssertTrue(loaded)
    }

    func testResetToDefaults() {
        sut.displayMode = .light
        sut.language = .hebrew
        sut.updateSimulationMode(true)
        sut.updateDebugMode(true)
        sut.addPresetPressure(50.0)

        sut.resetToDefaults()

        XCTAssertEqual(sut.displayMode, .dark)
        XCTAssertEqual(sut.language, .system)
        XCTAssertFalse(sut.simulationMode)
        XCTAssertFalse(sut.debugMode)
        XCTAssertEqual(sut.presetPressures, [8, 10, 12, 16, 20, 30, 38, 40])
    }

    func testDisplayModeProperties() {
        for mode in DisplayMode.allCases {
            XCTAssertFalse(mode.displayText.isEmpty)
            switch mode {
            case .system:
                XCTAssertNil(mode.colorScheme)
            case .light:
                XCTAssertEqual(mode.colorScheme, .light)
            case .dark:
                XCTAssertEqual(mode.colorScheme, .dark)
            }
        }
    }

    func testAppLanguageProperties() {
        for language in AppLanguage.allCases {
            XCTAssertFalse(language.displayText.isEmpty)
            XCTAssertFalse(language.localeIdentifier.isEmpty)
        }
    }

    func testFirmwareVersionComparison() {
        // Newer build number -> true
        XCTAssertTrue(
            FirmwareUpgradeManager.isBundledVersionNewer(
                bundled: "v1.0.261102_267",
                device: "v1.0.261101_256"
            )
        )
        // Same version -> false
        XCTAssertFalse(
            FirmwareUpgradeManager.isBundledVersionNewer(
                bundled: "v1.0.261102_267",
                device: "v1.0.261102_267"
            )
        )
        // Older bundled build -> false
        XCTAssertFalse(
            FirmwareUpgradeManager.isBundledVersionNewer(
                bundled: "v1.0.261101_250",
                device: "v1.0.261102_267"
            )
        )
        // Legacy version without build number -> true
        XCTAssertTrue(
            FirmwareUpgradeManager.isBundledVersionNewer(
                bundled: "v1.0.261102_267",
                device: "2.00"
            )
        )
    }

    func testSettingsJsonMigrationPreservesValuesAndFixesSchema() throws {
        let defaultSchema: [String: Any] = [
            "DeviceName": "esp32-AirUpDownController",
            "wifissid": "",
            "wifipassword": "",
            "RelayCompressorPin": 16,
            "RelayFreePin": 17,
            "SensorPin": 34,
            "MaxSecForStatus": 10,
            "SensorValueAt0PSI": 410,
            "SensorValueAt50PSI": 3400,
            "AccessCode": "",
            "MessureWait": 1,
            "Precision": 0.5,
            "SimulationMode": false,
            "PressureCalcMethod": 1,
            "MaxPressurePSI": 50,
            "MaxValveOpenSec": 120,
            "SensorFullScalePSI": 50,
            "AccessPointPassword": "12345678"
        ]
        let defaultSchemaData = try JSONSerialization.data(withJSONObject: defaultSchema, options: [])

        // Simulate an older device settings.json with custom user values,
        // missing newer keys (MaxValveOpenSec, SensorFullScalePSI, AccessPointPassword, AccessCode),
        // and having deprecated keys (BTPinCode, BLESecurityEnabled, AutoStart).
        let legacyDeviceJSON: [String: Any] = [
            "DeviceName": "Raptor-Air-MNG",
            "wifissid": "TrailNet",
            "wifipassword": "secretPassword",
            "RelayCompressorPin": 17,
            "RelayFreePin": 16,
            "SensorPin": 32,
            "MaxSecForStatus": 25,
            "SensorValueAt0PSI": 0.321,
            "SensorValueAt50PSI": 3.14,
            "MessureWait": 1.5,
            "Precision": 0.3,
            "SimulationMode": false,
            "PressureCalcMethod": 2,
            "MaxPressurePSI": 60,
            "BTPinCode": "9988",
            "BLESecurityEnabled": true,
            "AutoStart": true
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: legacyDeviceJSON, options: [])

        let result = try FirmwareUpgradeManager.migrateSettingsJSON(
            currentJSONData: legacyData,
            fallbackDeviceSettings: nil,
            defaultSchemaData: defaultSchemaData
        )

        // Deprecated keys removed
        XCTAssertEqual(result.removedKeys, ["AutoStart", "BLESecurityEnabled", "BTPinCode"])
        // Missing keys added with defaults (AccessCode was migrated from BTPinCode so it counts as retained)
        XCTAssertEqual(result.addedKeys, ["AccessPointPassword", "MaxValveOpenSec", "SensorFullScalePSI"])

        let migratedObj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: result.migratedJSONData, options: []) as? [String: Any]
        )

        // Existing user settings preserved
        XCTAssertEqual(migratedObj["DeviceName"] as? String, "Raptor-Air-MNG")
        XCTAssertEqual(migratedObj["wifissid"] as? String, "TrailNet")
        XCTAssertEqual(migratedObj["RelayCompressorPin"] as? Int, 17)
        XCTAssertEqual(migratedObj["SensorPin"] as? Int, 32)
        XCTAssertEqual(migratedObj["PressureCalcMethod"] as? Int, 2)
        // Legacy BTPinCode migrated into AccessCode
        XCTAssertEqual(migratedObj["AccessCode"] as? String, "9988")
        // Added defaults populated
        XCTAssertEqual(migratedObj["MaxValveOpenSec"] as? Int, 120)
        XCTAssertEqual(migratedObj["SensorFullScalePSI"] as? Int, 50)
        XCTAssertEqual(migratedObj["AccessPointPassword"] as? String, "12345678")
        // Deprecated keys absent
        XCTAssertNil(migratedObj["BTPinCode"])
        XCTAssertNil(migratedObj["BLESecurityEnabled"])
        XCTAssertNil(migratedObj["AutoStart"])
    }

    func testBundledFirmwareManifestIsPresent() {
        let manager = FirmwareUpgradeManager.shared
        XCTAssertNotNil(manager.manifest)
        XCTAssertFalse(manager.bundledVersion.isEmpty)
        XCTAssertEqual(manager.manifest?.requiredSettingsKeys.count, 18)
        XCTAssertFalse(manager.manifest?.staticFiles.isEmpty ?? true)
    }

    func testFontSizeScalePersistence() {
        XCTAssertEqual(sut.fontSizeScale, .defaultSize)
        XCTAssertEqual(sut.uiScaleFactor, 1.0)

        sut.updateFontSizeScale(.smaller)
        XCTAssertEqual(sut.fontSizeScale, .smaller)
        XCTAssertEqual(sut.uiScaleFactor, 0.85)

        sut.updateFontSizeScale(.bigger)
        XCTAssertEqual(sut.fontSizeScale, .bigger)
        XCTAssertEqual(sut.uiScaleFactor, 1.15)
    }
}

private extension Array where Element: Comparable {
    func isSorted() -> Bool {
        for i in 1..<count {
            if self[i-1] > self[i] { return false }
        }
        return true
    }
}
