# iOS Lock Animation (from Android)

Assets and Swift code are copied from **Android** (`app/src/main/assets/`). Android is the source of truth.

## Contents

- **LockAnimationFrames/** — 114 PNGs (`0000.png`–`0113.png`) for the lock animation
- **BatteryAnimationFrames/** — 163 frames: first frame `113-1.png` (renamed from 113 to avoid duplicate with lock’s last frame), then `0114.png`…`0275.png`. If missing, the battery screen shows text only.
- **IncompleteLockFrames/** — 30 PNGs (0000–0029) for incomplete-lock loop. Matches Android incomplete-lock.
- **LockState.swift** — Lock state (unknown, 1–6), `BatteryReleaseState`, `BatteryEjectStep` (incl. .ejected), `targetFrame` and `description`.
- **AnimationView.swift** — LockAnimationView (50 fps), BatteryAnimationView (40 fps), IncompleteLockView (looping); loaders for lock, battery, incomplete-lock.
- **AnimationFrameResources** — On-Demand Resources (ODR) manager for lock/battery frames; see below.

## Add to your Xcode project

### 1. Add the frame images

- In Xcode, right‑click your app target’s group → **Add Files to "[Your App]"…**
- Select the **LockAnimationFrames** folder (with the 114 PNGs inside).
- Check **Copy items if needed** and your app target.
- Leave **Create groups** selected so the folder appears as a group; ensure **Add to targets** includes your app.

For the **battery** animation, add **BatteryAnimationFrames** with first frame named `113-1.png` (to avoid duplicate with lock’s `0113.png`), then `0114`…`0275` (163 frames). Add **IncompleteLockFrames** (0000…0029, 30 frames) for incomplete-lock. If omitted, those screens show text only.

If you use an asset catalog instead:

- Create an image set (or a folder reference) and drag the PNGs so they’re available in the app bundle. Then in code, load by name (e.g. `UIImage(named: "0000")` in a loop) and build the `[UIImage]` array.

### 2. Add the Swift files

- Add **LockState.swift** and **AnimationView.swift** (contains lock and battery views) to your app target (drag into the project or File → Add Files…).

### 3. Use the animation

Load frames once (e.g. in your view model or a parent view) and pass them with the current lock state:

```swift
// Load once (e.g. at startup or in a view model)
let frames = loadLockAnimationFrames(bundle: .main)

// In your SwiftUI view
LockAnimationView(lockState: currentLockState, frames: frames, fps: 25)
    .frame(width: 200, height: 200)
```

**Lock frame mapping (matches Android LockAnimation.kt):** 2,3→45, 4→65, 5→75, 6→113, else→30. Lock FPS = 50.

**Battery step → frame:** Idle→0, Instruction/Armed→77, Sent→122, Ejected→162. Battery FPS = 40.

### 4. Battery animation (matches Android BatteryAnimation.kt)

- **BatteryEjectStep** drives the target frame: `idle`→0, `instruction`/`armed`→77, `sent`→122, `ejected`→162.
- Two-tap flow; `ejected` is set when disconnected after sending (matches Android).

### 5. Incomplete-lock (matches Android IncompleteLockState)

- When **lockState == .unknown** and **isInitialCheck** is true, **IncompleteLockView** is shown (looping 0…29) with message: “Ensure handle is in the correct starting position before attempting unlock.”
- Tapping **Open** sets **isInitialCheck = false** and sends unlock (matches Android BluLokLite.isInitialCheck).

### 6. On-Demand Resources (optional, for assets/frames)

To ship frame assets as **On-Demand Resources** (smaller initial download; frames downloaded when needed):

1. In Xcode, select your **app target** → **Build Phases** → expand **Copy Bundle Resources** (or add the frame folders here if needed).
2. Open **Resource Tags** (or **Asset Pack**): Xcode 14+ use **App Store** tab → **On-Demand Resources**; or in the project editor find where to add **Resource Tags**.
3. Create two tags: **`lock-frames`** and **`battery-frames`**.
4. Assign **`lock-frames`** to the **LockAnimationFrames** group (select the folder → File Inspector → **Resource Tags** → add `lock-frames`).
5. Assign **`battery-frames`** to the **BatteryAnimationFrames** group the same way.
6. Set both tags to **Download Only On Demand** (not Initial Install or Prefetch).

The app uses `AnimationFrameResources` to request these tags when the user sees the lock or battery screen; a progress indicator is shown while downloading. If ODR is not configured, frames are loaded from the main bundle (fallback).

### 7. BLE lock state

Parse the first byte of your BLE characteristic and convert to `LockState`:

```swift
let lockState = LockState(byte: characteristicValue.first)
```

Then pass that `lockState` into `LockAnimationView` as above.

## Updating from Android later

To refresh iOS from Android:

1. **Lock:** copy PNGs from Android `app/src/main/assets/lock/` into **LockAnimationFrames/**.
2. **Battery:** copy from Android `app/src/main/assets/battery/` into **BatteryAnimationFrames/**; rename the first frame (113) to `113-1` to avoid duplicate with lock’s last frame, then 0114…0275 (163 frames).
3. **Incomplete-lock:** copy Android assets/incomplete-lock/ into **IncompleteLockFrames/** (30 frames).
4. If Android’s frame count or state → target frame mapping changes, update **LockState.swift** and loaders in **AnimationView.swift**.
