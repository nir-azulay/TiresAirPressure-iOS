import CarPlay
import UIKit

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let bleManager: BLEManager

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        super.init()
    }

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

    private func setupCarPlayInterface() {
        let mainTemplate = createMainTemplate()
        interfaceController?.setRootTemplate(mainTemplate, animated: true, completion: nil)
    }

    private func createMainTemplate() -> CPInformationTemplate {
        CPInformationTemplate(
            title: NSLocalizedString("auto_app_title", comment: "Tire Air Pressure Management"),
            layout: .leading,
            items: createInformationItems(),
            actions: createMainActions()
        )
    }

    private func createInformationItems() -> [CPInformationItem] {
        var items: [CPInformationItem] = []

        let connectionItem = CPInformationItem(
            title: "Connection Status",
            detail: bleManager.connectionState.displayText
        )
        items.append(connectionItem)

        if let status = bleManager.deviceStatus {
            let pressureItem = CPInformationItem(
                title: NSLocalizedString("auto_current_pressure", comment: "Current Pressure"),
                detail: String(format: "%.1f PSI", status.pressure)
            )
            items.append(pressureItem)

            if status.isOperating {
                let operationItem = CPInformationItem(
                    title: "Operation",
                    detail: status.operationModeText
                )
                items.append(operationItem)
            }
        }

        return items
    }

    private func createMainActions() -> [CPTextButton] {
        var actions: [CPTextButton] = []

        if bleManager.connectionState.isConnected {
            let selectTargetAction = CPTextButton(
                title: NSLocalizedString("auto_select_target", comment: "Select Target Pressure"),
                textStyle: .normal
            ) { [weak self] _ in
                self?.presentTargetSelectionTemplate()
            }
            actions.append(selectTargetAction)

            if let status = bleManager.deviceStatus, status.isOperating {
                let stopAction = CPTextButton(
                    title: NSLocalizedString("stop", comment: "Stop"),
                    textStyle: .cancel
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.bleManager.stopOperation()
                    }
                }
                actions.append(stopAction)
            }
        } else {
            let connectAction = CPTextButton(
                title: NSLocalizedString("connect", comment: "Connect"),
                textStyle: .confirm
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.bleManager.startScanning()
                }
            }
            actions.append(connectAction)
        }

        return actions
    }

    private func presentTargetSelectionTemplate() {
        let actions = createTargetPressureActions()
        let actionSheet = CPActionSheetTemplate(
            title: NSLocalizedString("select_target_pressure", comment: "Select Target Pressure"),
            message: "Choose a target pressure",
            actions: actions
        )
        interfaceController?.pushTemplate(actionSheet, animated: true, completion: nil)
    }

    private func createTargetPressureActions() -> [CPAlertAction] {
        let pressures: [Double] = [8, 10, 12, 16, 20, 30, 38, 40]
        var actions: [CPAlertAction] = []

        for pressure in pressures {
            let action = CPAlertAction(
                title: String(format: "%.0f PSI", pressure),
                style: .default
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.bleManager.startInflation(targetPressure: pressure)
                }
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
            }
            actions.append(action)
        }

        actions.append(CPAlertAction(title: "Cancel", style: .cancel) { _ in })
        return actions
    }

    func updateCarPlayInterface() {
        guard let interfaceController = interfaceController else { return }
        let updatedTemplate = createMainTemplate()
        interfaceController.setRootTemplate(updatedTemplate, animated: false, completion: nil)
    }
}
