import SwiftUI

struct AboutView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var connectionDuration: TimeInterval = 0
    @State private var timer: Timer?

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Tire Pressure Manager"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon and Title
                    AppHeaderSection()

                    // Version Information
                    VersionInfoCard()

                    // Developer Information
                    DeveloperInfoCard()

                    // Connection Information
                    if bleManager.connectionState.isConnected {
                        ConnectionInfoCard(duration: connectionDuration)
                    }

                    // System Information
                    SystemInfoCard()

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("about", comment: "About"))
            .onAppear {
                startConnectionTimer()
            }
            .onDisappear {
                stopConnectionTimer()
            }
        }
    }

    private func startConnectionTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateConnectionDuration()
        }
    }

    private func stopConnectionTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateConnectionDuration() {
        // This would need to track connection start time in BLEManager
        // For now, we'll simulate it
        if bleManager.connectionState.isConnected {
            connectionDuration += 1
        } else {
            connectionDuration = 0
        }
    }
}

// MARK: - App Header Section
struct AppHeaderSection: View {
    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "gauge")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }

            VStack(spacing: 4) {
                Text("Tire Pressure Manager")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(NSLocalizedString("app_description", comment: "App description"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Version Info Card
struct VersionInfoCard: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        GroupBox("Version Information") {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "Version", value: appVersion)
                InfoRow(title: "Build", value: buildNumber)
                InfoRow(title: "Platform", value: "iOS")
                InfoRow(title: "Architecture", value: "ARM64")
            }
        }
    }
}

// MARK: - Developer Info Card
struct DeveloperInfoCard: View {
    var body: some View {
        GroupBox(NSLocalizedString("contact_info", comment: "Contact Information")) {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: NSLocalizedString("developed_by", comment: "Developed by"),
                       value: NSLocalizedString("developer_name", comment: "Nir Azulay"))

                HStack {
                    Text("Email:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Button(NSLocalizedString("developer_email", comment: "nir.azulay@gmail.com")) {
                        if let url = URL(string: "mailto:nir.azulay@gmail.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }

                InfoRow(title: "Copyright",
                       value: String(format: NSLocalizedString("copyright_notice", comment: "Copyright"), "Nir Azulay"))
            }
        }
    }
}

// MARK: - Connection Info Card
struct ConnectionInfoCard: View {
    let duration: TimeInterval

    var body: some View {
        GroupBox("Connection Information") {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "Status", value: "Connected")
                InfoRow(title: "Duration", value: formattedDuration)
                InfoRow(title: "Protocol", value: "Bluetooth Low Energy")
                InfoRow(title: "Service", value: "Tire Pressure Monitoring")
            }
        }
    }

    private var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: NSLocalizedString("connected_duration_hours", comment: "Connected duration hours"), hours, minutes)
        } else if minutes > 0 {
            return String(format: NSLocalizedString("connected_duration_minutes", comment: "Connected duration minutes"), minutes, seconds)
        } else {
            return String(format: NSLocalizedString("connected_duration_seconds", comment: "Connected duration seconds"), seconds)
        }
    }
}

// MARK: - System Info Card
struct SystemInfoCard: View {
    var body: some View {
        GroupBox("System Information") {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "iOS Version", value: UIDevice.current.systemVersion)
                InfoRow(title: "Device Model", value: UIDevice.current.model)
                InfoRow(title: "Device Name", value: UIDevice.current.name)

                if let bundleId = Bundle.main.bundleIdentifier {
                    InfoRow(title: "Bundle ID", value: bundleId)
                }

                InfoRow(title: "Min iOS", value: "15.0")
                InfoRow(title: "Bluetooth", value: "BLE 5.0+")
            }
        }
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title + ":")
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .environmentObject(BLEManager())
    }
}
#endif