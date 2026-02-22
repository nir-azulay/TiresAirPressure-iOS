import CarPlay
import UIKit
import Combine

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private var bleManager: BLEManager { BLEManager.shared }
    private var cancellables = Set<AnyCancellable>()

    private var targetPressure: Double = 0.0
    private var currentPressure: Double = 0.0
    private var operationMode: Int = DeviceStatus.modeStop
    private var isTargetReached = false
    private var refreshTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        subscribeToUpdates()
        refreshUI()
    }

    private func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        cancellables.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
        self.interfaceController = nil
    }

    // MARK: - Reactive Updates

    private func subscribeToUpdates() {
        Task { @MainActor in
            bleManager.$connectionState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.refreshUI() }
                .store(in: &cancellables)

            bleManager.$deviceStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    guard let self, let status else { return }
                    self.currentPressure = status.pressure

                    let prevMode = self.operationMode
                    self.operationMode = status.operationMode
                    if status.operationMode != DeviceStatus.modeStop && prevMode == DeviceStatus.modeStop {
                        self.isTargetReached = false
                    }
                    self.refreshUI()
                }
                .store(in: &cancellables)

            bleManager.targetReachedSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak self] info in
                    guard let self else { return }
                    self.isTargetReached = true
                    self.refreshUI()
                    self.showTargetReachedAlert(target: info.target, current: info.current)
                }
                .store(in: &cancellables)
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUI()
            }
        }
    }

    private func refreshUI() {
        guard let interfaceController else { return }

        let template: CPTemplate
        if bleManager.connectionState == .connected {
            template = buildConnectedTemplate()
        } else {
            template = buildDisconnectedTemplate()
        }

        interfaceController.setRootTemplate(template, animated: false, completion: nil)
    }

    // MARK: - Disconnected State

    private func buildDisconnectedTemplate() -> CPInformationTemplate {
        let statusItem = CPInformationItem(
            title: L("bluetooth_status", comment: ""),
            detail: bleManager.connectionState.displayText
        )

        let connectButton = CPTextButton(
            title: L("connect", comment: ""),
            textStyle: .confirm
        ) { [weak self] _ in
            Task { @MainActor in
                self?.bleManager.connectToSavedDevices()
            }
        }

        let scanButton = CPTextButton(
            title: L("scan_devices", comment: ""),
            textStyle: .normal
        ) { [weak self] _ in
            Task { @MainActor in
                self?.bleManager.startScanning()
            }
        }

        return CPInformationTemplate(
            title: L("app_name", comment: ""),
            layout: .leading,
            items: [statusItem],
            actions: [connectButton, scanButton]
        )
    }

    // MARK: - Connected State (Main Dashboard)

    private func buildConnectedTemplate() -> CPInformationTemplate {
        var items: [CPInformationItem] = []

        // Current Pressure with visual bar
        let pressureBar = buildPressureBar(current: currentPressure, target: targetPressure, max: 50.0)
        items.append(CPInformationItem(
            title: L("current_pressure", comment: ""),
            detail: String(format: "%.1f PSI  %@", currentPressure, pressureBar)
        ))

        // Target Pressure
        let targetDetail: String
        if targetPressure > 0 {
            targetDetail = String(format: "%.1f PSI", targetPressure)
        } else {
            targetDetail = L("auto_select_target", comment: "")
        }
        items.append(CPInformationItem(
            title: L("target_pressure", comment: ""),
            detail: targetDetail
        ))

        // Operation Status
        let statusText: String
        if isTargetReached {
            statusText = L("pressure_reached", comment: "")
        } else if operationMode == DeviceStatus.modeInflate {
            statusText = "▶ " + L("mode_inflating", comment: "")
        } else if operationMode == DeviceStatus.modeDeflate {
            statusText = "▶ " + L("mode_deflating", comment: "")
        } else {
            statusText = L("connected", comment: "")
        }
        items.append(CPInformationItem(
            title: L("auto_operation_status", comment: ""),
            detail: statusText
        ))

        // Device name
        if let name = bleManager.connectedDeviceName {
            items.append(CPInformationItem(
                title: L("auto_device", comment: ""),
                detail: name
            ))
        }

        // Action buttons
        var actions: [CPTextButton] = []

        let isOperating = operationMode == DeviceStatus.modeInflate || operationMode == DeviceStatus.modeDeflate

        if isOperating {
            let stopButton = CPTextButton(
                title: "⏹ " + L("stop", comment: ""),
                textStyle: .cancel
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.bleManager.stopOperation()
                }
            }
            actions.append(stopButton)
        } else {
            let startButton = CPTextButton(
                title: "▶ " + L("start", comment: ""),
                textStyle: .confirm
            ) { [weak self] _ in
                self?.presentTargetSelection()
            }
            actions.append(startButton)
        }

        let disconnectButton = CPTextButton(
            title: L("disconnect_device", comment: ""),
            textStyle: .normal
        ) { [weak self] _ in
            Task { @MainActor in
                self?.bleManager.disconnect()
            }
        }
        actions.append(disconnectButton)

        return CPInformationTemplate(
            title: L("auto_app_title", comment: ""),
            layout: .leading,
            items: items,
            actions: actions
        )
    }

    // MARK: - Target Pressure Selection

    private func presentTargetSelection() {
        let presets: [Double] = [8, 10, 12, 16, 20, 30, 38, 40]

        var actions: [CPAlertAction] = presets.map { pressure in
            CPAlertAction(
                title: String(format: "%.0f PSI", pressure),
                style: .default
            ) { [weak self] _ in
                guard let self else { return }
                self.targetPressure = pressure
                self.isTargetReached = false
                Task { @MainActor in
                    self.bleManager.startInflation(targetPressure: pressure)
                }
                self.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }
        }

        actions.append(CPAlertAction(
            title: L("cancel", comment: ""),
            style: .cancel
        ) { _ in })

        let sheet = CPActionSheetTemplate(
            title: L("select_target_pressure", comment: ""),
            message: L("auto_choose_pressure", comment: ""),
            actions: actions
        )

        interfaceController?.presentTemplate(sheet, animated: true, completion: nil)
    }

    // MARK: - Target Reached Alert

    private func showTargetReachedAlert(target: Double, current: Double) {
        let okAction = CPAlertAction(
            title: "OK",
            style: .default
        ) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }

        let alert = CPAlertTemplate(
            titleVariants: [L("target_reached_title", comment: "")],
            actions: [okAction]
        )

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }

    // MARK: - Pressure Bar Visualization

    private func buildPressureBar(current: Double, target: Double, max: Double) -> String {
        let barLength = 10
        let filled = Int(min(current / max, 1.0) * Double(barLength))
        let targetPos = target > 0 ? Int(min(target / max, 1.0) * Double(barLength)) : -1

        var bar = ""
        for i in 0..<barLength {
            if i < filled {
                bar += "█"
            } else if i == targetPos {
                bar += "▏"
            } else {
                bar += "░"
            }
        }
        return "[\(bar)]"
    }
}
