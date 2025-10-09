# GEMINI.md

## Project Overview

This project is a 3D visualization of Conway's Game of Life, built with TypeScript and Three.js. The application runs entirely in the browser, rendering multiple generations of the game stacked vertically in 3D space. This allows users to explore the evolution of Game of Life patterns as three-dimensional structures.

The project is structured with a clear separation of concerns:
-   **`GameEngine.ts`**: Handles the core logic of Conway's Game of Life, including computing generations and managing the game state.
-   **`Renderer3D.ts`**: Manages the 3D rendering of the game state using Three.js, including cell representation, lighting, and camera setup.
-   **`main.ts`**: The main entry point of the application, responsible for initializing the game engine, renderer, and user controls.
-   **`UIControls.ts`**: Manages the user interface and user interactions.
-   **`CameraController.ts`**: Handles camera movement and controls.
-   **`PatternLoader.ts`**: Loads predefined patterns into the game.

## Building and Running

The project uses `npm` for dependency management and running scripts.

### Prerequisites

-   Node.js and npm

### Installation

1.  Clone the repository.
2.  Install the dependencies:
    ```bash
    npm install
    ```

### Development

To build the project and start a local development server, run:

```bash
npm run dev
```

This will compile the TypeScript code, start a web server on port 8080, and open the application in your default browser.

### Available Scripts

-   `npm run build`: Compiles the TypeScript code into the `dist` directory.
-   `npm run watch`: Compiles the TypeScript code in watch mode, automatically recompiling on file changes.
-   `npm run serve`: Starts a local web server for the project.
-   `npm run clean`: Removes the `dist` directory.

## Development Conventions

-   **Language**: TypeScript
-   **3D Graphics**: Three.js
-   **Modularity**: The code is organized into ES modules with clear responsibilities.
-   **State Management**: The `GameEngine` class manages the game state, while the `Renderer3D` class manages the rendering state.
-   **User Interface**: The `UIControls` class is responsible for handling user interactions and updating the UI.
-   **Coding Style**: The code follows standard TypeScript and object-oriented programming conventions.
