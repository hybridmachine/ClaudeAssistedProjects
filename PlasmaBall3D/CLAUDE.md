# PlasmaBall3D

Browser-based 3D plasma globe simulator with interactive touch-responsive filaments.

## Build & Run

```bash
npm install
npm run build     # Compile TypeScript
npm run dev       # Build + serve at localhost:8080
npm run watch     # Watch mode for development
```

## Architecture

- **TypeScript + Three.js** with custom GLSL shaders
- Bloom post-processing via `EffectComposer` + `UnrealBloomPass`
- Import maps for browser-native ES module loading (no bundler)

### Source Files

| File | Purpose |
|------|---------|
| `main.ts` | Entry point, RAF loop, FPS counter |
| `PlasmaGlobe.ts` | Top-level orchestrator, wires all subsystems |
| `GlobeRenderer.ts` | Scene, camera, WebGLRenderer, bloom pipeline |
| `GlobeMesh.ts` | Glass sphere with Fresnel rim-glow shader |
| `CentralElectrode.ts` | Emissive center sphere + point light |
| `PlasmaFilament.ts` | Single arc: noise-perturbed path, glow shader, branches |
| `FilamentManager.ts` | Manages 7 filaments, idle wandering vs touch state |
| `InteractionController.ts` | Mouse/touch raycasting against globe |
| `CameraController.ts` | Right-click orbit, scroll zoom, auto-rotation |

## Key Rendering Techniques

- Filaments use `AdditiveBlending` with HDR brightness (4.0) so bloom picks them up
- Glass globe uses Fresnel shader (edge glow, transparent center)
- `ReinhardToneMapping` compresses HDR range
- Central electrode pulses with layered sine waves

## Interaction

- **Left-click/touch** on globe: filaments converge to touch point
- **Hover** (desktop): filaments follow cursor
- **Right-click drag / 3-finger drag**: orbit camera
- **Scroll / pinch**: zoom
- Auto-rotation when idle

## Deploy

```bash
./deploy.sh   # Build + upload to hybridmachine.com/PlasmaBall3D/
```

## Performance

- ~10 draw calls total
- ~10K vertices
- Zero per-frame allocations (pooled vectors)
- Target: 60 FPS desktop, 30+ FPS mobile
