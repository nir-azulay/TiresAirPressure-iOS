import SwiftUI

struct MainView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var targetPressure: Double = 32.0
    @State private var showTargetReachedAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection Status Card
                    ConnectionStatusCard()

                    if bleManager.connectionState.isConnected {
                        // Main pressure display
                        PressureDisplayCard(
                            currentPressure: bleManager.deviceStatus?.currentPressure ?? 0.0,
                            targetPressure: targetPressure
                        )

                        // Target pressure controls
                        TargetPressureCard(targetPressure: $targetPressure)

                        // Control buttons
                        ControlButtonsCard(
                            targetPressure: targetPressure,
                            isOperating: bleManager.deviceStatus?.isOperating ?? false
                        )

                        // Preset pressures
                        PresetPressuresCard(targetPressure: $targetPressure)

                        // Device info
                        if let status = bleManager.deviceStatus {
                            DeviceInfoCard(status: status)
                        }
                    } else {
                        // Not connected state
                        NotConnectedCard()
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("tire_pressure", comment: "Tire Pressure"))
            .refreshable {
                if bleManager.connectionState.isConnected {
                    bleManager.requestStatus()
                }
            }
        }
        .onReceive(bleManager.$deviceStatus) { status in
            checkTargetReached(status: status)
        }
        .alert(NSLocalizedString("target_reached_title", comment: "Target Reached"),
               isPresented: $showTargetReachedAlert) {
            Button("OK") { }
        } message: {
            Text(NSLocalizedString("target_reached_message", comment: "Target pressure reached"))
        }
    }

    private func checkTargetReached(status: DeviceStatus?) {
        guard let status = status,
              let target = status.targetPressure,
              !status.isOperating,
              abs(status.currentPressure - target) <= 0.5 else {
            return
        }

        showTargetReachedAlert = true
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        HStack {
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(bleManager.connectionState.displayText)
                    .font(.headline)
                    .foregroundColor(connectionColor)

                if let deviceName = bleManager.connectedDeviceName {
                    Text(deviceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if bleManager.connectionState == .connected {
                Button(NSLocalizedString("disconnect_device", comment: "Disconnect")) {
                    bleManager.disconnect()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var connectionIcon: String {
        switch bleManager.connectionState {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "antenna.radiowaves.left.and.right"
        case .scanning:
            return "magnifyingglass"
        case .bluetoothDisabled:
            return "bluetooth.slash"
        default:
            return "exclamationmark.triangle"
        }
    }

    private var connectionColor: Color {
        switch bleManager.connectionState {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Pressure Display Card
struct PressureDisplayCard: View {
    let currentPressure: Double
    let targetPressure: Double

    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("current_pressure", comment: "Current Pressure"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(String(format: "%.1f", currentPressure))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("PSI")
                .font(.title2)
                .foregroundColor(.secondary)

            if targetPressure > 0 {
                Divider()

                HStack {
                    Text(NSLocalizedString("target_pressure", comment: "Target Pressure"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f PSI", targetPressure))
                        .fontWeight(.medium)
                }

                let difference = currentPressure - targetPressure
                HStack {
                    Text(NSLocalizedString("pressure_difference", comment: "Difference"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%+.1f PSI", difference))
                        .fontWeight(.medium)
                        .foregroundColor(difference > 0.5 ? .red : difference < -0.5 ? .orange : .green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// MARK: - Target Pressure Card
struct TargetPressureCard: View {
    @Binding var targetPressure: Double

    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("target_pressure", comment: "Target Pressure"))
                .font(.headline)

            HStack(spacing: 20) {
                Button(action: { decreaseTarget() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                }
                .disabled(targetPressure <= 10)

                Text(String(format: "%.1f PSI", targetPressure))
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(minWidth: 100)

                Button(action: { increaseTarget() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .disabled(targetPressure >= 80)
            }

            Slider(value: $targetPressure, in: 10...80, step: 0.5)
                .accentColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func increaseTarget() {
        targetPressure = min(80, targetPressure + 0.5)
    }

    private func decreaseTarget() {
        targetPressure = max(10, targetPressure - 0.5)
    }
}

// MARK: - Control Buttons Card
struct ControlButtonsCard: View {
    @EnvironmentObject var bleManager: BLEManager
    let targetPressure: Double
    let isOperating: Bool

    var body: some View {
        VStack(spacing: 16) {
            if isOperating {
                // Stop button when operating
                Button(action: { bleManager.stopOperation() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text(NSLocalizedString("stop", comment: "Stop"))
                    }
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
            } else {
                // Control buttons when idle
                HStack(spacing: 16) {
                    Button(action: { bleManager.startInflation(targetPressure: targetPressure) }) {
                        VStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.largeTitle)
                            Text(NSLocalizedString("increase_pressure", comment: "Increase"))
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    Button(action: { bleManager.startDeflation(targetPressure: targetPressure) }) {
                        VStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.largeTitle)
                            Text(NSLocalizedString("decrease_pressure", comment: "Decrease"))
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Preset Pressures Card
struct PresetPressuresCard: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var targetPressure: Double

    var body: some View {
        if !settingsManager.presetPressures.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preset_pressures", comment: "Preset Pressures"))
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(settingsManager.presetPressures, id: \.self) { pressure in
                        Button(action: { targetPressure = pressure }) {
                            Text(String(format: "%.0f", pressure))
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(targetPressure == pressure ? .white : .blue)
                                .frame(height: 44)
                                .frame(maxWidth: .infinity)
                                .background(targetPressure == pressure ? Color.blue : Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
    }
}

// MARK: - Device Info Card
struct DeviceInfoCard: View {
    let status: DeviceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device Information")
                .font(.headline)

            if let batteryLevel = status.batteryLevel {
                HStack {
                    Image(systemName: "battery.100")
                        .foregroundColor(.green)
                    Text("Battery: \(batteryLevel)%")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Last Update: \(formatTimestamp(status.timestamp))")
                    .foregroundColor(.secondary)
                Spacer()
            }

            if !status.operationMode.displayText.isEmpty {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.orange)
                    Text(status.operationMode.displayText)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Not Connected Card
struct NotConnectedCard: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bluetooth.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text(NSLocalizedString("not_connected", comment: "Not Connected"))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Connect to a device in the Connection tab to start monitoring tire pressure.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}