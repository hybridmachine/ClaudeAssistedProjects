# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GameOfLife3D is a browser-based 3D visualization of Conway's Game of Life where multiple generations are stacked vertically in 3D space. Each generation renders in the X-Y plane with the Z-axis (rendered as Y in Three.js) representing time progression.

## Build and Development Commands

```bash
npm run build    # Compile TypeScript to dist/
npm run watch    # Compile on change (fast feedback)
npm run serve    # Launch local static server on http://localhost:8080/
npm run dev      # Build once, then serve (opens browser automatically)
npm run clean    # Remove dist/
```

No test framework is configured. Manual smoke testing: `npm run dev`, verify camera controls, pattern loading, generation stepping, and FPS stability with 100 generations.

## Architecture

### Component Data Flow

```
main.ts (GameOfLife3D)
    ├── GameEngine      → Computes generations, stores cell states
    ├── Renderer3D      → Three.js scene, InstancedMesh rendering
    ├── CameraController → Keyboard/mouse/touch input handling
    ├── UIControls      → DOM event handlers, animation loop
    └── PatternLoader   → RLE parsing, built-in patterns
```

### Key Architectural Decisions

- **InstancedMesh for cells**: `Renderer3D` uses a single `THREE.InstancedMesh` (max 4M instances: 200x200x100) with dynamic matrix updates for efficient rendering of thousands of cubes
- **Shader-based gradients**: Cell and edge colors use custom GLSL shaders with animated color cycling based on Y position (generation index)
- **Generations stored in memory**: `GameEngine.generations[]` holds all computed generations as `boolean[][]` grids plus precomputed `liveCells[]` arrays
- **Animation via UIControls**: Play/pause calls `GameEngine.computeSingleGeneration()` incrementally rather than batch computation

### Module Responsibilities

| Module | Key Responsibilities |
|--------|---------------------|
| `GameEngine.ts` | Game of Life rules (B3/S23), grid management, state import/export |
| `Renderer3D.ts` | WebGL setup, InstancedMesh updates, starfield/galaxy background, lighting |
| `CameraController.ts` | Spherical camera controls, WASD/QE/RF/OP keys, mouse drag, touch gestures |
| `UIControls.ts` | DOM bindings, playback animation, file load/save, FPS tracking |
| `PatternLoader.ts` | RLE format parsing, built-in patterns (glider, pulsar, glider-gun, etc.) |

## Coding Conventions

- TypeScript with strict mode; avoid `any`
- 2-space indentation, LF line endings
- PascalCase for files/classes, camelCase for functions/variables
- Imports use `.js` extension (ES modules in browser)
- Three.js: prefer object pooling, minimal per-frame allocations

## Performance Targets

- 30+ FPS with up to 200x200 grid and 100 generations displayed
- Max 1000 generations computed (enforced in `GameEngine.MAX_GENERATIONS`)
- Starfield: 5000 stars with 2% animated twinkle, 15 procedural galaxies
