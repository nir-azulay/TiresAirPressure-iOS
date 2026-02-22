import Foundation
import UIKit

struct AppConstants {

    static let appName = "Tires Air Pressure Manager"
    static let developerName = "Nir Azulay"
    static let developerEmail = "nir.azulay@gmail.com"

    struct Pressure {
        static let minValue: Double = 1.0
        static let maxValue: Double = 80.0
        static let defaultTarget: Double = 32.0
        static let defaultPresets: [Double] = [8, 10, 12, 16, 20, 30, 38, 40]
    }

    struct UI {
        static let animationDuration: Double = 0.3
        static let cardCornerRadius: CGFloat = 12.0
        static let buttonHeight: CGFloat = 44.0
        static let defaultPadding: CGFloat = 16.0
    }

    struct Connection {
        static let scanTimeout: TimeInterval = 10.0
        static let connectionTimeout: TimeInterval = 10.0
        static let reconnectDelay: TimeInterval = 3.0
        static let maxReconnectAttempts = 3
        static let debugSyncDelay: TimeInterval = 1.5
        static let settingsRestartDelay: TimeInterval = 3.0
    }

    struct Localization {
        static let supportedLanguages = ["en", "he"]
        static let defaultLanguage = "en"
    }
}

extension AppConstants {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var fullVersionInfo: String {
        "Version \(currentVersion) (\(currentBuild))"
    }
}
