//
//  BLEManager.swift
//  BluLok Demo
//
//  Created by Tulsi Vanol on 2026-01-22.
//

import Foundation
import CoreBluetooth
import Combine

final class BLEManager: NSObject, ObservableObject {

    private let controlServiceUUID     = CBUUID(string: "374E0100-02A1-4BE2-B1CE-4CAE91CF080E")
    private let unlockCharUUID         = CBUUID(string: "374E0102-02A1-4BE2-B1CE-4CAE91CF080E")
    private let releaseCharUUID        = CBUUID(string: "374E0103-02A1-4BE2-B1CE-4CAE91CF080E")

    // MARK: - Published State
    @Published var devices: [BLEDevice] = []
    @Published var isScanning: Bool = false
    @Published var statusText: String = "Tap Scan to find devices"
    @Published var isConnecting: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectedName: String? = nil
    @Published var errorText: String? = nil
    @Published var lockState: LockState? = nil
    @Published var batteryState: BatteryReleaseState? = nil

    private var central: CBCentralManager!
    private var deviceMap: [UUID: BLEDevice] = [:]

    private var connectedPeripheral: CBPeripheral?
    private var unlockChar: CBCharacteristic?
    private var releaseChar: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        errorText = nil
        devices = []
        deviceMap.removeAll()

        guard central.state == .poweredOn else {
            statusText = "Bluetooth is not enabled"
            return
        }

        statusText = "Scanning for devices…"
        isScanning = true

        // Filter only peripherals advertising your service UUID
        central.scanForPeripherals(
            withServices: [],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        statusText = "Scan stopped"
    }

    func connect(_ device: BLEDevice) {
        stopScan()
        errorText = nil
        isConnecting = true
        statusText = "Connecting to \(device.name)…"

        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self

        central.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        guard let p = connectedPeripheral else { return }
        isConnecting = false
        central.cancelPeripheralConnection(p)
    }

    // Actions (like your Android buttons)
    func sendUnlock() {
        write(value: Data([0x01]), to: unlockChar)
    }

    func releaseBattery() {
        write(value: Data([0x00]), to: releaseChar)
    }

    private func write(value: Data, to characteristic: CBCharacteristic?) {
        guard let p = connectedPeripheral,
              let c = characteristic else {
            errorText = "Not ready to send command"
            return
        }
        print("Sending command: \(value.hexEncodedString()), for char: \(c.uuid.uuidString)")
        p.writeValue(value, for: c, type: .withResponse)
        statusText = "Command sent"
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusText = "Bluetooth ready"
        case .poweredOff:
            statusText = "Bluetooth is off"
        case .unauthorized:
            statusText = "Bluetooth permission denied"
        default:
            statusText = "Bluetooth not available"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        let id = peripheral.identifier
        let name = peripheral.name ?? "Unknown Device"
        let newRssi = RSSI.intValue
        
        if name.contains("BluLok") == false { return }

        if var existing = deviceMap[id] {
            let nameChanged = existing.name != name && name != "Unknown Device"
            let rssiChanged = existing.rssi != newRssi

            if nameChanged { existing.name = name }
            if rssiChanged { existing.rssi = newRssi }

            existing.peripheral = peripheral
            if nameChanged || rssiChanged {
                deviceMap[id] = existing
            } else {
                return
            }
        } else {
            deviceMap[id] = BLEDevice(
                id: id,
                name: name,
                rssi: newRssi,
                peripheral: peripheral
            )
        }
        devices = deviceMap.values.sorted { $0.rssi > $1.rssi }
    }


    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectedName = peripheral.name ?? "Connected"
        statusText = "Discovering services…"

        peripheral.discoverServices([controlServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        isConnected = false
        statusText = "Failed to connect"
        errorText = error?.localizedDescription ?? "Unknown error"
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        isConnected = false
        connectedName = nil
        unlockChar = nil
        releaseChar = nil
        lockState = nil
        batteryState = nil
        statusText = "Disconnected"
        if let error = error { errorText = error.localizedDescription }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            errorText = error.localizedDescription
            return
        }
        guard let services = peripheral.services else { return }

        for s in services where s.uuid == controlServiceUUID {
            statusText = "Discovering characteristics…"
            peripheral.discoverCharacteristics([unlockCharUUID, releaseCharUUID], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            errorText = error.localizedDescription
            return
        }

        guard let chars = service.characteristics else { return }

        for c in chars {
            if c.uuid == unlockCharUUID { unlockChar = c }
            if c.uuid == releaseCharUUID { releaseChar = c }
        }

        // Enable notifications (match Android) so we receive lock/battery state updates
        if let u = unlockChar { peripheral.setNotifyValue(true, for: u) }
        if let r = releaseChar { peripheral.setNotifyValue(true, for: r) }

        statusText = "Connected"
        isConnecting = false
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value, let first = data.first else { return }
        print("Received notification: \(first)")
        if characteristic.uuid == unlockCharUUID {
            lockState = LockState(byte: first)
        } else if characteristic.uuid == releaseCharUUID {
            batteryState = BatteryReleaseState(byte: first)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            errorText = error.localizedDescription
            statusText = "Write failed"
        } else {
            statusText = "Command sent ✓"
        }
    }
}

extension Data {
    func hexEncodedString() -> String {
        return self.reduce("") {
            $0 + String(format: "%02x", $1)
        }
    }
}
