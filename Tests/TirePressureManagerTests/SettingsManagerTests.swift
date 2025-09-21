import XCTest
@testable import TirePressureManager

@MainActor
final class SettingsManagerTests: XCTestCase {
    var sut: SettingsManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Clear UserDefaults for testing
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        sut = SettingsManager()
    }

    override func tearDownWithError() throws {
        sut = nil

        // Clean up UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        try super.tearDownWithError()
    }

    func testInitialSettings() {
        // Given & When - SettingsManager is initialized

        // Then
        XCTAssertEqual(sut.displayMode, .system)
        XCTAssertEqual(sut.language, .system)
        XCTAssertFalse(sut.simulationMode)
        XCTAssertFalse(sut.debugMode)
        XCTAssertFalse(sut.presetPressures.isEmpty)
        XCTAssertNil(sut.lastConnectedDeviceId)
    }

    func testAddPresetPressure() {
        // Given
        let initialCount = sut.presetPressures.count
        let newPressure = 45.0

        // When
        sut.addPresetPressure(newPressure)

        // Then
        XCTAssertEqual(sut.presetPressures.count, initialCount + 1)
        XCTAssertTrue(sut.presetPressures.contains(newPressure))
        XCTAssertTrue(sut.presetPressures.isSorted())
    }

    func testAddInvalidPressure() {
        // Given
        let initialCount = sut.presetPressures.count
        let invalidPressures = [5.0, 85.0, -10.0, 100.0]

        // When & Then
        for pressure in invalidPressures {
            sut.addPresetPressure(pressure)
            XCTAssertEqual(sut.presetPressures.count, initialCount, "Invalid pressure \(pressure) should not be added")
        }
    }

    func testAddDuplicatePressure() {
        // Given
        let existingPressure = sut.presetPressures.first ?? 30.0
        let initialCount = sut.presetPressures.count

        // When
        sut.addPresetPressure(existingPressure)

        // Then
        XCTAssertEqual(sut.presetPressures.count, initialCount, "Duplicate pressure should not be added")
    }

    func testRemovePresetPressure() {
        // Given
        let pressureToRemove = 50.0
        sut.addPresetPressure(pressureToRemove)
        let countWithNewPressure = sut.presetPressures.count

        // When
        sut.removePresetPressure(pressureToRemove)

        // Then
        XCTAssertEqual(sut.presetPressures.count, countWithNewPressure - 1)
        XCTAssertFalse(sut.presetPressures.contains(pressureToRemove))
    }

    func testCannotRemoveBelowMinimum() {
        // Given - Remove pressures until we're at minimum
        while sut.presetPressures.count > 2 {
            if let pressure = sut.presetPressures.last {
                sut.removePresetPressure(pressure)
            }
        }

        let minimumCount = sut.presetPressures.count
        XCTAssertEqual(minimumCount, 2)

        // When - Try to remove another pressure
        if let pressure = sut.presetPressures.first {
            sut.removePresetPressure(pressure)
        }

        // Then - Count should remain the same
        XCTAssertEqual(sut.presetPressures.count, minimumCount)
        XCTAssertFalse(sut.canRemovePresetPressure)
    }

    func testCannotAddAboveMaximum() {
        // Given - Add pressures until we're at maximum
        var pressure = 20.0
        while sut.presetPressures.count < 8 {
            if !sut.presetPressures.contains(pressure) {
                sut.addPresetPressure(pressure)
            }
            pressure += 1.0
        }

        let maximumCount = sut.presetPressures.count
        XCTAssertEqual(maximumCount, 8)

        // When - Try to add another pressure
        sut.addPresetPressure(pressure)

        // Then - Count should remain the same
        XCTAssertEqual(sut.presetPressures.count, maximumCount)
        XCTAssertFalse(sut.canAddPresetPressure)
    }

    func testUpdatePresetPressure() {
        // Given
        let originalPressure = 30.0
        let newPressure = 35.0
        sut.addPresetPressure(originalPressure)

        guard let index = sut.presetPressures.firstIndex(of: originalPressure) else {
            XCTFail("Original pressure not found")
            return
        }

        // When
        sut.updatePresetPressure(at: index, to: newPressure)

        // Then
        XCTAssertTrue(sut.presetPressures.contains(newPressure))
        XCTAssertTrue(sut.presetPressures.isSorted())
    }

    func testResetToDefaults() {
        // Given - Modify settings
        sut.displayMode = .dark
        sut.language = .hebrew
        sut.simulationMode = true
        sut.debugMode = true
        sut.addPresetPressure(50.0)

        // When
        sut.resetToDefaults()

        // Then
        XCTAssertEqual(sut.displayMode, .system)
        XCTAssertEqual(sut.language, .system)
        XCTAssertFalse(sut.simulationMode)
        XCTAssertFalse(sut.debugMode)
        XCTAssertEqual(sut.presetPressures, [30.0, 32.0, 35.0, 40.0])
    }

    func testDisplayModeProperties() {
        let modes: [DisplayMode] = [.system, .light, .dark]

        for mode in modes {
            // Test display text exists
            XCTAssertFalse(mode.displayText.isEmpty, "Display text should not be empty for mode: \(mode)")

            // Test color scheme
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
        let languages: [AppLanguage] = [.system, .english, .hebrew]

        for language in languages {
            // Test display text exists
            XCTAssertFalse(language.displayText.isEmpty, "Display text should not be empty for language: \(language)")

            // Test locale identifier
            XCTAssertFalse(language.localeIdentifier.isEmpty, "Locale identifier should not be empty for language: \(language)")
        }
    }
}

// MARK: - Helper Extensions
private extension Array where Element: Comparable {
    func isSorted() -> Bool {
        for i in 1..<count {
            if self[i-1] > self[i] {
                return false
            }
        }
        return true
    }
}