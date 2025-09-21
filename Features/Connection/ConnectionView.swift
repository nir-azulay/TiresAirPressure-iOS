import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Bluetooth status
                BluetoothStatusCard()

                // Scan controls
                ScanControlCard()

                // Device list
                DeviceListSection()

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("scan_devices", comment: "Scan Devices"))
            .alert(NSLocalizedString("bluetooth_required", comment: "Bluetooth Required"),
                   isPresented: $showingPermissionAlert) {
                Button("OK") { }
            } message: {
                Text(NSLocalizedString("bluetooth_required_explanation", comment: "Bluetooth is required"))
            }
        }
        .onChange(of: bleManager.connectionState) { state in
            if state == .bluetoothDisabled {
                showingPermissionAlert = true
            }
        }
    }
}

// MARK: - Bluetooth Status Card
struct BluetoothStatusCard: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        HStack {
            Image(systemName: bluetoothIcon)
                .font(.title2)
                .foregroundColor(bluetoothColor)

            VStack(alignment: .leading) {
                Text("Bluetooth Status")
                    .font(.headline)
                Text(bleManager.connectionState.displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if bleManager.connectionState.isConnected {
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

    private var bluetoothIcon: String {
        switch bleManager.connectionState {
        case .connected:
            return "bluetooth.fill"
        case .scanning:
            return "bluetooth"
        case .bluetoothDisabled:
            return "bluetooth.slash"
        default:
            return "bluetooth"
        }
    }

    private var bluetoothColor: Color {
        switch bleManager.connectionState {
        case .connected:
            return .green
        case .scanning:
            return .blue
        case .bluetoothDisabled:
            return .red
        default:
            return .orange
        }
    }
}

// MARK: - Scan Control Card
struct ScanControlCard: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(spacing: 16) {
            if bleManager.isScanning {
                // Scanning state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text(NSLocalizedString("scanning", comment: "Scanning"))
                        .font(.headline)

                    Button(NSLocalizedString("stop_scan", comment: "Stop Scan")) {
                        bleManager.stopScanning()
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
            } else {
                // Not scanning state
                Button(NSLocalizedString("scan_devices", comment: "Scan Devices")) {
                    bleManager.startScanning()
                }
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(bleManager.connectionState.canScan ? Color.blue : Color.gray)
                .cornerRadius(12)
                .disabled(!bleManager.connectionState.canScan)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Device List Section
struct DeviceListSection: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("available_devices", comment: "Available Devices"))
                    .font(.headline)
                Spacer()
                Text("(\(bleManager.discoveredDevices.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if bleManager.discoveredDevices.isEmpty {
                EmptyDeviceListView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(bleManager.discoveredDevices) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    @EnvironmentObject var bleManager: BLEManager
    let device: BLEDevice

    var body: some View {
        Button(action: { connectToDevice() }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(device.address)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(device.signalStrengthText)
                        .font(.caption2)
                        .foregroundColor(signalColor)
                }

                Spacer()

                VStack {
                    SignalStrengthIndicator(strength: device.signalStrength)

                    if bleManager.connectionState == .connecting &&
                       bleManager.connectedPeripheral?.identifier == device.peripheral.identifier {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .disabled(bleManager.connectionState == .connecting)
    }

    private func connectToDevice() {
        bleManager.connect(to: device)
    }

    private var signalColor: Color {
        switch device.signalStrength {
        case .excellent, .good:
            return .green
        case .fair:
            return .orange
        case .weak, .noSignal:
            return .red
        }
    }
}

// MARK: - Signal Strength Indicator
struct SignalStrengthIndicator: View {
    let strength: SignalStrength

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                Rectangle()
                    .frame(width: 3, height: CGFloat(4 + index * 3))
                    .foregroundColor(barColor(for: index))
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        let strengthLevel = strengthToLevel(strength)
        return index < strengthLevel ? signalColor : Color(.systemGray4)
    }

    private func strengthToLevel(_ strength: SignalStrength) -> Int {
        switch strength {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .weak: return 1
        case .noSignal: return 0
        }
    }

    private var signalColor: Color {
        switch strength {
        case .excellent, .good: return .green
        case .fair: return .orange
        case .weak, .noSignal: return .red
        }
    }
}

// MARK: - Empty Device List View
struct EmptyDeviceListView: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(emptyStateText)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var emptyStateText: String {
        if bleManager.isScanning {
            return NSLocalizedString("scanning_for_devices", comment: "Scanning for devices...")
        } else {
            return NSLocalizedString("no_devices_found_message", comment: "No devices found")
        }
    }
}

#if DEBUG
struct ConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionView()
            .environmentObject(BLEManager())
    }
}
#endif