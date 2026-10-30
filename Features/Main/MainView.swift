import SwiftUI
import UIKit
import Combine

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var targetPressure: Double = 30.0
    @State private var showTargetReachedAlert = false
    @State private var targetReachedInfo: (target: Double, current: Double)?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isInflating = false
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showConnection = false
    @State private var showDeviceManagement = false
    @State private var animatedPressure: Double = 0.0
    @State private var accessCodeInput: String = ""

    private let minPressure: Double = 5.0
    private let maxPressure: Double = 40.0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        if bleManager.connectionState.isConnected {
                            ConnectionStatusCard()
                            PressureGaugeCard(
                                currentPressure: animatedPressure,
                                targetPressure: targetPressure,
                                maxPressure: maxPressure,
                                debugMode: settingsManager.debugMode,
                                deviceStatus: bleManager.deviceStatus
                            )
                            TargetPressureCard(
                                targetPressure: $targetPressure,
                                minPressure: minPressure,
                                maxPressure: maxPressure
                            )
                            PresetButtons(
                                pressures: settingsManager.presetPressures,
                                onSelect: { targetPressure = $0 }
                            )
                            InflationControlButton(
                                isInflating: isInflating,
                                onToggle: toggleInflation
                            )
                            InflationStatusIndicator(
                                isInflating: isInflating,
                                currentPressure: animatedPressure,
                                targetPressure: targetPressure
                            )
                        } else {
                            NotConnectedView(showConnection: $showConnection)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L("app_name", comment: ""))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                    Button {
                        isInflating = false
                        bleManager.disconnect()
                        showConnection = true
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(.white)
                    }
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(AppColors.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showConnection) {
                ConnectionView()
            }
        }
        .onAppear {
            bleManager.targetReachedSubject
                .receive(on: DispatchQueue.main)
                .sink { info in
                    targetReachedInfo = info
                    isInflating = false
                    showTargetReachedAlert = true
                }
                .store(in: &cancellables)
        }
        .onChange(of: bleManager.deviceStatus?.pressure) { newPressure in
            if let p = newPressure {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedPressure = p
                }
            }
        }
        .onChange(of: bleManager.deviceStatus?.operationMode) { mode in
            guard let mode = mode else { return }
            switch mode {
            case DeviceStatus.modeStop:
                isInflating = false
            case DeviceStatus.modeInflate, DeviceStatus.modeDeflate:
                isInflating = true
            default:
                break
            }
        }
        .onChange(of: bleManager.connectionState) { state in
            if state == .disconnected {
                isInflating = false
            }
        }
        .onChange(of: isInflating) { inflating in
            setKeepScreenOn(inflating)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                setKeepScreenOn(isInflating)
            }
        }
        .onDisappear {
            setKeepScreenOn(false)
        }
        .alert(
            L("access_code_title", comment: "Access code"),
            isPresented: Binding(
                get: { bleManager.accessCodeRequired },
                set: { bleManager.accessCodeRequired = $0 }
            )
        ) {
            SecureField(L("access_code_title", comment: "Access code"), text: $accessCodeInput)
            Button(L("ok", comment: "OK")) {
                bleManager.submitAccessCode(accessCodeInput)
                accessCodeInput = ""
            }
            Button(L("cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(L("access_code_message", comment: "Enter the access code from the controller configuration page."))
        }
        .alert(
            L("target_reached_title", comment: ""),
            isPresented: $showTargetReachedAlert
        ) {
            Button("OK") { }
        } message: {
            if let info = targetReachedInfo {
                Text("""
                \(L("target_reached_message", comment: ""))
                Target: \(String(format: "%.1f", info.target)) PSI
                Current: \(String(format: "%.1f", info.current)) PSI
                """)
            }
        }
    }

    private func toggleInflation() {
        if isInflating {
            bleManager.stopOperation()
            isInflating = false
        } else {
            bleManager.startInflation(targetPressure: targetPressure)
            isInflating = true
        }
    }

    /// Prevents auto-lock while the compressor is inflating or deflating.
    private func setKeepScreenOn(_ keepOn: Bool) {
        UIApplication.shared.isIdleTimerDisabled = keepOn
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            Image(systemName: connectionIcon)
                .font(.system(size: 16))
                .foregroundColor(connectionColor)

            Text(bleManager.connectionState.displayText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(connectionColor)

            if let name = bleManager.connectedDeviceName, bleManager.connectionState == .connected {
                Text("(\(name))")
                    .font(.system(size: 14))
                    .foregroundColor(connectionColor)
            }
            Spacer()
        }
        .padding(8)
        .background(connectionColor.opacity(0.2))
        .cornerRadius(8)
    }

    private var connectionIcon: String {
        switch bleManager.connectionState {
        case .connected: return "antenna.radiowaves.left.and.right.circle.fill"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .scanning: return "magnifyingglass"
        case .bluetoothDisabled: return "antenna.radiowaves.left.and.right.slash"
        default: return "exclamationmark.triangle"
        }
    }

    private var connectionColor: Color {
        switch bleManager.connectionState {
        case .connected: return AppColors.connectedGreen
        case .connecting: return AppColors.connectingAmber
        case .scanning: return AppColors.scanningBlue
        default: return AppColors.disconnectedRed
        }
    }
}

