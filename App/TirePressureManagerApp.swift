import SwiftUI

@main
struct TirePressureManagerApp: App {
    @ObservedObject private var bleManager = BLEManager.shared
    @StateObject private var settingsManager = SettingsManager()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView(isActive: $showSplash)
                        .environmentObject(bleManager)
                } else {
                    ContentView()
                        .environmentObject(bleManager)
                        .environmentObject(settingsManager)
                        .transition(.opacity)
                }
            }
            .id(localizationManager.refreshId)
            .onAppear {
                bleManager.setSettingsManager(settingsManager)
            }
            // The gauge, presets, and stop control are a fixed instrument layout.
            // Ignore Settings → Text Size so larger system text cannot overflow them.
            .dynamicTypeSize(.large)
            .preferredColorScheme(.dark)
        }
    }
}
