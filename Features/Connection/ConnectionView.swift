import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 16) {
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
                    .font(.system(size: 17, weight: .semibold))
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
        .preferredColorScheme(.dark)
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bluetoothColor.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: bluetoothIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(bluetoothColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L("bluetooth_status", comment: ""))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(bleManager.connectionState.displayText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(bluetoothColor)
            }

            Spacer()

            if bleManager.connectionState.isConnected {
                Button(L("disconnect_device", comment: "Disconnect")) {
                    bleManager.disconnect()
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.stopRed)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(14)
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
        VStack(spacing: 14) {
            if bleManager.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                        .scaleEffect(1.2)

                    Text(L("scanning", comment: "Scanning"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Button {
                        bleManager.stopScanning()
                    } label: {
                        Text(L("stop_scan", comment: "Stop Scan").uppercased())
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColors.stopRed)
                            .cornerRadius(12)
                    }
                }
            } else {
                Button {
                    bleManager.startScanning()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .bold))
                        Text(L("scan_devices", comment: "Scan Devices").uppercased())
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        bleManager.connectionState.canScan
                            ? LinearGradient(colors: [AppColors.primary, Color(hex: 0xE65100)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.gray, Color.gray], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(12)
                }
                .disabled(!bleManager.connectionState.canScan)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

// MARK: - Device List Section
struct DeviceListSection: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("available_devices", comment: "Available Devices").uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("(\(bleManager.discoveredDevices.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.primaryLight)
            }

            if bleManager.discoveredDevices.isEmpty {
                EmptyDeviceListView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(bleManager.discoveredDevices) { device in
                            DeviceRow(device: device)
                        }
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Text(device.address)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)

                    Text(device.signalStrengthText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(signalColor)
                }

                Spacer()

                VStack(spacing: 6) {
                    SignalStrengthIndicator(strength: device.signalStrength)

                    if bleManager.connectionState == .connecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.primaryLight)
                    }
                }
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
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
        return index < level ? signalColor : Color.white.opacity(0.2)
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
        VStack(spacing: 14) {
            Image(systemName: bleManager.isScanning ? "antenna.radiowaves.left.and.right" : "magnifyingglass")
                .font(.system(size: 42))
                .foregroundColor(AppColors.primary.opacity(0.8))

            Text(emptyStateText)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding()
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(14)
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
