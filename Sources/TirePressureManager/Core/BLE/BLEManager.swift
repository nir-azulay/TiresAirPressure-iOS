import Foundation
import CoreBluetooth
import Combine

/// Main BLE manager responsible for device discovery, connection, and communication
@MainActor
class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredDevices: [BLEDevice] = []
    @Published var connectedDeviceName: String?
    @Published var deviceStatus: DeviceStatus?
    @Published var deviceSettings: DeviceSettings?
    @Published var isScanning: Bool = false

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private var scanTimer: Timer?
    private var connectionTimer: Timer?
    private var connectionStartTime: Date?

    private let serviceUUID = CBUUID(string: BLEConstants.serviceUUID)
    private let commandUUID = CBUUID(string: BLEConstants.commandCharacteristicUUID)
    private let notifyUUID = CBUUID(string: BLEConstants.notifyCharacteristicUUID)

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public Methods

    /// Start scanning for BLE devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .bluetoothDisabled
            return
        }

        connectionState = .scanning
        isScanning = true
        discoveredDevices.removeAll()

        // Scan for devices with our service UUID
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after timeout
        scanTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.scanTimeout, repeats: false) { _ in
            self.stopScanning()
        }
    }

    /// Stop scanning for BLE devices
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil

        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    /// Connect to a specific BLE device
    func connect(to device: BLEDevice) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        connectionStartTime = Date()

        centralManager.connect(device.peripheral, options: nil)

        // Set connection timeout
        connectionTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.connectionTimeout, repeats: false) { _ in
            self.disconnect()
            self.connectionState = .connectionError
        }
    }

    /// Disconnect from the current device
    func disconnect() {
        connectionTimer?.invalidate()
        connectionTimer = nil

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        connectedPeripheral = nil
        commandCharacteristic = nil
        notifyCharacteristic = nil
        connectedDeviceName = nil
        deviceStatus = nil
        connectionState = .disconnected
    }

    /// Send inflation command to the device
    func startInflation(targetPressure: Double) {
        guard let data = BLECommand.inflateToTarget(targetPressure) else { return }
        sendCommand(data)
    }

    /// Send deflation command to the device
    func startDeflation(targetPressure: Double) {
        guard let data = BLECommand.deflateToTarget(targetPressure) else { return }
        sendCommand(data)
    }

    /// Stop current operation
    func stopOperation() {
        guard let data = BLECommand.stopOperation.toJSONData() else { return }
        sendCommand(data)
    }

    /// Request device status
    func requestStatus() {
        guard let data = BLECommand.getStatus.toJSONData() else { return }
        sendCommand(data)
    }

    /// Request device settings
    func requestSettings() {
        guard let data = BLECommand.getSettings.toJSONData() else { return }
        sendCommand(data)
    }

    /// Update device settings
    func updateSettings(_ settings: DeviceSettings) {
        guard let data = BLECommand.updateSettings(settings) else { return }
        sendCommand(data)
    }

    // MARK: - Private Methods

    private func sendCommand(_ data: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic,
              connectionState == .connected else {
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func handleReceivedData(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String: Any] else { return }

            // Handle different message types
            if let statusDict = dict["status"] as? [String: Any] {
                handleStatusUpdate(statusDict)
            } else if let settingsDict = dict["settings"] as? [String: Any] {
                handleSettingsUpdate(settingsDict)
            }
        } catch {
            print("Error parsing received data: \(error)")
        }
    }

    private func handleStatusUpdate(_ statusDict: [String: Any]) {
        guard let currentPressure = statusDict["currentPressure"] as? Double else { return }

        let targetPressure = statusDict["targetPressure"] as? Double
        let isInflating = statusDict["isInflating"] as? Bool ?? false
        let isDeflating = statusDict["isDeflating"] as? Bool ?? false
        let batteryLevel = statusDict["batteryLevel"] as? Int

        deviceStatus = DeviceStatus(
            currentPressure: currentPressure,
            targetPressure: targetPressure,
            isInflating: isInflating,
            isDeflating: isDeflating,
            batteryLevel: batteryLevel
        )
    }

    private func handleSettingsUpdate(_ settingsDict: [String: Any]) {
        do {
            let settingsData = try JSONSerialization.data(withJSONObject: settingsDict, options: [])
            deviceSettings = try JSONDecoder().decode(DeviceSettings.self, from: settingsData)
        } catch {
            print("Error decoding device settings: \(error)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if connectionState == .bluetoothDisabled {
                connectionState = .disconnected
            }
        case .poweredOff, .unauthorized, .unsupported:
            connectionState = .bluetoothDisabled
            disconnect()
        case .resetting:
            connectionState = .connectionError
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let device = BLEDevice(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI.intValue
        )

        // Update existing device or add new one
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimer?.invalidate()
        connectionTimer = nil

        connectionState = .connected
        connectedDeviceName = peripheral.name ?? "Unknown Device"

        // Discover services
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimer?.invalidate()
        connectionTimer = nil
        connectionState = .connectionError
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        disconnect()
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let services = peripheral.services else {
            connectionState = .connectionError
            return
        }

        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([commandUUID, notifyUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let characteristics = service.characteristics else {
            connectionState = .connectionError
            return
        }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case commandUUID:
                commandCharacteristic = characteristic
            case notifyUUID:
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }

        // Request initial status when connected
        if commandCharacteristic != nil && notifyCharacteristic != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.requestStatus()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              let data = characteristic.value else {
            return
        }

        handleReceivedData(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error)")
        }
    }
}