// LockAnimationView.swift — matches Android AnimationController.kt + LockAnimation.kt
// Lock: 114 frames (0000–0113), initialFrame 30, fps 50. Target by lockState?.code: 2,3->45, 4->65, 5->75, 6->113, else->30.
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
    let firstNames = ["113-1", "0113-1", "0113_1"]
    for name in firstNames {
        if let img = UIImage(named: name) {
            images.append(img)
            break
        }
    }
    for index in 114...275 {
        let name = String(format: "%04d", index)
        if let img = UIImage(named: name) {
            images.append(img)
        }
    }
    return images
}

/// Load incomplete-lock frames (30 frames 0000–0029). Matches Android incomplete-lock folder.
func loadIncompleteLockFrames(bundle: Bundle = .main) -> [UIImage] {
    (0..<30).compactMap { index in
        let name = String(format: "%04d", index)
        if let path = bundle.path(forResource: name, ofType: "png", inDirectory: "IncompleteLockFrames") ?? bundle.path(forResource: name, ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        return UIImage(named: name, in: bundle, with: nil)
    }
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

    init(lockState: LockState?, frames: [UIImage], fps: Int = 50) {
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
            applyTargetFromLockState()
        }
        .onAppear {
            if !frames.isEmpty {
                currentFrame = min(max(currentFrame, 0), frames.count - 1)
            }
            applyTargetFromLockState()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isPlaying) { playing in
            if playing { startAnimation(to: targetFrame) }
            else { timer?.invalidate() }
        }
    }

    /// Sync target frame from lockState and start animation if needed (match Android AnimationController). Ensures open state (frame 75) and other states drive correctly.
    private func applyTargetFromLockState() {
        let rawTarget = lockState.map { $0.targetFrame } ?? 30
        let maxFrame = max(0, frames.count - 1)
        let clampedTarget = min(max(rawTarget, 0), maxFrame)
        targetFrame = clampedTarget
        if clampedTarget > currentFrame {
            isPlaying = true
            startAnimation(to: clampedTarget)
        } else {
            currentFrame = clampedTarget
            isPlaying = false
            timer?.invalidate()
        }
    }

    private func startAnimation(to endFrame: Int? = nil) {
        guard !frames.isEmpty else { return }
        let end = endFrame ?? targetFrame ?? (frames.count - 1)
        let maxFrame = frames.count - 1
        let clampedEnd = min(max(end, 0), maxFrame)
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
                currentFrame = min(clampedEnd, maxFrame)
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

    init(batteryStep: BatteryEjectStep, frames: [UIImage], fps: Int = 40) {
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
            print("New step: \(batteryStep), New target: \(batteryStep.targetFrame)")
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

// MARK: - Incomplete lock (matches Android IncompleteLockState)

struct IncompleteLockView: View {
    let frames: [UIImage]
    let fps: Int

    @State private var currentFrame: Int = 0
    @State private var timer: Timer?

    init(frames: [UIImage], fps: Int = 25) {
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
        .onAppear {
            guard !frames.isEmpty else { return }
            let end = frames.count - 1
            timer?.invalidate()
            let interval = 1.0 / Double(fps)
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
                currentFrame += 1
                if currentFrame >= end {
                    currentFrame = 0
                }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
