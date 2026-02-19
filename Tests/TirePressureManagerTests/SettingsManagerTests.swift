import XCTest
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
        let initialCount = sut.presetPressures.count
        let newPressure = 45.0

        sut.addPresetPressure(newPressure)

        XCTAssertEqual(sut.presetPressures.count, initialCount + 1)
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
        let pressureToRemove = 50.0
        sut.addPresetPressure(pressureToRemove)
        let countWithNew = sut.presetPressures.count

        sut.removePresetPressure(pressureToRemove)

        XCTAssertEqual(sut.presetPressures.count, countWithNew - 1)
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
}

private extension Array where Element: Comparable {
    func isSorted() -> Bool {
        for i in 1..<count {
            if self[i-1] > self[i] { return false }
        }
        return true
    }
}
