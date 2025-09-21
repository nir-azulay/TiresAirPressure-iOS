import CarPlay
import UIKit

/// CarPlay scene delegate that manages the CarPlay interface for tire pressure monitoring
class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let bleManager: BLEManager

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        super.init()
    }

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupCarPlayInterface()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Private Methods

    private func setupCarPlayInterface() {
        let mainTemplate = createMainTemplate()
        interfaceController?.setRootTemplate(mainTemplate, animated: true, completion: nil)
    }

    private func createMainTemplate() -> CPInformationTemplate {
        let template = CPInformationTemplate(
            title: NSLocalizedString("auto_app_title", comment: "Tire Air Pressure Management"),
            layout: .leading,
            items: createInformationItems(),
            actions: createMainActions()
        )

        return template
    }

    private func createInformationItems() -> [CPInformationItem] {
        var items: [CPInformationItem] = []

        // Connection status
        let connectionItem = CPInformationItem(
            title: "Connection Status",
            detail: bleManager.connectionState.displayText
        )
        items.append(connectionItem)

        // Current pressure (if connected)
        if let deviceStatus = bleManager.deviceStatus {
            let pressureItem = CPInformationItem(
                title: NSLocalizedString("auto_current_pressure", comment: "Current Pressure"),
                detail: String(format: NSLocalizedString("auto_pressure_format", comment: "%.1f PSI"), deviceStatus.currentPressure)
            )
            items.append(pressureItem)

            // Target pressure (if set)
            if let targetPressure = deviceStatus.targetPressure {
                let targetItem = CPInformationItem(
                    title: NSLocalizedString("auto_target_pressure", comment: "Target Pressure"),
                    detail: String(format: NSLocalizedString("auto_pressure_format", comment: "%.1f PSI"), targetPressure)
                )
                items.append(targetItem)

                // Pressure difference
                let difference = deviceStatus.currentPressure - targetPressure
                let differenceItem = CPInformationItem(
                    title: "Pressure Difference",
                    detail: String(format: "%+.1f PSI", difference)
                )
                items.append(differenceItem)
            }

            // Operation status
            if deviceStatus.isOperating {
                let operationItem = CPInformationItem(
                    title: "Operation",
                    detail: deviceStatus.operationMode.displayText
                )
                items.append(operationItem)
            }

            // Battery level (if available)
            if let batteryLevel = deviceStatus.batteryLevel {
                let batteryItem = CPInformationItem(
                    title: "Battery Level",
                    detail: "\(batteryLevel)%"
                )
                items.append(batteryItem)
            }
        }

        return items
    }

    private func createMainActions() -> [CPTextButton] {
        var actions: [CPTextButton] = []

        if bleManager.connectionState.isConnected {
            // Select target pressure action
            let selectTargetAction = CPTextButton(
                text: NSLocalizedString("auto_select_target", comment: "Select Target Pressure"),
                textStyle: .normal
            ) { [weak self] _ in
                self?.presentTargetSelectionTemplate()
            }
            actions.append(selectTargetAction)

            // Quick inflation actions
            if let deviceStatus = bleManager.deviceStatus, !deviceStatus.isOperating {
                let inflateAction = CPTextButton(
                    text: NSLocalizedString("inflate", comment: "Start Inflation"),
                    textStyle: .confirm
                ) { [weak self] _ in
                    self?.startQuickInflation()
                }
                actions.append(inflateAction)
            }

            // Stop operation (if operating)
            if let deviceStatus = bleManager.deviceStatus, deviceStatus.isOperating {
                let stopAction = CPTextButton(
                    text: NSLocalizedString("stop", comment: "Stop"),
                    textStyle: .cancel
                ) { [weak self] _ in
                    self?.stopCurrentOperation()
                }
                actions.append(stopAction)
            }
        } else {
            // Connect action
            let connectAction = CPTextButton(
                text: NSLocalizedString("connect", comment: "Connect"),
                textStyle: .confirm
            ) { [weak self] _ in
                self?.presentConnectionTemplate()
            }
            actions.append(connectAction)
        }

        return actions
    }

    private func presentTargetSelectionTemplate() {
        let targetTemplate = createTargetSelectionTemplate()
        interfaceController?.pushTemplate(targetTemplate, animated: true, completion: nil)
    }

    private func createTargetSelectionTemplate() -> CPActionSheetTemplate {
        let actions = createTargetPressureActions()

        let actionSheet = CPActionSheetTemplate(
            title: NSLocalizedString("select_target_pressure", comment: "Select Target Pressure"),
            message: "Choose a target pressure for inflation or deflation",
            actions: actions
        )

        return actionSheet
    }

    private func createTargetPressureActions() -> [CPAlertAction] {
        var actions: [CPAlertAction] = []

        // Common pressure values
        let commonPressures: [Double] = [28.0, 30.0, 32.0, 35.0, 40.0, 45.0]

        for pressure in commonPressures {
            let action = CPAlertAction(
                title: String(format: "%.0f PSI", pressure),
                style: .default
            ) { [weak self] _ in
                self?.setTargetPressure(pressure)
            }
            actions.append(action)
        }

        // Cancel action
        let cancelAction = CPAlertAction(
            title: "Cancel",
            style: .cancel
        ) { _ in
            // Do nothing, just dismiss
        }
        actions.append(cancelAction)

        return actions
    }

    private func presentConnectionTemplate() -> CPListTemplate {
        let items = createConnectionListItems()

        let listTemplate = CPListTemplate(
            title: "Connect to Device",
            sections: [CPListSection(items: items)]
        )

        return listTemplate
    }

    private func createConnectionListItems() -> [CPListItem] {
        var items: [CPListItem] = []

        // Scan for devices action
        let scanItem = CPListItem(
            text: "Scan for Devices",
            detailText: "Search for nearby tire pressure devices"
        )
        scanItem.setHandler { [weak self] _, completion in
            self?.startScanning()
            completion()
        }
        items.append(scanItem)

        // Available devices (if any)
        for device in bleManager.discoveredDevices {
            let deviceItem = CPListItem(
                text: device.name,
                detailText: device.signalStrengthText
            )
            deviceItem.setHandler { [weak self] _, completion in
                self?.connectToDevice(device)
                completion()
            }
            items.append(deviceItem)
        }

        return items
    }

    // MARK: - Action Handlers

    private func setTargetPressure(_ pressure: Double) {
        // This would typically involve presenting inflation/deflation options
        let currentPressure = bleManager.deviceStatus?.currentPressure ?? 0.0

        if currentPressure < pressure {
            // Need to inflate
            presentInflationConfirmation(targetPressure: pressure)
        } else if currentPressure > pressure {
            // Need to deflate
            presentDeflationConfirmation(targetPressure: pressure)
        } else {
            // Already at target
            showTargetReachedAlert()
        }

        interfaceController?.popTemplate(animated: true, completion: nil)
    }

    private func presentInflationConfirmation(targetPressure: Double) {
        let currentPressure = bleManager.deviceStatus?.currentPressure ?? 0.0
        let difference = targetPressure - currentPressure

        let alertTemplate = CPAlertTemplate(
            titleVariants: ["Start Inflation?"],
            actions: [
                CPAlertAction(title: "Inflate", style: .default) { [weak self] _ in
                    Task { @MainActor in
                        self?.bleManager.startInflation(targetPressure: targetPressure)
                    }
                },
                CPAlertAction(title: "Cancel", style: .cancel) { _ in }
            ]
        )

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    private func presentDeflationConfirmation(targetPressure: Double) {
        let currentPressure = bleManager.deviceStatus?.currentPressure ?? 0.0
        let difference = currentPressure - targetPressure

        let alertTemplate = CPAlertTemplate(
            titleVariants: ["Start Deflation?"],
            actions: [
                CPAlertAction(title: "Deflate", style: .destructive) { [weak self] _ in
                    Task { @MainActor in
                        self?.bleManager.startDeflation(targetPressure: targetPressure)
                    }
                },
                CPAlertAction(title: "Cancel", style: .cancel) { _ in }
            ]
        )

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    private func showTargetReachedAlert() {
        let alertTemplate = CPAlertTemplate(
            titleVariants: [NSLocalizedString("target_reached_title", comment: "Target Reached")],
            actions: [
                CPAlertAction(title: "OK", style: .default) { _ in }
            ]
        )

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    private func startQuickInflation() {
        // Start inflation to a default target (e.g., 32 PSI)
        Task { @MainActor in
            bleManager.startInflation(targetPressure: 32.0)
        }
    }

    private func stopCurrentOperation() {
        Task { @MainActor in
            bleManager.stopOperation()
        }
    }

    private func startScanning() {
        Task { @MainActor in
            bleManager.startScanning()
        }
    }

    private func connectToDevice(_ device: BLEDevice) {
        Task { @MainActor in
            bleManager.connect(to: device)
        }
    }

    // MARK: - Template Updates

    func updateCarPlayInterface() {
        guard let interfaceController = interfaceController else { return }

        // Update the root template with new information
        let updatedTemplate = createMainTemplate()
        interfaceController.setRootTemplate(updatedTemplate, animated: false, completion: nil)
    }
}