import Foundation
import Combine
import UIKit
import Darwin

// MARK: - Models

struct BundledStaticFile: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let size: Int
    let sha256: String
}

struct FirmwareManifest: Codable, Equatable {
    let version: String
    let versionFull: String
    let buildNumber: Int
    let firmwareFile: String
    let firmwareSize: Int
    let firmwareSha256: String
    let defaultSettingsFile: String
    let requiredSettingsKeys: [String]
    let deprecatedSettingsKeys: [String]?
    let staticFiles: [BundledStaticFile]
}

struct SettingsMigrationResult: Equatable {
    let migratedJSONData: Data
    let retainedKeys: [String]
    let addedKeys: [String]
    let removedKeys: [String]

    var hasChanges: Bool {
        !addedKeys.isEmpty || !removedKeys.isEmpty
    }
}

enum UpgradeOperationMode: String, CaseIterable, Identifiable {
    case fullUpgrade
    case firmwareOnly
    case spiffsOnly
    case settingsJsonOnly

    var id: String { rawValue }
}

enum UpgradeState: Equatable {
    case idle
    case connectingWiFi(ssid: String)
    case migratingSettings
    case uploadingStaticFiles(current: Int, total: Int, fileName: String)
    case uploadingFirmware(progress: Double)
    case rebootingDevice
    case completed(summary: String)
    case failed(error: String)

    var isBusy: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}

enum FirmwareUpgradeError: LocalizedError {
    case packageNotFound
    case firmwareBinaryNotFound
    case defaultSettingsNotFound
    case deviceUnreachable(ssid: String, ip: String)
    case uploadFailed(file: String, statusCode: Int)
    case invalidSettingsJSON

    var errorDescription: String? {
        switch self {
        case .packageNotFound:
            return L("upgrade_error_package_missing", comment: "Bundled firmware package not found in app.")
        case .firmwareBinaryNotFound:
            return L("upgrade_error_firmware_missing", comment: "Bundled firmware.bin file is missing.")
        case .defaultSettingsNotFound:
            return L("upgrade_error_settings_schema_missing", comment: "Bundled default_settings.json schema is missing.")
        case .deviceUnreachable(let ssid, let ip):
            return String(format: L("upgrade_error_unreachable_format", comment: ""), ssid, ip)
        case .uploadFailed(let file, let statusCode):
            return String(format: L("upgrade_error_upload_failed_format", comment: ""), file, statusCode)
        case .invalidSettingsJSON:
            return L("upgrade_error_invalid_json", comment: "Failed to serialize migrated settings.json.")
        }
    }
}

struct WiFiConnectionPromptInfo: Identifiable, Equatable {
    let id = UUID()
    let ssid: String
    let password: String
    let expectedIP: String
}

// MARK: - FirmwareUpgradeManager

@MainActor
final class FirmwareUpgradeManager: NSObject, ObservableObject {
    static let shared = FirmwareUpgradeManager()

    @Published private(set) var manifest: FirmwareManifest?
    @Published private(set) var deviceVersion: String = ""
    @Published private(set) var isUpdateAvailable: Bool = false
    @Published var updateSuggestionDismissed: Bool = false
    @Published var showUpgradeSheet: Bool = false

    @Published private(set) var upgradeState: UpgradeState = .idle
    @Published private(set) var overallProgress: Double = 0.0
    @Published private(set) var stepLogs: [String] = []
    @Published private(set) var lastMigrationResult: SettingsMigrationResult?
    @Published private(set) var reachableHost: String?
    @Published var customHostIP: String = ""
    @Published var wifiPromptInfo: WiFiConnectionPromptInfo?
    @Published var wifiConnectedAlertHost: String?

    private var cancellables = Set<AnyCancellable>()
    private var dismissedForDeviceVersion: String?
    private var cachedDeviceSettings: DeviceSettings?
    private var savedPeripheralIdentifier: UUID?

    override init() {
        super.init()
        loadBundledManifest()
        observeBLEDevice()
    }

    var bundledVersion: String {
        manifest?.version ?? ""
    }

    var shouldSuggestUpdate: Bool {
        isUpdateAvailable && !updateSuggestionDismissed
    }

    func dismissUpdateSuggestion() {
        updateSuggestionDismissed = true
        dismissedForDeviceVersion = deviceVersion
    }

    func resetState() {
        if !upgradeState.isBusy {
            upgradeState = .idle
            overallProgress = 0.0
        }
    }

    // MARK: - Bundle Loading

