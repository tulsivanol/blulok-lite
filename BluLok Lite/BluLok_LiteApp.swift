//
//  BluLok_DemoApp.swift
//  BluLok Demo
//
//  Matches Android: Home when connected or connection lost (Reconnect); Picker when user disconnected.
//

import SwiftUI

@main
struct BluLok_LiteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var ble = BLEManager()
    @StateObject private var frameResources = AnimationFrameResources()

    var body: some Scene {
        WindowGroup {
            if ble.isConnected || (ble.lastConnectedName != nil && !ble.didUserDisconnect) {
                HomeView(ble: ble, frameResources: frameResources)
            } else {
                DevicePickerView(ble: ble)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if !ble.isConnected, !ble.didUserDisconnect, ble.lastConnectedName != nil {
                    ble.reconnect()
                }
            case .background:
                if ble.isConnected {
                    ble.disconnect(userInitiated: false)
                }
            default:
                break
            }
        }
    }
}
