import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var bleManager: BLEManager
    @State private var showingDeviceSettings = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("app_settings", comment: "App Settings")) {
                    // Note: display mode is always dark to match Android
                    Picker(NSLocalizedString("display_mode", comment: "Display Mode"),
                           selection: $settingsManager.displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayText).tag(mode)
                        }
                    }

                    Picker(NSLocalizedString("language", comment: "Language"),
                           selection: $settingsManager.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayText).tag(lang)
                        }
                    }

                    Toggle(NSLocalizedString("debug_mode", comment: "Debug Mode"),
                           isOn: Binding(
                            get: { settingsManager.debugMode },
                            set: { newValue in
                                settingsManager.updateDebugMode(newValue)
                                bleManager.sendDebugMode(enabled: newValue)
                            }
                           ))

                    Toggle(NSLocalizedString("simulation_mode", comment: "Simulation Mode"),
                           isOn: Binding(
                            get: { settingsManager.simulationMode },
                            set: { newValue in
                                settingsManager.updateSimulationMode(newValue)
                                bleManager.sendSimulationMode(enabled: newValue)
                            }
                           ))
                }

                Section(NSLocalizedString("preset_pressures_title", comment: "Preset Pressures")) {
                    PresetPressuresSection()
                }

                Section(NSLocalizedString("device_management", comment: "Device Management")) {
                    NavigationLink(destination: DeviceManagementView()) {
                        HStack {
                            Image(systemName: "externaldrive.connected.to.line.below")
                                .foregroundColor(AppColors.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("manage_paired_devices", comment: "Manage Paired Devices"))
                                Text(NSLocalizedString("manage_paired_devices_description", comment: "Description"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if bleManager.connectionState.isConnected {
                    Section(NSLocalizedString("device_settings", comment: "Device Settings")) {
                        Button(action: { showingDeviceSettings = true }) {
                            HStack {
                                Image(systemName: "gearshape.2")
                                    .foregroundColor(AppColors.primary)
                                Text("Configure Device Settings")
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
                                Text(NSLocalizedString("request_settings", comment: "Request Settings"))
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
                            Text("Reset to Defaults")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings", comment: "Settings"))
            .sheet(isPresented: $showingDeviceSettings) {
                DeviceSettingsView()
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }
}

// MARK: - Preset Pressures Section
struct PresetPressuresSection: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var newPressure: String = ""
    @State private var showingAddPressure = false

    var body: some View {
        ForEach(Array(settingsManager.presetPressures.enumerated()), id: \.offset) { _, pressure in
            HStack {
                Text(String(format: "%.0f PSI", pressure))
                Spacer()

                if settingsManager.canRemovePresetPressure {
                    Button(action: { settingsManager.removePresetPressure(pressure) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }

        if settingsManager.canAddPresetPressure {
            Button(action: { showingAddPressure = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("add_pressure", comment: "Add Pressure"))
                }
            }
            .alert("Add Preset Pressure", isPresented: $showingAddPressure) {
                TextField("Pressure (1-80 PSI)", text: $newPressure)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { newPressure = "" }
                Button("Add") { addNewPressure() }
            } message: {
                Text("Enter a pressure value between 1 and 80 PSI")
            }
        }

        Text("Presets: \(settingsManager.presetPressures.count)/\(settingsManager.maxPressureCount)")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private func addNewPressure() {
        guard let pressure = Double(newPressure),
              pressure >= 1.0 && pressure <= 80.0 else { return }
        settingsManager.addPresetPressure(pressure)
        newPressure = ""
    }
}

// MARK: - Device Settings View
struct DeviceSettingsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var deviceName: String = ""
    @State private var wifiSsid: String = ""
    @State private var wifiPassword: String = ""
    @State private var relayCompressorPin: Int = 0
    @State private var relayFreePin: Int = 0
    @State private var sensorPin: Int = 0
    @State private var maxSecForStatus: Int = 30
    @State private var sensorValueAt0PSI: String = "0.228"
    @State private var sensorValueAt50PSI: String = "2.853"
    @State private var measureWait: String = "2.0"
    @State private var precision: String = "1.0"
    @State private var btPinCode: String = "1234"
    @State private var simulationMode: Bool = false
    @State private var pressureCalcMethod: Int = 1

    @State private var hasUnsavedChanges = false
    @State private var showingExitAlert = false
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("General") {
                    TextField("Device Name", text: $deviceName)
                        .onChange(of: deviceName) { _ in hasUnsavedChanges = true }

                    TextField("BT Pin Code", text: $btPinCode)
                        .onChange(of: btPinCode) { _ in hasUnsavedChanges = true }
                }

                Section("WiFi") {
                    TextField("WiFi SSID", text: $wifiSsid)
                        .onChange(of: wifiSsid) { _ in hasUnsavedChanges = true }

                    SecureField("WiFi Password", text: $wifiPassword)
                        .onChange(of: wifiPassword) { _ in hasUnsavedChanges = true }
                }

                Section("Hardware Pins") {
                    Stepper("Compressor Pin: \(relayCompressorPin)", value: $relayCompressorPin, in: 0...40)
                        .onChange(of: relayCompressorPin) { _ in hasUnsavedChanges = true }

                    Stepper("Free Pin: \(relayFreePin)", value: $relayFreePin, in: 0...40)
                        .onChange(of: relayFreePin) { _ in hasUnsavedChanges = true }

                    Stepper("Sensor Pin: \(sensorPin)", value: $sensorPin, in: 0...40)
                        .onChange(of: sensorPin) { _ in hasUnsavedChanges = true }
                }

                Section("Calibration") {
                    HStack {
                        Text("Sensor at 0 PSI:")
                        Spacer()
                        TextField("0.228", text: $sensorValueAt0PSI)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: sensorValueAt0PSI) { _ in hasUnsavedChanges = true }
                    }

                    HStack {
                        Text("Sensor at 50 PSI:")
                        Spacer()
                        TextField("2.853", text: $sensorValueAt50PSI)
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
                        Text("Precision:")
                        Spacer()
                        TextField("1.0", text: $precision)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: precision) { _ in hasUnsavedChanges = true }
                    }

                    Stepper("Max Status Time: \(maxSecForStatus)s", value: $maxSecForStatus, in: 5...120)
                        .onChange(of: maxSecForStatus) { _ in hasUnsavedChanges = true }

                    HStack {
                        Text("Measure Wait:")
                        Spacer()
                        TextField("2.0", text: $measureWait)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: measureWait) { _ in hasUnsavedChanges = true }
                    }

                    Toggle("Simulation Mode", isOn: $simulationMode)
                        .onChange(of: simulationMode) { _ in hasUnsavedChanges = true }
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
                Text("You have unsaved changes that will be lost.")
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Saving & Restarting Device...")
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
        deviceName = s.deviceName
        wifiSsid = s.wifiSsid
        wifiPassword = s.wifiPassword
        relayCompressorPin = s.relayCompressorPin
        relayFreePin = s.relayFreePin
        sensorPin = s.sensorPin
        maxSecForStatus = s.maxSecForStatus
        sensorValueAt0PSI = String(format: "%.3f", s.sensorValueAt0PSI)
        sensorValueAt50PSI = String(format: "%.3f", s.sensorValueAt50PSI)
        measureWait = String(format: "%.1f", s.measureWait)
        precision = String(format: "%.1f", s.precision)
        btPinCode = s.btPinCode
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
        settings.relayCompressorPin = relayCompressorPin
        settings.relayFreePin = relayFreePin
        settings.sensorPin = sensorPin
        settings.maxSecForStatus = maxSecForStatus
        settings.sensorValueAt0PSI = Double(sensorValueAt0PSI) ?? 0.228
        settings.sensorValueAt50PSI = Double(sensorValueAt50PSI) ?? 2.853
        settings.measureWait = Double(measureWait) ?? 2.0
        settings.precision = Double(precision) ?? 1.0
        settings.btPinCode = btPinCode
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
