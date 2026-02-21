import XCTest

final class TirePressureManagerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    func testAppLaunch() {
        // Test that the app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testTabNavigation() {
        // Test that all main tabs are accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)

        // Test Tire Pressure tab (should be selected by default)
        let tireTab = tabBar.buttons["Tire Pressure"]
        XCTAssertTrue(tireTab.exists)
        XCTAssertTrue(tireTab.isSelected)

        // Test Connection tab
        let connectionTab = tabBar.buttons["Connect"]
        XCTAssertTrue(connectionTab.exists)
        connectionTab.tap()
        XCTAssertTrue(connectionTab.isSelected)

        // Test Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)

        // Test About tab
        let aboutTab = tabBar.buttons["About"]
        XCTAssertTrue(aboutTab.exists)
        aboutTab.tap()
        XCTAssertTrue(aboutTab.isSelected)
    }

    func testMainScreenElements() {
        // Navigate to main screen
        let tabBar = app.tabBars.firstMatch
        let tireTab = tabBar.buttons["Tire Pressure"]
        tireTab.tap()

        // Test that main screen elements exist
        XCTAssertTrue(app.navigationBars["Tire Pressure"].exists)

        // Test connection status card
        let connectionStatus = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Connected' OR label CONTAINS 'Disconnected'")).firstMatch
        XCTAssertTrue(connectionStatus.exists)

        // Test not connected state elements
        let notConnectedText = app.staticTexts["Not Connected"]
        if notConnectedText.exists {
            XCTAssertTrue(app.images["dot.radiowaves.left.and.right.slash"].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Connect to a device'")).firstMatch.exists)
        }
    }

    func testConnectionScreen() {
        // Navigate to connection screen
        let tabBar = app.tabBars.firstMatch
        let connectionTab = tabBar.buttons["Connect"]
        connectionTab.tap()

        // Test navigation title
        XCTAssertTrue(app.navigationBars["Scan Devices"].exists)

        // Test Bluetooth status card exists
        let bluetoothStatus = app.staticTexts.containing(NSPredicate(format: "label == 'Bluetooth Status'")).firstMatch
        XCTAssertTrue(bluetoothStatus.exists)

        // Test scan button exists
        let scanButton = app.buttons["Scan Devices"]
        if scanButton.exists {
            // Test scan button functionality
            scanButton.tap()

            // After tapping, either scanning starts or bluetooth permission is requested
            let stopScanButton = app.buttons["Stop Scan"]
            let bluetoothAlert = app.alerts.firstMatch

            XCTAssertTrue(stopScanButton.exists || bluetoothAlert.exists)

            // If scanning started, test stop functionality
            if stopScanButton.exists {
                stopScanButton.tap()
                XCTAssertTrue(scanButton.exists)
            }
        }
    }

    func testSettingsScreen() {
        // Navigate to settings screen
        let tabBar = app.tabBars.firstMatch
        let settingsTab = tabBar.buttons["Settings"]
        settingsTab.tap()

        // Test navigation title
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        // Test app settings section
        XCTAssertTrue(app.staticTexts["App Settings"].exists)

        // Test display mode picker
        let displayModePicker = app.buttons["Display Mode"]
        if displayModePicker.exists {
            displayModePicker.tap()
            // Should show picker options
            XCTAssertTrue(app.pickerWheels.firstMatch.exists || app.buttons["System Default"].exists)
        }

        // Test preset pressures section
        XCTAssertTrue(app.staticTexts["Preset Pressures"].exists)

        // Test add pressure button (if available)
        let addPressureButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Add Pressure'")).firstMatch
        if addPressureButton.exists {
            addPressureButton.tap()

            // Should show alert for adding pressure
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.exists)

            // Cancel the alert
            let cancelButton = alert.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
    }

    func testAboutScreen() {
        // Navigate to about screen
        let tabBar = app.tabBars.firstMatch
        let aboutTab = tabBar.buttons["About"]
        aboutTab.tap()

        // Test navigation title
        XCTAssertTrue(app.navigationBars["About"].exists)

        // Test app information elements
        XCTAssertTrue(app.staticTexts["Tire Pressure Manager"].exists)

        // Test version information
        let versionText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Version'")).firstMatch
        XCTAssertTrue(versionText.exists)

        // Test developer information
        XCTAssertTrue(app.staticTexts["Developed by"].exists || app.staticTexts["Contact Information"].exists)

        // Test email button (if exists)
        let emailButton = app.buttons.containing(NSPredicate(format: "label CONTAINS '@'")).firstMatch
        XCTAssertTrue(emailButton.exists)
    }

    func testAccessibility() {
        // Test that important elements are accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.isHittable)

        // Test tab buttons accessibility
        let tireTab = tabBar.buttons["Tire Pressure"]
        XCTAssertTrue(tireTab.exists)
        XCTAssertFalse(tireTab.label.isEmpty)

        let connectionTab = tabBar.buttons["Connect"]
        XCTAssertTrue(connectionTab.exists)
        XCTAssertFalse(connectionTab.label.isEmpty)

        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        XCTAssertFalse(settingsTab.label.isEmpty)

        let aboutTab = tabBar.buttons["About"]
        XCTAssertTrue(aboutTab.exists)
        XCTAssertFalse(aboutTab.label.isEmpty)
    }

    func testPressureControlsAccessibility() {
        // Navigate to main screen
        let tabBar = app.tabBars.firstMatch
        let tireTab = tabBar.buttons["Tire Pressure"]
        tireTab.tap()

        // Test that pressure control elements have proper accessibility
        let increaseButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Increase' OR label CONTAINS 'plus'")).firstMatch
        let decreaseButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Decrease' OR label CONTAINS 'minus'")).firstMatch

        if increaseButton.exists {
            XCTAssertTrue(increaseButton.isHittable)
            XCTAssertFalse(increaseButton.label.isEmpty)
        }

        if decreaseButton.exists {
            XCTAssertTrue(decreaseButton.isHittable)
            XCTAssertFalse(decreaseButton.label.isEmpty)
        }
    }

    func testAppLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}