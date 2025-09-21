# iOS Project Setup Instructions

## Quick Start

1. **Open the project in Xcode 15+**
   ```bash
   open TirePressureManager.xcodeproj
   ```

2. **Select your Development Team**
   - Go to Project Settings > Signing & Capabilities
   - Select your Apple Developer account
   - Xcode will automatically handle provisioning

3. **Build and Run**
   - Select target device or simulator
   - Press ⌘+R or click Run

## Detailed Setup

### Prerequisites
- **Xcode 15.0+** (from Mac App Store)
- **iOS 15.0+ deployment target**
- **Apple Developer Account** (for device testing)
- **CarPlay Simulator** (for automotive testing)

### Project Configuration

#### 1. Bundle Identifier
- Current: `com.nazulay.tirepressuremanager`
- Change in Project Settings > General > Identity

#### 2. Development Team
- Project Settings > Signing & Capabilities
- Select your team from dropdown
- Xcode will auto-generate provisioning profiles

#### 3. App Icons (Required)
The project includes placeholder app icon configuration. You need to add actual icon files:

**Icon Sizes Needed:**
- 20x20, 40x40, 60x60 (iPhone)
- 29x29, 58x58, 87x87 (Settings)
- 76x76, 152x152, 167x167 (iPad)
- 1024x1024 (App Store)

**Add Icons:**
1. Open `App/Assets.xcassets/AppIcon.appiconset/`
2. Drag icon files into Xcode Asset Catalog
3. Ensure all sizes are filled

#### 4. Launch Screen
- Customize `Info.plist` launch screen settings
- Or create custom `LaunchScreen.storyboard`

### Dependencies & Frameworks

#### System Frameworks (Already Configured)
- **CoreBluetooth** - BLE communication
- **CarPlay** - Vehicle integration
- **SwiftUI** - User interface
- **Combine** - Reactive programming
- **Foundation** - Core functionality

#### External Dependencies (None Currently)
- Project is designed to use only system frameworks
- To add SPM packages: File > Add Packages

### Entitlements Configuration

The project includes required entitlements in `TirePressureManager.entitlements`:

- ✅ **CarPlay Audio** - For automotive integration
- ✅ **Background Bluetooth Central** - For BLE monitoring
- ✅ **App Groups** - For data sharing (if needed)

### Build Configurations

#### Debug Configuration
- **Bundle ID Suffix**: `.debug`
- **Version Suffix**: `-debug`
- **Debug Flags**: Enabled
- **Optimizations**: Disabled

#### Release Configuration
- **Optimizations**: Enabled
- **Debug Flags**: Disabled
- **Code Signing**: Distribution
- **Bitcode**: Enabled

### Testing Setup

#### Unit Tests
```bash
# Run unit tests
⌘+U in Xcode
# Or command line:
xcodebuild test -scheme TirePressureManager -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### UI Tests
```bash
# Run UI tests
xcodebuild test -scheme TirePressureManagerUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### CarPlay Testing
1. **CarPlay Simulator:**
   - Xcode > Developer Tools > CarPlay Simulator
   - Connect to iOS Simulator
   - Test CarPlay interface

2. **Physical CarPlay:**
   - Connect iPhone to CarPlay-enabled vehicle
   - Install debug build
   - Test in vehicle environment

### Code Signing & Distribution

#### Development
- Automatic signing enabled
- Development team selected
- Provisions iPhone/iPad testing

#### Distribution (App Store)
1. **Archive Build:**
   ```
   Product > Archive
   ```

2. **Upload to App Store Connect:**
   - Window > Organizer
   - Select archive
   - Distribute App > App Store Connect

3. **App Store Requirements:**
   - Privacy descriptions in `Info.plist`
   - App icons for all sizes
   - Screenshots for App Store
   - App description and metadata

### Localization Setup

#### Supported Languages
- **English** (Base language)
- **Hebrew** (RTL support included)

#### Adding New Languages
1. **Add Language:**
   - Project Settings > Localizations > +
   - Select language

2. **Translate Strings:**
   - Copy `Resources/en.lproj/Localizable.strings`
   - Create `Resources/[lang].lproj/Localizable.strings`
   - Translate all string values

3. **Update Code:**
   - Add language to `AppLanguage` enum
   - Update language picker in settings

### Troubleshooting

#### Common Build Issues

**"No matching provisioning profiles found"**
- Solution: Select development team in Project Settings

**"Bluetooth permission denied"**
- Solution: Add usage descriptions to Info.plist (already included)

**"CarPlay not working in simulator"**
- Solution: Use CarPlay Simulator from Xcode Developer Tools

**"App crashes on launch"**
- Check: Bundle identifier matches provisioning profile
- Check: All required frameworks are linked
- Check: Info.plist is properly configured

#### BLE Testing Issues

**Cannot discover devices:**
- Ensure location permission granted
- Check Bluetooth is enabled
- Verify BLE service UUIDs match hardware

**Connection fails:**
- Check device is advertising
- Verify service/characteristic UUIDs
- Ensure device is not connected to other apps

#### CarPlay Issues

**CarPlay app doesn't appear:**
- Verify entitlements are properly set
- Check CarPlay simulator connection
- Ensure Info.plist has CarPlay configuration

### File Structure
```
TirePressureManager-iOS/
├── TirePressureManager.xcodeproj/    # Xcode project
├── App/                              # App entry point
│   ├── TirePressureManagerApp.swift
│   ├── ContentView.swift
│   ├── Info.plist
│   └── Assets.xcassets/
├── Core/                             # Core business logic
│   ├── BLE/                          # Bluetooth management
│   ├── Models/                       # Data models
│   ├── Services/                     # App services
│   └── Utils/                        # Utilities & extensions
├── Features/                         # Feature modules
│   ├── Main/                         # Main pressure screen
│   ├── Connection/                   # Device connection
│   ├── Settings/                     # App settings
│   ├── About/                        # About screen
│   └── CarPlay/                      # CarPlay integration
├── UI/                               # Reusable UI components
│   └── Components/
├── Resources/                        # Localization files
│   ├── en.lproj/
│   └── he.lproj/
├── Tests/                            # Test suites
└── TirePressureManager.entitlements  # App entitlements
```

### Next Steps

1. **Customize App Icons** - Add your brand's icons
2. **Test on Device** - Install on iPhone for BLE testing
3. **Configure CarPlay** - Test automotive integration
4. **Customize Branding** - Update colors, fonts, copy
5. **Add Analytics** - Integrate crash reporting/analytics if needed
6. **Prepare for Release** - Screenshots, metadata, testing

### Support

For setup issues:
- Check Xcode console for detailed error messages
- Verify all file paths are correct
- Ensure development team is properly selected
- Test on both simulator and physical device

The project is configured to work out-of-the-box with minimal setup required.