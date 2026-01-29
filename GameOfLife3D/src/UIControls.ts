import { GameEngine } from './GameEngine.js';
import { Renderer3D } from './Renderer3D.js';
import { CameraController } from './CameraController.js';
import { PatternLoader } from './PatternLoader.js';
import { PopulationGraph, GraphSize } from './PopulationGraph.js';

export interface UIState {
    gridSize: number;
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
    private populationGraph: PopulationGraph;

    private elements: { [key: string]: HTMLElement } = {};
    private isPlaying = false;
    private animationSpeed = 200;
    private currentAnimationFrame = 0;
    private lastAnimationTime = 0;

    private fpsCounter = 0;
    private lastFpsTime = 0;
    private frameCount = 0;
    private cachedTotalCells = 0;

    constructor(
        gameEngine: GameEngine,
        renderer: Renderer3D,
        cameraController: CameraController,
        patternLoader: PatternLoader,
        populationGraph: PopulationGraph
    ) {
        this.gameEngine = gameEngine;
        this.renderer = renderer;
        this.cameraController = cameraController;
        this.patternLoader = patternLoader;
        this.populationGraph = populationGraph;

        this.initializeElements();
        this.setupEventListeners();
        this.updateUI();
    }

    private initializeElements(): void {
        const elementIds = [
            'toggle-controls', 'controls',
            'grid-size', 'rule-preset', 'custom-rule-container', 'custom-birth', 'custom-survival', 'apply-custom-rule',
            'toroidal-toggle', 'display-start', 'display-end',
            'play-pause-btn', 'step-back', 'step-forward', 'reset-simulation',
            'cell-padding', 'padding-value', 'cell-color', 'grid-lines', 'generation-labels',
            'face-color-cycling', 'edge-color-cycling', 'edge-color', 'edge-color-angle', 'angle-value',
            'graph-toggle', 'graph-size',
            'load-pattern', 'load-pattern-btn', 'save-session', 'load-session', 'load-session-btn',
            'reset-camera',
            'status-generation', 'status-rule', 'status-fps', 'status-cells'
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

        if (this.elements['toroidal-toggle']) {
            this.elements['toroidal-toggle'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onToroidalChange(target.checked);
            });
        }

        if (this.elements['rule-preset']) {
            this.elements['rule-preset'].addEventListener('change', (e) => {
                const target = e.target as HTMLSelectElement;
                this.onRulePresetChange(target.value);
            });
        }

        if (this.elements['apply-custom-rule']) {
            this.elements['apply-custom-rule'].addEventListener('click', () => {
                this.onApplyCustomRule();
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

        if (this.elements['play-pause-btn']) {
            this.elements['play-pause-btn'].addEventListener('click', () => this.togglePlayPause());
        }

        if (this.elements['step-back']) {
            this.elements['step-back'].addEventListener('click', () => this.stepGeneration(-1));
        }

        if (this.elements['step-forward']) {
            this.elements['step-forward'].addEventListener('click', () => this.stepGeneration(1));
        }

        if (this.elements['reset-simulation']) {
            this.elements['reset-simulation'].addEventListener('click', () => this.resetSimulation());
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

        if (this.elements['face-color-cycling']) {
            this.elements['face-color-cycling'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onFaceColorCyclingChange(target.checked);
            });
        }

        // Disable color picker by default since face color cycling starts enabled
        const colorPicker = this.elements['cell-color'] as HTMLInputElement | undefined;
        if (colorPicker) {
            colorPicker.disabled = true;
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

        if (this.elements['edge-color']) {
            this.elements['edge-color'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onEdgeColorChange(target.value);
            });
        }

        if (this.elements['edge-color-angle']) {
            this.elements['edge-color-angle'].addEventListener('input', (e) => {
                const target = e.target as HTMLInputElement;
                this.onEdgeColorAngleChange(parseInt(target.value));
            });
        }

        if (this.elements['graph-toggle']) {
            this.elements['graph-toggle'].addEventListener('change', (e) => {
                const target = e.target as HTMLInputElement;
                this.onGraphToggleChange(target.checked);
            });
        }

        if (this.elements['graph-size']) {
            this.elements['graph-size'].addEventListener('change', (e) => {
                const target = e.target as HTMLSelectElement;
                this.onGraphSizeChange(target.value as GraphSize);
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

    private onToroidalChange(enabled: boolean): void {
        this.gameEngine.setToroidal(enabled);
        // Toroidal mode affects generation computation, so we need to recompute
        // from the initial pattern if generations have been computed
        const generations = this.gameEngine.getGenerations();
        if (generations.length > 1) {
            // Keep the initial generation (gen 0) and recompute
            const gen0Cells = generations[0].cells;
            const genCount = generations.length;
            this.gameEngine.clear();
            this.gameEngine.initializeFromPattern(gen0Cells);
            this.gameEngine.computeGenerations(genCount);
            this.syncDisplayRange();
            this.renderCurrentView();
            this.updateUI();
        }
    }

    private onRulePresetChange(ruleKey: string): void {
        const customContainer = this.elements['custom-rule-container'];

        if (ruleKey === 'custom') {
            // Show custom rule input
            if (customContainer) {
                customContainer.style.display = 'block';
            }
            return;
        }

        // Hide custom rule input
        if (customContainer) {
            customContainer.style.display = 'none';
        }

        this.gameEngine.setRule(ruleKey);
        this.recomputeGenerations();
    }

    private onApplyCustomRule(): void {
        const birthInput = this.elements['custom-birth'] as HTMLInputElement | undefined;
        const survivalInput = this.elements['custom-survival'] as HTMLInputElement | undefined;

        if (!birthInput || !survivalInput) {
            return;
        }

        const birthStr = birthInput.value.replace(/[^0-8]/g, '');
        const survivalStr = survivalInput.value.replace(/[^0-8]/g, '');

        const birth = birthStr.split('').map(Number).filter((n, i, a) => a.indexOf(n) === i);
        const survival = survivalStr.split('').map(Number).filter((n, i, a) => a.indexOf(n) === i);

        this.gameEngine.setCustomRule(birth, survival);
        this.recomputeGenerations();
    }

    private recomputeGenerations(): void {
        // Rule change affects generation computation, so we need to recompute
        const generations = this.gameEngine.getGenerations();
        if (generations.length > 1) {
            const gen0Cells = generations[0].cells;
            const genCount = generations.length;
            this.gameEngine.clear();
            this.gameEngine.initializeFromPattern(gen0Cells);
            this.gameEngine.computeGenerations(genCount);
            this.syncDisplayRange();
        }
        this.renderCurrentView();
        this.updateUI();
    }

    private onDisplayRangeChange(): void {
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '0');

        if (start <= end) {
            this.renderCurrentView();
            this.updateUI();
        }
    }

    private togglePlayPause(): void {
        if (this.isPlaying) {
            this.stopAnimation();
        } else {
            this.startAnimation();
        }
    }

    private startAnimation(): void {
        this.isPlaying = true;
        this.updatePlayPauseButton();
        this.animate();
    }

    private stopAnimation(): void {
        this.isPlaying = false;
        this.updatePlayPauseButton();
    }

    private updatePlayPauseButton(): void {
        const btn = this.elements['play-pause-btn'] as HTMLButtonElement | undefined;
        if (btn) {
            btn.textContent = this.isPlaying ? 'Pause' : 'Play';
        }
    }

    private animate(): void {
        if (!this.isPlaying) return;

        const now = Date.now();
        if (now - this.lastAnimationTime > this.animationSpeed) {
            // Compute the next generation
            const computed = this.gameEngine.computeSingleGeneration();

            if (computed) {
                // Update display range to show the growing timeline
                const endInput = this.elements['display-end'] as HTMLInputElement | undefined;
                if (endInput) {
                    const maxGen = this.gameEngine.getGenerationCount() - 1;
                    endInput.value = maxGen.toString();
                    endInput.max = maxGen.toString();
                }

                // Update start input max as well
                const startInput = this.elements['display-start'] as HTMLInputElement | undefined;
                if (startInput) {
                    const maxGen = this.gameEngine.getGenerationCount() - 1;
                    startInput.max = maxGen.toString();
                }

                this.renderCurrentView();
                this.updateUI();
            } else {
                // Reached max generations, stop playing
                this.stopAnimation();
            }

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
        const end = parseInt(endInput.value || '0');
        let maxGen = this.gameEngine.getGenerationCount() - 1;

        // Ensure we have valid generations to step through
        if (maxGen < 0) {
            return;
        }

        const windowSize = end - start;

        // Calculate new positions
        let newStart = start + direction;
        let newEnd = end + direction;

        // If stepping forward and at the edge, compute a new generation
        if (direction > 0 && newEnd > maxGen) {
            const computed = this.gameEngine.computeSingleGeneration();
            if (computed) {
                maxGen = this.gameEngine.getGenerationCount() - 1;
                // Update input max values
                startInput.max = maxGen.toString();
                endInput.max = maxGen.toString();
            } else {
                // At max, can't step forward
                return;
            }
        }

        // Boundary checks
        if (direction > 0 && newEnd > maxGen) {
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

        // Enable edge color picker when cycling is OFF, disable when ON
        const edgeColorPicker = this.elements['edge-color'] as HTMLInputElement | undefined;
        if (edgeColorPicker) {
            edgeColorPicker.disabled = enabled;
        }

        // Disable angle slider when cycling is OFF (angle only applies to cycling)
        const angleSlider = this.elements['edge-color-angle'] as HTMLInputElement | undefined;
        if (angleSlider) {
            angleSlider.disabled = !enabled;
        }

        this.renderCurrentView();
    }

    private onEdgeColorChange(color: string): void {
        this.renderer.setRenderSettings({ edgeColor: color });
        this.renderCurrentView();
    }

    private onEdgeColorAngleChange(angle: number): void {
        if (this.elements['angle-value']) {
            this.elements['angle-value'].textContent = `${angle}°`;
        }
        this.renderer.setRenderSettings({ edgeColorAngle: angle });
        this.renderCurrentView();
    }

    private onFaceColorCyclingChange(enabled: boolean): void {
        this.renderer.setRenderSettings({ faceColorCycling: enabled });

        // Disable color picker when cycling is ON, enable when OFF
        const colorPicker = this.elements['cell-color'] as HTMLInputElement | undefined;
        if (colorPicker) {
            colorPicker.disabled = enabled;
        }

        this.renderCurrentView();
    }

    private onGraphToggleChange(visible: boolean): void {
        this.populationGraph.setVisible(visible);
    }

    private onGraphSizeChange(size: GraphSize): void {
        this.populationGraph.setSize(size);
        this.renderPopulationGraph();
    }

    private renderPopulationGraph(): void {
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '0');
        const generations = this.gameEngine.getGenerations();

        this.populationGraph.render(generations, { min: start, max: end });
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

                // Restore toroidal toggle state
                const toroidalToggle = this.elements['toroidal-toggle'] as HTMLInputElement | undefined;
                if (toroidalToggle) {
                    toroidalToggle.checked = state.toroidal ?? false;
                }

                // Restore rule preset state
                const rulePreset = this.elements['rule-preset'] as HTMLSelectElement | undefined;
                const customContainer = this.elements['custom-rule-container'];
                if (rulePreset) {
                    const ruleName = state.ruleName ?? 'conway';
                    if (ruleName === 'custom') {
                        rulePreset.value = 'custom';
                        if (customContainer) {
                            customContainer.style.display = 'block';
                        }
                        // Populate custom rule inputs
                        const birthInput = this.elements['custom-birth'] as HTMLInputElement | undefined;
                        const survivalInput = this.elements['custom-survival'] as HTMLInputElement | undefined;
                        if (birthInput && state.birthRule) {
                            birthInput.value = state.birthRule.join('');
                        }
                        if (survivalInput && state.survivalRule) {
                            survivalInput.value = state.survivalRule.join('');
                        }
                    } else {
                        rulePreset.value = ruleName;
                        if (customContainer) {
                            customContainer.style.display = 'none';
                        }
                    }
                }

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

    private resetSimulation(): void {
        // Stop any running animation
        if (this.isPlaying) {
            this.stopAnimation();
        }

        // Clear all generations and reset the game engine
        this.gameEngine.clear();

        // Reset rule to default Conway's Life
        this.gameEngine.setRule('conway');
        const rulePreset = this.elements['rule-preset'] as HTMLSelectElement | undefined;
        if (rulePreset) {
            rulePreset.value = 'conway';
        }
        const customContainer = this.elements['custom-rule-container'];
        if (customContainer) {
            customContainer.style.display = 'none';
        }

        // Reset toroidal to off
        this.gameEngine.setToroidal(false);
        const toroidalToggle = this.elements['toroidal-toggle'] as HTMLInputElement | undefined;
        if (toroidalToggle) {
            toroidalToggle.checked = false;
        }

        // Load default pattern (r-pentomino) to create generation 0
        const defaultPattern = this.patternLoader.getBuiltInPattern('r-pentomino');
        if (defaultPattern) {
            this.gameEngine.initializeFromPattern(defaultPattern);
        }

        // Sync display range and update view
        this.syncDisplayRange();
        this.renderCurrentView();
        this.updateUI();
    }

    syncDisplayRange(): void {
        const startInput = this.elements['display-start'] as HTMLInputElement | undefined;
        const endInput = this.elements['display-end'] as HTMLInputElement | undefined;

        if (!startInput || !endInput) {
            return;
        }

        const maxGen = Math.max(0, this.gameEngine.getGenerationCount() - 1);

        startInput.max = maxGen.toString();
        startInput.value = '0';
        endInput.max = maxGen.toString();
        endInput.value = maxGen.toString();
    }

    private renderCurrentView(): void {
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '50');
        const generations = this.gameEngine.getGenerations();

        // Compute and cache total cells for visible generations
        let totalCells = 0;
        for (let i = start; i <= end && i < generations.length; i++) {
            if (generations[i]) {
                totalCells += generations[i].liveCells.length;
            }
        }
        this.cachedTotalCells = totalCells;

        this.renderer.renderGenerations(generations, start, end);
        this.populationGraph.render(generations, { min: start, max: end });
    }

    private updateUI(): void {
        const start = parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0');
        const end = parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '50');

        if (this.elements['status-generation']) {
            this.elements['status-generation'].textContent = `Gen: ${start}-${end}`;
        }

        if (this.elements['status-rule']) {
            this.elements['status-rule'].textContent = `Rule: ${this.gameEngine.getRuleString()}`;
        }

        if (this.elements['status-cells']) {
            this.elements['status-cells'].textContent = `Cells: ${this.cachedTotalCells}`;
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
            displayStart: parseInt((this.elements['display-start'] as HTMLInputElement)?.value || '0'),
            displayEnd: parseInt((this.elements['display-end'] as HTMLInputElement)?.value || '0'),
            cellPadding: parseInt((this.elements['cell-padding'] as HTMLInputElement)?.value || '20'),
            cellColor: (this.elements['cell-color'] as HTMLInputElement)?.value || '#00ff88',
            showGridLines: (this.elements['grid-lines'] as HTMLInputElement)?.checked || true,
            showGenerationLabels: (this.elements['generation-labels'] as HTMLInputElement)?.checked || true,
            isPlaying: this.isPlaying,
            animationSpeed: this.animationSpeed
        };
    }
}
