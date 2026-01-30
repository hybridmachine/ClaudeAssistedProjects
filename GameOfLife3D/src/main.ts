import { GameEngine } from './GameEngine.js';
import { Renderer3D } from './Renderer3D.js';
import { CameraController } from './CameraController.js';
import { UIControls } from './UIControls.js';
import { PatternLoader } from './PatternLoader.js';
import { PopulationGraph } from './PopulationGraph.js';
import { URLHandler, URLConfig } from './URLHandler.js';

class GameOfLife3D {
    private gameEngine!: GameEngine;
    private renderer!: Renderer3D;
    private cameraController!: CameraController;
    private uiControls!: UIControls;
    private patternLoader!: PatternLoader;
    private populationGraph!: PopulationGraph;

    private canvas!: HTMLCanvasElement;
    private isRunning = false;

    constructor() {
        this.initializeCanvas();
        this.initializeComponents();
        this.setupApplication();
        this.startRenderLoop();
    }

    private initializeCanvas(): void {
        this.canvas = document.getElementById('canvas') as HTMLCanvasElement;
        if (!this.canvas) {
            throw new Error('Canvas element not found');
        }

        this.canvas.setAttribute('tabindex', '0');
        this.canvas.focus();
    }

    private initializeComponents(): void {
        this.gameEngine = new GameEngine(50);
        this.renderer = new Renderer3D(this.canvas);
        this.cameraController = new CameraController(this.renderer.getCamera(), this.canvas);
        this.patternLoader = new PatternLoader();
        this.populationGraph = new PopulationGraph();

        this.uiControls = new UIControls(
            this.gameEngine,
            this.renderer,
            this.cameraController,
            this.patternLoader,
            this.populationGraph
        );
    }

