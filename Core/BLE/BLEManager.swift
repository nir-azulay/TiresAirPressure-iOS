import Foundation
import CoreBluetooth
import Combine

@MainActor
class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredDevices: [BLEDevice] = []
    @Published var connectedDeviceName: String?
    @Published var deviceStatus: DeviceStatus?
    @Published var deviceSettings: DeviceSettings?
    @Published var isScanning: Bool = false

    let targetReachedSubject = PassthroughSubject<(target: Double, current: Double), Never>()

    // MARK: - Internal (for ConnectionView access)
    private(set) var connectedPeripheral: CBPeripheral?

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var commandCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private var scanTimer: Timer?
    private var connectionTimer: Timer?
    private var connectionStartTime: Date?

    private let serviceUUID = CBUUID(string: BLEConstants.serviceUUID)
    private let commandUUID = CBUUID(string: BLEConstants.commandCharacteristicUUID)
    private let notifyUUID = CBUUID(string: BLEConstants.notifyCharacteristicUUID)

    private var messageBuffer = ""
    private var writeQueue: [Data] = []
    private var isWriting = false

    private var settingsRequestAttempts = 0
    private let maxSettingsRequestAttempts = 3
    private var ignoreNextStatusUpdate = false

    private var autoConnectTask: Task<Void, Never>?
    private var debugSyncTask: Task<Void, Never>?

    private var settingsManager: SettingsManager?

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func setSettingsManager(_ manager: SettingsManager) {
        self.settingsManager = manager
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .bluetoothDisabled
            return
        }

        connectionState = .scanning
        isScanning = true
        discoveredDevices.removeAll()

        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        scanTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.scanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScanning()
            }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil

        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    // MARK: - Connection

    func connect(to device: BLEDevice) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        connectionStartTime = Date()

        centralManager.connect(device.peripheral, options: nil)

        connectionTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.connectionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleConnectionTimeout()
            }
        }
    }

    func connectByIdentifier(_ identifier: UUID) {
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
        guard let peripheral = peripherals.first else {
            print("[BLEManager] No peripheral found for identifier: \(identifier)")
            return
        }

        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionStartTime = Date()
        centralManager.connect(peripheral, options: nil)

        connectionTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.connectionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleConnectionTimeout()
            }
        }
    }

    func disconnect() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        autoConnectTask?.cancel()
        debugSyncTask?.cancel()

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        connectedPeripheral = nil
        commandCharacteristic = nil
        notifyCharacteristic = nil
        connectedDeviceName = nil
        deviceStatus = nil
        deviceSettings = nil
        messageBuffer = ""
        writeQueue.removeAll()
        isWriting = false
        settingsRequestAttempts = 0
        connectionState = .disconnected
    }

    func forceReconnect() {
        guard let peripheral = connectedPeripheral else { return }
        let identifier = peripheral.identifier
        disconnect()

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.connectByIdentifier(identifier)
        }
    }

    // MARK: - Commands

    func sendCommand(_ command: BLECommand) {
        guard connectionState == .connected,
              let data = command.toJSONData() else {
            print("[BLEManager] Cannot send command: not connected or serialization failed")
            return
        }

        if case .startTargetPressure = command {
            ignoreNextStatusUpdate = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.ignoreNextStatusUpdate = false
            }
        } else if case .stop = command {
            ignoreNextStatusUpdate = false
        }

        print("[BLEManager] Queueing command: \(String(data: data, encoding: .utf8) ?? "")")
        writeQueue.append(data)
        processWriteQueue()
    }

    func startInflation(targetPressure: Double) {
        sendCommand(.startTargetPressure(targetPressure: targetPressure))
    }

    func startDeflation(targetPressure: Double) {
        sendCommand(.startTargetPressure(targetPressure: targetPressure))
    }

    func stopOperation() {
        sendCommand(.stop)
    }

    func requestSettings() {
        sendCommand(.requestSettings)
    }

    func requestStatus() {
        sendCommand(.requestStatus)
    }

    func updateSettings(_ settings: DeviceSettings) {
        sendCommand(.updateSettings(settings))
    }

    func sendDebugMode(enabled: Bool) {
        sendCommand(.debugMode(enabled: enabled))
    }

    func sendSimulationMode(enabled: Bool) {
        sendCommand(.simulationMode(enabled: enabled))
    }

    // MARK: - Auto-Connect

    func connectToSavedDevices() {
        let savedDevices = getSavedDevices()
        guard !savedDevices.isEmpty else {
            startScanning()
            return
        }

        autoConnectTask?.cancel()
        autoConnectTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            for saved in savedDevices {
                guard !Task.isCancelled else { return }
                if let uuid = UUID(uuidString: saved.address) {
                    for attempt in 1...3 {
                        guard !Task.isCancelled else { return }
                        print("[BLEManager] Auto-connect attempt \(attempt) to \(saved.name)")
                        self.connectByIdentifier(uuid)
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if self.connectionState == .connected {
                            return
                        }
                    }
                }
            }
            if self.connectionState != .connected {
                self.startScanning()
            }
        }
    }

    // MARK: - Write Queue

    private func processWriteQueue() {
        guard !isWriting, !writeQueue.isEmpty else { return }
        guard let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic else {
            writeQueue.removeAll()
            return
        }

        isWriting = true
        let data = writeQueue.removeFirst()
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    // MARK: - Message Parsing

    private func handleReceivedData(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }

        messageBuffer += chunk

        while let range = messageBuffer.range(of: "}") {
            let jsonString = String(messageBuffer[messageBuffer.startIndex...range.lowerBound])
            messageBuffer = String(messageBuffer[range.upperBound...])
            processMessage(jsonString)
        }
    }

    private func sanitizeJSON(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(of: "'", with: "\"")
        // Add double quotes around unquoted keys: { key: "val" } -> { "key": "val" }
        let keyPattern = try! NSRegularExpression(pattern: "(?<=\\{|,)\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*:")
        s = keyPattern.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " \"$1\":")
        return s
    }

    private func processMessage(_ jsonString: String) {
        print("[BLEManager] Processing message: \(jsonString)")

        let sanitized = sanitizeJSON(jsonString)
        guard let data = sanitized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("[BLEManager] Failed to parse JSON: \(jsonString)")
            return
        }

        if let type = json["type"] as? String, type == "target_reached" {
            let targetPressure = parseDouble(json["targetPressure"]) ?? 0
            let currentPressure = parseDouble(json["currentPressure"]) ?? 0
            print("[BLEManager] Target reached: target=\(targetPressure), current=\(currentPressure)")
            SoundManager.shared.playTargetReachedSound()
            targetReachedSubject.send((target: targetPressure, current: currentPressure))
            return
        }

        if json["DeviceName"] != nil {
            let settings = DeviceSettings.from(json: json)
            deviceSettings = settings
            onDeviceFullSettingsReceived(settings)
            return
        }

        let hasPressure = json["CurrentPressure"] != nil || json["Pressure"] != nil
        let hasOperationMode = json["operationMode"] != nil

        if hasPressure && hasOperationMode {
            let pressure: Double
            if let p = parseDouble(json["CurrentPressure"]) {
                pressure = p
            } else if let p = parseDouble(json["Pressure"]) {
                pressure = p
            } else {
                pressure = 0
            }

            let operationMode = parseInt(json["operationMode"]) ?? BLEConstants.modeSettings
            let rawADC = parseStringThenInt(json["rawADC"])
            let voltage = parseStringThenDouble(json["voltage"])

            let status = DeviceStatus(
                pressure: pressure,
                operationMode: operationMode,
                rawADC: rawADC,
                voltage: voltage
            )

            print("[BLEManager] DeviceStatus: pressure=\(pressure), mode=\(operationMode), rawADC=\(rawADC.map { String($0) } ?? "nil"), voltage=\(voltage.map { String($0) } ?? "nil")")
            onDeviceStatusReceived(status)
            return
        }

        print("[BLEManager] Unrecognized message: \(jsonString)")
    }

    private func onDeviceStatusReceived(_ status: DeviceStatus) {
        if ignoreNextStatusUpdate {
            ignoreNextStatusUpdate = false
            print("[BLEManager] Ignoring first status update after inflate/deflate command")
            return
        }
        deviceStatus = status
    }

    private func onDeviceFullSettingsReceived(_ settings: DeviceSettings) {
        let pressureValue = settings.currentPressure
        let currentStatus = deviceStatus
        deviceStatus = DeviceStatus(
            pressure: pressureValue,
            operationMode: settings.operationMode,
            rawADC: currentStatus?.rawADC,
            voltage: currentStatus?.voltage
        )
        print("[BLEManager] Updated DeviceStatus from full settings, preserved debug values")
    }

    // MARK: - Debug Mode Sync

    private func syncDebugModeAfterConnection() {
        debugSyncTask?.cancel()
        debugSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, let self = self else { return }
            let debugEnabled = self.settingsManager?.debugMode ?? false
            print("[BLEManager] Syncing debug mode on connection: \(debugEnabled)")
            self.sendDebugMode(enabled: debugEnabled)
        }
    }

    // MARK: - Settings Request Scheduling

    private func scheduleSettingsRequest() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self = self else { return }
            if self.deviceSettings == nil && self.settingsRequestAttempts < self.maxSettingsRequestAttempts {
                self.settingsRequestAttempts += 1
                print("[BLEManager] Requesting settings (attempt \(self.settingsRequestAttempts))")
                self.requestSettings()
                if self.settingsRequestAttempts < self.maxSettingsRequestAttempts {
                    self.scheduleSettingsRequest()
                }
            }
        }
    }

    // MARK: - Connection Timeout

    private func handleConnectionTimeout() {
        if connectionState == .connecting {
            disconnect()
            connectionState = .connectionError
        }
    }

    // MARK: - JSON Parsing Helpers

    private func parseDouble(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private func parseInt(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? Double { return Int(n) }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private func parseStringThenInt(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        if let s = value as? String { return Int(s) }
        if let n = value as? Double { return Int(n) }
        return nil
    }

    private func parseStringThenDouble(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let s = value as? String { return Double(s) }
        if let n = value as? Int { return Double(n) }
        return nil
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            switch central.state {
            case .poweredOn:
                self.connectionState = .disconnected
                self.connectToSavedDevices()
            case .poweredOff, .unauthorized, .unsupported:
                self.connectionState = .bluetoothDisabled
                self.disconnect()
            case .resetting:
                self.connectionState = .connectionError
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                     advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let device = BLEDevice(
                peripheral: peripheral,
                advertisementData: advertisementData,
                rssi: RSSI.intValue
            )

            if let index = self.discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
                self.discoveredDevices[index] = device
            } else {
                self.discoveredDevices.append(device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.connectionTimer?.invalidate()
            self.connectionTimer = nil

            self.connectionState = .connected
            self.connectedDeviceName = peripheral.name ?? "Unknown Device"
            SoundManager.shared.playConnectionSound()

            if let device = self.discoveredDevices.first(where: { $0.peripheral.identifier == peripheral.identifier }) {
                self.saveDevice(device)
            }

            peripheral.discoverServices([self.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            self?.connectionTimer?.invalidate()
            self?.connectionTimer = nil
            self?.connectionState = .connectionError
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            self?.disconnect()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self, error == nil, let services = peripheral.services else {
                self?.connectionState = .connectionError
                return
            }

            for service in services where service.uuid == self.serviceUUID {
                peripheral.discoverCharacteristics([self.commandUUID, self.notifyUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self, error == nil, let characteristics = service.characteristics else {
                self?.connectionState = .connectionError
                return
            }

            for characteristic in characteristics {
                switch characteristic.uuid {
                case self.commandUUID:
                    self.commandCharacteristic = characteristic
                case self.notifyUUID:
                    self.notifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                default:
                    break
                }
            }

            if self.commandCharacteristic != nil && self.notifyCharacteristic != nil {
                self.settingsRequestAttempts = 0
                self.scheduleSettingsRequest()
                self.syncDebugModeAfterConnection()
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            guard error == nil, let data = characteristic.value else { return }
            self?.handleReceivedData(data)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let error = error {
                print("[BLEManager] Write error: \(error.localizedDescription)")
            }
            self.isWriting = false

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.processWriteQueue()
            }
        }
    }
}

// MARK: - Device Management
extension BLEManager {
    func getSavedDevices() -> [SavedDevice] {
        return SavedDevice.load().sorted { $0.connectionPriority < $1.connectionPriority }
    }

    func saveDevice(_ device: BLEDevice) {
        var savedDevices = SavedDevice.load()
        if savedDevices.count >= 2 {
            if !savedDevices.contains(where: { $0.address == device.address }) {
                return
            }
        }

        if let index = savedDevices.firstIndex(where: { $0.address == device.address }) {
            savedDevices[index].connectionPriority = 0
            for i in savedDevices.indices where i != index {
                savedDevices[i].connectionPriority = savedDevices[i].connectionPriority + 1
            }
        } else {
            for i in savedDevices.indices {
                savedDevices[i].connectionPriority += 1
            }
            let saved = SavedDevice(
                name: device.name,
                address: device.address,
                connectionPriority: 0
            )
            savedDevices.append(saved)
        }

        SavedDevice.save(savedDevices)
    }

    func deleteDevice(_ address: String) {
        var savedDevices = SavedDevice.load()
        savedDevices.removeAll { $0.address == address }
        for i in savedDevices.indices {
            savedDevices[i].connectionPriority = i
        }
        SavedDevice.save(savedDevices)
    }

    func reorderDevices(_ addressOrder: [String]) {
        let savedDevices = SavedDevice.load()
        var reordered: [SavedDevice] = []
        for (index, address) in addressOrder.enumerated() {
            if var device = savedDevices.first(where: { $0.address == address }) {
                device.connectionPriority = index
                reordered.append(device)
            }
        }
        SavedDevice.save(reordered)
    }
}
