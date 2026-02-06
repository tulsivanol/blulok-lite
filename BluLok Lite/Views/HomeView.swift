//
//  HomeView.swift
//  BluLok Demo
//
//  Matches Android UI: no app bar, Status card, Big Lock/Battery (Lottie + text), Actions row, Error card.
//

import SwiftUI

// MARK: - Lock state text (match Android)
private func lockStateText(_ state: LockState?) -> String {
    guard let s = state else { return "Waiting for lock…" }
    switch s {
    case .connected: return "Lock is ready. Tap Open to arm."
    case .armed: return "Key engaged. Pull the latch within ~30s."
    case .openInProgress: return "Latch moving. Pull to open."
    case .open: return "Latch open. Close the door to relock."
    case .close: return "Key removed. Ready for next use."
    }
}

private func targetFrame(_ state: LockState?) -> Int {
    guard let s = state else { return 30 }
    switch s {
    case .connected: return 30
    case .armed: return 45
    case .openInProgress: return 65
    case .open: return 75
    case .close: return 113
    }
}


// Lock Lottie progress (match Android frame mapping: 0, 50, 95, 103; close=0)
private func lockProgress(_ state: LockState?) -> CGFloat {
    let total: CGFloat = 300
    guard let s = state else { return 0 }
    switch s {
    case .connected: return 0 / total
    case .armed: return 50 / total
    case .openInProgress: return 95 / total
    case .open: return 103 / total
    case .close: return 0
    }
}

private func batteryStatusText(_ state: BatteryReleaseState?) -> String {
    guard let s = state else { return "Waiting for battery state…" }
    switch s {
    case .canRemove: return "You can remove the battery now."
    case .notReady: return "Release the latch first, then remove when it shows ready."
    }
}

/// Battery status text driven by step (matches Android BatteryAnimationContainer).
private func batteryStatusTextForStep(_ step: BatteryEjectStep) -> String {
    switch step {
    case .idle: return "Tap Battery Eject to start."
    case .instruction, .armed: return "Firmly depress battery, then press Arm Eject button."
    case .sent: return "Quickly release battery to eject."
    }
}

// MARK: - Android-style dimensions (Responsive.kt: 1 dp ≈ 1 pt)
private let kContentPaddingH: CGFloat = 16
private let kContentPaddingV: CGFloat = 12
private let kCardPadding: CGFloat = 14
private let kSpacingBetweenCards: CGFloat = 14
private let kSpacingInsideCard: CGFloat = 10
/// Lottie size: compact so it never overlaps status text or Actions (max 100pt).
private let kBigStatusSize: CGFloat = 100

