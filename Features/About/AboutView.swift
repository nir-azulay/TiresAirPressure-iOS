import SwiftUI

struct AboutView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var connectionDuration: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // App Header Card
                        VStack(spacing: 16) {
                            Image("ProfileNir")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())

                            Text(L("app_name", comment: ""))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            Text(L("app_description", comment: ""))
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .cornerRadius(12)

                        // Version Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("version", comment: ""))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Text("\(AppConstants.currentVersion) (\(AppConstants.currentBuild))")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                        .cornerRadius(12)

                        // Contact Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("contact_info", comment: ""))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                Text(AppConstants.developerName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                Button(AppConstants.developerEmail) {
                                    if let url = URL(string: "mailto:\(AppConstants.developerEmail)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.primaryLight)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                        .cornerRadius(12)

                        // Connection Info Card
                        if bleManager.connectionState.isConnected {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("connection", comment: ""))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                InfoRowDark(title: "Status", value: "Connected")
                                InfoRowDark(title: "Duration", value: formattedDuration)
                                InfoRowDark(title: "Protocol", value: "Bluetooth Low Energy")
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                        }

                        // System Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("system", comment: ""))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            InfoRowDark(title: "iOS", value: UIDevice.current.systemVersion)
                            InfoRowDark(title: "Model", value: UIDevice.current.model)
                            if let bundleId = Bundle.main.bundleIdentifier {
                                InfoRowDark(title: "Bundle", value: bundleId)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                        .cornerRadius(12)

                        // Copyright
                        Text("2025 \(AppConstants.developerName). All rights reserved.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.vertical, 16)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle(L("about", comment: "About"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(AppColors.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { startConnectionTimer() }
            .onDisappear { stopConnectionTimer() }
        }
    }

    private var formattedDuration: String {
        let hours = Int(connectionDuration) / 3600
        let minutes = (Int(connectionDuration) % 3600) / 60
        let seconds = Int(connectionDuration) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private func startConnectionTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if bleManager.connectionState.isConnected {
                    connectionDuration += 1
                } else {
                    connectionDuration = 0
                }
            }
        }
    }

    private func stopConnectionTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct InfoRowDark: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title + ":")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
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
