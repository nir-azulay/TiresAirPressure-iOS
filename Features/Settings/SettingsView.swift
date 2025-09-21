import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var bleManager: BLEManager
    @State private var showingDeviceSettings = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            Form {
                // App Settings Section
                Section(NSLocalizedString("app_settings", comment: "App Settings")) {
                    // Display Mode
                    Picker(NSLocalizedString("display_mode", comment: "Display Mode"), selection: $settingsManager.displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayText).tag(mode)
                        }
                    }

                    // Language
                    Picker(NSLocalizedString("language", comment: "Language"), selection: $settingsManager.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayText).tag(language)
                        }
                    }

                    // Debug Mode Toggle
                    Toggle(NSLocalizedString("debug_mode", comment: "Debug Mode"), isOn: $settingsManager.debugMode)

                    // Simulation Mode Toggle
                    Toggle(NSLocalizedString("simulation_mode", comment: "Simulation Mode"), isOn: $settingsManager.simulationMode)
                        .help(NSLocalizedString("simulation_mode_description", comment: "Simulation mode description"))
                }

                // Preset Pressures Section
                Section(NSLocalizedString("preset_pressures_title", comment: "Preset Pressures")) {
                    PresetPressuresSection()
                }

                // Device Settings Section (only when connected)
                if bleManager.connectionState.isConnected {
                    Section(NSLocalizedString("device_settings", comment: "Device Settings")) {
                        Button(action: { showingDeviceSettings = true }) {
                            HStack {
                                Image(systemName: "gearshape.2")
                                    .foregroundColor(.blue)
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
                                    .foregroundColor(.orange)
                                Text(NSLocalizedString("request_settings", comment: "Request Settings"))
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                // Reset Section
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
        ForEach(Array(settingsManager.presetPressures.enumerated()), id: \.offset) { index, pressure in
            HStack {
                Text(String(format: "%.1f PSI", pressure))
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
                TextField("Pressure (10-80 PSI)", text: $newPressure)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {
                    newPressure = ""
                }
                Button("Add") {
                    addNewPressure()
                }
            } message: {
                Text("Enter a pressure value between 10 and 80 PSI")
            }
        }

        Text("Pressure Count: \(settingsManager.presetPressures.count)/8")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private func addNewPressure() {
        guard let pressure = Double(newPressure),
              pressure >= 10.0 && pressure <= 80.0 else {
            return
        }

        settingsManager.addPresetPressure(pressure)
        newPressure = ""
    }
}

// MARK: - Device Settings View
struct DeviceSettingsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var settings = DeviceSettings()
    @State private var hasUnsavedChanges = false
    @State private var showingExitAlert = false
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("device_settings_title", comment: "Device Settings")) {
                    TextField(NSLocalizedString("device_name", comment: "Device Name"), text: $settings.deviceName)
                        .onChange(of: settings.deviceName) { _ in hasUnsavedChanges = true }

                    Toggle(NSLocalizedString("auto_start", comment: "Auto Start"), isOn: $settings.autoStart)
                        .onChange(of: settings.autoStart) { _ in hasUnsavedChanges = true }
                }

                Section(NSLocalizedString("hardware_settings", comment: "Hardware Settings")) {
                    Stepper(value: $settings.hardwareSettings.relayCompressorPin, in: 1...40) {
                        Text("Compressor Pin: \(settings.hardwareSettings.relayCompressorPin)")
                    }
                    .onChange(of: settings.hardwareSettings.relayCompressorPin) { _ in hasUnsavedChanges = true }

                    Stepper(value: $settings.hardwareSettings.relayFreePin, in: 1...40) {
                        Text("Free Pin: \(settings.hardwareSettings.relayFreePin)")
                    }
                    .onChange(of: settings.hardwareSettings.relayFreePin) { _ in hasUnsavedChanges = true }

                    Stepper(value: $settings.hardwareSettings.sensorPin, in: 1...40) {
                        Text("Sensor Pin: \(settings.hardwareSettings.sensorPin)")
                    }
                    .onChange(of: settings.hardwareSettings.sensorPin) { _ in hasUnsavedChanges = true }
                }

                Section(NSLocalizedString("calibration_settings", comment: "Calibration Settings")) {
                    VStack(alignment: .leading) {
                        Text("Sensor Value at 0 PSI: \(String(format: "%.3f", settings.calibrationSettings.sensorValueAt0PSI))")
                        Slider(value: $settings.calibrationSettings.sensorValueAt0PSI, in: 0.0...5.0, step: 0.001)
                            .onChange(of: settings.calibrationSettings.sensorValueAt0PSI) { _ in hasUnsavedChanges = true }
                    }

                    VStack(alignment: .leading) {
                        Text("Sensor Value at 50 PSI: \(String(format: "%.3f", settings.calibrationSettings.sensorValueAt50PSI))")
                        Slider(value: $settings.calibrationSettings.sensorValueAt50PSI, in: 0.0...5.0, step: 0.001)
                            .onChange(of: settings.calibrationSettings.sensorValueAt50PSI) { _ in hasUnsavedChanges = true }
                    }

                    Picker(NSLocalizedString("pressure_calc_method", comment: "Pressure Calc Method"), selection: $settings.calibrationSettings.pressureCalcMethod) {
                        ForEach(PressureCalcMethod.allCases, id: \.self) { method in
                            Text(method.displayText).tag(method)
                        }
                    }
                    .onChange(of: settings.calibrationSettings.pressureCalcMethod) { _ in hasUnsavedChanges = true }

                    Stepper(value: $settings.calibrationSettings.maxSecForStatus, in: 5...120) {
                        Text("Max Status Time: \(settings.calibrationSettings.maxSecForStatus)s")
                    }
                    .onChange(of: settings.calibrationSettings.maxSecForStatus) { _ in hasUnsavedChanges = true }

                    Stepper(value: $settings.calibrationSettings.measureWaitTime, in: 1...10) {
                        Text("Measure Wait: \(settings.calibrationSettings.measureWaitTime)s")
                    }
                    .onChange(of: settings.calibrationSettings.measureWaitTime) { _ in hasUnsavedChanges = true }
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
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(isSaving)
                }
            }
            .alert(NSLocalizedString("exit_without_save", comment: "Exit Without Saving?"), isPresented: $showingExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button(NSLocalizedString("discard", comment: "Discard"), role: .destructive) {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("unsaved_changes_message", comment: "Unsaved changes message"))
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text(NSLocalizedString("saving_settings", comment: "Saving Settings"))
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
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        if let currentSettings = bleManager.deviceSettings {
            settings = currentSettings
        }
        hasUnsavedChanges = false
    }

    private func saveSettings() {
        isSaving = true
        bleManager.updateSettings(settings)

        // Simulate save delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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