// MARK: - Pressure Gauge Card (matching Android layout)
struct PressureGaugeCard: View {
    let currentPressure: Double
    let targetPressure: Double
    let maxPressure: Double
    let debugMode: Bool
    let deviceStatus: DeviceStatus?

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Current Pressure text
            VStack(spacing: 4) {
                Text(L("current_pressure", comment: ""))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)

                Text(String(format: "%.1f", currentPressure))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("PSI")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                if debugMode, let status = deviceStatus,
                   status.rawADC != nil || status.voltage != nil {
                    Spacer().frame(height: 8)
                    if let rawADC = status.rawADC {
                        Text("rawADC: \(rawADC)")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                    if let voltage = status.voltage {
                        Text("voltage: \(String(format: "%.3f", voltage)) V")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            // Right side - Circular Gauge
            ZStack {
                let progress = min(max(currentPressure / maxPressure, 0), 1)
                let targetProgress = min(max(targetPressure / maxPressure, 0), 1)

                // Track
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 16)

                // Current pressure arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: currentPressure)

                // Target pressure arc (inner)
                Circle()
                    .trim(from: 0, to: targetProgress)
                    .stroke(AppColors.primaryLight, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .padding(8)
                    .rotationEffect(.degrees(-90))

                // Target text in center
                Text(String(format: "%.1f", targetPressure))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Target Pressure Card
struct TargetPressureCard: View {
    @Binding var targetPressure: Double
    let minPressure: Double
    let maxPressure: Double

    var body: some View {
        VStack(spacing: 8) {
            Text(L("target_pressure", comment: ""))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Slider(
                value: $targetPressure,
                in: minPressure...maxPressure,
                step: 0.5
            )
            .tint(AppColors.primaryLight)

            HStack {
                Button {
                    if targetPressure > minPressure { targetPressure -= 0.5 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(AppColors.primaryLight)
                        .clipShape(Circle())
                }

                Spacer()

                Text(String(format: "%.1f PSI", targetPressure))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    if targetPressure < maxPressure { targetPressure += 0.5 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(AppColors.primaryLight)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Preset Buttons (4 per row, matching Android)
struct PresetButtons: View {
    let pressures: [Double]
    let onSelect: (Double) -> Void

    var body: some View {
        if !pressures.isEmpty {
            let rows = pressures.chunked(into: 4)
            VStack(spacing: 4) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { colIndex in
                            if colIndex < rows[rowIndex].count {
                                let pressure = rows[rowIndex][colIndex]
                                Button {
                                    onSelect(pressure)
                                } label: {
                                    Text(String(format: "%.0f PSI", pressure))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AppColors.presetButtonText)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(AppColors.presetButtonBg)
                                        .cornerRadius(4)
                                }
                            } else {
                                Spacer().frame(maxWidth: .infinity, minHeight: 48)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Inflation Control Button
struct InflationControlButton: View {
    let isInflating: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isInflating ? "stop.fill" : "play.fill")
                    .font(.system(size: 20))
                Text(isInflating
                     ? L("stop", comment: "")
                     : L("start", comment: ""))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isInflating ? AppColors.stopRed : AppColors.buttonBlue)
            .cornerRadius(28)
        }
    }
}

// MARK: - Inflation Status Indicator
struct InflationStatusIndicator: View {
    let isInflating: Bool
    let currentPressure: Double
    let targetPressure: Double
    @State private var dotScale: CGFloat = 0.8

    var body: some View {
        if isInflating {
            HStack(spacing: 8) {
                Spacer()
                Circle()
                    .fill(AppColors.errorRed)
                    .frame(width: 12, height: 12)
                    .scaleEffect(dotScale)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: dotScale
                    )
                    .onAppear { dotScale = 1.2 }
                    .onDisappear { dotScale = 0.8 }

                Text(currentPressure > targetPressure
                     ? L("mode_deflating", comment: "")
                     : L("mode_inflating", comment: ""))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.errorRed)
                Spacer()
            }
            .frame(height: 48)
            .transition(.opacity)
        }
    }
}

// MARK: - Not Connected View
struct NotConnectedView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var showConnection: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 80))
                .foregroundColor(Color.gray.opacity(0.5))

            Text(L("not_connected", comment: ""))
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.gray)

            Text(L("connect_to_device_hint", comment: ""))
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                bleManager.startScanning()
                showConnection = true
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text(L("scan_devices", comment: ""))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.primary)
                .cornerRadius(25)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Array chunking helper
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
