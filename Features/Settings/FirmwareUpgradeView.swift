import SwiftUI
import UIKit

struct FirmwareUpgradeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var bleManager: BLEManager
    @ObservedObject var upgradeManager = FirmwareUpgradeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isCheckingWiFi = false
    @State private var confirmMode: UpgradeOperationMode?
    @State private var completedSummaryAlert: String?

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        versionComparisonCard
                        wifiConnectionCard
                        progressAndLogsCard
                        actionsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle(L("firmware_upgrade_title", comment: "Firmware & File System"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.navBarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("close", comment: "Close")) {
                        upgradeManager.resetState()
                        dismiss()
                    }
                    .disabled(upgradeManager.upgradeState.isBusy)
                }
            }
            .onAppear {
                if bleManager.deviceSettings == nil && bleManager.connectionState.isConnected {
                    bleManager.requestSettings()
                }
                Task {
                    _ = await upgradeManager.checkReachability()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && !upgradeManager.upgradeState.isBusy {
                    Task {
                        _ = await upgradeManager.checkReachability()
                    }
                }
            }
            .onChange(of: upgradeManager.upgradeState) { newState in
                if case .completed(let summary) = newState {
                    completedSummaryAlert = summary
                }
            }
            .onChange(of: upgradeManager.upgradeState.isBusy) { isBusy in
                // Keep the screen awake while flashing — display sleep
                // mid-upload stalls the transfer (same fix as Android's
                // FLAG_KEEP_SCREEN_ON during upgrades).
                UIApplication.shared.isIdleTimerDisabled = isBusy
            }
            .onDisappear {
                if !upgradeManager.upgradeState.isBusy {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
            .alert(
                L("confirm_upgrade_title", comment: "Start Controller Update?"),
                isPresented: Binding(
                    get: { confirmMode != nil },
                    set: { if !$0 { confirmMode = nil } }
                ),
                presenting: confirmMode
            ) { mode in
                Button(L("cancel", comment: "Cancel"), role: .cancel) {
                    confirmMode = nil
                }
                Button(L("start", comment: "Start")) {
                    let selected = mode
                    confirmMode = nil
                    Task {
                        await upgradeManager.performOperation(selected)
                    }
                }
            } message: { mode in
                Text(confirmationMessage(for: mode))
            }
            .alert(
                L("firmware_upgrade_title", comment: "Firmware & File System"),
                isPresented: Binding(
                    get: { completedSummaryAlert != nil },
                    set: { if !$0 { completedSummaryAlert = nil } }
                )
            ) {
                Button(L("ok", comment: "OK")) {
                    completedSummaryAlert = nil
                    upgradeManager.resetState()
                    dismiss()
                }
            } message: {
                Text(completedSummaryAlert ?? "")
            }
            .alert(
                L("wifi_connected_alert_title", comment: "Wi-Fi Connected"),
                isPresented: Binding(
                    get: { upgradeManager.wifiConnectedAlertHost != nil },
                    set: { if !$0 { upgradeManager.wifiConnectedAlertHost = nil } }
                )
            ) {
                Button(L("ok", comment: "OK")) {
                    upgradeManager.wifiConnectedAlertHost = nil
                }
            } message: {
                Text(String(format: L("wifi_connected_alert_message_format", comment: ""), upgradeManager.wifiConnectedAlertHost ?? ""))
            }
            .alert(
                L("wifi_manual_join_title", comment: "Connect to Controller Wi-Fi"),
                isPresented: Binding(
                    get: { upgradeManager.wifiPromptInfo != nil },
                    set: { if !$0 { upgradeManager.wifiPromptInfo = nil } }
                ),
                presenting: upgradeManager.wifiPromptInfo
            ) { info in
                Button(L("open_wifi_settings_button", comment: "Open Wi-Fi Settings")) {
                    upgradeManager.wifiPromptInfo = nil
                    openSystemWiFiSettings()
                }
                Button(L("check_again_button", comment: "Check Again")) {
                    upgradeManager.wifiPromptInfo = nil
                    Task {
                        _ = await upgradeManager.checkReachability()
                    }
                }
                Button(L("cancel", comment: "Cancel"), role: .cancel) {
                    upgradeManager.wifiPromptInfo = nil
                }
            } message: { info in
                Text(String(format: L("wifi_manual_join_message_format", comment: ""), info.ssid, info.password, info.expectedIP))
            }
        }
    }

    private func openSystemWiFiSettings() {
        if let wifiURL = URL(string: "App-Prefs:root=WIFI"), UIApplication.shared.canOpenURL(wifiURL) {
            UIApplication.shared.open(wifiURL)
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - Version Comparison Card

    private var versionComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.primary)
                Text(L("firmware_version_status", comment: "Firmware Version Status"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                statusBadge
            }

            Divider().background(AppColors.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("installed_on_device", comment: "Installed on Controller"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text(upgradeManager.deviceVersion.isEmpty ? "—" : upgradeManager.deviceVersion)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("bundled_in_app", comment: "Bundled in App"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text(upgradeManager.bundledVersion.isEmpty ? "—" : upgradeManager.bundledVersion)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.primaryLight)
                }
            }

            if let manifest = upgradeManager.manifest {
                HStack(spacing: 16) {
                    Label("\(manifest.firmwareSize / 1024) KB .bin", systemImage: "memorychip")
                    Label("\(manifest.staticFiles.count) Web UI files", systemImage: "doc.on.doc")
                    Label("\(manifest.requiredSettingsKeys.count) JSON keys", systemImage: "slider.horizontal.3")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(upgradeManager.isUpdateAvailable ? AppColors.primary.opacity(0.7) : AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private var statusBadge: some View {
        let isNewer = upgradeManager.isUpdateAvailable
        let text = isNewer
            ? L("update_available_badge", comment: "Update Available")
            : L("up_to_date_badge", comment: "Up to Date")
        let color = isNewer ? AppColors.connectingAmber : AppColors.connectedGreen

        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .cornerRadius(8)
    }

    // MARK: - Wi-Fi Connection Card

    private var wifiConnectionCard: some View {
        let targets = upgradeManager.preferredWiFiTargets()
        let primarySSID = targets.first?.ssid ?? (bleManager.deviceSettings?.deviceName ?? bleManager.connectedDeviceName ?? "esp32-AirUpDownController")
        let isReachable = upgradeManager.reachableHost != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wifi")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isReachable ? AppColors.connectedGreen : AppColors.connectingAmber)
                Text(L("wifi_connection_title", comment: "Controller Wi-Fi Link"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let host = upgradeManager.reachableHost {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text(host)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(AppColors.connectedGreen)
                } else {
                    Text(L("wifi_not_verified", comment: "Not Verified"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Text(String(format: L("wifi_upgrade_instructions_format", comment: ""), primarySSID))
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 10) {
                TextField("192.168.4.1", text: $upgradeManager.customHostIP)
                    .font(.system(size: 14, design: .monospaced))
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .disabled(upgradeManager.upgradeState.isBusy)

                Button {
                    isCheckingWiFi = true
                    Task {
                        await upgradeManager.connectWiFiFromButton()
                        isCheckingWiFi = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isCheckingWiFi {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: isReachable ? "checkmark.circle.fill" : "wifi.circle.fill")
                        }
                        Text(
                            isReachable
                                ? L("wifi_connected_button", comment: "Wi-Fi Connected")
                                : L("connect_wifi_button", comment: "Connect Wi-Fi")
                        )
                        .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(isReachable ? AppColors.connectedGreen : AppColors.primary)
                    .cornerRadius(8)
                }
                .disabled(isCheckingWiFi || upgradeManager.upgradeState.isBusy)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isReachable ? AppColors.connectedGreen.opacity(0.5) : AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(14)
    }

    // MARK: - Progress & Logs Card

    @ViewBuilder
    private var progressAndLogsCard: some View {
        if upgradeManager.upgradeState != .idle || !upgradeManager.stepLogs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if upgradeManager.upgradeState.isBusy {
                        ProgressView()
                            .scaleEffect(0.85)
                            .padding(.trailing, 4)
                    } else if case .completed = upgradeManager.upgradeState {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.connectedGreen)
                    } else if case .failed = upgradeManager.upgradeState {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.stopRed)
                    }

                    Text(stateDescription)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(Int(upgradeManager.overallProgress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.primaryLight)
                }

                ProgressView(value: upgradeManager.overallProgress, total: 1.0)
                    .tint(AppColors.primary)

                if let migration = upgradeManager.lastMigrationResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            String(
                                format: L("settings_migration_summary_format", comment: ""),
                                migration.retainedKeys.count,
                                migration.addedKeys.count,
                                migration.removedKeys.count
                            )
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.connectedGreen)

                        if !migration.addedKeys.isEmpty {
                            Text("+ \(migration.addedKeys.joined(separator: ", "))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.primaryLight)
                        }
                        if !migration.removedKeys.isEmpty {
                            Text("- \(migration.removedKeys.joined(separator: ", "))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.stopRed)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }

                if !upgradeManager.stepLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(upgradeManager.stepLogs.enumerated()), id: \.offset) { _, line in
                            Text("• \(line)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.top, 4)
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

    private var stateDescription: String {
        switch upgradeManager.upgradeState {
        case .idle:
            return L("upgrade_state_ready", comment: "Ready")
        case .connectingWiFi(let ssid):
            return String(format: L("upgrade_state_connecting_wifi_format", comment: ""), ssid)
        case .migratingSettings:
            return L("upgrade_state_migrating_settings", comment: "Migrating settings.json...")
        case .uploadingStaticFiles(let current, let total, let fileName):
            return String(format: L("upgrade_state_uploading_spiffs_format", comment: ""), fileName, current, total)
        case .uploadingFirmware(let progress):
            return String(format: L("upgrade_state_uploading_firmware_format", comment: ""), Int(progress * 100))
        case .rebootingDevice:
            return L("upgrade_state_rebooting", comment: "Rebooting & reconnecting...")
        case .completed(let summary):
            return summary
        case .failed(let error):
            return error
        }
    }

    // MARK: - Separate & Combined Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("upgrade_options_header", comment: "Upgrade & Maintenance Options").uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundColor(AppColors.textSecondary)

            actionButtonCard(
                mode: .fullUpgrade,
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: L("upgrade_option_full_title", comment: "Full Upgrade (Recommended)"),
                subtitle: L("upgrade_option_full_subtitle", comment: "Upgrades firmware.bin, updates all SPIFFS static files, and migrates settings.json while keeping your current values."),
                accentColor: AppColors.primary,
                highlighted: upgradeManager.isUpdateAvailable
            )

            actionButtonCard(
                mode: .firmwareOnly,
                icon: "cpu",
                title: L("upgrade_option_firmware_only_title", comment: "Firmware Only (firmware.bin)"),
                subtitle: L("upgrade_option_firmware_only_subtitle", comment: "Flashes only the ESP32 firmware binary via /doUpdate without modifying SPIFFS files."),
                accentColor: AppColors.inflateBlue,
                highlighted: false
            )

            actionButtonCard(
                mode: .spiffsOnly,
                icon: "folder.fill.badge.gearshape",
                title: L("upgrade_option_spiffs_only_title", comment: "SPIFFS Static Files Only"),
                subtitle: L("upgrade_option_spiffs_only_subtitle", comment: "Uploads all bundled HTML, CSS, and JS Web UI files to SPIFFS without changing firmware or settings.json."),
                accentColor: AppColors.connectingAmber,
                highlighted: false
            )

            actionButtonCard(
                mode: .settingsJsonOnly,
                icon: "doc.badge.gearshape.fill",
                title: L("upgrade_option_settings_only_title", comment: "Fix & Migrate settings.json Only"),
                subtitle: L("upgrade_option_settings_only_subtitle", comment: "Keeps your current device settings while adding missing schema keys and removing deprecated entities."),
                accentColor: AppColors.connectedGreen,
                highlighted: false
            )
        }
    }

    private func actionButtonCard(
        mode: UpgradeOperationMode,
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        highlighted: Bool
    ) -> some View {
        Button {
            confirmMode = mode
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 12)
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highlighted ? accentColor : AppColors.cardBorder, lineWidth: highlighted ? 1.5 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(upgradeManager.upgradeState.isBusy)
        .opacity(upgradeManager.upgradeState.isBusy ? 0.6 : 1.0)
    }

    private func confirmationMessage(for mode: UpgradeOperationMode) -> String {
        switch mode {
        case .fullUpgrade:
            return L("confirm_upgrade_full_message", comment: "")
        case .firmwareOnly:
            return L("confirm_upgrade_firmware_message", comment: "")
        case .spiffsOnly:
            return L("confirm_upgrade_spiffs_message", comment: "")
        case .settingsJsonOnly:
            return L("confirm_upgrade_settings_message", comment: "")
        }
    }
}
