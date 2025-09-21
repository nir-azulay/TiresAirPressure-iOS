import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem {
                    Image(systemName: "gauge")
                    Text(NSLocalizedString("tire_pressure", comment: "Tire Pressure"))
                }
                .tag(0)

            ConnectionView()
                .tabItem {
                    Image(systemName: "bluetooth")
                    Text(NSLocalizedString("connect", comment: "Connect"))
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(NSLocalizedString("settings", comment: "Settings"))
                }
                .tag(2)

            AboutView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text(NSLocalizedString("about", comment: "About"))
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}