    private setupApplication(): void {
        // Check for URL configuration
        const urlConfig = URLHandler.parseURL();

        this.renderer.setRenderSettings({
            cellPadding: urlConfig.padding ?? 20,
            cellColor: '#00ff88',
            showGridLines: true,
            showGenerationLabels: true,
            faceColorCycling: urlConfig.colors ?? true
        });

        if (URLHandler.hasURLConfig()) {
            this.applyURLConfig(urlConfig);
        } else {
            this.loadDefaultPattern();
        }

        window.addEventListener('beforeunload', () => {
            this.dispose();
        });

        window.addEventListener('error', (event) => {
            console.error('Application error:', event.error);
        });

        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.pauseApplication();
            } else {
                this.resumeApplication();
                this.canvas.focus();
            }
        });
    }

    private loadDefaultPattern(): void {
        const initialPattern = this.patternLoader.getBuiltInPattern('r-pentomino');
        if (initialPattern) {
            this.gameEngine.initializeFromPattern(initialPattern);
            // Only show generation 0 initially - user clicks Play to animate
            this.uiControls.syncDisplayRange();
            this.updateView();
        }
    }

    private updateView(): void {
        const generations = this.gameEngine.getGenerations();
        // Show only generation 0 initially
        this.renderer.renderGenerations(generations, 0, 0);
    }

    private applyURLConfig(config: URLConfig): void {
        // Apply grid size first (affects pattern placement)
        if (config.grid) {
            this.gameEngine.setGridSize(config.grid);
            this.renderer.setGridSize(config.grid);
            // Update UI dropdown
            const gridSelect = document.getElementById('grid-size') as HTMLSelectElement | null;
            if (gridSelect) {
                gridSelect.value = config.grid.toString();
            }
        }

        // Apply toroidal setting
        if (config.toroidal !== undefined) {
            this.gameEngine.setToroidal(config.toroidal);
            const toroidalToggle = document.getElementById('toroidal-toggle') as HTMLInputElement | null;
            if (toroidalToggle) {
                toroidalToggle.checked = config.toroidal;
            }
        }

        // Apply rule
        if (config.rule) {
            const rulePreset = document.getElementById('rule-preset') as HTMLSelectElement | null;
            const customContainer = document.getElementById('custom-rule-container');

            if (config.rule.match(/^B\d*S\d*$/i)) {
                // Custom B/S notation
                const match = config.rule.match(/B(\d*)S(\d*)/i);
                if (match) {
                    const birth = match[1].split('').map(Number);
                    const survival = match[2].split('').map(Number);
                    this.gameEngine.setCustomRule(birth, survival);
                    if (rulePreset) {
                        rulePreset.value = 'custom';
                    }
                    if (customContainer) {
                        customContainer.style.display = 'block';
                    }
                    const birthInput = document.getElementById('custom-birth') as HTMLInputElement | null;
                    const survivalInput = document.getElementById('custom-survival') as HTMLInputElement | null;
                    if (birthInput) birthInput.value = match[1];
                    if (survivalInput) survivalInput.value = match[2];
                }
            } else {
                // Preset name
                this.gameEngine.setRule(config.rule);
                if (rulePreset) {
                    rulePreset.value = config.rule;
                }
                if (customContainer) {
                    customContainer.style.display = 'none';
                }
            }
        }

        // Load pattern
        if (config.pattern) {
            const pattern = this.patternLoader.getBuiltInPattern(config.pattern);
            if (pattern) {
                this.gameEngine.initializeFromPattern(pattern);
            }
        } else if (config.rle) {
            try {
                const pattern = this.patternLoader.parseRLE(config.rle);
                this.gameEngine.initializeFromPattern(pattern);
            } catch (error) {
                console.error('Error parsing RLE from URL:', error);
                // Fall back to default pattern
                this.loadDefaultPattern();
                return;
            }
        } else {
            // No pattern specified, load default
            this.loadDefaultPattern();
            return;
        }

        // Compute generations if specified
        if (config.gens && config.gens > 0) {
            this.gameEngine.computeGenerations(config.gens);
        }

        // Apply padding
        if (config.padding !== undefined) {
            const paddingSlider = document.getElementById('cell-padding') as HTMLInputElement | null;
            const paddingValue = document.getElementById('padding-value');
            if (paddingSlider) {
                paddingSlider.value = config.padding.toString();
            }
            if (paddingValue) {
                paddingValue.textContent = `${config.padding}%`;
            }
        }

        // Apply color cycling
        if (config.colors !== undefined) {
            const colorCycling = document.getElementById('face-color-cycling') as HTMLInputElement | null;
            if (colorCycling) {
                colorCycling.checked = config.colors;
            }
            const colorPicker = document.getElementById('cell-color') as HTMLInputElement | null;
            if (colorPicker) {
                colorPicker.disabled = config.colors;
            }
        }

        // Sync display range with UIControls
        this.uiControls.syncDisplayRange();

        // Set display range if specified
        if (config.range) {
            const startInput = document.getElementById('display-start') as HTMLInputElement | null;
            const endInput = document.getElementById('display-end') as HTMLInputElement | null;
            if (startInput && endInput) {
                const maxGen = this.gameEngine.getGenerationCount() - 1;
                startInput.value = Math.min(config.range.min, maxGen).toString();
                endInput.value = Math.min(config.range.max, maxGen).toString();
            }
        }

        this.updateView();
    }

    private startRenderLoop(): void {
        this.isRunning = true;
        this.render();
    }

    private render(): void {
        if (!this.isRunning) return;

        this.cameraController.update();
        this.renderer.render();
        this.uiControls.updateFPS();

        requestAnimationFrame(() => this.render());
    }

    private pauseApplication(): void {
        this.isRunning = false;
        this.cameraController.setEnabled(false);
    }

    private resumeApplication(): void {
        if (!this.isRunning) {
            this.isRunning = true;
            this.cameraController.setEnabled(true);
            this.render();
        }
    }

    private dispose(): void {
        this.isRunning = false;
        this.renderer.dispose();
        this.cameraController.dispose();
        this.populationGraph.destroy();
    }
}

document.addEventListener('DOMContentLoaded', () => {
    try {
        new GameOfLife3D();
        console.log('GameOfLife3D application started successfully');
    } catch (error) {
        console.error('Failed to start GameOfLife3D application:', error);

        const errorMessage = document.createElement('div');
        errorMessage.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: #ff4444;
            color: white;
            padding: 20px;
            border-radius: 8px;
            font-family: Arial, sans-serif;
            text-align: center;
            z-index: 10000;
        `;
        errorMessage.innerHTML = `
            <h3>Failed to load GameOfLife3D</h3>
            <p>Please check the browser console for details.</p>
            <p>Make sure your browser supports WebGL.</p>
        `;
        document.body.appendChild(errorMessage);
    }
});

declare global {
    interface Window {
        GameOfLife3D: typeof GameOfLife3D;
    }
}

window.GameOfLife3D = GameOfLife3D;
