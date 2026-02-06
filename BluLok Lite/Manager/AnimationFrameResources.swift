//
//  AnimationFrameResources.swift
//  BluLok Demo
//
//  On-Demand Resources for lock and battery animation frames.
//  Assign Resource Tags in Xcode to LockAnimationFrames and BatteryAnimationFrames (see README).
//

import SwiftUI
import Combine

/// Resource tag names. Assign these in Xcode to the respective frame folders (Resource Tags).
enum AnimationResourceTag {
    static let lockFrames = "lock-frames"
    static let batteryFrames = "battery-frames"
}

/// Loads and caches lock/battery animation frames via On-Demand Resources (ODR).
/// Falls back to loading from the main bundle if ODR is not configured or request fails.
final class AnimationFrameResources: NSObject, ObservableObject {
    @Published private(set) var lockFrames: [UIImage] = []
    @Published private(set) var batteryFrames: [UIImage] = []
    @Published private(set) var isLockLoading = false
    @Published private(set) var isBatteryLoading = false
    @Published private(set) var loadingProgress: Double = 0
    @Published private(set) var errorMessage: String?

    private var lockRequest: NSBundleResourceRequest?
    private var batteryRequest: NSBundleResourceRequest?
    private var progressObserver: NSKeyValueObservation?

    override init() {
        super.init()
    }

    // MARK: - Lock frames

    /// Request lock animation frames (ODR). On success or fallback, `lockFrames` is updated.
    func requestLockFrames() {
        guard lockFrames.isEmpty, !isLockLoading else { return }
        isLockLoading = true
        errorMessage = nil
        loadingProgress = 0

        let request = NSBundleResourceRequest(tags: [AnimationResourceTag.lockFrames])
        lockRequest = request
        observeProgress(request.progress)

        request.beginAccessingResources { [weak self] error in
            DispatchQueue.main.async {
                self?.isLockLoading = false
                self?.loadingProgress = 1
                self?.progressObserver = nil
                self?.lockRequest = nil

                if let error = error as NSError? {
                    // ODR not configured or download failed — try main bundle (e.g. dev without ODR)
                    let fallback = loadLockAnimationFrames(bundle: .main)
                    if !fallback.isEmpty {
                        self?.lockFrames = fallback
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                } else {
                    self?.lockFrames = loadLockAnimationFrames(bundle: .main)
                }
            }
        }
    }

    /// Release lock ODR when no longer needed (allows system to purge).
    func endAccessingLockFrames() {
        lockRequest?.endAccessingResources()
        lockRequest = nil
    }

    // MARK: - Battery frames

    /// Request battery animation frames (ODR). On success or fallback, `batteryFrames` is updated.
    func requestBatteryFrames() {
        guard batteryFrames.isEmpty, !isBatteryLoading else { return }
        isBatteryLoading = true
        errorMessage = nil
        loadingProgress = 0

        let request = NSBundleResourceRequest(tags: [AnimationResourceTag.batteryFrames])
        batteryRequest = request
        observeProgress(request.progress)

        request.beginAccessingResources { [weak self] error in
            DispatchQueue.main.async {
                self?.isBatteryLoading = false
                self?.loadingProgress = 1
                self?.progressObserver = nil
                self?.batteryRequest = nil

                if let error = error as NSError? {
                    let fallback = loadBatteryAnimationFrames(bundle: .main)
                    if !fallback.isEmpty {
                        self?.batteryFrames = fallback
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                } else {
                    self?.batteryFrames = loadBatteryAnimationFrames(bundle: .main)
                }
            }
        }
    }

    func endAccessingBatteryFrames() {
        batteryRequest?.endAccessingResources()
        batteryRequest = nil
    }

    // MARK: - Progress

    private func observeProgress(_ progress: Progress) {
        progressObserver = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] p, _ in
            DispatchQueue.main.async {
                self?.loadingProgress = p.fractionCompleted
            }
        }
    }
}
