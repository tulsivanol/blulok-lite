//
//  HomeView.swift
//  BluLok Demo
//
//  Matches Android UI: no app bar, Status card, Big Lock/Battery (Lottie + text), Actions row, Error card.
//

import SwiftUI

// MARK: - Lock state text (match Android: use LockState.description)
private func lockStateText(_ state: LockState?) -> String {
    state?.description ?? "Waiting for lock…"
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
    case .ejected: return "Battery is removed from lock."
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
    /// Matches Android BatteryEjectStep: Idle → Instruction → Sent → Ejected.
    @State private var batteryStep: BatteryEjectStep = .idle
    /// Matches Android BluLokLite.isInitialCheck: show incomplete-lock until user taps Open.
    @State private var isInitialCheck: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: kSpacingBetweenCards) {
                statusCard
                // Always show lock/battery section (match Android: no if (isConnected) around big status Column).
                bigStatusSection
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
            guard let newValue else { return }
            if newValue == .notReady {
                commandType = ""
                batteryStep = .idle
            } else if newValue == .canRemove {
                batteryStep = .sent
            }
        }
        .onChange(of: ble.isConnected) { _, connected in
            if !connected, batteryStep == .sent {
                batteryStep = .ejected
            }
            if connected {
                batteryStep = .idle
            }
        }
    }
    
    // MARK: - Status Card (Android ElevatedCard + cardPadding + spacingInsideCard)
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: kSpacingInsideCard) {
            HStack(alignment: .center, spacing: kSpacingInsideCard) {
                statusIcon
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
                        .scaleEffect(0.85)
                        .frame(width: 18, height: 18)
                }
            }
            
            if ble.isConnected {
                Button { ble.disconnect() } label: {
                    Label("Disconnect", systemImage: "bolt.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button { ble.reconnect() } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(ble.isConnecting)
            }
        }
        .padding(kCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
    
    /// Status icon: checkmark when connected; xmark with pulse animation when disconnected (Android: CheckCircle / Close + busy spinner).
    private var statusIcon: some View {
        let iconName = ble.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = ble.isConnected ? Color(red: 0.18, green: 0.49, blue: 0.2) : .red
        return Group {
            if ble.isConnected {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(color)
            } else {
                TimelineView(.animation(minimumInterval: 0.05)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let opacity = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 2.0 * .pi / 1.1))
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(color)
                        .opacity(opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ble.isConnected)
    }
    
    
    // MARK: - Big status (Android: IncompleteLockState when ready, else Lock / Battery)
    private var bigStatusSection: some View {
        Group {
            if ble.lockState == .armed{
                incompleteLockView
            } else if commandType == "battery" {
                batteryStatusView
            } else {
                lockStatusView
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var incompleteLockView: some View {
        let frames = loadIncompleteLockFrames()
        return VStack(spacing: 10) {
            if !frames.isEmpty {
                IncompleteLockView(frames: frames)
                    .frame(maxWidth: .infinity)
            }
            Text("Ensure handle is in the correct starting position before attempting unlock.")
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
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
        case .ejected: return "Ejected"
        }
    }

    private var batteryButtonInfo: String {
        switch batteryStep {
        case .idle: return "Tap Battery Eject to begin."
        case .instruction, .armed: return "Firmly depress battery, then press Arm Eject button."
        case .sent: return "Quickly release battery to eject."
        case .ejected: return "Battery is removed from lock."
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
                    info: "Arm · Pull latch within ~30s",
                    icon: "lock.open.fill",
                    enabled: ble.isConnected
                ) {
                    commandType = "unlock"
                    isInitialCheck = false
                    ble.sendUnlock()
                }
                actionCard(
                    title: batteryButtonTitle,
                    info: batteryButtonInfo,
                    icon: "battery.100.bolt",
                    enabled: ble.isConnected && batteryStep != .sent && batteryStep != .ejected
                ) {
                    commandType = "battery"
                    switch batteryStep {
                    case .idle:
                        batteryStep = .instruction
                    case .instruction, .armed:
//                        batteryStep = .sent
                        ble.releaseBattery()
                        // Sent is set only when BLE reports .canRemove (in onChange below), matching Android LaunchedEffect(batteryState)
                    case .sent, .ejected:
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
