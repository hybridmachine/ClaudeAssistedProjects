import { GameEngine } from './GameEngine.js';
import { Renderer3D } from './Renderer3D.js';
import { CameraController } from './CameraController.js';
import { UIControls } from './UIControls.js';
import { PatternLoader } from './PatternLoader.js';
class GameOfLife3D {
    constructor() {
        this.isRunning = false;
        this.initializeCanvas();
        this.initializeComponents();
        this.setupApplication();
        this.startRenderLoop();
    }
    initializeCanvas() {
        this.canvas = document.getElementById('canvas');
        if (!this.canvas) {
            throw new Error('Canvas element not found');
        }
        this.canvas.setAttribute('tabindex', '0');
        this.canvas.focus();
    }
    initializeComponents() {
        this.gameEngine = new GameEngine(50);
        this.renderer = new Renderer3D(this.canvas);
        this.cameraController = new CameraController(this.renderer.getCamera(), this.canvas);
        this.patternLoader = new PatternLoader();
        this.uiControls = new UIControls(this.gameEngine, this.renderer, this.cameraController, this.patternLoader);
    }
    setupApplication() {
        this.loadDefaultPattern();
        this.renderer.setRenderSettings({
            cellPadding: 20,
            cellColor: '#00ff88',
            showGridLines: true,
            showGenerationLabels: true
        });
        window.addEventListener('beforeunload', () => {
            this.dispose();
        });
        window.addEventListener('error', (event) => {
            console.error('Application error:', event.error);
        });
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.pauseApplication();
            }
            else {
                this.resumeApplication();
                this.canvas.focus();
            }
        });
    }
    loadDefaultPattern() {
        const gliderPattern = this.patternLoader.getBuiltInPattern('glider');
        if (gliderPattern) {
            this.gameEngine.initializeFromPattern(gliderPattern);
            this.gameEngine.computeGenerations(50);
            this.updateView();
        }
    }
    updateView() {
        const generations = this.gameEngine.getGenerations();
        const maxGen = Math.min(49, generations.length - 1);
        this.renderer.renderGenerations(generations, 0, maxGen);
    }
    startRenderLoop() {
        this.isRunning = true;
        this.render();
    }
    render() {
        if (!this.isRunning)
            return;
        this.cameraController.update();
        this.renderer.render();
        this.uiControls.updateFPS();
        requestAnimationFrame(() => this.render());
    }
    pauseApplication() {
        this.isRunning = false;
        this.cameraController.setEnabled(false);
    }
    resumeApplication() {
        if (!this.isRunning) {
            this.isRunning = true;
            this.cameraController.setEnabled(true);
            this.render();
        }
    }
    dispose() {
        this.isRunning = false;
        this.renderer.dispose();
        this.cameraController.dispose();
    }
}
document.addEventListener('DOMContentLoaded', () => {
    try {
        new GameOfLife3D();
        console.log('GameOfLife3D application started successfully');
    }
    catch (error) {
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
window.GameOfLife3D = GameOfLife3D;
//# sourceMappingURL=main.js.map