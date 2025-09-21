export class UIControls {
    constructor(gameEngine, renderer, cameraController, patternLoader) {
        this.elements = {};
        this.isPlaying = false;
        this.animationSpeed = 200;
        this.currentAnimationFrame = 0;
        this.lastAnimationTime = 0;
        this.fpsCounter = 0;
        this.lastFpsTime = 0;
        this.frameCount = 0;
        this.gameEngine = gameEngine;
        this.renderer = renderer;
        this.cameraController = cameraController;
        this.patternLoader = patternLoader;
        this.initializeElements();
        this.setupEventListeners();
        this.updateUI();
    }
    initializeElements() {
        const elementIds = [
            'toggle-controls', 'controls',
            'grid-size', 'generation-count', 'display-start', 'display-end',
            'compute-btn', 'play-btn', 'pause-btn', 'step-back', 'step-forward',
            'cell-padding', 'padding-value', 'cell-color', 'grid-lines', 'generation-labels',
            'load-pattern', 'load-pattern-btn', 'save-session', 'load-session', 'load-session-btn',
            'reset-camera',
            'status-generation', 'status-fps', 'status-cells'
        ];
        elementIds.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                this.elements[id] = element;
            }
            else {
                console.warn(`Element with id '${id}' not found`);
            }
        });
    }
    setupEventListeners() {
        if (this.elements['toggle-controls']) {
            this.elements['toggle-controls'].addEventListener('click', () => this.toggleControlsPanel());
        }
        if (this.elements['grid-size']) {
            this.elements['grid-size'].addEventListener('change', (e) => {
                const target = e.target;
                this.onGridSizeChange(parseInt(target.value));
            });
        }
        if (this.elements['generation-count']) {
            this.elements['generation-count'].addEventListener('input', (e) => {
                const target = e.target;
                this.onGenerationCountChange(parseInt(target.value));
            });
        }
        if (this.elements['display-start']) {
            this.elements['display-start'].addEventListener('input', (e) => {
                const target = e.target;
                this.onDisplayRangeChange();
            });
        }
        if (this.elements['display-end']) {
            this.elements['display-end'].addEventListener('input', (e) => {
                const target = e.target;
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
                const target = e.target;
                this.onCellPaddingChange(parseInt(target.value));
            });
        }
        if (this.elements['cell-color']) {
            this.elements['cell-color'].addEventListener('change', (e) => {
                const target = e.target;
                this.onCellColorChange(target.value);
            });
        }
        if (this.elements['grid-lines']) {
            this.elements['grid-lines'].addEventListener('change', (e) => {
                const target = e.target;
                this.onGridLinesChange(target.checked);
            });
        }
        if (this.elements['generation-labels']) {
            this.elements['generation-labels'].addEventListener('change', (e) => {
                const target = e.target;
                this.onGenerationLabelsChange(target.checked);
            });
        }
        if (this.elements['load-pattern-btn']) {
            this.elements['load-pattern-btn'].addEventListener('click', () => {
                this.elements['load-pattern']?.click();
            });
        }
        if (this.elements['load-pattern']) {
            this.elements['load-pattern'].addEventListener('change', (e) => {
                const target = e.target;
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
                const target = e.target;
                this.loadSessionFile(target.files);
            });
        }
        if (this.elements['reset-camera']) {
            this.elements['reset-camera'].addEventListener('click', () => this.resetCamera());
        }
        document.querySelectorAll('.pattern-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const target = e.target;
                const pattern = target.getAttribute('data-pattern');
                if (pattern) {
                    this.loadBuiltInPattern(pattern);
                }
            });
        });
    }
    toggleControlsPanel() {
        const controls = this.elements['controls'];
        const toggle = this.elements['toggle-controls'];
        if (controls) {
            controls.classList.toggle('collapsed');
            if (toggle) {
                toggle.textContent = controls.classList.contains('collapsed') ? '▶' : '◀';
            }
        }
    }
    onGridSizeChange(size) {
        this.gameEngine.setGridSize(size);
        this.renderer.setGridSize(size);
        this.updateDisplayRange();
        this.updateUI();
    }
    onGenerationCountChange(count) {
        this.updateDisplayRange();
        this.updateUI();
    }
    onDisplayRangeChange() {
        const start = parseInt(this.elements['display-start']?.value || '0');
        const end = parseInt(this.elements['display-end']?.value || '50');
        if (start <= end) {
            this.renderCurrentView();
            this.updateUI();
        }
    }
    computeGenerations() {
        const count = parseInt(this.elements['generation-count']?.value || '50');
        try {
            if (this.gameEngine.getGenerationCount() === 0) {
                this.gameEngine.initializeRandom(0.3);
            }
            this.gameEngine.computeGenerations(count);
            this.updateDisplayRange();
            this.renderCurrentView();
            this.updateUI();
        }
        catch (error) {
            console.error('Error computing generations:', error);
            alert('Please load a pattern first or ensure grid is properly initialized.');
        }
    }
    startAnimation() {
        this.isPlaying = true;
        this.animate();
    }
    stopAnimation() {
        this.isPlaying = false;
    }
    animate() {
        if (!this.isPlaying)
            return;
        const now = Date.now();
        if (now - this.lastAnimationTime > this.animationSpeed) {
            this.stepGeneration(1);
            this.lastAnimationTime = now;
        }
        requestAnimationFrame(() => this.animate());
    }
    stepGeneration(direction) {
        const start = parseInt(this.elements['display-start']?.value || '0');
        const end = parseInt(this.elements['display-end']?.value || '50');
        const maxGen = this.gameEngine.getGenerationCount() - 1;
        let newStart = Math.max(0, start + direction);
        let newEnd = Math.max(1, end + direction);
        if (newEnd > maxGen) {
            newEnd = maxGen;
            newStart = Math.max(0, newEnd - (end - start));
        }
        if (newStart < 0) {
            newStart = 0;
            newEnd = Math.min(maxGen, newStart + (end - start));
        }
        this.elements['display-start'].value = newStart.toString();
        this.elements['display-end'].value = newEnd.toString();
        this.renderCurrentView();
        this.updateUI();
    }
    onCellPaddingChange(padding) {
        if (this.elements['padding-value']) {
            this.elements['padding-value'].textContent = `${padding}%`;
        }
        this.renderer.setRenderSettings({ cellPadding: padding });
        this.renderCurrentView();
    }
    onCellColorChange(color) {
        this.renderer.setRenderSettings({ cellColor: color });
        this.renderCurrentView();
    }
    onGridLinesChange(show) {
        this.renderer.setRenderSettings({ showGridLines: show });
        this.renderCurrentView();
    }
    onGenerationLabelsChange(show) {
        this.renderer.setRenderSettings({ showGenerationLabels: show });
        this.renderCurrentView();
    }
    loadPatternFile(files) {
        if (!files || files.length === 0)
            return;
        const file = files[0];
        const reader = new FileReader();
        reader.onload = (e) => {
            const content = e.target?.result;
            try {
                const pattern = this.patternLoader.parseRLE(content);
                this.gameEngine.initializeFromPattern(pattern);
                this.updateDisplayRange();
                this.renderCurrentView();
                this.updateUI();
            }
            catch (error) {
                console.error('Error loading pattern:', error);
                alert('Error loading pattern file. Please check the format.');
            }
        };
        reader.readAsText(file);
    }
    saveSession() {
        const state = this.gameEngine.exportState();
        const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `gameoflife3d_session_${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }
    loadSessionFile(files) {
        if (!files || files.length === 0)
            return;
        const file = files[0];
        const reader = new FileReader();
        reader.onload = (e) => {
            const content = e.target?.result;
            try {
                const state = JSON.parse(content);
                this.gameEngine.importState(state);
                this.elements['grid-size'].value = state.gridSize.toString();
                this.renderer.setGridSize(state.gridSize);
                this.updateDisplayRange();
                this.renderCurrentView();
                this.updateUI();
            }
            catch (error) {
                console.error('Error loading session:', error);
                alert('Error loading session file. Please check the format.');
            }
        };
        reader.readAsText(file);
    }
    loadBuiltInPattern(patternName) {
        const pattern = this.patternLoader.getBuiltInPattern(patternName);
        if (pattern) {
            this.gameEngine.initializeFromPattern(pattern);
            this.updateDisplayRange();
            this.renderCurrentView();
            this.updateUI();
        }
    }
    resetCamera() {
        this.cameraController.reset();
    }
    updateDisplayRange() {
        const maxGen = Math.max(0, this.gameEngine.getGenerationCount() - 1);
        const generationCount = parseInt(this.elements['generation-count']?.value || '50');
        this.elements['display-start'].max = maxGen.toString();
        this.elements['display-end'].max = maxGen.toString();
        this.elements['display-end'].value = Math.min(generationCount - 1, maxGen).toString();
    }
    renderCurrentView() {
        const start = parseInt(this.elements['display-start']?.value || '0');
        const end = parseInt(this.elements['display-end']?.value || '50');
        const generations = this.gameEngine.getGenerations();
        this.renderer.renderGenerations(generations, start, end);
    }
    updateUI() {
        const generations = this.gameEngine.getGenerations();
        const start = parseInt(this.elements['display-start']?.value || '0');
        const end = parseInt(this.elements['display-end']?.value || '50');
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
    updateFPS() {
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
    getState() {
        return {
            gridSize: parseInt(this.elements['grid-size']?.value || '50'),
            generationCount: parseInt(this.elements['generation-count']?.value || '50'),
            displayStart: parseInt(this.elements['display-start']?.value || '0'),
            displayEnd: parseInt(this.elements['display-end']?.value || '50'),
            cellPadding: parseInt(this.elements['cell-padding']?.value || '20'),
            cellColor: this.elements['cell-color']?.value || '#00ff88',
            showGridLines: this.elements['grid-lines']?.checked || true,
            showGenerationLabels: this.elements['generation-labels']?.checked || true,
            isPlaying: this.isPlaying,
            animationSpeed: this.animationSpeed
        };
    }
}
//# sourceMappingURL=UIControls.js.map