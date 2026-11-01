import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss

    @State private var editDisplayMode: DisplayMode = .dark
    @State private var editLanguage: AppLanguage = .system
    @State private var editDebugMode: Bool = false
    @State private var editSimulationMode: Bool = false
    @State private var editPresetPressures: [Double] = []

    @State private var showingDeviceSettings = false
    @State private var showingResetAlert = false
    @State private var hasUnsavedChanges = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section(L("app_settings", comment: "App Settings")) {
                        Picker(L("display_mode", comment: "Display Mode"),
                               selection: $editDisplayMode) {
                            ForEach(DisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayText).tag(mode)
                            }
                        }

                        Picker(L("language", comment: "Language"),
                               selection: $editLanguage) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayText).tag(lang)
                            }
                        }

                        Toggle(L("debug_mode", comment: "Debug Mode"),
                               isOn: $editDebugMode)

                        Toggle(L("simulation_mode", comment: "Simulation Mode"),
                               isOn: $editSimulationMode)
                    }

                    Section(L("preset_pressures_title", comment: "Preset Pressures")) {
                        PresetPressuresSection(
                            presetPressures: $editPresetPressures,
                            maxPressureCount: settingsManager.maxPressureCount,
                            minPressureCount: settingsManager.minPressureCount
                        )
                    }

                    Section(L("device_management", comment: "Device Management")) {
                        NavigationLink(destination: DeviceManagementView()) {
                            HStack {
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .foregroundColor(AppColors.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L("manage_paired_devices", comment: "Manage Paired Devices"))
                                    Text(L("manage_paired_devices_description", comment: "Description"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    if bleManager.connectionState.isConnected {
                        Section(L("device_settings", comment: "Device Settings")) {
                            Button(action: { showingDeviceSettings = true }) {
                                HStack {
                                    Image(systemName: "gearshape.2")
                                        .foregroundColor(AppColors.primary)
                                    Text(L("configure_device_settings", comment: ""))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)

                            Button(action: { bleManager.requestSettings() }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(AppColors.connectingAmber)
                                    Text(L("request_settings", comment: "Request Settings"))
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    Section {
                        Button(action: { showingResetAlert = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.red)
                                Text(L("reset_to_defaults", comment: ""))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)

                // Bottom bar with Save and Close/Discard buttons (matching Android)
                VStack(spacing: 8) {
                    if hasUnsavedChanges {
                        Text(L("unsaved_changes_message", comment: ""))
                            .font(.caption)
                            .foregroundColor(AppColors.primaryLight)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        Button(action: saveSettings) {
                            Text(L("save_settings", comment: "Save Settings"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.primary)
                                .cornerRadius(12)
                        }

                        Button(action: closeOrDiscard) {
                            Text(hasUnsavedChanges
                                 ? L("discard", comment: "Discard Changes")
                                 : L("close", comment: "Close"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
                .background(AppColors.navBarBackground)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(L("settings", comment: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.navBarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingDeviceSettings) {
                DeviceSettingsView()
            }
            .alert(L("reset_to_defaults", comment: ""), isPresented: $showingResetAlert) {
                Button(L("cancel", comment: ""), role: .cancel) { }
                Button(L("reset", comment: ""), role: .destructive) {
                    settingsManager.resetToDefaults()
                    loadFromSettingsManager()
                    hasUnsavedChanges = false
                }
            } message: {
                Text(L("reset_defaults_message", comment: ""))
            }
        }
        .onAppear { loadFromSettingsManager() }
        .onChange(of: bleManager.deviceSettings) { newSettings in
            if let s = newSettings, !hasUnsavedChanges {
                editSimulationMode = s.simulationMode
            }
        }
        .onChange(of: editDisplayMode) { _ in checkForChanges() }
        .onChange(of: editLanguage) { _ in checkForChanges() }
        .onChange(of: editDebugMode) { _ in checkForChanges() }
        .onChange(of: editSimulationMode) { _ in checkForChanges() }
        .onChange(of: editPresetPressures) { _ in checkForChanges() }
    }

    private func loadFromSettingsManager() {
        editDisplayMode = settingsManager.displayMode
        editLanguage = settingsManager.language
        editDebugMode = settingsManager.debugMode
        editSimulationMode = bleManager.deviceSettings?.simulationMode ?? settingsManager.simulationMode
        editPresetPressures = settingsManager.presetPressures
        hasUnsavedChanges = false
    }

    private func checkForChanges() {
        hasUnsavedChanges = editDisplayMode != settingsManager.displayMode
            || editLanguage != settingsManager.language
            || editDebugMode != settingsManager.debugMode
            || editSimulationMode != settingsManager.simulationMode
            || editPresetPressures != settingsManager.presetPressures
    }

    private func saveSettings() {
        settingsManager.displayMode = editDisplayMode
        settingsManager.language = editLanguage
        settingsManager.presetPressures = editPresetPressures

        if editDebugMode != settingsManager.debugMode {
            settingsManager.updateDebugMode(editDebugMode)
            bleManager.sendDebugMode(enabled: editDebugMode)
        }
        if editSimulationMode != settingsManager.simulationMode {
            settingsManager.updateSimulationMode(editSimulationMode)
            bleManager.sendSimulationMode(enabled: editSimulationMode)
        }

        settingsManager.saveSettings()
        hasUnsavedChanges = false
        dismiss()
    }

    private func closeOrDiscard() {
        dismiss()
    }
}

// MARK: - Preset Pressures Section
struct PresetPressuresSection: View {
    @Binding var presetPressures: [Double]
    let maxPressureCount: Int
    let minPressureCount: Int

    @State private var newPressure: String = ""
    @State private var showingAddPressure = false

    private var canAdd: Bool { presetPressures.count < maxPressureCount }
    private var canRemove: Bool { presetPressures.count > minPressureCount }

    var body: some View {
        ForEach(Array(presetPressures.enumerated()), id: \.offset) { _, pressure in
            HStack {
                Text(String(format: "%.0f PSI", pressure))
                Spacer()

                if canRemove {
                    Button(action: { presetPressures.removeAll { $0 == pressure } }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }

        if canAdd {
            Button(action: { showingAddPressure = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text(L("add_pressure", comment: "Add Pressure"))
                }
            }
            .alert(L("add_pressure", comment: ""), isPresented: $showingAddPressure) {
                TextField("1-80 PSI", text: $newPressure)
                    .keyboardType(.decimalPad)
                Button(L("cancel", comment: ""), role: .cancel) { newPressure = "" }
                Button(L("add", comment: "")) { addNewPressure() }
            } message: {
                Text(L("enter_pressure_hint", comment: ""))
            }
        }

        Text(String(format: L("presets_count", comment: ""), presetPressures.count, maxPressureCount))
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private func addNewPressure() {
        guard let pressure = Double(newPressure),
              pressure >= 1.0 && pressure <= 80.0,
              !presetPressures.contains(pressure) else { return }
        presetPressures.append(pressure)
        presetPressures.sort()
        newPressure = ""
    }
}

// MARK: - Device Settings View
struct DeviceSettingsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var softwareVersion: String = ""
    @State private var ipAddress: String = ""
    @State private var deviceName: String = ""
    @State private var wifiSsid: String = ""
    @State private var wifiPassword: String = ""
    @State private var accessPointPassword: String = "12345678"
    @State private var hasAccessCode: Bool = false
    @State private var accessCode: String = ""
    @State private var clearAccessCode: Bool = false
    @State private var relayCompressorPin: Int = 16
    @State private var relayFreePin: Int = 17
    @State private var sensorPin: Int = 34
    @State private var maxSecForStatus: Int = 10
    @State private var sensorValueAt0PSI: String = "410.000"
    @State private var sensorValueAt50PSI: String = "3400.000"
    @State private var sensorFullScalePSI: String = "50.0"
    @State private var maxPressurePSI: String = "50.0"
    @State private var maxValveOpenSec: Int = 120
    @State private var measureWait: String = "1.0"
    @State private var precision: String = "0.5"
    @State private var simulationMode: Bool = false
    @State private var pressureCalcMethod: Int = 1

    @State private var hasUnsavedChanges = false
    @State private var showingExitAlert = false
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                if !softwareVersion.isEmpty || !ipAddress.isEmpty {
                    Section(L("device_info", comment: "")) {
                        if !softwareVersion.isEmpty {
                            HStack {
                                Text(L("firmware_version", comment: ""))
                                Spacer()
                                Text(softwareVersion)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if !ipAddress.isEmpty {
                            HStack {
                                Text(L("ip_address", comment: ""))
                                Spacer()
                                Text(ipAddress)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(L("general", comment: "")) {
                    HStack {
                        Text(L("device_name", comment: ""))
                        Spacer()
                        TextField(L("device_name", comment: ""), text: $deviceName)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: deviceName) { _ in hasUnsavedChanges = true }
                    }

                    Toggle(L("simulation_mode", comment: ""), isOn: $simulationMode)
                        .onChange(of: simulationMode) { _ in hasUnsavedChanges = true }
                }

                Section(L("wifi_and_hotspot", comment: "")) {
                    TextField(L("ssid", comment: ""), text: $wifiSsid)
                        .onChange(of: wifiSsid) { _ in hasUnsavedChanges = true }

                    SecureField(L("wifi_password_keep_hint", comment: ""), text: $wifiPassword)
                        .onChange(of: wifiPassword) { _ in hasUnsavedChanges = true }

                    SecureField(L("hotspot_password_hint", comment: ""), text: $accessPointPassword)
                        .onChange(of: accessPointPassword) { _ in hasUnsavedChanges = true }
                }

                Section(L("ble_security", comment: "")) {
                    SecureField(
                        hasAccessCode ? L("access_code_set_hint", comment: "") : L("access_code_unlocked_hint", comment: ""),
                        text: $accessCode
                    )
                    .disabled(clearAccessCode)
                    .onChange(of: accessCode) { _ in hasUnsavedChanges = true }

                    Toggle(L("clear_access_code", comment: ""), isOn: $clearAccessCode)
                        .onChange(of: clearAccessCode) { val in
                            if val { accessCode = "" }
                            hasUnsavedChanges = true
                        }
                }

                Section(L("safety_limits", comment: "")) {
                    HStack {
                        Text(L("sensor_full_scale_psi", comment: ""))
                        Spacer()
                        TextField("50.0", text: $sensorFullScalePSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: sensorFullScalePSI) { _ in hasUnsavedChanges = true }
                    }

                    HStack {
                        Text(L("max_pressure_psi", comment: ""))
                        Spacer()
                        TextField("50.0", text: $maxPressurePSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: maxPressurePSI) { _ in hasUnsavedChanges = true }
                    }

                    Stepper(String(format: L("max_valve_open_format", comment: ""), maxValveOpenSec), value: $maxValveOpenSec, in: 10...600, step: 10)
                        .onChange(of: maxValveOpenSec) { _ in hasUnsavedChanges = true }
                }

                Section(L("hardware_pins", comment: "")) {
                    Stepper(String(format: L("compressor_pin_format", comment: ""), relayCompressorPin), value: $relayCompressorPin, in: 1...39)
                        .onChange(of: relayCompressorPin) { _ in hasUnsavedChanges = true }

                    Stepper(String(format: L("free_pin_format", comment: ""), relayFreePin), value: $relayFreePin, in: 1...39)
                        .onChange(of: relayFreePin) { _ in hasUnsavedChanges = true }

                    Stepper(String(format: L("sensor_pin_format", comment: ""), sensorPin), value: $sensorPin, in: 32...39)
                        .onChange(of: sensorPin) { _ in hasUnsavedChanges = true }
                }

                Section(L("calibration_and_timing", comment: "")) {
                    HStack {
                        Text(L("sensor_at_0_psi", comment: ""))
                        Spacer()
                        TextField("410.000", text: $sensorValueAt0PSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: sensorValueAt0PSI) { _ in hasUnsavedChanges = true }
                    }

                    HStack {
                        Text(L("sensor_at_50_psi", comment: ""))
                        Spacer()
                        TextField("3400.000", text: $sensorValueAt50PSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: sensorValueAt50PSI) { _ in hasUnsavedChanges = true }
                    }

                    Picker(L("pressure_calc_method", comment: ""), selection: $pressureCalcMethod) {
                        ForEach(PressureCalcMethod.allCases, id: \.rawValue) { method in
                            Text(method.displayText).tag(method.rawValue)
                        }
                    }
                    .onChange(of: pressureCalcMethod) { _ in hasUnsavedChanges = true }

                    HStack {
                        Text(L("precision_label", comment: ""))
                        Spacer()
                        TextField("0.5", text: $precision)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: precision) { _ in hasUnsavedChanges = true }
                    }

                    Stepper(String(format: L("max_status_time_format", comment: ""), maxSecForStatus), value: $maxSecForStatus, in: 1...120)
                        .onChange(of: maxSecForStatus) { _ in hasUnsavedChanges = true }

                    HStack {
                        Text(L("measure_wait_label", comment: ""))
                        Spacer()
                        TextField("1.0", text: $measureWait)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: measureWait) { _ in hasUnsavedChanges = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(L("device_configuration", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.navBarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("cancel", comment: "")) {
                        if hasUnsavedChanges {
                            showingExitAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("save", comment: "")) { saveSettings() }
                        .disabled(isSaving)
                }
            }
            .alert(L("exit_without_save", comment: ""), isPresented: $showingExitAlert) {
                Button(L("cancel", comment: ""), role: .cancel) { }
                Button(L("discard", comment: ""), role: .destructive) { dismiss() }
            } message: {
                Text(L("unsaved_changes_warning", comment: ""))
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text(L("saving_restarting", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(32)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                        }
                }
            }
        }
        .onAppear {
            if bleManager.deviceSettings == nil {
                bleManager.requestSettings()
            }
            loadCurrentSettings()
        }
        .onChange(of: bleManager.deviceSettings) { _ in
            if !hasUnsavedChanges && !isSaving {
                loadCurrentSettings()
            }
        }
    }

    private func parseDecimal(_ text: String, fallback: Double) -> Double {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? fallback
    }

    private func loadCurrentSettings() {
        guard let s = bleManager.deviceSettings else { return }
        softwareVersion = s.softwareVersion
        ipAddress = s.ipAddress
        deviceName = s.deviceName
        wifiSsid = s.wifiSsid
        wifiPassword = s.wifiPassword
        accessPointPassword = s.accessPointPassword
        hasAccessCode = s.hasAccessCode
        accessCode = ""
        clearAccessCode = false
        relayCompressorPin = s.relayCompressorPin
        relayFreePin = s.relayFreePin
        sensorPin = s.sensorPin
        maxSecForStatus = s.maxSecForStatus
        sensorValueAt0PSI = String(format: "%.3f", s.sensorValueAt0PSI)
        sensorValueAt50PSI = String(format: "%.3f", s.sensorValueAt50PSI)
        sensorFullScalePSI = String(format: "%.1f", s.sensorFullScalePSI)
        maxPressurePSI = String(format: "%.1f", s.maxPressurePSI)
        maxValveOpenSec = s.maxValveOpenSec
        measureWait = String(format: "%.1f", s.measureWait)
        precision = String(format: "%.1f", s.precision)
        simulationMode = s.simulationMode
        pressureCalcMethod = s.pressureCalcMethod
        hasUnsavedChanges = false
    }

    private func saveSettings() {
        isSaving = true

        var settings = DeviceSettings()
        settings.deviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.wifiSsid = wifiSsid.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.wifiPassword = wifiPassword
        settings.accessPointPassword = accessPointPassword.count >= 8 ? accessPointPassword : "12345678"
        settings.accessCode = accessCode
        settings.clearAccessCode = clearAccessCode
        settings.relayCompressorPin = relayCompressorPin
        settings.relayFreePin = relayFreePin
        settings.sensorPin = sensorPin
        settings.maxSecForStatus = maxSecForStatus
        settings.sensorValueAt0PSI = parseDecimal(sensorValueAt0PSI, fallback: 410.0)
        settings.sensorValueAt50PSI = parseDecimal(sensorValueAt50PSI, fallback: 3400.0)
        settings.sensorFullScalePSI = parseDecimal(sensorFullScalePSI, fallback: 50.0)
        settings.maxPressurePSI = parseDecimal(maxPressurePSI, fallback: 50.0)
        settings.maxValveOpenSec = maxValveOpenSec
        settings.measureWait = parseDecimal(measureWait, fallback: 1.0)
        settings.precision = parseDecimal(precision, fallback: 0.5)
        settings.simulationMode = simulationMode
        settings.pressureCalcMethod = pressureCalcMethod

        bleManager.updateSettings(settings)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            bleManager.forceReconnect()

            try? await Task.sleep(nanoseconds: 5_000_000_000)

            let debugEnabled = settingsManager.debugMode
            bleManager.sendDebugMode(enabled: debugEnabled)

            isSaving = false
            hasUnsavedChanges = false
            dismiss()
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsManager())
            .environmentObject(BLEManager())
    }
}
#endif
