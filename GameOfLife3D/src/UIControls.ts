import { GameEngine } from './GameEngine.js';
import { Renderer3D } from './Renderer3D.js';
import { CameraController } from './CameraController.js';
import { PatternLoader } from './PatternLoader.js';

export interface UIState {
    gridSize: number;
    generationCount: number;
    displayStart: number;
    displayEnd: number;
    cellPadding: number;
    cellColor: string;
    showGridLines: boolean;
    showGenerationLabels: boolean;
    isPlaying: boolean;
    animationSpeed: number;
}

export class UIControls {
    private gameEngine: GameEngine;
    private renderer: Renderer3D;
    private cameraController: CameraController;
    private patternLoader: PatternLoader;

    private elements: { [key: string]: HTMLElement } = {};
    private isPlaying = false;
    private animationSpeed = 200;
    private currentAnimationFrame = 0;
    private lastAnimationTime = 0;

    private fpsCounter = 0;
    private lastFpsTime = 0;
    private frameCount = 0;

    constructor(
        gameEngine: GameEngine,
        renderer: Renderer3D,
        cameraController: CameraController,
        patternLoader: PatternLoader
    ) {
        this.gameEngine = gameEngine;
        this.renderer = renderer;
        this.cameraController = cameraController;
        this.patternLoader = patternLoader;

        this.initializeElements();
        this.setupEventListeners();
        this.updateUI();
    }

