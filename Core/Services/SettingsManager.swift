import Foundation
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    @Published var displayMode: DisplayMode = .dark
    @Published var language: AppLanguage = .system
    @Published var presetPressures: [Double] = [8, 10, 12, 16, 20, 30, 38, 40]
    @Published var simulationMode: Bool = false
    @Published var debugMode: Bool = false
    @Published var minPressureCount: Int = 1
    @Published var maxPressureCount: Int = 8
    @Published var lastConnectedDeviceId: String?

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let displayMode = "displayMode"
        static let language = "language"
        static let presetPressures = "presetPressures"
        static let simulationMode = "simulationMode"
        static let debugMode = "debugMode"
        static let minPressureCount = "minPressureCount"
        static let maxPressureCount = "maxPressureCount"
        static let lastConnectedDeviceId = "lastConnectedDeviceId"
        static let isFirstLaunch = "isFirstLaunch"
    }

    init() {
        loadSettings()
        setupDefaults()
    }

    // MARK: - Preset Pressures

    func addPresetPressure(_ pressure: Double) {
        guard presetPressures.count < maxPressureCount,
              !presetPressures.contains(pressure),
              pressure >= 1.0 && pressure <= 80.0 else { return }

        presetPressures.append(pressure)
        presetPressures.sort()
        savePresetPressures()
    }

    func removePresetPressure(_ pressure: Double) {
        guard presetPressures.count > minPressureCount else { return }
        presetPressures.removeAll { $0 == pressure }
        savePresetPressures()
    }

    func updatePresetPressure(at index: Int, to newPressure: Double) {
        guard index >= 0 && index < presetPressures.count,
              newPressure >= 1.0 && newPressure <= 80.0,
              !presetPressures.contains(newPressure) else { return }

        presetPressures[index] = newPressure
        presetPressures.sort()
        savePresetPressures()
    }

    var canAddPresetPressure: Bool {
        presetPressures.count < maxPressureCount
    }

    var canRemovePresetPressure: Bool {
        presetPressures.count > minPressureCount
    }

    // MARK: - Debug Mode

    func updateDebugMode(_ enabled: Bool) {
        debugMode = enabled
        userDefaults.set(enabled, forKey: Keys.debugMode)
        print("[SettingsManager] Debug mode updated: \(enabled)")
    }

    func updateSimulationMode(_ enabled: Bool) {
        simulationMode = enabled
        userDefaults.set(enabled, forKey: Keys.simulationMode)
    }

    // MARK: - Reset

    func resetToDefaults() {
        displayMode = .dark
        language = .system
        presetPressures = [8, 10, 12, 16, 20, 30, 38, 40]
        simulationMode = false
        debugMode = false
        minPressureCount = 1
        maxPressureCount = 8
        saveAllSettings()
    }

    var isFirstLaunch: Bool {
        get { !userDefaults.bool(forKey: Keys.isFirstLaunch) }
        set { userDefaults.set(!newValue, forKey: Keys.isFirstLaunch) }
    }

    func saveSettings() {
        saveAllSettings()
    }

    // MARK: - Private

    private func setupDefaults() {
        if isFirstLaunch {
            saveAllSettings()
            isFirstLaunch = false
        }
    }

    private func loadSettings() {
        if let modeStr = userDefaults.string(forKey: Keys.displayMode),
           let mode = DisplayMode(rawValue: modeStr) {
            displayMode = mode
        }

        if let langStr = userDefaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: langStr) {
            language = lang
        }

        if let data = userDefaults.data(forKey: Keys.presetPressures),
           let pressures = try? JSONDecoder().decode([Double].self, from: data) {
            presetPressures = pressures.sorted()
        }

        simulationMode = userDefaults.bool(forKey: Keys.simulationMode)
        debugMode = userDefaults.bool(forKey: Keys.debugMode)
        print("[SettingsManager] Loaded debugMode: \(debugMode)")

        if userDefaults.object(forKey: Keys.minPressureCount) != nil {
            minPressureCount = userDefaults.integer(forKey: Keys.minPressureCount)
        }
        if userDefaults.object(forKey: Keys.maxPressureCount) != nil {
            maxPressureCount = userDefaults.integer(forKey: Keys.maxPressureCount)
        }

        lastConnectedDeviceId = userDefaults.string(forKey: Keys.lastConnectedDeviceId)
    }

    private func saveAllSettings() {
        userDefaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        userDefaults.set(language.rawValue, forKey: Keys.language)
        userDefaults.set(simulationMode, forKey: Keys.simulationMode)
        userDefaults.set(debugMode, forKey: Keys.debugMode)
        userDefaults.set(minPressureCount, forKey: Keys.minPressureCount)
        userDefaults.set(maxPressureCount, forKey: Keys.maxPressureCount)
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
        case .system: return NSLocalizedString("system_default", comment: "System Default")
        case .light: return NSLocalizedString("light_mode", comment: "Light Mode")
        case .dark: return NSLocalizedString("dark_mode", comment: "Dark Mode")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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
        case .system: return NSLocalizedString("system_default", comment: "System Default")
        case .english: return "English"
        case .hebrew: return "עברית"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system: return Locale.current.identifier
        case .english: return "en"
        case .hebrew: return "he"
        }
    }
}
