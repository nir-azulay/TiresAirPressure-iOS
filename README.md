# Tire Pressure Manager - iOS

A complete iOS implementation of the Tire Air Pressure Management app, migrated from Android/Kotlin to iOS/Swift.

## Features

### Core Functionality
- **Real-time pressure monitoring** via Bluetooth Low Energy
- **Automatic inflation/deflation** to target pressure
- **Preset pressure buttons** for quick selection
- **Multi-language support** (English & Hebrew)
- **CarPlay integration** for in-vehicle use
- **Device settings management** with real-time sync

### User Interface
- **Native SwiftUI** implementation following iOS Human Interface Guidelines
- **Dark/Light mode** support with system integration
- **Accessibility** optimized with VoiceOver support
- **Responsive design** for iPhone and iPad
- **Smooth animations** and modern iOS design patterns

### Connectivity
- **Bluetooth Low Energy** device discovery and management
- **Auto-reconnect** to last connected device
- **Connection status monitoring** with signal strength indicators
- **Background BLE** support for continuous monitoring

### CarPlay Integration
- **Native CarPlay templates** for safe in-vehicle operation
- **Voice control** compatibility
- **Simple interface** optimized for driving scenarios
- **Real-time pressure updates** in CarPlay dashboard

## Architecture

### Project Structure
```
TirePressureManager-iOS/
├── App/                          # App entry point and configuration
│   ├── TirePressureManagerApp.swift
│   ├── ContentView.swift
│   └── Info.plist
├── Sources/TirePressureManager/
│   ├── Core/                     # Core business logic
│   │   ├── BLE/                  # Bluetooth Low Energy management
│   │   ├── Models/               # Data models and enums
│   │   ├── Services/             # App services (Settings, etc.)
│   │   └── Utils/                # Utility functions
│   ├── Features/                 # Feature-specific views and logic
│   │   ├── Main/                 # Main pressure monitoring screen
│   │   ├── Settings/             # App and device settings
│   │   ├── Connection/           # Device connection management
│   │   ├── About/                # App information screen
│   │   └── CarPlay/              # CarPlay integration
│   └── UI/                       # Reusable UI components
│       ├── Components/
│       ├── Modifiers/
│       └── Themes/
├── Resources/                    # App resources
│   ├── Localizable/              # Localization files
│   ├── Images/                   # App images and icons
│   └── Sounds/                   # Audio assets
└── Tests/                        # Test suites
    ├── Unit/
    ├── Integration/
    └── UI/
```

### Key Components

#### BLE Manager (`BLEManager.swift`)
- Handles all Bluetooth Low Energy operations
- Device discovery, connection, and communication
- Real-time status updates and command sending
- Thread-safe with `@MainActor` annotations

#### Settings Manager (`SettingsManager.swift`)
- Manages app preferences and user settings
- Persistent storage with UserDefaults
- Preset pressure management
- Display mode and language preferences

#### CarPlay Integration (`CarPlaySceneDelegate.swift`)
- Native CarPlay templates and navigation
- Safe driving-optimized interface
- Real-time pressure monitoring in vehicle
- Voice control compatibility

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **UI Framework** | SwiftUI | Modern declarative UI |
| **Language** | Swift 5.9+ | Type-safe iOS development |
| **BLE Communication** | Core Bluetooth | Native iOS BLE framework |
| **Vehicle Integration** | CarPlay Framework | In-vehicle interface |
| **Data Persistence** | UserDefaults | Settings and preferences |
| **Localization** | iOS Localization | Multi-language support |
| **Architecture** | MVVM + Combine | Reactive programming |

## Requirements

### System Requirements
- **iOS 15.0+** (iPhone, iPad)
- **Bluetooth Low Energy** support
- **CarPlay** compatible vehicle (optional)

### Development Requirements
- **Xcode 15+**
- **Swift 5.9+**
- **iOS Simulator** or physical device for testing
- **CarPlay Simulator** for automotive testing

## Installation

### For Users
1. Download the app from the App Store (when published)
2. Grant Bluetooth permissions when prompted
3. Connect to your tire pressure monitoring device
4. Start monitoring and controlling tire pressure

