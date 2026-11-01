import SwiftUI

struct AppColors {
    static let background = Color(hex: 0x0D1117)
    static let surface = Color(hex: 0x131922)
    static let cardBackground = Color(hex: 0x171F2C)
    static let cardBorder = Color(hex: 0x293548)
    static let navBarBackground = Color(hex: 0x131A24)

    // Brand accents matching the Off-Road TPMS Icon & Splash
    static let primary = Color(hex: 0xFF7A00)       // Signature Off-Road Orange
    static let primaryLight = Color(hex: 0xFFA726)  // Warm Amber-Orange highlight
    static let secondary = Color(hex: 0x00B4FF)     // Inflate Cyan-Blue
    static let tertiary = Color(hex: 0x7E57C2)

    static let inflateBlue = Color(hex: 0x00B4FF)
    static let deflateRed = Color(hex: 0xFF453A)
    static let buttonBlue = Color(hex: 0x0091EA)
    static let errorRed = Color(hex: 0xFF5252)
    static let stopRed = Color(hex: 0xE53935)

    static let connectedGreen = Color(hex: 0x10B981)
    static let connectingAmber = Color(hex: 0xFFB300)
    static let scanningBlue = Color(hex: 0x00B4FF)
    static let disconnectedRed = Color(hex: 0xFF453A)

    static let debugYellow = Color(hex: 0xFFD60A)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x94A3B8)

    static let presetButtonBg = Color(hex: 0x1E293B)
    static let presetButtonActiveBg = Color(hex: 0xFF7A00)
    static let presetButtonText = Color(hex: 0xE2E8F0)
    static let presetButtonActiveText = Color.white
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
