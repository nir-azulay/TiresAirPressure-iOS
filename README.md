# Tire Pressure Manager — iOS & CarPlay (`v2.1.0`)

Native SwiftUI iOS, iPadOS, and CarPlay application for monitoring and controlling the ESP32 Tire Air Pressure Controller over Bluetooth Low Energy (BLE).

## Features

- **270° Off-Road Speedometer Gauge:** Live manifold pressure in PSI or BAR with high-contrast off-road dark theme (`#101318` / `#181C24`).
- **Automated Closed-Loop Inflation & Deflation:** Set target pressure via slider, `+/-` steppers, or quick preset chips (`Road`, `Trail`, `Sand`, `Rock`, plus customizable presets).
- **Target Reached Celebration:** Animated celebration overlay with sound and haptic feedback when tires reach the target pressure.
- **Full Controller Configuration over BLE:** Edit all 18 ESP32 hardware and safety settings directly from the app (`DeviceSettingsView`), including:
  - Device Name, Wi-Fi SSID (with live **ESP32 BLE Wi-Fi network scanner**), and Wi-Fi Password (with Show/Hide toggle)
  - Hotspot Password and BLE Access Code (with Show/Hide toggles)
  - Relay Compressor Pin, Relay Free Pin, and Sensor Pin (ADC1)
  - Pressure Calculation Method (`1`: Raw ADC, `2`: Voltage Divider) and `0 PSI` / `Full Scale` calibration values
  - Sensor Full Scale PSI, Max Pressure PSI, Max Valve Open Seconds, Measure Wait, Precision, Simulation Mode, and Debug Mode
- **Multi-Device Auto-Connect:** Saves the 2 most recently used controllers and automatically connects on launch using parallel `connectByIdentifier` and BLE scanning.
- **Apple CarPlay Integration:** Native CarPlay dashboard for monitoring pressure, triggering presets, and stopping airflow from the vehicle head unit.
- **Bilingual Localization:** Runtime switching between English (`en`) and Hebrew (`he`, full RTL layout).

## Project Structure

```text
ios/
├── App/                              # App entry point, Info.plist, Assets.xcassets
├── Core/
│   ├── BLE/BLEManager.swift          # CoreBluetooth GATT client, 180-byte chunking, auto-reconnect
│   ├── Models/                       # BLECommand, DeviceSettings, DeviceStatus, SavedDevice
│   ├── Services/SettingsManager.swift# UserDefaults persistence & presets
│   └── Utils/LocalizationManager.swift
├── Features/
│   ├── Main/                         # MainView (270° gauge, presets, TargetReachedCelebrationView)
│   ├── Connection/                   # ConnectionView & SavedDevicesView
│   ├── Settings/                     # SettingsView & DeviceSettingsView
│   ├── About/                        # AboutView
│   └── CarPlay/                      # CarPlaySceneDelegate
├── Resources/
│   ├── en.lproj/Localizable.strings
│   └── he.lproj/Localizable.strings
└── fastlane/                         # Fastlane beta lane for TestFlight CI
```

## BLE GATT Configuration

- **Service UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Notification Characteristic:** `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Command Characteristic:** `e3223119-9445-4e96-a4a1-85358c4046a2`

See [`SPECIFICATION.md`](../SPECIFICATION.md) and [`ble/docs/BLE_PROTOCOL.md`](../ble/docs/BLE_PROTOCOL.md) for the complete BLE JSON command and notification protocol.

## Build & Release

- **Local Xcode Build:** Open `TirePressureManager.xcodeproj` in Xcode 16+, select scheme `TirePressureManager`, and build (`⌘R`).
- **TestFlight CI/CD:** GitHub Actions workflow [`ios-testflight.yml`](.github/workflows/ios-testflight.yml) (see [`docs/ios-testflight-ci.md`](docs/ios-testflight-ci.md)).

## License

Copyright © 2026 Nir Azulay. All rights reserved.
