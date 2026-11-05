import SwiftUI
import UIKit
import Combine

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var upgradeManager = FirmwareUpgradeManager.shared
    @State private var targetPressure: Double = 30.0
    @State private var showTargetReachedAlert = false
    @State private var targetReachedInfo: (target: Double, current: Double)?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isInflating = false
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showConnection = false
    @State private var showDeviceManagement = false
    @State private var showFirmwareUpgrade = false
    @State private var animatedPressure: Double = 0.0
    @State private var accessCodeInput: String = ""

    private let minPressure: Double = 5.0
    private let maxPressure: Double = 40.0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        if bleManager.connectionState.isConnected {
                            ConnectionStatusCard()
                            if upgradeManager.shouldSuggestUpdate {
                                FirmwareUpdateSuggestionBanner(
                                    deviceVersion: upgradeManager.deviceVersion,
                                    bundledVersion: upgradeManager.bundledVersion,
                                    onUpgrade: { showFirmwareUpgrade = true },
                                    onDismiss: { upgradeManager.dismissUpdateSuggestion() }
                                )
                            }
                            PressureGaugeCard(
                                currentPressure: animatedPressure,
                                targetPressure: targetPressure,
                                maxPressure: maxPressure,
                                isInflating: isInflating,
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
                                selectedPressure: targetPressure,
                                onSelect: { preset in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        targetPressure = preset
                                    }
                                }
                            )
                            InflationControlButton(
                                isInflating: isInflating,
                                currentPressure: animatedPressure,
                                targetPressure: targetPressure,
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
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.primary)
                        Text(L("app_name", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Button {
                        isInflating = false
                        bleManager.disconnect()
                        showConnection = true
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .toolbarBackground(AppColors.navBarBackground, for: .navigationBar)
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
            .sheet(isPresented: $showFirmwareUpgrade) {
                FirmwareUpgradeView()
            }
        }
        .onAppear {
            bleManager.targetReachedSubject
                .receive(on: DispatchQueue.main)
                .sink { info in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        .overlay {
            if showTargetReachedAlert, let info = targetReachedInfo {
                TargetReachedCelebrationView(
                    targetPressure: info.target,
                    currentPressure: info.current,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showTargetReachedAlert = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    private func toggleInflation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
struct FirmwareUpdateSuggestionBanner: View {
    let deviceVersion: String
    let bundledVersion: String
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.primaryLight)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("firmware_update_available_title", comment: "Controller Firmware Update Available"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text(String(format: L("firmware_update_available_message_format", comment: ""), deviceVersion, bundledVersion))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(6)
                }
            }

            HStack(spacing: 10) {
                Button(action: onUpgrade) {
                    Text(L("upgrade_now_button", comment: "Upgrade Now"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(8)
                }

                Button(action: onDismiss) {
                    Text(L("later_button", comment: "Later"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(14)
        .background(AppColors.primary.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.primary.opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct ConnectionStatusCard: View {
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .shadow(color: connectionColor.opacity(0.8), radius: 4)

            Image(systemName: connectionIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(connectionColor)

            Text(bleManager.connectionState.displayText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(connectionColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let name = bleManager.connectedDeviceName, bleManager.connectionState == .connected {
                Text("• \(name)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(connectionColor.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(connectionColor.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var connectionIcon: String {
        switch bleManager.connectionState {
        case .connected: return "antenna.radiowaves.left.and.right"
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

// MARK: - Automotive Speedometer Pressure Gauge Card
struct PressureGaugeCard: View {
    let currentPressure: Double
    let targetPressure: Double
    let maxPressure: Double
    let isInflating: Bool
    let debugMode: Bool
    let deviceStatus: DeviceStatus?

    /// Width of this card. The dial and readout scale down on a narrow phone
    /// (iPhone 17 Pro, Display Zoom) and stay at the designed size on Pro Max.
    @State private var cardWidth: CGFloat = 0

    private var gaugeSize: CGFloat {
        let width = cardWidth > 0 ? cardWidth : 360
        return min(144, max(108, width * 0.40))
    }

    private var typeScale: CGFloat { gaugeSize / 144 }

    private var activeAccentColor: Color {
        if !isInflating {
            if abs(currentPressure - targetPressure) <= 0.5 && currentPressure > 0 {
                return AppColors.connectedGreen
            }
            return AppColors.primary
        }
        return currentPressure <= targetPressure ? AppColors.inflateBlue : AppColors.deflateRed
    }

    var body: some View {
        let gauge = gaugeSize
        let scale = typeScale

        HStack(spacing: 8) {
            // Left side - Live Readout & Delta
            VStack(alignment: .leading, spacing: 6) {
                Text(L("current_pressure", comment: "").uppercased())
                    .font(.system(size: 11 * scale, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", currentPressure))
                        .font(.system(size: 46 * scale, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("PSI")
                        .font(.system(size: 15 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(activeAccentColor)
                        .lineLimit(1)
                }

                // Delta pill
                let delta = targetPressure - currentPressure
                HStack(spacing: 4) {
                    Image(systemName: abs(delta) <= 0.5 ? "checkmark.circle.fill" : (delta > 0 ? "arrow.up.right" : "arrow.down.right"))
                        .font(.system(size: 11 * scale, weight: .bold))
                    Text(abs(delta) <= 0.5 ? L("at_target", comment: "") : String(format: L("psi_to_target_format", comment: ""), delta))
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(abs(delta) <= 0.5 ? AppColors.connectedGreen : (delta > 0 ? AppColors.inflateBlue : AppColors.primaryLight))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)

                if debugMode, let status = deviceStatus,
                   status.rawADC != nil || status.voltage != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if let rawADC = status.rawADC {
                            Text("ADC: \(rawADC)")
                                .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.debugYellow)
                        }
                        if let voltage = status.voltage {
                            Text(String(format: "V: %.3f V", voltage))
                                .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.debugYellow)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .padding(.vertical, 12)

            // Right side - 270° Speedometer Dial
            ZStack {
                let progress = min(max(currentPressure / maxPressure, 0), 1)
                let targetProgress = min(max(targetPressure / maxPressure, 0), 1)

                // Outer tick marks (270 degrees arc)
                ForEach(0..<21, id: \.self) { tick in
                    let isMajor = tick % 5 == 0
                    Rectangle()
                        .fill(Double(tick) / 20.0 <= progress ? activeAccentColor : Color.white.opacity(isMajor ? 0.35 : 0.15))
                        .frame(width: (isMajor ? 2.5 : 1.5) * scale, height: (isMajor ? 8 : 5) * scale)
                        .offset(y: -64 * scale)
                        .rotationEffect(.degrees(-135 + Double(tick) * 13.5))
                }

                // Background 270° Track
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Target pressure inner 270° arc
                Circle()
                    .trim(from: 0, to: targetProgress * 0.75)
                    .stroke(AppColors.primaryLight.opacity(0.45), style: StrokeStyle(lineWidth: 6 * scale, lineCap: .round))
                    .padding(11 * scale)
                    .rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 0.25), value: targetPressure)

                // Current pressure glowing 270° arc
                Circle()
                    .trim(from: 0, to: progress * 0.75)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [AppColors.inflateBlue, activeAccentColor]),
                            center: .center,
                            startAngle: .degrees(135),
                            endAngle: .degrees(405)
                        ),
                        style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .shadow(color: activeAccentColor.opacity(0.5), radius: 6)
                    .animation(.easeInOut(duration: 0.5), value: currentPressure)

                // Center Target Display
                VStack(spacing: 2) {
                    Text(L("target_short", comment: ""))
                        .font(.system(size: 10 * scale, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(String(format: "%.1f", targetPressure))
                        .font(.system(size: 24 * scale, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.primaryLight)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("PSI")
                        .font(.system(size: 10 * scale, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(width: gauge, height: gauge)
            .padding(8)
        }
        .padding(12)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CardWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(CardWidthKey.self) { cardWidth = $0 }
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.4), radius: 8, y: 4)
    }
}

// MARK: - Target Pressure Card
struct TargetPressureCard: View {
    @Binding var targetPressure: Double
    let minPressure: Double
    let maxPressure: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L("target_pressure", comment: "").uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(Int(minPressure))–\(Int(maxPressure)) PSI")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 16) {
                Button {
                    if targetPressure > minPressure {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        targetPressure -= 0.5
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.presetButtonBg)
                        .overlay(
                            Circle().stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .clipShape(Circle())
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", targetPressure))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.primaryLight)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("PSI")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer()

                Button {
                    if targetPressure < maxPressure {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        targetPressure += 0.5
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 4, y: 2)
                }
            }

            Slider(
                value: $targetPressure,
                in: minPressure...maxPressure,
                step: 0.5
            )
            .tint(AppColors.primary)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
    }
}

// MARK: - Preset Buttons (4 per row, with active highlight)
struct PresetButtons: View {
    let pressures: [Double]
    let selectedPressure: Double
    let onSelect: (Double) -> Void

    var body: some View {
        if !pressures.isEmpty {
            let rows = pressures.chunked(into: 4)
            VStack(spacing: 8) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { colIndex in
                            if colIndex < rows[rowIndex].count {
                                let pressure = rows[rowIndex][colIndex]
                                let isSelected = abs(pressure - selectedPressure) < 0.05
                                Button {
                                    onSelect(pressure)
                                } label: {
                                    VStack(spacing: 1) {
                                        Text(String(format: "%.0f", pressure))
                                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                        Text("PSI")
                                            .font(.system(size: 10, weight: .bold))
                                            .opacity(0.8)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .foregroundColor(isSelected ? AppColors.presetButtonActiveText : AppColors.presetButtonText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        isSelected
                                            ? AppColors.presetButtonActiveBg
                                            : AppColors.cardBackground
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                isSelected ? AppColors.primaryLight : AppColors.cardBorder,
                                                lineWidth: isSelected ? 1.5 : 1
                                            )
                                    )
                                    .cornerRadius(12)
                                    .shadow(
                                        color: isSelected ? AppColors.primary.opacity(0.4) : .clear,
                                        radius: 6,
                                        y: 2
                                    )
                                }
                            } else {
                                Spacer().frame(maxWidth: .infinity, minHeight: 52)
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
    let currentPressure: Double
    let targetPressure: Double
    let onToggle: () -> Void

    private var isDeflateAction: Bool {
        currentPressure > targetPressure + 0.5
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isInflating ? "stop.fill" : (isDeflateAction ? "arrow.down.circle.fill" : "arrow.up.circle.fill"))
                    .font(.system(size: 22, weight: .bold))
                Text(isInflating
                     ? L("stop", comment: "").uppercased()
                     : L("start", comment: "").uppercased())
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .tracking(1.0)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(
                    colors: isInflating
                        ? [AppColors.stopRed, Color(hex: 0xB71C1C)]
                        : [AppColors.primary, Color(hex: 0xE65100)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(
                color: (isInflating ? AppColors.stopRed : AppColors.primary).opacity(0.45),
                radius: 8,
                y: 4
            )
        }
        .padding(.top, 4)
    }
}

// MARK: - Inflation Status Indicator Banner
struct InflationStatusIndicator: View {
    let isInflating: Bool
    let currentPressure: Double
    let targetPressure: Double
    @State private var pulse: Bool = false

    private var isDeflating: Bool {
        currentPressure > targetPressure
    }

    private var accentColor: Color {
        isDeflating ? AppColors.deflateRed : AppColors.inflateBlue
    }

    var body: some View {
        if isInflating {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 34, height: 34)
                        .scaleEffect(pulse ? 1.2 : 0.9)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulse
                        )
                    Image(systemName: isDeflating ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(accentColor)
                }
                .onAppear { pulse = true }
                .onDisappear { pulse = false }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isDeflating
                         ? L("mode_deflating", comment: "")
                         : L("mode_inflating", comment: ""))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    let remaining = abs(targetPressure - currentPressure)
                    Text(String(format: L("psi_remaining_to_target_format", comment: ""), remaining, targetPressure))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(accentColor.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accentColor.opacity(0.45), lineWidth: 1)
            )
            .cornerRadius(14)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

// MARK: - Not Connected View
struct NotConnectedView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var showConnection: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle().stroke(AppColors.cardBorder, lineWidth: 1.5)
                    )

                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }

            VStack(spacing: 8) {
                Text(L("not_connected", comment: ""))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(L("connect_to_device_hint", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                bleManager.startScanning()
                showConnection = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .bold))
                    Text(L("scan_devices", comment: "").uppercased())
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, Color(hex: 0xE65100)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: AppColors.primary.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Target Reached Celebration Overlay
struct TargetReachedCelebrationView: View {
    let targetPressure: Double
    let currentPressure: Double
    let onDismiss: () -> Void

    @State private var cardScale: CGFloat = 0.6
    @State private var cardOpacity: Double = 0.0
    @State private var badgeScale: CGFloat = 0.2
    @State private var ringScale1: CGFloat = 0.6
    @State private var ringOpacity1: Double = 0.9
    @State private var ringScale2: CGFloat = 0.6
    @State private var ringOpacity2: Double = 0.7
    @State private var particlesExpanded: Bool = false
    @State private var glowPulse: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Expanding shockwave rings & radial burst particles
            ZStack {
                Circle()
                    .stroke(AppColors.connectedGreen, lineWidth: 3)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ringScale1)
                    .opacity(ringOpacity1)

                Circle()
                    .stroke(AppColors.primary, lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ringScale2)
                    .opacity(ringOpacity2)

                ForEach(0..<12, id: \.self) { index in
                    let angle = Double(index) * 30.0
                    Circle()
                        .fill(index % 2 == 0 ? AppColors.connectedGreen : AppColors.primaryLight)
                        .frame(width: index % 3 == 0 ? 8 : 5, height: index % 3 == 0 ? 8 : 5)
                        .offset(y: particlesExpanded ? -135 : -30)
                        .opacity(particlesExpanded ? 0.0 : 1.0)
                        .rotationEffect(.degrees(angle))
                }
            }
            .offset(y: -70)

            // Celebration Card
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppColors.connectedGreen.opacity(0.18))
                        .frame(width: 96, height: 96)
                        .scaleEffect(glowPulse ? 1.12 : 0.96)

                    Circle()
                        .stroke(AppColors.connectedGreen, lineWidth: 3)
                        .frame(width: 82, height: 82)
                        .shadow(color: AppColors.connectedGreen.opacity(0.8), radius: 10)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(AppColors.connectedGreen)
                }
                .scaleEffect(badgeScale)
                .padding(.top, 6)

                VStack(spacing: 6) {
                    Text(L("target_reached_title", comment: "").uppercased())
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(L("target_reached_message", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Achieved Pressure Display
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", currentPressure))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.connectedGreen)
                        .monospacedDigit()

                    Text("PSI")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primaryLight)
                }
                .padding(.vertical, 4)

                // Target vs Current comparison pill
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(L("target_short", comment: ""))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(String(format: "%.1f PSI", targetPressure))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.primaryLight)
                    }
                    Divider()
                        .frame(height: 28)
                        .background(AppColors.cardBorder)
                    VStack(spacing: 2) {
                        Text(L("current_short", comment: ""))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(String(format: "%.1f PSI", currentPressure))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.connectedGreen)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                }) {
                    Text(L("ok", comment: "OK").uppercased())
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [AppColors.connectedGreen, Color(hex: 0x059669)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: AppColors.connectedGreen.opacity(0.45), radius: 8, y: 4)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppColors.connectedGreen.opacity(0.7), lineWidth: 1.5)
            )
            .cornerRadius(22)
            .shadow(color: AppColors.connectedGreen.opacity(0.25), radius: 24, y: 8)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) {
                badgeScale = 1.0
            }
            withAnimation(.easeOut(duration: 1.1)) {
                ringScale1 = 2.4
                ringOpacity1 = 0.0
                particlesExpanded = true
            }
            withAnimation(.easeOut(duration: 1.3).delay(0.15)) {
                ringScale2 = 2.1
                ringOpacity2 = 0.0
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Card width

private struct CardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
