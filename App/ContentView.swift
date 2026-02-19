import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        MainView()
            .preferredColorScheme(.dark)
    }
}
