//
//  LockState.swift
//  BluLok Demo
//
//  Matches Android: LockState (unknown, 1–6) and BatteryReleaseState (0–1).
//

import Foundation

/// Lock hardware state from BLE characteristic (first byte). Matches Android: unknown, 1=connected, 2=armed, 3=ready, 4=open in progress, 5=open, 6=close.
enum LockState: Int, CaseIterable {
    case unknown = 0
    case connected = 1
    case armed = 2
    case ready = 3
    case openInProgress = 4
    case open = 5
    case close = 6

    init?(byte: UInt8?) {
        guard let b = byte else { return nil }
        let v = Int(b)
        switch v {
        case 0, 255: self = .unknown
        case 1: self = .connected
        case 2: self = .armed
        case 3: self = .ready
        case 4: self = .openInProgress
        case 5: self = .open
        case 6: self = .close
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .unknown: return "Unknown"
        case .connected: return "Connected"
        case .armed: return "Armed"
        case .ready: return "Ready"
        case .openInProgress: return "Open in progress"
        case .open: return "Open"
        case .close: return "Close"
        }
    }

    /// Description for UI (matches Android LockState.description).
    var description: String {
        switch self {
        case .unknown: return "Unknown handle position"
        case .connected: return "Lock is ready. Tap Open to arm."
        case .armed: return "Electromagnet primed. Pull latch within ~30s."
        case .ready: return "Lock is ready. Tap Open to arm."
        case .openInProgress: return "Latch moving; electromagnet firing."
        case .open: return "Latch open. Close the door to relock."
        case .close: return "Relock confirmed. Ready for next use."
        }
    }

    /// BLE/code value for animation (matches Android LockState.code). Used for lock target frame mapping.
    var code: Int {
        switch self {
        case .unknown: return -1
        case .connected: return 1
        case .armed: return 2
        case .ready: return 3
        case .openInProgress: return 4
        case .open: return 5
        case .close: return 6
        }
    }

    /// Animation frame index (matches Android LockAnimation.kt targetForState: when(lockState?.code) { 2,3->45, 4->65, 5->75, 6->113, else->30 }).
    var targetFrame: Int {
        switch code {
        case 2, 3: return 45
        case 4: return 65
        case 5: return 75
        case 6: return 113
        default: return 30
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
    case idle
    case instruction
    case armed
    case sent
    case ejected

    /// Target frame for BatteryAnimationView (matches Android BatteryAnimation.kt stepToTarget).
    var targetFrame: Int {
        switch self {
        case .idle: return 0
        case .instruction, .armed: return 77
        case .sent: return 122
        case .ejected: return 162
        }
    }
}
