# PlasmaGlobeIOS

## Overview
A soothing Plasma Globe simulation for iPhones and iPads. Users touch the screen to attract plasma tendrils toward their finger, just like a real plasma globe. The globe floats in a slowly drifting procedural starfield with occasional galaxies. Written in Swift with Metal shaders for GPU-accelerated rendering.

## Design Goals
- Clean modern Swift code with no duplication
- Efficient GPU rendering, smooth 60 FPS experience
- Fully procedural visuals (no image textures except a 256x256 noise texture)

## Tech Stack
- **Language:** Swift 5
- **UI Framework:** SwiftUI (minimal — just hosts the Metal view)
- **Rendering:** Metal + MetalKit (MTKView)
- **Audio:** AVAudioEngine with procedural audio (no asset files)
- **Haptics:** CoreHaptics for force-modulated continuous vibration
- **Motion:** CoreMotion for gyroscope parallax
- **State:** Combine (`@Published` properties in TouchHandler, `@AppStorage` in PlasmaSettings)
- **Build Tool:** XcodeGen (`project.yml` generates the `.xcodeproj`)
- **Min Deployment Target:** iOS 16.0
- **Supported Devices:** iPhone and iPad (requires Metal GPU)
- **No external dependencies** — Apple frameworks only

## Project Structure
```
PlasmaGlobeIOS/
  PlasmaGlobeIOS/
    PlasmaGlobeIOSApp.swift      # App entry point
    ContentView.swift             # Root SwiftUI view, manages scene lifecycle + audio/motion
    Rendering/
      MetalView.swift             # UIViewRepresentable bridging MTKView to SwiftUI
      PlasmaRenderer.swift        # Metal pipeline setup and two-pass draw loop
      Uniforms.swift              # Shared CPU/GPU uniform structs (Uniforms, TouchPoint, PlasmaConfig)
    Metal/
      FullscreenQuad.metal        # Vertex shader (fullscreen triangle strip)
      Starfield.metal             # Fragment shader for starfield + galaxies + gyro parallax
      Shaders.metal               # Fragment shader for plasma globe (ray-marched, multi-touch, discharge)
    Interaction/
      TouchHandler.swift          # ObservableObject tracking multi-touch state + haptics/audio triggers
      MultiTouchGestureRecognizer.swift  # Custom UIGestureRecognizer for 5-finger tracking + force
      HapticManager.swift         # CoreHaptics engine for continuous vibration + discharge bursts
      MotionManager.swift         # CoreMotion gyroscope wrapper for tilt data
    Audio/
      AudioManager.swift          # AVAudioEngine with procedural hum, crackle, and discharge sounds
    Settings/
      ColorTheme.swift            # 7 predefined color palettes
      PlasmaSettings.swift        # ObservableObject with @AppStorage for persistence
      SettingsOverlay.swift       # SwiftUI settings panel (themes, sliders, toggles)
    Assets.xcassets/              # App icon and colors
    Info.plist                    # iOS config (status bar hidden, orientations, motion usage)
  project.yml                    # XcodeGen project definition
```

## Rendering Architecture
Two-pass fullscreen Metal pipeline with four Metal buffers:

- **Buffer 0 — `Uniforms`**: time, resolution, camera, touchCount, dischargeTime, gyroTilt
- **Buffer 1 — `TouchPoint[5]`**: position, force, active, worldDir (pre-computed on CPU) for each multi-touch slot
- **Buffer 2 — `PlasmaConfig`**: 6 color vectors + tendrilCount, brightness, speed, thickness
- **Buffer 3 — `TendrilInfo[20]`**: pre-computed per-frame tendril data (direction, basis vectors, touch bias, branching, flicker) — computed on CPU to avoid redundant per-pixel transcendental math

### Passes
1. **Pass 1 — Starfield:** Clears to dark background, renders multi-layer parallax stars and procedural galaxy patches with gyroscope-driven depth parallax.
2. **Pass 2 — Plasma Globe:** Additive blend over starfield. Ray-marches up to 20 tendrils with configurable colors from PlasmaConfig, force-modulated width/brightness, branching forks, discharge flash (8 lightning tendrils), glass shell, and center post. Tendril data and touch world-directions are pre-computed on CPU each frame.

## Touch Interaction Flow
1. `MetalView` registers a `MultiTouchGestureRecognizer` (up to 5 touches) + pinch + double-tap
2. Each touch tracked by identity, normalized to `[0, 1]`, force read from `UITouch.force`
3. CPU (PlasmaRenderer) maps each touch to 3D direction via ray-sphere intersection, stored in `TouchPoint.worldDir`
4. CPU pre-computes all `TendrilInfo` structs (direction, touch attraction, lifecycle, branching)
5. Each tendril attracts toward its nearest active touch, force modulates width (+50%) and brightness (+80%)
6. Double-tap triggers discharge flash (1.5s lightning burst with haptic + sound)

## Key Shader Constants (PlasmaCommon.h)
- `MAX_TENDRILS = 20` — maximum plasma arm count (runtime via config.tendrilCount)
- `MAX_TOUCHES = 5` — multi-touch slots
- `VOL_STEPS = 32` — ray-march sample count
- `SPHERE_R = 1.0` — globe radius
- `CORE_R = 0.06` — central electrode radius
- `POST_RADIUS_MAX = 0.095` — center post bounding cylinder radius
- `QUICK_REJECT_DIST = 0.25` — perpendicular distance threshold for tendril skip

## Build & Run
```bash
# Generate Xcode project from project.yml (requires xcodegen installed)
xcodegen generate

# Open in Xcode
open PlasmaGlobeIOS.xcodeproj

# Build and run on device (Metal requires real hardware, not simulator)
```

## Conventions
- Folder-based code organization: `Rendering/`, `Metal/`, `Interaction/`, `Audio/`, `Settings/`
- All animation is time-driven (`CFAbsoluteTime`), no state machines
- Shader functions are pure math — `tnoise`, `sphereHit`, `fastPow`; tendril computation is on CPU (`PlasmaRenderer.computeTendrilInfo`)
- Coordinates normalized to `[0, 1]` or `[-1, 1]` consistently
- Settings persisted via `@AppStorage` — survive app kill/relaunch
- Audio is fully procedural (AVAudioSourceNode) — no asset files
- No unit tests currently in the project
