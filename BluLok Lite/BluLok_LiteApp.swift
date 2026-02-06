//
//  BluLok_DemoApp.swift
//  BluLok Demo
//
//  Created by Tulsi Vanol on 2026-01-22.
//

import SwiftUI

@main
struct BluLok_LiteApp: App {
    @StateObject private var ble = BLEManager()
    @StateObject private var frameResources = AnimationFrameResources()
    var body: some Scene {
        WindowGroup {
            if ble.isConnected {
                HomeView(ble: ble, frameResources: frameResources)
            } else {
                DevicePickerView(ble: ble)
            }
        }
    }
}