struct HomeView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var frameResources: AnimationFrameResources

    /// Matches Android: "unlock" | "battery" | ""; empty or unlock → lock view, battery → battery view.
    @State private var commandType: String = ""
    /// Matches Android BatteryEjectStep: Idle → Instruction → Sent (Armed optional).
    @State private var batteryStep: BatteryEjectStep = .idle

    var body: some View {
        ScrollView {
            VStack(spacing: kSpacingBetweenCards) {
                statusCard
                if ble.isConnected {
                    bigStatusSection
                }
                actionsSection
                if let err = ble.errorText, !err.isEmpty {
                    errorCard(err)
                }
            }
            .padding(.horizontal, kContentPaddingH)
            .padding(.top, kContentPaddingV)
            .padding(.bottom, kContentPaddingV * 2)
        }
        .navigationBarHidden(true)
        .onChange(of: ble.batteryState) { _, newValue in
            if newValue == .notReady {
                commandType = ""
                batteryStep = .idle
            } else if newValue == .canRemove {
                batteryStep = .sent
            }
        }
    }
    
    // MARK: - Status Card (Android ElevatedCard + cardPadding + spacingInsideCard)
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: kSpacingInsideCard) {
            HStack(alignment: .center, spacing: kSpacingInsideCard) {
                Image(systemName: ble.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ble.isConnected ? Color(red: 0.18, green: 0.49, blue: 0.2) : Color.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(ble.connectedName ?? "No device")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(ble.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if ble.isConnecting {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }
            
            if ble.isConnected {
                Button { ble.disconnect() } label: {
                    Label("Disconnect", systemImage: "bolt.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button { ble.startScan() } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(kCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
    
    // MARK: - Big status (Android: BigLockStatus / BatteryAnimation – Lottie + text, spacingInsideCard)
    private var bigStatusSection: some View {
        Group {
            if commandType == "battery" {
                batteryStatusView
            } else {
                lockStatusView
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var lockStatusView: some View {
        VStack(spacing: 10) {
            lockAnimationContent
            Text(lockStateText(ble.lockState))
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
        .onAppear { frameResources.requestLockFrames() }
    }

    @ViewBuilder
    private var lockAnimationContent: some View {
        if frameResources.isLockLoading {
            VStack(spacing: 8) {
                ProgressView(value: frameResources.loadingProgress)
                    .progressViewStyle(.linear)
                Text("Loading lock animation…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else if !frameResources.lockFrames.isEmpty {
            LockAnimationView(lockState: ble.lockState, frames: frameResources.lockFrames)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var batteryStatusView: some View {
        VStack(spacing: 10) {
            batteryAnimationContent
            Text(batteryStatusTextForStep(batteryStep))
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
        .onAppear { frameResources.requestBatteryFrames() }
    }

    @ViewBuilder
    private var batteryAnimationContent: some View {
        if frameResources.isBatteryLoading {
            VStack(spacing: 8) {
                ProgressView(value: frameResources.loadingProgress)
                    .progressViewStyle(.linear)
                Text("Loading battery animation…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else if !frameResources.batteryFrames.isEmpty {
            BatteryAnimationView(batteryStep: batteryStep, frames: frameResources.batteryFrames)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var batteryButtonTitle: String {
        switch batteryStep {
        case .idle: return "Battery Eject"
        case .instruction, .armed: return "Arm Eject"
        case .sent: return "Ejecting…"
        }
    }

    private var batteryButtonInfo: String {
        switch batteryStep {
        case .idle: return "Tap Battery Eject to begin."
        case .instruction, .armed: return "Firmly depress battery, then press Arm Eject button."
        case .sent: return "Quickly release battery to eject."
        }
    }

    // MARK: - Actions (Android: titleSmall + bodySmall + Row spacedBy(12), ActionCard weight(1))
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.subheadline.weight(.semibold))
            Text("Open arms the lock (~30s). Pull the latch to unlock; close the door to relock.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack(alignment: .top, spacing: 12) {
                actionCard(
                    title: "Open",
                    info: "Pull latch within ~30s",
                    icon: "lock.open.fill",
                    enabled: ble.isConnected
                ) {
                    commandType = "unlock"
                    ble.sendUnlock()
                }
                actionCard(
                    title: batteryButtonTitle,
                    info: batteryButtonInfo,
                    icon: "battery.100.bolt",
                    enabled: ble.isConnected && batteryStep != .sent
                ) {
                    commandType = "battery"
                    switch batteryStep {
                    case .idle:
                        batteryStep = .instruction
                    case .instruction, .armed:
                        ble.releaseBattery()
                        // Sent is set only when BLE reports .canRemove (in onChange below), matching Android LaunchedEffect(batteryState)
                    case .sent:
                        break
                    }
                }
            }
        }
    }
    
    private func actionCard(
        title: String,
        info: String,
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(enabled ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(enabled ? Color.accentColor : .secondary)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(enabled ? Color.primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(info)
                    .font(.caption2)
                    .foregroundStyle(enabled ? Color.primary.opacity(0.8) : .secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .frame(height: 120)
            .background(enabled ? Color(.secondarySystemBackground) : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(enabled ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
    
    // MARK: - Error Card (match Android)
    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Issue")
                    .font(.subheadline.weight(.semibold))
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(kCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(ble: {
            let bleManager = BLEManager()
            bleManager.isConnected = true
            return bleManager
        }(), frameResources: AnimationFrameResources())
    }
}
