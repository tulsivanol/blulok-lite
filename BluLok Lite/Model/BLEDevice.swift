//
//  BLEDevice.swift
//  BluLok Demo
//
//  Created by Tulsi Vanol on 2026-01-22.
//

import Foundation
import CoreBluetooth

struct BLEDevice: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
    var peripheral: CBPeripheral

    var addressLike: String {
        // iOS doesn't expose MAC address. Use UUID.
        id.uuidString
    }
}
