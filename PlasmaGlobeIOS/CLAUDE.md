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
- **State:** Combine (`@Published` properties in TouchHandler)
- **Build Tool:** XcodeGen (`project.yml` generates the `.xcodeproj`)
- **Min Deployment Target:** iOS 16.0
- **Supported Devices:** iPhone and iPad (requires Metal GPU)
- **No external dependencies** — Apple frameworks only

## Project Structure
```
PlasmaGlobeIOS/
  PlasmaGlobeIOS/
    PlasmaGlobeIOSApp.swift      # App entry point
    ContentView.swift             # Root SwiftUI view, manages scene lifecycle
    Rendering/
      MetalView.swift             # UIViewRepresentable bridging MTKView to SwiftUI
      PlasmaRenderer.swift        # Metal pipeline setup and two-pass draw loop
      Uniforms.swift              # Shared CPU/GPU uniform structs
    Metal/
      FullscreenQuad.metal        # Vertex shader (fullscreen triangle strip)
      Starfield.metal             # Fragment shader for starfield + galaxies
      Shaders.metal               # Fragment shader for plasma globe (ray-marched)
    Interaction/
      TouchHandler.swift          # ObservableObject tracking touch state
    Assets.xcassets/              # App icon and colors
    Info.plist                    # iOS config (status bar hidden, orientations)
  project.yml                    # XcodeGen project definition
```

## Rendering Architecture
Two-pass fullscreen Metal pipeline, both passes render a fullscreen quad:

1. **Pass 1 — Starfield:** Clears to dark background, renders multi-layer parallax stars and procedural galaxy patches. Uses hash-based pseudo-random placement with twinkling animation.
2. **Pass 2 — Plasma Globe:** Loads the previous framebuffer and renders the plasma globe on top with **additive blending** (`src=ONE, dst=ONE`). Uses volumetric ray-marching (28 steps) through a sphere to accumulate 7 plasma tendrils with Gaussian glow profiles, a glass shell Fresnel effect, vignette, and tone mapping.

Uniforms passed each frame: `time`, `resolution`, `touchPosition`, `isTouching`.

## Touch Interaction Flow
1. `MetalView` registers a `UIPanGestureRecognizer` (1 touch)
2. Coordinator normalizes touch position to `[0, 1]` and updates `TouchHandler`
3. Shader maps 2D touch to 3D world direction via ray-sphere intersection
4. When touching, tendrils blend toward touch direction (35%–60%)

## Key Shader Constants (Shaders.metal)
- `NUM_TENDRILS = 12` — plasma arm count (with branching forks)
- `VOL_STEPS = 28` — ray-march sample count
- `SPHERE_R = 1.0` — globe radius
- `CORE_R = 0.06` — central electrode radius
- `POST_RADIUS_MAX = 0.095` — center post bounding cylinder radius (actual profile varies via `postRadius(y)`)
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
- Folder-based code organization: `Rendering/`, `Metal/`, `Interaction/`
- All animation is time-driven (`CFAbsoluteTime`), no state machines
- Shader functions are pure math — `tnoise`, `sphereHit`, `computeTendril`
- Coordinates normalized to `[0, 1]` or `[-1, 1]` consistently
- No unit tests currently in the project
