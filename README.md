# BluLok Demo (iOS)

iOS demo app for BluLok: BLE-connected lock with Open and Battery Eject flows, lock and battery frame animations, and optional On-Demand Resources for assets.

## Structure

- **BluLok Lite/** — Main app target
  - **Views/** — `HomeView`, `DevicePickerView`, lock/battery animation views
  - **Manager/** — `BLEManager`, `AnimationFrameResources` (ODR)
  - **Model/** — `LockState`, `BatteryReleaseState`, `BatteryEjectStep`, `BLEDevice`
  - **LockAnimationFrames/** — 114 PNGs (0000–0113) for lock animation
  - **BatteryAnimationFrames/** — 114 PNGs (113-1, 0114–0226) for battery animation
- **BluLok Lite.xcodeproj/** — Xcode project

## Features

- **BLE** — Scan, connect, disconnect; read lock and battery state; send Open and Release Battery commands
- **Lock animation** — Frame-based animation driven by `LockState` (connected → armed → open → close), 25 fps
- **Battery animation** — Two-tap flow (Battery Eject → Arm Eject) with frame animation; “Sent” when BLE reports battery ready
- **On-Demand Resources** — Optional ODR for lock and battery frame assets; see [BluLok Lite/README.md](BluLok%20Lite/README.md)

## Setup

1. Open **BluLok Lite.xcodeproj** in Xcode.
2. Select your device or simulator and run.
3. For animation assets and ODR setup, see **[BluLok Lite/README.md](BluLok%20Lite/README.md)**.

## Android reference

Lock and battery behavior and frame mapping follow the Android app (BluLok Lite). Android is the source of truth for assets and state→frame mapping.
