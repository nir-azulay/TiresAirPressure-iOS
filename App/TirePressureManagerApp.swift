import SwiftUI

@main
struct TirePressureManagerApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var settingsManager = SettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    bleManager.setSettingsManager(settingsManager)
                }
        }
    }
}
