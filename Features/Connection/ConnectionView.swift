import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    BluetoothStatusCard()
                    ScanControlCard()
                    DeviceListSection()
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(L("scan_devices", comment: "Scan Devices"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.navBarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("close", comment: "Close")) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryLight)
                }
            }
            .alert(L("bluetooth_required", comment: "Bluetooth Required"),
                   isPresented: $showingPermissionAlert) {
                Button("OK") { }
            } message: {
                Text(L("bluetooth_required_explanation", comment: "Bluetooth is required"))
            }
        }
        .onChange(of: bleManager.connectionState) { state in
            if state == .bluetoothDisabled {
                showingPermissionAlert = true
            }
            if state == .connected {
                dismiss()
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
                Text(L("bluetooth_status", comment: ""))
                    .font(.headline)
                Text(bleManager.connectionState.displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if bleManager.connectionState.isConnected {
                Button(L("disconnect_device", comment: "Disconnect")) {
                    bleManager.disconnect()
                }
                .font(.caption)
                .foregroundColor(AppColors.stopRed)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private var bluetoothIcon: String {
        switch bleManager.connectionState {
        case .connected: return "antenna.radiowaves.left.and.right.circle.fill"
        case .scanning: return "antenna.radiowaves.left.and.right"
        case .bluetoothDisabled: return "antenna.radiowaves.left.and.right.slash"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var bluetoothColor: Color {
        switch bleManager.connectionState {
        case .connected: return AppColors.connectedGreen
        case .scanning: return AppColors.scanningBlue
        case .bluetoothDisabled: return AppColors.disconnectedRed
        default: return AppColors.connectingAmber
        }
    }
}

// MARK: - Scan Control Card
struct ScanControlCard: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(spacing: 16) {
            if bleManager.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text(L("scanning", comment: "Scanning"))
                        .font(.headline)

                    Button(L("stop_scan", comment: "Stop Scan")) {
                        bleManager.stopScanning()
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.stopRed)
                    .cornerRadius(12)
                }
            } else {
                Button(L("scan_devices", comment: "Scan Devices")) {
                    bleManager.startScanning()
                }
                .font(.title2.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(bleManager.connectionState.canScan ? AppColors.primary : Color.gray)
                .cornerRadius(12)
                .disabled(!bleManager.connectionState.canScan)
            }
        }
        .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Device List Section
struct DeviceListSection: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("available_devices", comment: "Available Devices"))
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
        Button(action: { bleManager.connect(to: device) }) {
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

                    if bleManager.connectionState == .connecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .disabled(bleManager.connectionState == .connecting)
    }

    private var signalColor: Color {
        switch device.signalStrength {
        case .excellent, .good: return AppColors.connectedGreen
        case .fair: return AppColors.connectingAmber
        case .weak, .noSignal: return AppColors.disconnectedRed
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
        let level = strengthLevel
        return index < level ? signalColor : Color(.systemGray4)
    }

    private var strengthLevel: Int {
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
        case .excellent, .good: return AppColors.connectedGreen
        case .fair: return AppColors.connectingAmber
        case .weak, .noSignal: return AppColors.disconnectedRed
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
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private var emptyStateText: String {
        if bleManager.isScanning {
            return L("scanning_for_devices", comment: "Scanning for devices...")
        } else {
            return L("no_devices_found_message", comment: "No devices found")
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
