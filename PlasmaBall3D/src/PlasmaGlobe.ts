import { GlobeRenderer } from './GlobeRenderer.js';
import { GlobeMesh } from './GlobeMesh.js';
import { CentralElectrode } from './CentralElectrode.js';
import { CameraController } from './CameraController.js';
import { FilamentManager } from './FilamentManager.js';
import { InteractionController } from './InteractionController.js';
import { Starfield } from './Starfield.js';

export class PlasmaGlobe {
    private globeRenderer: GlobeRenderer;
    private globeMesh: GlobeMesh;
    private electrode: CentralElectrode;
    private cameraController: CameraController;
    private filamentManager: FilamentManager;
    private interactionController: InteractionController;
    private starfield: Starfield;
    private startTime: number;
    private lastTime: number;

    constructor(canvas: HTMLCanvasElement) {
        this.startTime = performance.now() / 1000;
        this.lastTime = this.startTime;
        this.globeRenderer = new GlobeRenderer(canvas);

        const scene = this.globeRenderer.scene;
        this.starfield = new Starfield(scene);
        const globeRadius = 2.0;
        this.globeMesh = new GlobeMesh(scene, globeRadius);
        this.electrode = new CentralElectrode(scene);
        this.cameraController = new CameraController(this.globeRenderer.camera, canvas);
        this.filamentManager = new FilamentManager(scene, globeRadius);
        this.interactionController = new InteractionController(
            this.globeRenderer.camera,
            canvas,
            this.globeMesh.getMesh(),
            this.filamentManager,
            () => this.cameraController.isOrbitDragging(),
        );
    }

    update(): void {
        const now = performance.now() / 1000;
        const time = now - this.startTime;
        const deltaTime = now - this.lastTime;
        this.lastTime = now;

        this.cameraController.update(deltaTime);
        this.filamentManager.update(time, deltaTime);
        this.electrode.update(time);
        this.globeRenderer.render();
    }

    dispose(): void {
        this.interactionController.dispose();
        this.cameraController.dispose();
        this.filamentManager.dispose();
        this.globeMesh.dispose();
        this.electrode.dispose();
        this.starfield.dispose();
        this.globeRenderer.dispose();
    }
}
