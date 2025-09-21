import Foundation
import SwiftUI
import CoreBluetooth

// MARK: - Double Extensions
extension Double {
    /// Format pressure value with PSI unit
    var formattedPressure: String {
        return String(format: "%.1f PSI", self)
    }

    /// Format pressure value as integer PSI
    var formattedIntegerPressure: String {
        return String(format: "%.0f PSI", self)
    }

    /// Check if pressure is within valid range
    var isValidPressure: Bool {
        return self >= 10.0 && self <= 80.0
    }

    /// Round to nearest half
    var roundedToHalf: Double {
        return (self * 2).rounded() / 2
    }
}

// MARK: - String Extensions
extension String {
    /// Check if string is a valid pressure value
    var isValidPressureString: Bool {
        guard let pressure = Double(self) else { return false }
        return pressure.isValidPressure
    }

    /// Convert to Double if valid, otherwise return nil
    var pressureValue: Double? {
        guard let value = Double(self), value.isValidPressure else { return nil }
        return value
    }

    /// Localized string helper
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// Localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Date Extensions
extension Date {
    /// Format date for BLE communication (ISO8601)
    var bleTimestamp: String {
        return ISO8601DateFormatter().string(from: self)
    }

    /// Format date for display (short time)
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Format date for display (short date and time)
    var displayDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Time interval since date in human readable format
    func timeIntervalDescription(to date: Date = Date()) -> String {
        let interval = date.timeIntervalSince(self)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return "connected_duration_hours".localized(hours, minutes)
        } else if minutes > 0 {
            return "connected_duration_minutes".localized(minutes, seconds)
        } else {
            return "connected_duration_seconds".localized(seconds)
        }
    }
}

// MARK: - Color Extensions
extension Color {
    /// App-specific colors
    static let primaryBlue = Color(red: 0.0, green: 0.584, blue: 1.0)
    static let secondaryOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let successGreen = Color(red: 0.2, green: 0.8, blue: 0.2)
    static let warningRed = Color(red: 1.0, green: 0.2, blue: 0.2)

    /// Status colors for connection states
    static func statusColor(for state: ConnectionState) -> Color {
        switch state {
        case .connected:
            return .successGreen
        case .connecting, .scanning:
            return .secondaryOrange
        case .bluetoothDisabled, .connectionError:
            return .warningRed
        case .disconnected:
            return .gray
        }
    }

    /// Signal strength colors
    static func signalColor(for strength: SignalStrength) -> Color {
        switch strength {
        case .excellent, .good:
            return .successGreen
        case .fair:
            return .secondaryOrange
        case .weak, .noSignal:
            return .warningRed
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply card-style appearance
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    /// Apply pressure button style
    func pressureButtonStyle(isSelected: Bool = false) -> some View {
        self
            .font(.title3)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .primary)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.primaryBlue : Color(.systemGray6))
            .cornerRadius(8)
    }

    /// Apply action button style
    func actionButtonStyle(color: Color = .primaryBlue) -> some View {
        self
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(12)
    }

    /// Hide keyboard when tapped
    func hideKeyboard() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    /// App-specific UserDefaults instance
    static let app = UserDefaults.standard

    /// Generic method to get Codable objects from UserDefaults
    func getCodableObject<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Generic method to set Codable objects in UserDefaults
    func setCodableObject<T: Codable>(_ object: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        set(data, forKey: key)
    }
}

// MARK: - Bundle Extensions
extension Bundle {
    /// App version string
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// App build number
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// App display name
    var displayName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ?? "TirePressureManager"
    }

    /// Bundle identifier
    var bundleId: String {
        return bundleIdentifier ?? "com.nazulay.tirepressuremanager"
    }

    /// Full version string (version + build)
    var fullVersion: String {
        return "\(appVersion) (\(buildNumber))"
    }
}

// MARK: - UIDevice Extensions
extension UIDevice {
    /// Device model name
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    /// Custom notifications for the app
    static let deviceConnected = Notification.Name("deviceConnected")
    static let deviceDisconnected = Notification.Name("deviceDisconnected")
    static let pressureUpdated = Notification.Name("pressureUpdated")
    static let operationCompleted = Notification.Name("operationCompleted")
    static let settingsChanged = Notification.Name("settingsChanged")
}

// MARK: - CBPeripheral Extensions
extension CBPeripheral {
    /// Get a display-friendly name for the peripheral
    var displayName: String {
        return name ?? "unknown_device".localized
    }

    /// Check if peripheral has the required service
    func hasService(uuid: CBUUID) -> Bool {
        return services?.contains { $0.uuid == uuid } ?? false
    }
}

// MARK: - Array Extensions
extension Array where Element: Equatable {
    /// Remove all instances of an element
    mutating func removeAll(_ element: Element) {
        self = filter { $0 != element }
    }

    /// Safe subscript access
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element: Comparable {
    /// Check if array is sorted in ascending order
    var isSorted: Bool {
        return zip(self, dropFirst()).allSatisfy(<=)
    }
}

// MARK: - CGFloat Extensions
extension CGFloat {
    /// Convert to Double
    var doubleValue: Double {
        return Double(self)
    }
}

// MARK: - Int Extensions
extension Int {
    /// Convert to Double
    var doubleValue: Double {
        return Double(self)
    }

    /// Format as PSI string
    var psiString: String {
        return "\(self) PSI"
    }
}