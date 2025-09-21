# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GameOfLife3D is a browser-based 3D visualization of Conway's Game of Life where multiple generations are stacked vertically in 3D space. This creates a three-dimensional structure showing the evolution of patterns through time.

## Technology Stack

- **Frontend**: TypeScript, HTML5, CSS3
- **3D Rendering**: WebGL via Three.js (recommended)
- **File Formats**: RLE for patterns, JSON for save/load sessions
- **Performance**: InstancedMesh for rendering many cubes efficiently

## Architecture Overview

The application follows a modular structure:

1. **Game Logic Layer**: Conway's Game of Life computation engine
2. **3D Rendering Layer**: Three.js-based WebGL rendering system
3. **UI Control Layer**: Browser-based controls for simulation and visualization
4. **File I/O Layer**: Pattern loading (RLE format) and session save/load (JSON)

## Key Technical Requirements

- **Grid System**: X-Y plane for each generation, Z-axis represents time/generations
- **Cell Rendering**: Live cells as colored cubes with configurable padding (0-100%)
- **Performance Targets**: 30+ FPS, up to 200x200 grid, 100 generations max
- **Lighting**: 80% ambient + 20% directional light
- **Background**: Starfield using astronomical star catalog data

## Development Approach

When implementing features:

1. **Performance First**: Use InstancedMesh for cube rendering, implement frustum culling
2. **Progressive Loading**: Handle large generation counts with progressive rendering
3. **Browser Compatibility**: Target Firefox, Chrome, Edge (2022+)
4. **Memory Management**: Validate grid sizes, provide memory usage warnings

## Core Components to Implement

- **GameEngine**: Handles Game of Life rules and generation computation
- **Renderer3D**: Three.js wrapper for 3D visualization
- **PatternLoader**: RLE file parsing and built-in pattern library
- **CameraController**: WASD/mouse controls with orbit, pan, zoom
- **UIControls**: Generation controls, visual settings, file operations

## File Formats

- **Patterns**: RLE format (Run Length Encoded)
- **Sessions**: JSON with metadata (grid size, generation count, cell states)
- **Built-in Patterns**: Glider, Blinker, Pulsar, Glider Gun, R-pentomino

## Performance Considerations

- Use Web Workers for generation computation if needed
- Implement view frustum culling for cells outside camera view
- Consider memory usage for large grids (200x200 x 100 generations = 4M cells max)
- Progressive loading for generation ranges