    private initializeElements(): void {
        const elementIds = [
            'toggle-controls', 'controls',
            'grid-size', 'generation-count', 'display-start', 'display-end',
            'compute-btn', 'play-btn', 'pause-btn', 'step-back', 'step-forward',
            'cell-padding', 'padding-value', 'cell-color', 'grid-lines', 'generation-labels',
            'edge-color-cycling', 'edge-color-angle', 'angle-value',
            'load-pattern', 'load-pattern-btn', 'save-session', 'load-session', 'load-session-btn',
            'reset-camera',
            'status-generation', 'status-fps', 'status-cells'
        ];

        elementIds.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                this.elements[id] = element;
            } else {
                console.warn(`Element with id '${id}' not found`);
            }
        });

        const controls = this.elements['controls'];
        if (controls) {
            controls.setAttribute('aria-hidden', 'false');
        }

        const toggle = this.elements['toggle-controls'] as HTMLButtonElement | undefined;
        if (toggle) {
            toggle.setAttribute('aria-expanded', 'true');
            toggle.setAttribute('aria-label', 'Hide Controls panel');
            toggle.setAttribute('title', 'Hide Controls');
        }
    }

    private setupEventListeners(): void {
        if (this.elements['toggle-controls']) {
            this.elements['toggle-controls'].addEventListener('click', () => this.toggleControlsPanel());
        }

        if (this.elements['grid-size']) {
            this.elements['grid-size'].addEventListener('change', (e) => {
                const target = e.target as HTMLSelectElement;
                this.onGridSizeChange(parseInt(target.value));
            });
        }

        if (this.elements['generation-count']) {
            this.elements['generation-count'].addEventListener('input', (e) => {
                const target = e.target as HTMLInputElement;
                this.onGenerationCountChange(parseInt(target.value));
            });
        }

        if (this.elements['display-start']) {
            this.elements['display-start'].addEventListener('input', (e) => {
                const target = e.target as HTMLInputElement;
                this.onDisplayRangeChange();
            });
        }

        if (this.elements['display-end']) {
            this.elements['display-end'].addEventListener('input', (e) => {
                const target = e.target as HTMLInputElement;
                this.onDisplayRangeChange();
            });
        }

        if (this.elements['compute-btn']) {
            this.elements['compute-btn'].addEventListener('click', () => this.computeGenerations());
        }

        if (this.elements['play-btn']) {
            this.elements['play-btn'].addEventListener('click', () => this.startAnimation());
        }

        if (this.elements['pause-btn']) {
            this.elements['pause-btn'].addEventListener('click', () => this.stopAnimation());
        }

        if (this.elements['step-back']) {
            this.elements['step-back'].addEventListener('click', () => this.stepGeneration(-1));
        }

        if (this.elements['step-forward']) {
            this.elements['step-forward'].addEventListener('click', () => this.stepGeneration(1));
        }

        if (this.elements['cell-padding']) {
            this.elements['cell-padding'].addEventListener('input', (e) => {
                const target = e.target as HTMLInputElement;
                this.onCellPaddingChange(parseInt(target.value));
            });
        }

        if (this.elements['cell-color']) {
            this.elements['cell-color'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onCellColorChange(target.value);
            });
        }

        if (this.elements['grid-lines']) {
            this.elements['grid-lines'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onGridLinesChange(target.checked);
            });
        }

        if (this.elements['generation-labels']) {
            this.elements['generation-labels'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onGenerationLabelsChange(target.checked);
            });
        }

        if (this.elements['edge-color-cycling']) {
            this.elements['edge-color-cycling'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onEdgeColorCyclingChange(target.checked);
            });
        }

        if (this.elements['edge-color-angle']) {
            this.elements['edge-color-angle'].addEventListener('input', (e) => {
                const target = e.target as HTMLInputElement;
                this.onEdgeColorAngleChange(parseInt(target.value));
            });
        }

        if (this.elements['load-pattern-btn']) {
            this.elements['load-pattern-btn'].addEventListener('click', () => {
                this.elements['load-pattern']?.click();
            });
        }

        if (this.elements['load-pattern']) {
            this.elements['load-pattern'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.loadPatternFile(target.files);
            });
        }

        if (this.elements['save-session']) {
            this.elements['save-session'].addEventListener('click', () => this.saveSession());
        }

        if (this.elements['load-session-btn']) {
            this.elements['load-session-btn'].addEventListener('click', () => {
                this.elements['load-session']?.click();
            });
        }

        if (this.elements['load-session']) {
            this.elements['load-session'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.loadSessionFile(target.files);
            });
        }

        if (this.elements['reset-camera']) {
            this.elements['reset-camera'].addEventListener('click', () => this.resetCamera());
        }

        document.querySelectorAll('.pattern-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const target = e.target as HTMLElement;
                const pattern = target.getAttribute('data-pattern');
                if (pattern) {
                    this.loadBuiltInPattern(pattern);
                }
            });
        });
    }

    private toggleControlsPanel(): void {
        const controls = this.elements['controls'];
        const toggle = this.elements['toggle-controls'] as HTMLButtonElement | undefined;

        if (!controls || !toggle) {
            return;
        }

        const isCollapsed = controls.classList.toggle('collapsed');
        document.body.classList.toggle('controls-collapsed', isCollapsed);
        controls.setAttribute('aria-hidden', isCollapsed.toString());

        const expandedText = 'Hide Controls';
        const collapsedText = 'Show Controls';
        const label = isCollapsed ? collapsedText : expandedText;

        toggle.textContent = label;
        toggle.setAttribute('aria-expanded', (!isCollapsed).toString());
        toggle.setAttribute('aria-label', `${label} panel`);
        toggle.setAttribute('title', label);

        window.requestAnimationFrame(() => {
            window.dispatchEvent(new Event('resize'));
        });
    }

    private onGridSizeChange(size: number): void {
        this.gameEngine.setGridSize(size);
        this.renderer.setGridSize(size);
        this.syncDisplayRange();
        this.updateUI();
    }

    private onGenerationCountChange(count: number): void {
        this.syncDisplayRange();
        this.updateUI();
    }

    private onDisplayRangeChange(): void {
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '50');

        if (start <= end) {
            this.renderCurrentView();
            this.updateUI();
        }
    }

    private computeGenerations(): void {
        const count = parseInt((this.elements['generation-count'] as HTMLInputElement)?.value || '50');

        try {
            if (this.gameEngine.getGenerationCount() === 0) {
                this.gameEngine.initializeRandom(0.3);
            }

            this.gameEngine.computeGenerations(count);
            this.syncDisplayRange();
            this.renderCurrentView();
            this.updateUI();
        } catch (error) {
            console.error('Error computing generations:', error);
            alert('Please load a pattern first or ensure grid is properly initialized.');
        }
    }

    private startAnimation(): void {
        this.isPlaying = true;
        this.animate();
    }

    private stopAnimation(): void {
        this.isPlaying = false;
    }

    private animate(): void {
        if (!this.isPlaying) return;

        const now = Date.now();
        if (now - this.lastAnimationTime > this.animationSpeed) {
            this.stepGeneration(1);
            this.lastAnimationTime = now;
        }

        requestAnimationFrame(() => this.animate());
    }

    private stepGeneration(direction: number): void {
        const startInput = this.elements['display-start'] as HTMLInputElement | undefined;
        const endInput = this.elements['display-end'] as HTMLInputElement | undefined;

        if (!startInput || !endInput) {
            console.warn('Display range inputs not found');
            return;
        }

        const start = parseInt(startInput.value || '0');
        const end = parseInt(endInput.value || '50');
        const maxGen = this.gameEngine.getGenerationCount() - 1;

        // Ensure we have valid generations to step through
        if (maxGen < 0) {
            return;
        }

        const windowSize = end - start;

        // Calculate new positions
        let newStart = start + direction;
        let newEnd = end + direction;

        // Boundary checks - stop at edges rather than clamping back
        if (direction > 0 && newEnd > maxGen) {
            // Stepping forward: stop if already at the end
            if (end >= maxGen) {
                return; // Already at the end, can't step forward
            }
            // Clamp to the end while preserving window size if possible
            newEnd = maxGen;
            newStart = Math.max(0, newEnd - windowSize);
        }

        if (direction < 0 && newStart < 0) {
            // Stepping backward: stop if already at the start
            if (start <= 0) {
                return; // Already at the start, can't step backward
            }
            // Clamp to the start while preserving window size if possible
            newStart = 0;
            newEnd = Math.min(maxGen, newStart + windowSize);
        }

        startInput.value = newStart.toString();
        endInput.value = newEnd.toString();

        this.renderCurrentView();
        this.updateUI();
    }

    private onCellPaddingChange(padding: number): void {
        if (this.elements['padding-value']) {
            this.elements['padding-value'].textContent = `${padding}%`;
        }
        this.renderer.setRenderSettings({ cellPadding: padding });
        this.renderCurrentView();
    }

    private onCellColorChange(color: string): void {
        this.renderer.setRenderSettings({ cellColor: color });
        this.renderCurrentView();
    }

    private onGridLinesChange(show: boolean): void {
        this.renderer.setRenderSettings({ showGridLines: show });
        this.renderCurrentView();
    }

    private onGenerationLabelsChange(show: boolean): void {
        this.renderer.setRenderSettings({ showGenerationLabels: show });
        this.renderCurrentView();
    }

    private onEdgeColorCyclingChange(enabled: boolean): void {
        this.renderer.setRenderSettings({ edgeColorCycling: enabled });
        this.renderCurrentView();
    }

    private onEdgeColorAngleChange(angle: number): void {
        if (this.elements['angle-value']) {
            this.elements['angle-value'].textContent = `${angle}°`;
        }
        this.renderer.setRenderSettings({ edgeColorAngle: angle });
        this.renderCurrentView();
    }

    private loadPatternFile(files: FileList | null): void {
        if (!files || files.length === 0) return;

        const file = files[0];
        const reader = new FileReader();

        reader.onload = (e) => {
            const content = e.target?.result as string;
            try {
                const pattern = this.patternLoader.parseRLE(content);
                this.gameEngine.initializeFromPattern(pattern);
                this.syncDisplayRange();
                this.renderCurrentView();
                this.updateUI();
            } catch (error) {
                console.error('Error loading pattern:', error);
                alert('Error loading pattern file. Please check the format.');
            }
        };

        reader.readAsText(file);
    }

    private saveSession(): void {
        const state = this.gameEngine.exportState();
        const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = `gameoflife3d_session_${Date.now()}.json`;
        a.click();

        URL.revokeObjectURL(url);
    }

    private loadSessionFile(files: FileList | null): void {
        if (!files || files.length === 0) return;

        const file = files[0];
        const reader = new FileReader();

        reader.onload = (e) => {
            const content = e.target?.result as string;
            try {
                const state = JSON.parse(content);
                this.gameEngine.importState(state);

                (this.elements['grid-size'] as HTMLSelectElement).value = state.gridSize.toString();
                this.renderer.setGridSize(state.gridSize);

                this.syncDisplayRange();
                this.renderCurrentView();
                this.updateUI();
            } catch (error) {
                console.error('Error loading session:', error);
                alert('Error loading session file. Please check the format.');
            }
        };

        reader.readAsText(file);
    }

    private loadBuiltInPattern(patternName: string): void {
        const pattern = this.patternLoader.getBuiltInPattern(patternName);
        if (pattern) {
            this.gameEngine.initializeFromPattern(pattern);
            this.syncDisplayRange();
            this.renderCurrentView();
            this.updateUI();
        }
    }

    private resetCamera(): void {
        this.cameraController.reset();
    }

    syncDisplayRange(): void {
        const startInput = this.elements['display-start'] as HTMLInputElement | undefined;
        const endInput = this.elements['display-end'] as HTMLInputElement | undefined;

        if (!startInput || !endInput) {
            return;
        }

        const maxGen = Math.max(0, this.gameEngine.getGenerationCount() - 1);
        const generationCount = parseInt((this.elements['generation-count'] as HTMLInputElement)?.value || '50');

        startInput.max = maxGen.toString();
        endInput.max = maxGen.toString();
        endInput.value = Math.min(generationCount - 1, maxGen).toString();
    }

    private renderCurrentView(): void {
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '50');
        const generations = this.gameEngine.getGenerations();

        this.renderer.renderGenerations(generations, start, end);
    }

    private updateUI(): void {
        const generations = this.gameEngine.getGenerations();
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '50');

        if (this.elements['status-generation']) {
            this.elements['status-generation'].textContent = `Gen: ${start}-${end}`;
        }

        let totalCells = 0;
        for (let i = start; i <= end && i < generations.length; i++) {
            if (generations[i]) {
                totalCells += generations[i].liveCells.length;
            }
        }

        if (this.elements['status-cells']) {
            this.elements['status-cells'].textContent = `Cells: ${totalCells}`;
        }
    }

    updateFPS(): void {
        this.frameCount++;
        const now = Date.now();

        if (now - this.lastFpsTime >= 1000) {
            this.fpsCounter = Math.round((this.frameCount * 1000) / (now - this.lastFpsTime));
            this.frameCount = 0;
            this.lastFpsTime = now;

            if (this.elements['status-fps']) {
                this.elements['status-fps'].textContent = `FPS: ${this.fpsCounter}`;
            }
        }
    }

    getState(): UIState {
        return {
            gridSize: parseInt((this.elements['grid-size'] as HTMLSelectElement)?.value || '50'),
            generationCount: parseInt((this.elements['generation-count'] as HTMLInputElement)?.value || '50'),
            displayStart: parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0'),
            displayEnd: parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '50'),
            cellPadding: parseInt((this.elements['cell-padding'] as HTMLInputElement)?.value || '20'),
            cellColor: (this.elements['cell-color'] as HTMLInputElement)?.value || '#00ff88',
            showGridLines: (this.elements['grid-lines'] as HTMLInputElement)?.checked || true,
            showGenerationLabels: (this.elements['generation-labels'] as HTMLInputElement)?.checked || true,
            isPlaying: this.isPlaying,
            animationSpeed: this.animationSpeed
        };
    }
}
