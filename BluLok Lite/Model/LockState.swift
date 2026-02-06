//
//  LockState.swift
//  BluLok Demo
//
//  Matches Android: LockState (1–5) and BatteryReleaseState (0–1).
//

import Foundation

/// Lock hardware state from BLE characteristic (first byte). 1=connected, 2=armed, 3=open in progress, 4=open, 5=close.
enum LockState: Int, CaseIterable {
    case connected = 1
    case armed = 2
    case openInProgress = 3
    case open = 4
    case close = 5

    init?(byte: UInt8?) {
        guard let b = byte else { return nil }
        self.init(rawValue: Int(b))
    }

    var title: String {
        switch self {
        case .connected: return "Connected"
        case .armed: return "Armed"
        case .openInProgress: return "Open in progress"
        case .open: return "Open"
        case .close: return "Close"
        }
    }

    /// Animation frame index for LockAnimationView (matches Android frame mapping).
    var targetFrame: Int {
        switch self {
        case .connected: return 30
        case .armed: return 45
        case .openInProgress: return 65
        case .open: return 75
        case .close: return 113
        }
    }
}

/// Battery release characteristic: 1 = removable, 0 = not ready.
enum BatteryReleaseState: Int, CaseIterable {
    case notReady = 0
    case canRemove = 1

    init?(byte: UInt8?) {
        guard let b = byte else { return nil }
        self.init(rawValue: Int(b))
    }

    var title: String {
        switch self {
        case .notReady: return "Battery not ready"
        case .canRemove: return "Battery ready"
        }
    }
}

/// Battery eject UI flow (matches Android BatteryEjectStep). Drives battery animation target frame.
enum BatteryEjectStep {
    case idle           // No flow started
    case instruction    // Step 1 shown (blue segment)
    case armed          // Step 2 ready (button shows Arm Eject)
    case sent           // Command sent (green + eject animation)

    /// Target frame for BatteryAnimationView (matches Android BatteryAnimation.kt stepToTarget).
    var targetFrame: Int {
        switch self {
        case .idle: return 0
        case .instruction, .armed: return 45   // End of BLUE instruction segment
        case .sent: return 113                 // End of GREEN eject segment
        }
    }
}
