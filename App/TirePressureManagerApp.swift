import SwiftUI
import CarPlay

@main
struct TirePressureManagerApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var settingsManager = SettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(settingsManager.displayMode.colorScheme)
        }
    }
}

// MARK: - CarPlay Scene
extension TirePressureManagerApp {
    var carPlayScene: some Scene {
        CPTemplateApplicationScene(id: "CarPlayScene") { templateApplicationScene in
            CarPlaySceneDelegate(bleManager: bleManager)
        }
    }
}