    func loadBundledManifest() {
        guard let url = resourceURL(path: "manifest.json") else {
            print("[FirmwareUpgradeManager] manifest.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(FirmwareManifest.self, from: data)
            self.manifest = decoded
            evaluateUpdateAvailability()
        } catch {
            print("[FirmwareUpgradeManager] Failed to decode manifest.json: \(error)")
        }
    }

    private func resourceURL(path: String) -> URL? {
        let nsPath = path as NSString
        let name = nsPath.deletingPathExtension
        let ext = nsPath.pathExtension
        let subdir = nsPath.deletingLastPathComponent

        let folderSubdir = subdir.isEmpty ? "FirmwarePackage" : "FirmwarePackage/\(subdir)"
        let cleanName = (name as NSString).lastPathComponent

        if let url = Bundle.main.url(forResource: cleanName, withExtension: ext.isEmpty ? nil : ext, subdirectory: folderSubdir) {
            return url
        }
        if !subdir.isEmpty,
           let url = Bundle.main.url(forResource: cleanName, withExtension: ext.isEmpty ? nil : ext, subdirectory: subdir) {
            return url
        }
        return Bundle.main.url(forResource: cleanName, withExtension: ext.isEmpty ? nil : ext)
    }

    // MARK: - Version Observation & Comparison

    private func observeBLEDevice() {
        BLEManager.shared.$deviceSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                if let settings = settings {
                    self.cachedDeviceSettings = settings
                }
                if let periphId = BLEManager.shared.connectedPeripheral?.identifier {
                    self.savedPeripheralIdentifier = periphId
                }
                let newVer = settings?.softwareVersion.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !newVer.isEmpty {
                    self.deviceVersion = newVer
                }
                if let ip = settings?.ipAddress, !ip.isEmpty, self.customHostIP.isEmpty {
                    self.customHostIP = ip
                }
                if !newVer.isEmpty && newVer != self.dismissedForDeviceVersion {
                    self.updateSuggestionDismissed = false
                }
                self.evaluateUpdateAvailability()
            }
            .store(in: &cancellables)

        BLEManager.shared.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                if state == .disconnected && !self.upgradeState.isBusy {
                    self.deviceVersion = ""
                    self.isUpdateAvailable = false
                    self.reachableHost = nil
                }
            }
            .store(in: &cancellables)
    }

    private func evaluateUpdateAvailability() {
        guard let bundled = manifest?.version, !bundled.isEmpty, !deviceVersion.isEmpty else {
            isUpdateAvailable = false
            return
        }
        isUpdateAvailable = Self.isBundledVersionNewer(bundled: bundled, device: deviceVersion)
    }

    /// Compares controller firmware version strings (e.g. `v1.0.261105_268` vs `v1.0.261102_266` or legacy `2.00`).
    nonisolated static func isBundledVersionNewer(bundled: String, device: String) -> Bool {
        let cleanBundled = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevice = device.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanBundled.isEmpty, !cleanDevice.isEmpty else { return false }
        if cleanBundled == cleanDevice { return false }

        let bundledInfo = parseVersionComponents(cleanBundled)
        let deviceInfo = parseVersionComponents(cleanDevice)

        if let bBuild = bundledInfo.buildNumber, let dBuild = deviceInfo.buildNumber {
            if bBuild != dBuild {
                return bBuild > dBuild
            }
        }

        if bundledInfo.buildNumber != nil && deviceInfo.buildNumber == nil {
            return true
        }

        let maxCount = max(bundledInfo.numericParts.count, deviceInfo.numericParts.count)
        for i in 0..<maxCount {
            let bVal = i < bundledInfo.numericParts.count ? bundledInfo.numericParts[i] : 0
            let dVal = i < deviceInfo.numericParts.count ? deviceInfo.numericParts[i] : 0
            if bVal != dVal {
                return bVal > dVal
            }
        }

        return false
    }

    nonisolated private static func parseVersionComponents(_ version: String) -> (numericParts: [Int], buildNumber: Int?) {
        var working = version
        while working.lowercased().hasPrefix("v") {
            working.removeFirst()
        }
        if let dashRange = working.range(of: " - ") {
            working = String(working[..<dashRange.lowerBound])
        }

        let underscoreParts = working.split(separator: "_", maxSplits: 1).map(String.init)
        let buildNumber: Int? = underscoreParts.count > 1 ? Int(underscoreParts[1]) : nil

        let dotParts = underscoreParts[0]
            .split(separator: ".")
            .compactMap { Int($0) }

        return (dotParts, buildNumber)
    }

    // MARK: - settings.json Non-Destructive Schema Migration

    nonisolated static func migrateSettingsJSON(
        currentJSONData: Data?,
        fallbackDeviceSettings: DeviceSettings?,
        defaultSchemaData: Data,
        overrideSimulationMode: Bool? = nil
    ) throws -> SettingsMigrationResult {
        guard let defaultObj = try JSONSerialization.jsonObject(with: defaultSchemaData, options: []) as? [String: Any] else {
            throw FirmwareUpgradeError.invalidSettingsJSON
        }

        var currentObj: [String: Any] = [:]
        if let data = currentJSONData,
           let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            currentObj = parsed
        } else if let s = fallbackDeviceSettings {
            currentObj = dictionaryFromDeviceSettings(s)
        }

        if let overrideSim = overrideSimulationMode {
            currentObj["SimulationMode"] = overrideSim
        }

        var merged: [String: Any] = [:]
        var retainedKeys: [String] = []
        var addedKeys: [String] = []
        var removedKeys: [String] = []

        let hasAccessCodeKey = currentObj["AccessCode"] != nil && !(currentObj["AccessCode"] is NSNull)
        if !hasAccessCodeKey,
           let legacyPin = currentObj["BTPinCode"] as? String,
           !legacyPin.isEmpty {
            let securityEnabled: Bool = {
                if let b = currentObj["BLESecurityEnabled"] as? Bool { return b }
                if let n = currentObj["BLESecurityEnabled"] as? Int { return n != 0 }
                if let s = currentObj["BLESecurityEnabled"] as? String {
                    return s.lowercased() == "true" || s == "1"
                }
                return false
            }()
            if securityEnabled {
                currentObj["AccessCode"] = legacyPin
            }
        }

        for key in currentObj.keys.sorted() {
            if defaultObj[key] == nil {
                removedKeys.append(key)
            }
        }

        for key in defaultObj.keys.sorted() {
            guard let defaultValue = defaultObj[key] else { continue }
            if let existingValue = currentObj[key], !(existingValue is NSNull) {
                merged[key] = coerceValue(existingValue, matchingDefault: defaultValue)
                retainedKeys.append(key)
            } else {
                merged[key] = defaultValue
                addedKeys.append(key)
            }
        }

        let migratedData = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
        return SettingsMigrationResult(
            migratedJSONData: migratedData,
            retainedKeys: retainedKeys,
            addedKeys: addedKeys,
            removedKeys: removedKeys
        )
    }

    nonisolated private static func coerceValue(_ existing: Any, matchingDefault defaultValue: Any) -> Any {
        let isDefaultBoolean: Bool = {
            guard let num = defaultValue as? NSNumber else { return defaultValue is Bool }
            return CFGetTypeID(num) == CFBooleanGetTypeID()
        }()

        if isDefaultBoolean {
            if let num = existing as? NSNumber, CFGetTypeID(num) == CFBooleanGetTypeID() {
                return num.boolValue
            }
            if let b = existing as? Bool { return b }
            if let n = existing as? NSNumber { return n.boolValue }
            if let s = existing as? String { return s.lowercased() == "true" || s == "1" }
        }
        if defaultValue is String {
            if let s = existing as? String { return s }
            if let n = existing as? NSNumber { return n.stringValue }
        }
        if defaultValue is NSNumber {
            if let n = existing as? NSNumber { return n }
            if let s = existing as? String, let d = Double(s) { return d }
        }
        return existing
    }

    nonisolated private static func dictionaryFromDeviceSettings(_ s: DeviceSettings) -> [String: Any] {
        return [
            "DeviceName": s.deviceName,
            "wifissid": s.wifiSsid,
            "wifipassword": s.wifiPassword,
            "RelayCompressorPin": s.relayCompressorPin,
            "RelayFreePin": s.relayFreePin,
            "SensorPin": s.sensorPin,
            "MaxSecForStatus": s.maxSecForStatus,
            "SensorValueAt0PSI": s.sensorValueAt0PSI,
            "SensorValueAt50PSI": s.sensorValueAt50PSI,
            "AccessCode": s.accessCode,
            "MessureWait": s.measureWait,
            "Precision": s.precision,
            "SimulationMode": s.simulationMode,
            "PressureCalcMethod": s.pressureCalcMethod,
            "MaxPressurePSI": s.maxPressurePSI,
            "MaxValveOpenSec": s.maxValveOpenSec,
            "SensorFullScalePSI": s.sensorFullScalePSI,
            "AccessPointPassword": s.accessPointPassword
        ]
    }

    // MARK: - Wi-Fi Reachability & Connection

    func checkReachability() async -> String? {
        let settings = BLEManager.shared.deviceSettings ?? cachedDeviceSettings
        let host = await resolveReachableHost(deviceSettings: settings)
        self.reachableHost = host
        if let host = host {
            self.customHostIP = host
        }
        return host
    }

    /// Called by the Wi-Fi button in `FirmwareUpgradeView`.
    func connectWiFiFromButton() async {
        guard !upgradeState.isBusy else { return }
        let settings = BLEManager.shared.deviceSettings ?? cachedDeviceSettings

        if let host = await resolveReachableHost(deviceSettings: settings) {
            self.reachableHost = host
            self.customHostIP = host
            self.upgradeState = .idle
            appendLog(String(format: L("upgrade_log_connected_ip_format", comment: ""), host))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.wifiConnectedAlertHost = host
            return
        }

        let target = preferredWiFiTargets().first ?? (ssid: "esp32-AirUpDownController", password: "12345678")
        if !target.password.isEmpty {
            UIPasteboard.general.string = target.password
        }
        let expectedIP = (settings?.ipAddress.isEmpty == false) ? settings!.ipAddress : "192.168.4.1"
        self.reachableHost = nil
        self.wifiPromptInfo = WiFiConnectionPromptInfo(
            ssid: target.ssid,
            password: target.password,
            expectedIP: expectedIP
        )
    }

    private func candidateHosts(for settings: DeviceSettings?) -> [String] {
        var hosts: [String] = []
        let trimmedCustom = customHostIP
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "/", with: "")
        if !trimmedCustom.isEmpty {
            hosts.append(trimmedCustom)
        }
        if let bleIP = settings?.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
           !bleIP.isEmpty,
           !hosts.contains(bleIP) {
            hosts.append(bleIP)
        }
        if !hosts.contains("192.168.4.1") {
            hosts.append("192.168.4.1")
        }
        return hosts
    }

    private func resolveReachableHost(deviceSettings: DeviceSettings?) async -> String? {
        for host in candidateHosts(for: deviceSettings) {
            if let ver = await probeSettingsValues(host: host) {
                if !ver.isEmpty {
                    self.deviceVersion = ver
                    self.updateBLEManagerVersion(ver)
                    self.evaluateUpdateAvailability()
                }
                return host
            }
            if let resp = try? await DirectWiFiHTTPClient.sendGET(host: host, path: "/settings.json", timeoutSec: 2.0),
               (200...299).contains(resp.statusCode) {
                return host
            }
        }
        return nil
    }

    private func probeSettingsValues(host: String) async -> String? {
        guard let resp = try? await DirectWiFiHTTPClient.sendGET(host: host, path: "/settingsValues", timeoutSec: 2.5),
              (200...299).contains(resp.statusCode),
              let text = String(data: resp.body, encoding: .utf8) else {
            return nil
        }
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ";", omittingEmptySubsequences: false)
            .map(String.init)
        if parts.count > 6 {
            let simFlag = parts[6].trimmingCharacters(in: .whitespacesAndNewlines)
            let isSim = (simFlag == "1" || simFlag.lowercased() == "true")
            if cachedDeviceSettings == nil {
                var s = DeviceSettings()
                s.deviceName = parts[0]
                s.simulationMode = isSim
                cachedDeviceSettings = s
            } else {
                cachedDeviceSettings?.simulationMode = isSim
            }
        }
        if parts.count > 15 {
            let ver = parts[15].trimmingCharacters(in: .whitespacesAndNewlines)
            if !ver.isEmpty && ver != "0" {
                return ver
            }
        }
        return ""
    }

    private func updateBLEManagerVersion(_ version: String) {
        if BLEManager.shared.deviceSettings != nil {
            BLEManager.shared.deviceSettings?.softwareVersion = version
        }
        cachedDeviceSettings?.softwareVersion = version
    }

    func preferredWiFiTargets() -> [(ssid: String, password: String)] {
        let settings = BLEManager.shared.deviceSettings ?? cachedDeviceSettings
        let apSSID = (settings?.deviceName.isEmpty == false)
            ? settings!.deviceName
            : (BLEManager.shared.connectedDeviceName ?? "esp32-AirUpDownController")
        let apPass = (settings?.accessPointPassword.count ?? 0) >= 8
            ? settings!.accessPointPassword
            : "12345678"

        var targets: [(ssid: String, password: String)] = []
        if let s = settings,
           !s.wifiSsid.isEmpty,
           !s.ipAddress.isEmpty,
           s.ipAddress != "192.168.4.1" {
            targets.append((ssid: s.wifiSsid, password: s.wifiPassword))
        }
        if !targets.contains(where: { $0.ssid == apSSID }) {
            targets.append((ssid: apSSID, password: apPass))
        }
        return targets
    }

    func connectToControllerWiFi() async throws -> String {
        let settings = BLEManager.shared.deviceSettings ?? cachedDeviceSettings
        if let existingHost = await resolveReachableHost(deviceSettings: settings) {
            reachableHost = existingHost
            customHostIP = existingHost
            appendLog(String(format: L("upgrade_log_connected_ip_format", comment: ""), existingHost))
            return existingHost
        }

        let target = preferredWiFiTargets().first ?? (ssid: "esp32-AirUpDownController", password: "12345678")
        if !target.password.isEmpty {
            UIPasteboard.general.string = target.password
        }
        let expectedIP = (settings?.ipAddress.isEmpty == false) ? settings!.ipAddress : "192.168.4.1"
        self.wifiPromptInfo = WiFiConnectionPromptInfo(
            ssid: target.ssid,
            password: target.password,
            expectedIP: expectedIP
        )
        throw FirmwareUpgradeError.deviceUnreachable(ssid: target.ssid, ip: expectedIP)
    }

    // MARK: - Upgrade Operations

    func performOperation(_ mode: UpgradeOperationMode) async {
        guard !upgradeState.isBusy else { return }
        stepLogs.removeAll()
        overallProgress = 0.0
        lastMigrationResult = nil

        if let s = BLEManager.shared.deviceSettings {
            cachedDeviceSettings = s
        }
        if let periphId = BLEManager.shared.connectedPeripheral?.identifier {
            savedPeripheralIdentifier = periphId
        }

        if BLEManager.shared.connectionState == .connected {
            BLEManager.shared.stopOperation()
        }

        do {
            let host = try await connectToControllerWiFi()

            // Snapshot original settings.json and SimulationMode before temporarily enabling SimulationMode
            let originalSettingsData = await fetchExistingSettingsJSON(host: host)
            let originalSimMode = resolveOriginalSimulationMode(from: originalSettingsData)
            var didEnableTemporarySimMode = false

            if mode != .settingsJsonOnly && !originalSimMode {
                didEnableTemporarySimMode = await enableTemporarySimulationMode(host: host)
            }

            switch mode {
            case .fullUpgrade:
                try await executeStaticFilesUpload(host: host, progressRange: 0.05...0.32)
                try await executeSettingsMigration(
                    host: host,
                    prefetchedData: originalSettingsData,
                    overrideSimulationMode: originalSimMode,
                    progressRange: 0.32...0.42
                )
                try? await Task.sleep(nanoseconds: 500_000_000)
                try await executeFirmwareUpload(host: host, progressRange: 0.42...0.92)
                await finalizeWithRebootAndReconnect(
                    host: host,
                    alreadyRebooting: true,
                    expectBundledFirmware: true,
                    restoreSimulationModeTo: didEnableTemporarySimMode ? originalSimMode : nil
                )
                let summary = String(format: L("upgrade_complete_full_format", comment: ""), deviceVersion)
                upgradeState = .completed(summary: summary)
                appendLog(summary)
                UINotificationFeedbackGenerator().notificationOccurred(.success)

            case .firmwareOnly:
                if didEnableTemporarySimMode, let originalSettingsData = originalSettingsData {
                    // Restore original SimulationMode in /spiffs/settings.json on disk while RAM stays in SimulationMode=true
                    try? await uploadMultipartFile(
                        host: host,
                        endpoint: "/doUpload",
                        fieldName: "file",
                        fileName: "/settings.json",
                        mimeType: "application/json",
                        fileData: originalSettingsData,
                        isFirmwareOTA: false,
                        onProgress: nil
                    )
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
                try await executeFirmwareUpload(host: host, progressRange: 0.08...0.92)
                await finalizeWithRebootAndReconnect(
                    host: host,
                    alreadyRebooting: true,
                    expectBundledFirmware: true,
                    restoreSimulationModeTo: didEnableTemporarySimMode ? originalSimMode : nil
                )
                let summary = String(format: L("upgrade_complete_firmware_format", comment: ""), deviceVersion)
                upgradeState = .completed(summary: summary)
                appendLog(summary)
                UINotificationFeedbackGenerator().notificationOccurred(.success)

            case .spiffsOnly:
                try await executeStaticFilesUpload(host: host, progressRange: 0.05...0.92)
                if didEnableTemporarySimMode {
                    await restoreSimulationModeAfterMaintenance(host: host, originalSimMode: originalSimMode, originalSettingsData: originalSettingsData)
                }
                overallProgress = 1.0
                let count = manifest?.staticFiles.count ?? 0
                let summary = String(format: L("upgrade_complete_spiffs_format", comment: ""), count)
                upgradeState = .completed(summary: summary)
                appendLog(summary)
                UINotificationFeedbackGenerator().notificationOccurred(.success)

            case .settingsJsonOnly:
                try await executeSettingsMigration(
                    host: host,
                    prefetchedData: originalSettingsData,
                    overrideSimulationMode: originalSimMode,
                    progressRange: 0.10...0.85
                )
                await finalizeWithRebootAndReconnect(
                    host: host,
                    alreadyRebooting: false,
                    expectBundledFirmware: false,
                    restoreSimulationModeTo: nil
                )
                let result = lastMigrationResult
                let summary = String(
                    format: L("upgrade_complete_settings_format", comment: ""),
                    result?.retainedKeys.count ?? 0,
                    result?.addedKeys.count ?? 0,
                    result?.removedKeys.count ?? 0
                )
                upgradeState = .completed(summary: summary)
                appendLog(summary)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            let message = error.localizedDescription
            appendLog(message)
            upgradeState = .failed(error: message)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func resolveOriginalSimulationMode(from settingsData: Data?) -> Bool {
        if let data = settingsData,
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let val = json["SimulationMode"] {
            if let b = val as? Bool { return b }
            if let n = val as? NSNumber { return n.boolValue }
            if let s = val as? String { return s.lowercased() == "true" || s == "1" }
        }
        return (BLEManager.shared.deviceSettings ?? cachedDeviceSettings)?.simulationMode ?? false
    }

    private func enableTemporarySimulationMode(host: String) async -> Bool {
        appendLog("Switching controller to Simulation Mode for uninterrupted OTA...")
        if BLEManager.shared.connectionState == .connected {
            BLEManager.shared.sendSimulationMode(enabled: true)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            return true
        }
        if let resp = try? await DirectWiFiHTTPClient.sendGET(host: host, path: "/updateSettings?SimulationMode=1", timeoutSec: 3.0),
           (200...299).contains(resp.statusCode) {
            try? await Task.sleep(nanoseconds: 5_500_000_000)
            return true
        }
        return false
    }

    private func restoreSimulationModeAfterMaintenance(
        host: String,
        originalSimMode: Bool,
        originalSettingsData: Data?
    ) async {
        appendLog("Restoring controller Simulation Mode to \(originalSimMode ? "On" : "Off")...")
        if BLEManager.shared.connectionState == .connected {
            BLEManager.shared.sendSimulationMode(enabled: originalSimMode)
            try? await Task.sleep(nanoseconds: 800_000_000)
        } else if let data = originalSettingsData {
            try? await uploadMultipartFile(
                host: host,
                endpoint: "/doUpload",
                fieldName: "file",
                fileName: "/settings.json",
                mimeType: "application/json",
                fileData: data,
                isFirmwareOTA: false,
                onProgress: nil
            )
            _ = try? await DirectWiFiHTTPClient.sendGET(host: host, path: "/reboot", timeoutSec: 2.5)
        }
    }

    // MARK: - Step Executors

    private func executeSettingsMigration(
        host: String,
        prefetchedData: Data? = nil,
        overrideSimulationMode: Bool? = nil,
        progressRange: ClosedRange<Double>
    ) async throws {
        upgradeState = .migratingSettings
        overallProgress = progressRange.lowerBound
        appendLog(L("upgrade_log_fetching_settings", comment: "Reading current settings.json from device..."))

        guard let schemaURL = resourceURL(path: "default_settings.json"),
              let defaultSchemaData = try? Data(contentsOf: schemaURL) else {
            throw FirmwareUpgradeError.defaultSettingsNotFound
        }

        let currentData: Data?
        if let prefetched = prefetchedData {
            currentData = prefetched
        } else {
            currentData = await fetchExistingSettingsJSON(host: host)
        }
        let migration = try Self.migrateSettingsJSON(
            currentJSONData: currentData,
            fallbackDeviceSettings: BLEManager.shared.deviceSettings ?? cachedDeviceSettings,
            defaultSchemaData: defaultSchemaData,
            overrideSimulationMode: overrideSimulationMode
        )
        self.lastMigrationResult = migration

        appendLog(
            String(
                format: L("upgrade_log_settings_merged_format", comment: ""),
                migration.retainedKeys.count,
                migration.addedKeys.count,
                migration.removedKeys.count
            )
        )

        overallProgress = (progressRange.lowerBound + progressRange.upperBound) / 2.0

        try await uploadMultipartFile(
            host: host,
            endpoint: "/doUpload",
            fieldName: "file",
            fileName: "/settings.json",
            mimeType: "application/json",
            fileData: migration.migratedJSONData,
            isFirmwareOTA: false,
            onProgress: nil
        )

        overallProgress = progressRange.upperBound
        appendLog(L("upgrade_log_settings_uploaded", comment: "Updated settings.json saved to SPIFFS."))
    }

    private func executeStaticFilesUpload(host: String, progressRange: ClosedRange<Double>) async throws {
        guard let manifest = manifest else {
            throw FirmwareUpgradeError.packageNotFound
        }
        let files = manifest.staticFiles
        guard !files.isEmpty else { return }

        let total = files.count
        for (idx, fileInfo) in files.enumerated() {
            let stepNum = idx + 1
            upgradeState = .uploadingStaticFiles(current: stepNum, total: total, fileName: fileInfo.name)
            appendLog(String(format: L("upgrade_log_uploading_file_format", comment: ""), fileInfo.name, stepNum, total))

            guard let fileURL = resourceURL(path: "spiffs/\(fileInfo.name)"),
                  let fileData = try? Data(contentsOf: fileURL) else {
                throw FirmwareUpgradeError.packageNotFound
            }

            try await uploadMultipartFile(
                host: host,
                endpoint: "/doUpload",
                fieldName: "file",
                fileName: "/\(fileInfo.name)",
                mimeType: mimeType(for: fileInfo.name),
                fileData: fileData,
                isFirmwareOTA: false,
                onProgress: nil
            )

            try? await Task.sleep(nanoseconds: 350_000_000)

            let fraction = Double(stepNum) / Double(total)
            overallProgress = progressRange.lowerBound + fraction * (progressRange.upperBound - progressRange.lowerBound)
        }
    }

    private func executeFirmwareUpload(host: String, progressRange: ClosedRange<Double>) async throws {
        guard let fwURL = resourceURL(path: "firmware.bin"),
              let fwData = try? Data(contentsOf: fwURL) else {
            throw FirmwareUpgradeError.firmwareBinaryNotFound
        }

        upgradeState = .uploadingFirmware(progress: 0.0)
        appendLog(String(format: L("upgrade_log_flashing_firmware_format", comment: ""), bundledVersion, fwData.count / 1024))

        try await uploadMultipartFile(
            host: host,
            endpoint: "/doUpdate",
            fieldName: "update",
            fileName: "firmware.bin",
            mimeType: "application/octet-stream",
            fileData: fwData,
            isFirmwareOTA: true
        ) { [weak self] pct in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.upgradeState = .uploadingFirmware(progress: pct)
                self.overallProgress = progressRange.lowerBound + pct * (progressRange.upperBound - progressRange.lowerBound)
            }
        }

        overallProgress = progressRange.upperBound
        appendLog(L("upgrade_log_firmware_uploaded", comment: "Firmware image written to flash."))
    }

    private func finalizeWithRebootAndReconnect(
        host: String,
        alreadyRebooting: Bool,
        expectBundledFirmware: Bool,
        restoreSimulationModeTo: Bool? = nil
    ) async {
        upgradeState = .rebootingDevice
        overallProgress = 0.94
        appendLog(L("upgrade_log_rebooting", comment: "Rebooting controller and reconnecting via BLE..."))

        if !alreadyRebooting {
            _ = try? await DirectWiFiHTTPClient.sendGET(host: host, path: "/reboot", timeoutSec: 2.5)
        }

        // Wait ~5.5s for ESP32 to finish scheduleRestart(1000), boot new partition, and start Wi-Fi + BLE
        try? await Task.sleep(nanoseconds: 5_500_000_000)

        if let uuid = savedPeripheralIdentifier {
            BLEManager.shared.connectByIdentifier(uuid)
        } else {
            BLEManager.shared.connectToSavedDevices()
        }

        var verifiedVersion: String?
        for _ in 0..<8 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let httpVer = await probeSettingsValues(host: host), !httpVer.isEmpty {
                verifiedVersion = httpVer
                deviceVersion = httpVer
                updateBLEManagerVersion(httpVer)
                evaluateUpdateAvailability()
            }
            if BLEManager.shared.connectionState == .connected {
                if let targetSim = restoreSimulationModeTo {
                    BLEManager.shared.sendSimulationMode(enabled: targetSim)
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
                BLEManager.shared.requestSettings()
                try? await Task.sleep(nanoseconds: 900_000_000)
                if let bleVer = BLEManager.shared.deviceSettings?.softwareVersion, !bleVer.isEmpty {
                    verifiedVersion = bleVer
                    deviceVersion = bleVer
                }
                if verifiedVersion != nil {
                    break
                }
            }
        }

        if expectBundledFirmware, verifiedVersion == nil, !bundledVersion.isEmpty {
            // If iOS switched away from SoftAP during ESP32 reboot and BLE is still reconnecting,
            // reflect the newly flashed version until BLE finishes reconnecting.
            deviceVersion = bundledVersion
            updateBLEManagerVersion(bundledVersion)
        }
        evaluateUpdateAvailability()
        if !isUpdateAvailable {
            updateSuggestionDismissed = true
            dismissedForDeviceVersion = deviceVersion
        }
        overallProgress = 1.0
    }

    // MARK: - Networking Helpers

    private func fetchExistingSettingsJSON(host: String) async -> Data? {
        if let resp = try? await DirectWiFiHTTPClient.sendGET(host: host, path: "/settings.json", timeoutSec: 4.0),
           (200...299).contains(resp.statusCode),
           !resp.body.isEmpty {
            return resp.body
        }
        return nil
    }

    private func uploadMultipartFile(
        host: String,
        endpoint: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        isFirmwareOTA: Bool,
        onProgress: ((Double) -> Void)?
    ) async throws {
        let statusCode = try await DirectWiFiHTTPClient.uploadMultipart(
            host: host,
            path: endpoint,
            fieldName: fieldName,
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            isFirmwareOTA: isFirmwareOTA,
            onProgress: onProgress
        )
        guard (200...299).contains(statusCode) else {
            throw FirmwareUpgradeError.uploadFailed(file: fileName, statusCode: statusCode)
        }
    }

    private func mimeType(for fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".html") { return "text/html" }
        if lower.hasSuffix(".css") { return "text/css" }
        if lower.hasSuffix(".js") { return "text/javascript" }
        if lower.hasSuffix(".json") { return "application/json" }
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return "image/jpeg" }
        if lower.hasSuffix(".png") { return "image/png" }
        return "application/octet-stream"
    }

    private func appendLog(_ text: String) {
        print("[FirmwareUpgradeManager] \(text)")
        stepLogs.append(text)
    }
}

