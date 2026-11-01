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

                // Bottom bar with Save and Close/Discard buttons (matching Android)
                VStack(spacing: 8) {
                    if hasUnsavedChanges {
                        Text(L("unsaved_changes_message", comment: ""))
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        Button(action: saveSettings) {
                            Text(L("save_settings", comment: "Save Settings"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.primary)
                                .cornerRadius(10)
                        }

                        Button(action: closeOrDiscard) {
                            Text(hasUnsavedChanges
                                 ? L("discard", comment: "Discard Changes")
                                 : L("close", comment: "Close"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.gray.opacity(0.6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle(L("settings", comment: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDeviceSettings) {
                DeviceSettingsView()
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.resetToDefaults()
                    loadFromSettingsManager()
                    hasUnsavedChanges = false
                }
            } message: {
                Text(L("reset_defaults_message", comment: ""))
            }
        }
        .onAppear { loadFromSettingsManager() }
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
        editSimulationMode = settingsManager.simulationMode
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
            .alert("Add Preset Pressure", isPresented: $showingAddPressure) {
                TextField("Pressure (1-80 PSI)", text: $newPressure)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { newPressure = "" }
                Button("Add") { addNewPressure() }
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
                    Section("Device Info") {
                        if !softwareVersion.isEmpty {
                            HStack {
                                Text("Firmware Version")
                                Spacer()
                                Text(softwareVersion)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if !ipAddress.isEmpty {
                            HStack {
                                Text("IP Address")
                                Spacer()
                                Text(ipAddress)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("General") {
                    HStack {
                        Text("Device Name")
                        Spacer()
                        TextField("Device Name", text: $deviceName)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: deviceName) { _ in hasUnsavedChanges = true }
                    }

                    Toggle("Simulation Mode", isOn: $simulationMode)
                        .onChange(of: simulationMode) { _ in hasUnsavedChanges = true }
                }

                Section("Wi-Fi & Hotspot") {
                    TextField("Wi-Fi SSID", text: $wifiSsid)
                        .onChange(of: wifiSsid) { _ in hasUnsavedChanges = true }

                    SecureField("Wi-Fi Password (leave blank to keep)", text: $wifiPassword)
                        .onChange(of: wifiPassword) { _ in hasUnsavedChanges = true }

                    SecureField("Hotspot Password (min 8 chars)", text: $accessPointPassword)
                        .onChange(of: accessPointPassword) { _ in hasUnsavedChanges = true }
                }

                Section("BLE Security") {
                    SecureField(
                        hasAccessCode ? "Access Code IS SET (leave blank to keep)" : "Access Code (unlocked - enter to set)",
                        text: $accessCode
                    )
                    .disabled(clearAccessCode)
                    .onChange(of: accessCode) { _ in hasUnsavedChanges = true }

                    Toggle("Clear Access Code", isOn: $clearAccessCode)
                        .onChange(of: clearAccessCode) { val in
                            if val { accessCode = "" }
                            hasUnsavedChanges = true
                        }
                }

                Section("Safety Limits") {
                    HStack {
                        Text("Sensor Full Scale (PSI)")
                        Spacer()
                        TextField("50.0", text: $sensorFullScalePSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: sensorFullScalePSI) { _ in hasUnsavedChanges = true }
                    }

                    HStack {
                        Text("Max Pressure (PSI)")
                        Spacer()
                        TextField("50.0", text: $maxPressurePSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: maxPressurePSI) { _ in hasUnsavedChanges = true }
                    }

                    Stepper("Max Valve Open: \(maxValveOpenSec)s", value: $maxValveOpenSec, in: 10...600, step: 10)
                        .onChange(of: maxValveOpenSec) { _ in hasUnsavedChanges = true }
                }

                Section("Hardware Pins") {
                    Stepper("Compressor Pin (GPIO): \(relayCompressorPin)", value: $relayCompressorPin, in: 1...39)
                        .onChange(of: relayCompressorPin) { _ in hasUnsavedChanges = true }

                    Stepper("Free/Deflate Pin (GPIO): \(relayFreePin)", value: $relayFreePin, in: 1...39)
                        .onChange(of: relayFreePin) { _ in hasUnsavedChanges = true }

                    Stepper("Sensor Pin (ADC1 GPIO): \(sensorPin)", value: $sensorPin, in: 32...39)
                        .onChange(of: sensorPin) { _ in hasUnsavedChanges = true }
                }

                Section("Calibration & Timing") {
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

                    Picker("Calc Method", selection: $pressureCalcMethod) {
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

                    Stepper("Max Status Time: \(maxSecForStatus)s", value: $maxSecForStatus, in: 1...120)
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
            .navigationTitle("Device Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingExitAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveSettings() }
                        .disabled(isSaving)
                }
            }
            .alert("Exit Without Saving?", isPresented: $showingExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Discard", role: .destructive) { dismiss() }
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
        .onAppear { loadCurrentSettings() }
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
        settings.deviceName = deviceName
        settings.wifiSsid = wifiSsid
        settings.wifiPassword = wifiPassword
        settings.accessPointPassword = accessPointPassword.count >= 8 ? accessPointPassword : "12345678"
        settings.accessCode = accessCode
        settings.clearAccessCode = clearAccessCode
        settings.relayCompressorPin = relayCompressorPin
        settings.relayFreePin = relayFreePin
        settings.sensorPin = sensorPin
        settings.maxSecForStatus = maxSecForStatus
        settings.sensorValueAt0PSI = Double(sensorValueAt0PSI) ?? 410.0
        settings.sensorValueAt50PSI = Double(sensorValueAt50PSI) ?? 3400.0
        settings.sensorFullScalePSI = Double(sensorFullScalePSI) ?? 50.0
        settings.maxPressurePSI = Double(maxPressurePSI) ?? 50.0
        settings.maxValveOpenSec = maxValveOpenSec
        settings.measureWait = Double(measureWait) ?? 1.0
        settings.precision = Double(precision) ?? 0.5
        settings.simulationMode = simulationMode
        settings.pressureCalcMethod = pressureCalcMethod

        bleManager.updateSettings(settings)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