### For Developers
1. Clone this repository
2. Open `TirePressureManager.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on device or simulator

```bash
git clone [repository-url]
cd TirePressureManager-iOS
open TirePressureManager.xcodeproj
```

## Usage

### Main Features

#### Device Connection
1. Open the **Connection** tab
2. Tap **Scan Devices** to discover nearby devices
3. Select your tire pressure device from the list
4. Wait for connection confirmation

#### Pressure Monitoring
1. View real-time pressure on the **Main** screen
2. Set target pressure using the slider or +/- buttons
3. Use **Inflate** or **Deflate** buttons to adjust pressure
4. Monitor progress with real-time updates

#### Settings Management
1. Configure app preferences in **Settings** tab
2. Access device settings when connected
3. Customize preset pressure values
4. Adjust display and language preferences

#### CarPlay Usage
1. Connect iPhone to CarPlay-enabled vehicle
2. Launch Tire Pressure Manager from CarPlay screen
3. Monitor pressure and control inflation while driving
4. Use voice commands for hands-free operation

## Localization

The app supports multiple languages:

- **English** (`en`) - Default language
- **Hebrew** (`he`) - Right-to-left layout support

### Adding New Languages
1. Create new `.lproj` folder in `Resources/Localizable/`
2. Copy `Localizable.strings` and translate all keys
3. Add language code to `Info.plist` `CFBundleLocalizations`
4. Update `AppLanguage` enum in `SettingsManager.swift`

## BLE Protocol

The app communicates with tire pressure devices using JSON over BLE:

### Command Structure
```json
{
  "command": "START_INFLATION",
  "targetPressure": 32.0,
  "timestamp": "2024-03-15T10:30:00Z"
}
```

### Status Response
```json
{
  "status": {
    "currentPressure": 28.5,
    "targetPressure": 32.0,
    "isInflating": true,
    "isDeflating": false,
    "batteryLevel": 85
  }
}
```

### Service Configuration
- **Service UUID**: `12345678-1234-1234-1234-123456789abc`
- **Command Characteristic**: `87654321-4321-4321-4321-210987654321`
- **Notify Characteristic**: `11223344-5566-7788-99aa-bbccddeeff00`

## Testing

### Unit Tests
```bash
# Run unit tests
xcodebuild test -scheme TirePressureManager -destination 'platform=iOS Simulator,name=iPhone 15'
```

### UI Tests
```bash
# Run UI automation tests
xcodebuild test -scheme TirePressureManagerUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### CarPlay Testing
1. Use CarPlay Simulator in Xcode
2. Test templates and navigation flow
3. Verify voice control integration
4. Test with different vehicle configurations

## Contributing

### Development Guidelines
1. Follow Swift coding conventions
2. Use SwiftUI best practices
3. Maintain MVVM architecture
4. Add unit tests for new features
5. Update localization files
6. Test on multiple device sizes

### Code Review Process
1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Submit pull request
5. Address review feedback

## Migration Notes

This iOS app maintains feature parity with the original Android version:

### Migrated Features ✅
- ✅ Bluetooth Low Energy communication
- ✅ Real-time pressure monitoring
- ✅ Automatic inflation/deflation control
- ✅ Device settings management
- ✅ Multi-language support (English/Hebrew)
- ✅ CarPlay integration (replaces Android Auto)
- ✅ Preset pressure management
- ✅ Connection management and auto-reconnect

### Platform-Specific Improvements
- **Native iOS UI/UX** following Human Interface Guidelines
- **SwiftUI animations** and smooth transitions
- **iOS accessibility** features (VoiceOver, Dynamic Type)
- **CarPlay templates** optimized for driving safety
- **Background BLE** support within iOS limitations

## License

Copyright © 2024 Nir Azulay. All rights reserved.

This project maintains the same licensing as the original Android version.

## Support

For issues, questions, or feature requests:

- **Email**: nir.azulay@gmail.com
- **GitHub Issues**: [Create an issue](link-to-issues)

## Changelog

### Version 1.2.1 (Build 442)
- Initial iOS implementation
- Complete feature parity with Android version
- CarPlay integration
- Multi-language support (English/Hebrew)
- Native iOS UI with SwiftUI