// MARK: - Direct Wi-Fi POSIX Socket HTTP Client
// Binds directly to the local Wi-Fi interface (`en0`) so iOS never drops or reroutes
// traffic to Cellular when connected to an ESP32 SoftAP (`192.168.4.1`) without internet,
// and paces 4 KB / 64 KB OTA chunks to match ESP32 SPI flash sector/block erase timing.

enum DirectWiFiHTTPClient {
    struct HTTPResponse {
        let statusCode: Int
        let body: Data
    }

    static func sendGET(host: String, path: String, timeoutSec: Double) async throws -> HTTPResponse {
        try await Task.detached(priority: .userInitiated) {
            let fd = try openConnectedSocket(host: host, port: 80, timeoutSec: timeoutSec)
            defer { Darwin.close(fd) }

            let reqStr = "GET \(path) HTTP/1.1\r\nHost: \(host)\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n"
            guard let reqData = reqStr.data(using: .utf8) else {
                throw URLError(.badURL)
            }
            try writeAll(fd: fd, data: reqData)
            return try readHTTPResponse(fd: fd)
        }.value
    }

    static func uploadMultipart(
        host: String,
        path: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        isFirmwareOTA: Bool,
        onProgress: ((Double) -> Void)?
    ) async throws -> Int {
        try await Task.detached(priority: .userInitiated) {
            try uploadMultipartSync(
                host: host,
                path: path,
                fieldName: fieldName,
                fileName: fileName,
                mimeType: mimeType,
                fileData: fileData,
                isFirmwareOTA: isFirmwareOTA,
                onProgress: onProgress
            )
        }.value
    }

