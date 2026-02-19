import SwiftUI

struct AppColors {
    static let background = Color(hex: 0x121212)
    static let surface = Color(hex: 0x1E1E1E)
    static let cardBackground = Color(hex: 0x1E2530)

    static let primary = Color(hex: 0x1976D2)
    static let primaryLight = Color(hex: 0xBBDEFB)
    static let secondary = Color(hex: 0x26A69A)
    static let tertiary = Color(hex: 0x7E57C2)

    static let buttonBlue = Color(hex: 0x3F51B5)
    static let errorRed = Color(hex: 0xE57373)
    static let stopRed = Color(hex: 0xF44336)

    static let connectedGreen = Color(hex: 0x4CAF50)
    static let connectingAmber = Color(hex: 0xFFC107)
    static let scanningBlue = Color(hex: 0x2196F3)
    static let disconnectedRed = Color(hex: 0xF44336)

    static let debugYellow = Color.yellow
    static let textPrimary = Color.white
    static let textSecondary = Color.gray

    static let presetButtonBg = Color(hex: 0x1976D2).opacity(0.3)
    static let presetButtonText = Color(hex: 0xBBDEFB)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
