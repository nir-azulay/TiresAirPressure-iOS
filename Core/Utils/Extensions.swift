import Foundation
import SwiftUI
import CoreBluetooth

// MARK: - Double Extensions
extension Double {
    var formattedPressure: String {
        String(format: "%.1f PSI", self)
    }

    var isValidPressure: Bool {
        self >= 1.0 && self <= 80.0
    }
}

// MARK: - String Extensions
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localized(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBlue = AppColors.primary
    static let secondaryOrange = AppColors.connectingAmber
    static let successGreen = AppColors.connectedGreen
    static let warningRed = AppColors.disconnectedRed

    static func statusColor(for state: ConnectionState) -> Color {
        switch state {
        case .connected: return AppColors.connectedGreen
        case .connecting, .scanning: return AppColors.connectingAmber
        case .bluetoothDisabled, .connectionError: return AppColors.disconnectedRed
        case .disconnected: return .gray
        }
    }

    static func signalColor(for strength: SignalStrength) -> Color {
        switch strength {
        case .excellent, .good: return AppColors.connectedGreen
        case .fair: return AppColors.connectingAmber
        case .weak, .noSignal: return AppColors.disconnectedRed
        }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    func hideKeyboard() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Bundle Extensions
extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var displayName: String {
        infoDictionary?["CFBundleDisplayName"] as? String ?? "TirePressureManager"
    }

    var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }
}

// MARK: - CBPeripheral Extensions
extension CBPeripheral {
    var displayName: String {
        name ?? "unknown_device".localized
    }
}

// MARK: - Array Extensions
extension Array where Element: Equatable {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
