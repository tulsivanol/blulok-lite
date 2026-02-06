// LockAnimationView.swift — matches Android AnimationController.kt + LockAnimation.kt
// Uses frame sequence 0000.png–0113.png (114 frames), 25 fps, initialFrame 30.
// Source of truth: Android app/src/main/assets/

import SwiftUI
import UIKit

// MARK: - Frame loading (matches Android getFrames)

/// Load lock animation frames from bundle. Add the LockAnimationFrames folder (or PNGs) to your app target.
func loadLockAnimationFrames(bundle: Bundle = .main) -> [UIImage] {
    (0..<114).compactMap { index in
            let name = String(format: "%04d", index)
            return UIImage(named: name)
        }
}

/// Load battery animation frames from bundle. First frame is 113-1.png (renamed from 113 to avoid duplicate with lock’s last frame); then 0114.png … 0226.png (114 frames total).
func loadBatteryAnimationFrames(bundle: Bundle = .main) -> [UIImage] {
    var images: [UIImage] = []

        // First special frame
        if let first = UIImage(named: "0113_1") {
            images.append(first)
        }

        // Remaining frames
        for index in 114...226 {
            let name = String(format: "%04d", index)
            if let image = UIImage(named: name) {
                images.append(image)
            }
        }

        return images
}

// MARK: - SwiftUI view

struct LockAnimationView: View {
    let lockState: LockState?
    let frames: [UIImage]
    let fps: Int

    @State private var currentFrame: Int = 30
    @State private var isPlaying: Bool = false
    @State private var targetFrame: Int? = nil
    @State private var timer: Timer?

    init(lockState: LockState?, frames: [UIImage], fps: Int = 25) {
        self.lockState = lockState
        self.frames = frames
        self.fps = fps
    }

    var body: some View {
        Group {
            if let img = frames[safe: currentFrame] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            }
        }
        .onChange(of: lockState) {
            // Match Android: targetForState(null) = 30 (else branch); target = rawTarget.coerceIn(0, frames.size-1)
            let target = lockState.map { $0.targetFrame } ?? 30
            let clampedTarget = min(max(target, 0), max(0, frames.count - 1))
            targetFrame = clampedTarget
            if clampedTarget > currentFrame {
                isPlaying = true
            } else {
                currentFrame = clampedTarget
                isPlaying = false
            }
        }
        .onAppear {
            if !frames.isEmpty {
                currentFrame = min(max(currentFrame, 0), frames.count - 1)
            }
            let target = lockState.map { $0.targetFrame } ?? 30
            let clampedTarget = min(max(target, 0), max(0, frames.count - 1))
            targetFrame = clampedTarget
            if clampedTarget > currentFrame {
                isPlaying = true
            } else {
                currentFrame = clampedTarget
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isPlaying) { playing in
            if playing { startAnimation() }
            else { timer?.invalidate() }
        }
    }

    private func startAnimation() {
        let end = (targetFrame ?? (frames.count - 1))
        let clampedEnd = min(max(end, 0), max(0, frames.count - 1))
        guard clampedEnd > currentFrame else {
            currentFrame = clampedEnd
            isPlaying = false
            return
        }
        timer?.invalidate()
        let interval = 1.0 / Double(fps)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            currentFrame += 1
            if currentFrame >= clampedEnd || currentFrame >= frames.count {
                currentFrame = min(clampedEnd, frames.count - 1)
                isPlaying = false
                t.invalidate()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

// MARK: - Battery animation (matches Android BatteryAnimation.kt + AnimationController)

struct BatteryAnimationView: View {
    let batteryStep: BatteryEjectStep
    let frames: [UIImage]
    let fps: Int

    @State private var currentFrame: Int = 0  // Android battery spec initialFrame = 0
    @State private var isPlaying: Bool = false
    @State private var targetFrame: Int = 0
    @State private var timer: Timer?

    init(batteryStep: BatteryEjectStep, frames: [UIImage], fps: Int = 25) {
        self.batteryStep = batteryStep
        self.frames = frames
        self.fps = fps
    }

    var body: some View {
        Group {
            if let img = frames[safe: currentFrame] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            }
        }
        .onChange(of: batteryStep) {
            let rawTarget = batteryStep.targetFrame
            let clampedTarget = frames.isEmpty ? 0 : min(max(rawTarget, 0), frames.count - 1)
            targetFrame = clampedTarget
            if clampedTarget > currentFrame {
                isPlaying = true
            } else {
                currentFrame = clampedTarget
                isPlaying = false
            }
        }
        .onAppear {
            if !frames.isEmpty {
                currentFrame = min(max(currentFrame, 0), frames.count - 1)
            }
            let rawTarget = batteryStep.targetFrame
            let clampedTarget = frames.isEmpty ? 0 : min(max(rawTarget, 0), frames.count - 1)
            targetFrame = clampedTarget
            if clampedTarget > currentFrame {
                isPlaying = true
            } else {
                currentFrame = clampedTarget
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isPlaying) { playing in
            if playing { startAnimation() }
            else { timer?.invalidate() }
        }
    }

    private func startAnimation() {
        let clampedEnd = frames.isEmpty ? 0 : min(max(targetFrame, 0), frames.count - 1)
        guard clampedEnd > currentFrame else {
            currentFrame = clampedEnd
            isPlaying = false
            return
        }
        timer?.invalidate()
        let interval = 1.0 / Double(fps)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            currentFrame += 1
            if currentFrame >= clampedEnd || currentFrame >= frames.count {
                currentFrame = min(clampedEnd, frames.count - 1)
                isPlaying = false
                t.invalidate()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