    private static func uploadMultipartSync(
        host: String,
        path: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        isFirmwareOTA: Bool,
        onProgress: ((Double) -> Void)?
    ) throws -> Int {
        let timeoutSec: Double = isFirmwareOTA ? 90.0 : 30.0
        let fd = try openConnectedSocket(host: host, port: 80, timeoutSec: timeoutSec)
        defer { Darwin.close(fd) }

        let boundary = "ESP32FormBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var preamble = Data()
        preamble.append("--\(boundary)\r\n".data(using: .utf8)!)
        preamble.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        preamble.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

        let epilogue = "\r\n--\(boundary)--\r\n".data(using: .utf8)!
        let contentLength = preamble.count + fileData.count + epilogue.count

        var headerStr = "POST \(path) HTTP/1.1\r\n"
        headerStr += "Host: \(host)\r\n"
        headerStr += "Content-Type: multipart/form-data; boundary=\(boundary)\r\n"
        headerStr += "Content-Length: \(contentLength)\r\n"
        headerStr += "Connection: close\r\n\r\n"

        guard let headerData = headerStr.data(using: .utf8) else {
            throw URLError(.badURL)
        }

        // 1. Send HTTP headers + multipart preamble together
        var initialHeaderAndPreamble = Data()
        initialHeaderAndPreamble.append(headerData)
        initialHeaderAndPreamble.append(preamble)
        try writeAll(fd: fd, data: initialHeaderAndPreamble)

        // 2. Stream fileData in paced chunks
        let totalBytes = fileData.count
        let chunkSize = isFirmwareOTA ? 1436 : 4096 // 1436 matches ESP32 LwIP TCP_MSS
        var offset = 0
        var lastReportedPct = -1

        while offset < totalBytes {
            let end = min(offset + chunkSize, totalBytes)
            let slice = fileData.subdata(in: offset..<end)
            try writeAll(fd: fd, data: slice)

            let prevBlock = offset / 65536
            offset = end
            let newBlock = offset / 65536

            if isFirmwareOTA {
                if newBlock > prevBlock {
                    // Every 64 KB boundary triggers SPI_FLASH_BLOCK_SIZE erase on ESP32
                    usleep(25_000)
                } else {
                    usleep(3_000)
                }
            }

            let pctInt = Int((Double(offset) / Double(max(totalBytes, 1))) * 100)
            if pctInt != lastReportedPct {
                lastReportedPct = pctInt
                onProgress?(Double(offset) / Double(max(totalBytes, 1)))
            }
        }

        // 3. Send closing multipart boundary
        try writeAll(fd: fd, data: epilogue)
        onProgress?(1.0)

        // 4. Read HTTP response from ESP32 (sent 1000ms before scheduleRestart)
        let response = try readHTTPResponse(fd: fd)
        return response.statusCode
    }

