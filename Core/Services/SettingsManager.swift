import Foundation
import SwiftUI

/// Manages app settings and preferences
@MainActor
class SettingsManager: ObservableObject {
    // MARK: - Published Properties
    @Published var displayMode: DisplayMode = .system
    @Published var language: AppLanguage = .system
    @Published var presetPressures: [Double] = [30.0, 32.0, 35.0, 40.0]
    @Published var simulationMode: Bool = false
    @Published var debugMode: Bool = false
    @Published var lastConnectedDeviceId: String?

    // MARK: - Constants
    private let userDefaults = UserDefaults.standard
    private let maxPresetPressures = 8
    private let minPresetPressures = 2

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let displayMode = "displayMode"
        static let language = "language"
        static let presetPressures = "presetPressures"
        static let simulationMode = "simulationMode"
        static let debugMode = "debugMode"
        static let lastConnectedDeviceId = "lastConnectedDeviceId"
        static let isFirstLaunch = "isFirstLaunch"
    }

    // MARK: - Initialization
    init() {
        loadSettings()
        setupDefaults()
    }

    // MARK: - Public Methods

    func addPresetPressure(_ pressure: Double) {
        guard presetPressures.count < maxPresetPressures,
              !presetPressures.contains(pressure),
              pressure >= 10.0 && pressure <= 80.0 else {
            return
        }

        presetPressures.append(pressure)
        presetPressures.sort()
        savePresetPressures()
    }

    func removePresetPressure(_ pressure: Double) {
        guard presetPressures.count > minPresetPressures else {
            return
        }

        presetPressures.removeAll { $0 == pressure }
        savePresetPressures()
    }

    func updatePresetPressure(at index: Int, to newPressure: Double) {
        guard index >= 0 && index < presetPressures.count,
              newPressure >= 10.0 && newPressure <= 80.0,
              !presetPressures.contains(newPressure) else {
            return
        }

        presetPressures[index] = newPressure
        presetPressures.sort()
        savePresetPressures()
    }

    func resetToDefaults() {
        displayMode = .system
        language = .system
        presetPressures = [30.0, 32.0, 35.0, 40.0]
        simulationMode = false
        debugMode = false
        saveAllSettings()
    }

    var isFirstLaunch: Bool {
        get { !userDefaults.bool(forKey: Keys.isFirstLaunch) }
        set { userDefaults.set(!newValue, forKey: Keys.isFirstLaunch) }
    }

    var canAddPresetPressure: Bool {
        return presetPressures.count < maxPresetPressures
    }

    var canRemovePresetPressure: Bool {
        return presetPressures.count > minPresetPressures
    }

    // MARK: - Private Methods

    private func setupDefaults() {
        if isFirstLaunch {
            saveAllSettings()
            isFirstLaunch = false
        }
    }

    private func loadSettings() {
        // Display mode
        if let displayModeString = userDefaults.string(forKey: Keys.displayMode),
           let mode = DisplayMode(rawValue: displayModeString) {
            displayMode = mode
        }

        // Language
        if let languageString = userDefaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: languageString) {
            language = lang
        }

        // Preset pressures
        if let pressuresData = userDefaults.data(forKey: Keys.presetPressures),
           let pressures = try? JSONDecoder().decode([Double].self, from: pressuresData) {
            presetPressures = pressures.sorted()
        }

        // Boolean settings
        simulationMode = userDefaults.bool(forKey: Keys.simulationMode)
        debugMode = userDefaults.bool(forKey: Keys.debugMode)

        // Last connected device
        lastConnectedDeviceId = userDefaults.string(forKey: Keys.lastConnectedDeviceId)
    }

    private func saveAllSettings() {
        userDefaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        userDefaults.set(language.rawValue, forKey: Keys.language)
        userDefaults.set(simulationMode, forKey: Keys.simulationMode)
        userDefaults.set(debugMode, forKey: Keys.debugMode)
        userDefaults.set(lastConnectedDeviceId, forKey: Keys.lastConnectedDeviceId)
        savePresetPressures()
    }

    private func savePresetPressures() {
        if let data = try? JSONEncoder().encode(presetPressures) {
            userDefaults.set(data, forKey: Keys.presetPressures)
        }
    }
}

// MARK: - Display Mode
enum DisplayMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayText: String {
        switch self {
        case .system:
            return NSLocalizedString("system_default", comment: "System Default")
        case .light:
            return NSLocalizedString("light_mode", comment: "Light Mode")
        case .dark:
            return NSLocalizedString("dark_mode", comment: "Dark Mode")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// MARK: - App Language
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case hebrew = "he"

    var displayText: String {
        switch self {
        case .system:
            return NSLocalizedString("system_default", comment: "System Default")
        case .english:
            return "English"
        case .hebrew:
            return "עברית"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.current.identifier
        case .english:
            return "en"
        case .hebrew:
            return "he"
        }
    }
}