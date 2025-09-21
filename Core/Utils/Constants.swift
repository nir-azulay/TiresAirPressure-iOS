import Foundation

/// App-wide constants
struct AppConstants {

    // MARK: - App Information
    static let appName = "Tire Pressure Manager"
    static let developerName = "Nir Azulay"
    static let developerEmail = "nir.azulay@gmail.com"
    static let supportURL = "https://support.example.com"
    static let privacyPolicyURL = "https://privacy.example.com"

    // MARK: - Pressure Constants
    struct Pressure {
        static let minValue: Double = 10.0
        static let maxValue: Double = 80.0
        static let defaultTarget: Double = 32.0
        static let precisionStep: Double = 0.5
        static let toleranceLevel: Double = 1.0

        /// Common tire pressure values
        static let commonValues: [Double] = [28.0, 30.0, 32.0, 35.0, 40.0, 45.0]

        /// Default preset pressures
        static let defaultPresets: [Double] = [30.0, 32.0, 35.0, 40.0]
    }

    // MARK: - UI Constants
    struct UI {
        static let animationDuration: Double = 0.3
        static let cardCornerRadius: CGFloat = 12.0
        static let buttonHeight: CGFloat = 44.0
        static let defaultPadding: CGFloat = 16.0
        static let smallPadding: CGFloat = 8.0
        static let largePadding: CGFloat = 24.0
    }

    // MARK: - Connection Constants
    struct Connection {
        static let scanTimeout: TimeInterval = 30.0
        static let connectionTimeout: TimeInterval = 10.0
        static let reconnectDelay: TimeInterval = 2.0
        static let statusUpdateInterval: TimeInterval = 1.0
        static let maxReconnectAttempts = 3
    }

    // MARK: - Settings Constants
    struct Settings {
        static let minPresetPressures = 2
        static let maxPresetPressures = 8
        static let defaultDisplayMode = "system"
        static let defaultLanguage = "system"
    }

    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let displayMode = "displayMode"
        static let language = "language"
        static let presetPressures = "presetPressures"
        static let simulationMode = "simulationMode"
        static let debugMode = "debugMode"
        static let lastConnectedDeviceId = "lastConnectedDeviceId"
        static let isFirstLaunch = "isFirstLaunch"
        static let autoReconnect = "autoReconnect"
        static let notificationsEnabled = "notificationsEnabled"
    }

    // MARK: - Notification Constants
    struct Notifications {
        static let pressureReachedTitle = "Target Pressure Reached"
        static let pressureReachedBody = "Your tire has reached the target pressure."
        static let connectionLostTitle = "Device Disconnected"
        static let connectionLostBody = "Connection to tire pressure device was lost."
        static let lowBatteryTitle = "Low Battery Warning"
        static let lowBatteryBody = "Device battery is running low."

        static let categoryId = "TirePressureManager"
        static let soundName = "pressure_alert.wav"
    }

    // MARK: - Error Messages
    struct ErrorMessages {
        static let bluetoothDisabled = "Bluetooth is disabled. Please enable Bluetooth in Settings."
        static let locationPermissionDenied = "Location permission is required for device scanning."
        static let deviceNotFound = "Could not find the tire pressure device."
        static let connectionFailed = "Failed to connect to the device. Please try again."
        static let operationFailed = "Operation failed. Please check your device connection."
        static let invalidPressureValue = "Please enter a valid pressure value between 10-80 PSI."
        static let settingsSaveFailed = "Failed to save settings. Please try again."
        static let unknownError = "An unknown error occurred. Please restart the app."
    }

    // MARK: - URLs and Links
    struct URLs {
        static let appStore = "https://apps.apple.com/app/id123456789"
        static let support = "mailto:support@example.com"
        static let website = "https://tirepressuremanager.com"
        static let userGuide = "https://tirepressuremanager.com/guide"
        static let troubleshooting = "https://tirepressuremanager.com/troubleshooting"
    }

    // MARK: - File Names
    struct FileNames {
        static let settingsFile = "AppSettings.plist"
        static let deviceProfilesFile = "DeviceProfiles.json"
        static let logFile = "app.log"
        static let crashReportFile = "crash_report.txt"
    }

    // MARK: - Animation Constants
    struct Animations {
        static let springDamping: CGFloat = 0.8
        static let springResponse: CGFloat = 0.4
        static let fadeInDuration: Double = 0.3
        static let slideInDuration: Double = 0.5
        static let pulseScale: CGFloat = 1.05
        static let rotationAngle: Double = 360.0
    }

    // MARK: - CarPlay Constants
    struct CarPlay {
        static let maxListItems = 12
        static let maxActionButtons = 4
        static let templateTitle = "Tire Pressure"
        static let informationTitle = "Tire Air Pressure Management"
        static let quickPressureValues: [Double] = [28.0, 30.0, 32.0, 35.0, 40.0]
    }

    // MARK: - Accessibility
    struct Accessibility {
        static let pressureGaugeLabel = "Pressure gauge showing current tire pressure"
        static let connectionStatusLabel = "Device connection status"
        static let inflationButtonLabel = "Start inflation to increase tire pressure"
        static let deflationButtonLabel = "Start deflation to decrease tire pressure"
        static let targetPressureLabel = "Target pressure setting"
        static let presetPressureLabel = "Preset pressure button"
    }

    // MARK: - Localization
    struct Localization {
        static let supportedLanguages = ["en", "he"]
        static let defaultLanguage = "en"
        static let rtlLanguages = ["he", "ar"]
    }

    // MARK: - Device Capabilities
    struct DeviceCapabilities {
        static let requiredBluetoothVersion = "4.0"
        static let minimumIOSVersion = "15.0"
        static let supportedDeviceFamilies = ["iPhone", "iPad"]
        static let requiresBLESupport = true
        static let supportsCarPlay = true
        static let supportsBackground = true
    }

    // MARK: - Performance
    struct Performance {
        static let maxConcurrentConnections = 1
        static let dataProcessingQueueQoS = DispatchQoS.userInitiated
        static let backgroundTaskExpiration: TimeInterval = 30.0
        static let memoryWarningThreshold = 50 // MB
    }

    // MARK: - Validation
    struct Validation {
        static let deviceNameMaxLength = 32
        static let deviceNameMinLength = 1
        static let passwordMaxLength = 64
        static let passwordMinLength = 8
        static let ssidMaxLength = 32
        static let pinCodeLength = 6
    }

    // MARK: - Debug
    struct Debug {
        static let enableLogging = true
        static let logLevel = "info" // debug, info, warning, error
        static let maxLogFileSize = 10 * 1024 * 1024 // 10MB
        static let logRetentionDays = 7
        static let enableCrashReporting = true
        static let enablePerformanceMonitoring = true
    }
}

// MARK: - Computed Properties
extension AppConstants {

    /// Current app version string
    static var currentVersion: String {
        return Bundle.main.appVersion
    }

    /// Current build number
    static var currentBuild: String {
        return Bundle.main.buildNumber
    }

    /// Full version info
    static var fullVersionInfo: String {
        return "Version \(currentVersion) (\(currentBuild))"
    }

    /// Is this a debug build?
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Is this running on simulator?
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Current device type
    static var deviceType: String {
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    /// Support email subject
    static var supportEmailSubject: String {
        return "Support Request - \(appName) \(currentVersion)"
    }

    /// App Store review URL
    static var appStoreReviewURL: String {
        return "\(URLs.appStore)?action=write-review"
    }
}