    private static func openConnectedSocket(host: String, port: UInt16, timeoutSec: Double) throws -> Int32 {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw URLError(.cannotConnectToHost)
        }

        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))

        // Keep kernel send buffer small (16 KB) so send() naturally backpressures against ESP32's 5744-byte TCP window
        var sndBuf: Int32 = 16384
        setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sndBuf, socklen_t(MemoryLayout<Int32>.size))

        // Bind to local Wi-Fi interface (e.g. en0) if it matches the target subnet or is active
        if var ifIndex = resolveWiFiInterfaceIndex(forHost: host), ifIndex > 0 {
            setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &ifIndex, socklen_t(MemoryLayout<UInt32>.size))
        }

        // Non-blocking connect with poll() timeout
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            Darwin.close(fd)
            throw URLError(.cannotFindHost)
        }

        let connectRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectRes < 0 && errno != EINPROGRESS {
            Darwin.close(fd)
            throw URLError(.cannotConnectToHost)
        }

        if connectRes < 0 {
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let pollRes = Darwin.poll(&pfd, 1, Int32(timeoutSec * 1000))
            if pollRes <= 0 {
                Darwin.close(fd)
                throw URLError(.timedOut)
            }
            var soError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
            if soError != 0 {
                Darwin.close(fd)
                throw URLError(.cannotConnectToHost)
            }
        }

        // Restore blocking mode and set send/receive timeouts
        _ = fcntl(fd, F_SETFL, flags)
        let wholeSec = Int(timeoutSec)
        let usec = Int32((timeoutSec - Double(wholeSec)) * 1_000_000)
        var tv = timeval(tv_sec: wholeSec, tv_usec: usec)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        return fd
    }

    private static func writeAll(fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var sent = 0
            while sent < data.count {
                let n = Darwin.send(fd, base.advanced(by: sent), data.count - sent, 0)
                if n > 0 {
                    sent += n
                } else if n < 0 && (errno == EINTR || errno == EAGAIN) {
                    Thread.sleep(forTimeInterval: 0.01)
                    continue
                } else {
                    throw URLError(.networkConnectionLost)
                }
            }
        }
    }

    private static func readHTTPResponse(fd: Int32) throws -> HTTPResponse {
        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 2048)
        while true {
            let n = Darwin.recv(fd, &buffer, buffer.count, 0)
            if n > 0 {
                received.append(buffer, count: n)
            } else if n == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                // If we already received HTTP/1.1 200 OK before the ESP32 rebooted and reset the socket, treat as valid
                if !received.isEmpty {
                    break
                }
                throw URLError(.networkConnectionLost)
            }
        }

        guard !received.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let separator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        let headerData: Data
        let bodyData: Data
        if let range = received.range(of: separator) {
            headerData = received.subdata(in: 0..<range.lowerBound)
            bodyData = received.subdata(in: range.upperBound..<received.count)
        } else {
            headerData = received
            bodyData = Data()
        }

        let headerStr = String(data: headerData, encoding: .utf8) ?? ""
        let firstLine = headerStr.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let statusCode = parts.count >= 2 ? (Int(parts[1]) ?? -1) : -1

        return HTTPResponse(statusCode: statusCode, body: bodyData)
    }

    /// Finds the BSD interface index (e.g. `en0`) whose IPv4 address shares a `/24` prefix with `host`,
    /// or falls back to `en0` if `en0` has a valid IPv4 address.
    private static func resolveWiFiInterfaceIndex(forHost host: String) -> UInt32? {
        var targetAddr = in_addr()
        guard inet_pton(AF_INET, host, &targetAddr) == 1 else { return nil }
        let targetNet24 = UInt32(bigEndian: targetAddr.s_addr) & 0xFFFFFF00

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var fallbackEn0Index: UInt32?
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ifa = cursor?.pointee {
            if let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ifa.ifa_name)
                let sin = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let ipNet24 = UInt32(bigEndian: sin.sin_addr.s_addr) & 0xFFFFFF00
                let idx = if_nametoindex(ifa.ifa_name)
                if idx > 0 {
                    if ipNet24 == targetNet24 {
                        return idx
                    }
                    if name == "en0" {
                        fallbackEn0Index = idx
                    }
                }
            }
            cursor = ifa.ifa_next
        }
        return fallbackEn0Index
    }
}
