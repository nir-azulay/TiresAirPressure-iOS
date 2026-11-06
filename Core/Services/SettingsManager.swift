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
    @Published var fontSizeScale: AppFontSize = .defaultSize
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
        static let fontSizeScale = "fontSizeScale"
        static let lastConnectedDeviceId = "lastConnectedDeviceId"
        static let isFirstLaunch = "isFirstLaunch"
    }

    var uiScaleFactor: CGFloat {
        fontSizeScale.scaleFactor
    }

    func updateFontSizeScale(_ size: AppFontSize) {
        fontSizeScale = size
        userDefaults.set(size.rawValue, forKey: Keys.fontSizeScale)
    }

    init() {
        loadSettings()
        setupDefaults()
        LocalizationManager.shared.applyLanguage(language)
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
        fontSizeScale = .defaultSize
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
        var needsRepair = false

        if let modeStr = userDefaults.string(forKey: Keys.displayMode),
           let mode = DisplayMode(rawValue: modeStr) {
            displayMode = mode
        } else {
            displayMode = .dark
            needsRepair = true
        }

        if let langStr = userDefaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: langStr) {
            language = lang
        } else {
            language = .system
            needsRepair = true
        }

        if userDefaults.object(forKey: Keys.minPressureCount) != nil {
            let minVal = userDefaults.integer(forKey: Keys.minPressureCount)
            if minVal >= 1 && minVal <= 8 {
                minPressureCount = minVal
            } else {
                minPressureCount = 1
                needsRepair = true
            }
        } else {
            minPressureCount = 1
            needsRepair = true
        }

        if userDefaults.object(forKey: Keys.maxPressureCount) != nil {
            let maxVal = userDefaults.integer(forKey: Keys.maxPressureCount)
            if maxVal >= minPressureCount && maxVal <= 16 {
                maxPressureCount = maxVal
            } else {
                maxPressureCount = 8
                needsRepair = true
            }
        } else {
            maxPressureCount = 8
            needsRepair = true
        }

        if let data = userDefaults.data(forKey: Keys.presetPressures),
           let pressures = try? JSONDecoder().decode([Double].self, from: data) {
            let valid = Array(Set(pressures.filter { !$0.isNaN && $0 >= 1.0 && $0 <= 80.0 }))
                .sorted()
            if valid.count >= minPressureCount {
                let capped = Array(valid.prefix(maxPressureCount))
                if capped != pressures {
                    needsRepair = true
                }
                presetPressures = capped
            } else {
                presetPressures = [8, 10, 12, 16, 20, 30, 38, 40]
                needsRepair = true
            }
        } else {
            presetPressures = [8, 10, 12, 16, 20, 30, 38, 40]
            needsRepair = true
        }

        if userDefaults.object(forKey: Keys.simulationMode) == nil {
            needsRepair = true
        }
        simulationMode = userDefaults.bool(forKey: Keys.simulationMode)

        if userDefaults.object(forKey: Keys.debugMode) == nil {
            needsRepair = true
        }
        debugMode = userDefaults.bool(forKey: Keys.debugMode)
        print("[SettingsManager] Loaded debugMode: \(debugMode)")

        if let sizeStr = userDefaults.string(forKey: Keys.fontSizeScale),
           let size = AppFontSize(rawValue: sizeStr) {
            fontSizeScale = size
        } else {
            fontSizeScale = .defaultSize
            needsRepair = true
        }

        lastConnectedDeviceId = userDefaults.string(forKey: Keys.lastConnectedDeviceId)

        // Ensure saved devices list is also validated/migrated at startup
        _ = SavedDevice.load()

        if needsRepair {
            print("[SettingsManager] Auto-fixing app configuration in UserDefaults")
            saveAllSettings()
        }
    }

    private func saveAllSettings() {
        userDefaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        userDefaults.set(language.rawValue, forKey: Keys.language)
        LocalizationManager.shared.applyLanguage(language)
        userDefaults.set(simulationMode, forKey: Keys.simulationMode)
        userDefaults.set(debugMode, forKey: Keys.debugMode)
        userDefaults.set(minPressureCount, forKey: Keys.minPressureCount)
        userDefaults.set(maxPressureCount, forKey: Keys.maxPressureCount)
        userDefaults.set(fontSizeScale.rawValue, forKey: Keys.fontSizeScale)
        userDefaults.set(lastConnectedDeviceId, forKey: Keys.lastConnectedDeviceId)
        savePresetPressures()
    }

    private func savePresetPressures() {
        if let data = try? JSONEncoder().encode(presetPressures) {
            userDefaults.set(data, forKey: Keys.presetPressures)
        }
    }
}

// MARK: - App Font Size
enum AppFontSize: String, CaseIterable {
    case smallest = "smallest"
    case smaller = "smaller"
    case defaultSize = "default"
    case bigger = "bigger"
    case biggest = "biggest"

    var displayText: String {
        switch self {
        case .smallest: return L("font_size_smallest", comment: "Smallest")
        case .smaller: return L("font_size_smaller", comment: "Smaller")
        case .defaultSize: return L("font_size_default", comment: "Default")
        case .bigger: return L("font_size_bigger", comment: "Bigger")
        case .biggest: return L("font_size_biggest", comment: "Biggest")
        }
    }

    var scaleFactor: CGFloat {
        switch self {
        case .smallest: return 0.72
        case .smaller: return 0.85
        case .defaultSize: return 1.00
        case .bigger: return 1.15
        case .biggest: return 1.30
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
        case .system: return L("system_default", comment: "System Default")
        case .light: return L("light_mode", comment: "Light Mode")
        case .dark: return L("dark_mode", comment: "Dark Mode")
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
        case .system: return LocalizationManager.shared.localizedString("system_default")
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

    var languageCode: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .hebrew: return "he"
        }
    }
}

// MARK: - Localization Manager
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var bundle: Bundle = .main
    @Published var refreshId: UUID = UUID()

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "language"),
           let lang = AppLanguage(rawValue: saved) {
            applyLanguage(lang)
        }
    }

    func applyLanguage(_ language: AppLanguage) {
        guard let code = language.languageCode else {
            bundle = .main
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            refreshId = UUID()
            return
        }

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }

        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        refreshId = UUID()
    }

    func localizedString(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
