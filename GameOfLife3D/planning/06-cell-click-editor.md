# Feature: Cell Click Editor

## Overview

Allow users to click directly on the initial generation (generation 0) grid to toggle cells on/off, enabling custom pattern creation without needing to write RLE or edit code.

## Motivation

- Most requested feature for cellular automaton tools
- Enables creativity and experimentation
- Lower barrier to entry for new users
- No need to understand RLE format
- Instant visual feedback
- Foundation for more advanced drawing tools

## Proposed Design

### Interaction Model

1. **Edit Mode Toggle**: Button or keyboard shortcut (E) to enter/exit edit mode
2. **Visual Feedback**:
   - Grid overlay on generation 0 when in edit mode
   - Cursor changes to crosshair
   - Hover highlights cell under cursor
3. **Click Actions**:
   - Left click: Toggle cell (alive ↔ dead)
   - Click + drag: Paint cells (all on or all off based on first click)
4. **Exit Edit Mode**: Press E, click button, or press Escape

### Visual Indicators

```
Edit Mode Active:
+----------------------------------+
|  [Exit Edit Mode]  Clear All    |
|                                  |
|     . . . . . . . . . .         |
|     . . . [X] . . . . .         |  <- Grid overlay
|     . . [X] [X] . . . .         |
|     . . . [X] . . . . .         |
|     . . . . . . . . . .         |
|                                  |
|  Click cells to toggle          |
+----------------------------------+
```

## Implementation

### 1. New File: CellEditor.ts

```typescript
import * as THREE from 'three';

export interface CellEditorConfig {
    camera: THREE.Camera;
    scene: THREE.Scene;
    renderer: THREE.WebGLRenderer;
    gridSize: number;
    onCellToggle: (x: number, y: number, state: boolean) => void;
    onEditModeChange: (active: boolean) => void;
}

export class CellEditor {
    private camera: THREE.Camera;
    private scene: THREE.Scene;
    private renderer: THREE.WebGLRenderer;
    private gridSize: number;
    private onCellToggle: (x: number, y: number, state: boolean) => void;
    private onEditModeChange: (active: boolean) => void;

    private isEditMode: boolean = false;
    private gridPlane: THREE.Mesh | null = null;
    private hoverIndicator: THREE.Mesh | null = null;
    private gridHelper: THREE.GridHelper | null = null;

    private raycaster: THREE.Raycaster = new THREE.Raycaster();
    private mouse: THREE.Vector2 = new THREE.Vector2();

    private isDragging: boolean = false;
    private dragState: boolean = true; // true = painting alive, false = painting dead
    private lastCell: { x: number, y: number } | null = null;

    constructor(config: CellEditorConfig) {
        this.camera = config.camera;
        this.scene = config.scene;
        this.renderer = config.renderer;
        this.gridSize = config.gridSize;
        this.onCellToggle = config.onCellToggle;
        this.onEditModeChange = config.onEditModeChange;

        this.createGridOverlay();
        this.createHoverIndicator();
        this.attachEventListeners();
    }

    private createGridOverlay(): void {
        // Invisible plane for raycasting
        const geometry = new THREE.PlaneGeometry(this.gridSize, this.gridSize);
        const material = new THREE.MeshBasicMaterial({
            visible: false,
            side: THREE.DoubleSide
        });
        this.gridPlane = new THREE.Mesh(geometry, material);
        this.gridPlane.rotation.x = -Math.PI / 2; // Lay flat on XZ plane
        this.gridPlane.position.set(this.gridSize / 2, 0, this.gridSize / 2);

        // Visual grid helper
        this.gridHelper = new THREE.GridHelper(
            this.gridSize,
            this.gridSize,
            0x444444,
            0x222222
        );
        this.gridHelper.position.set(this.gridSize / 2, 0.01, this.gridSize / 2);
        this.gridHelper.visible = false;
    }

    private createHoverIndicator(): void {
        const geometry = new THREE.BoxGeometry(1, 0.1, 1);
        const material = new THREE.MeshBasicMaterial({
            color: 0x00ff88,
            transparent: true,
            opacity: 0.5
        });
        this.hoverIndicator = new THREE.Mesh(geometry, material);
        this.hoverIndicator.visible = false;
    }

    public setEditMode(active: boolean): void {
        this.isEditMode = active;

        if (active) {
            this.scene.add(this.gridPlane!);
            this.scene.add(this.gridHelper!);
            this.scene.add(this.hoverIndicator!);
            this.gridHelper!.visible = true;
            this.renderer.domElement.style.cursor = 'crosshair';
        } else {
            this.scene.remove(this.gridPlane!);
            this.scene.remove(this.gridHelper!);
            this.scene.remove(this.hoverIndicator!);
            this.hoverIndicator!.visible = false;
            this.renderer.domElement.style.cursor = 'default';
        }

        this.onEditModeChange(active);
    }

    public toggleEditMode(): void {
        this.setEditMode(!this.isEditMode);
    }

    public isActive(): boolean {
        return this.isEditMode;
    }

    private attachEventListeners(): void {
        const canvas = this.renderer.domElement;

        canvas.addEventListener('mousemove', this.handleMouseMove.bind(this));
        canvas.addEventListener('mousedown', this.handleMouseDown.bind(this));
        canvas.addEventListener('mouseup', this.handleMouseUp.bind(this));
        canvas.addEventListener('mouseleave', this.handleMouseLeave.bind(this));

        document.addEventListener('keydown', (e) => {
            if (e.code === 'KeyE' && !this.isInputFocused()) {
                e.preventDefault();
                this.toggleEditMode();
            }
            if (e.code === 'Escape' && this.isEditMode) {
                this.setEditMode(false);
            }
        });
    }

    private isInputFocused(): boolean {
        const active = document.activeElement;
        return active instanceof HTMLInputElement ||
               active instanceof HTMLTextAreaElement ||
               active instanceof HTMLSelectElement;
    }

    private handleMouseMove(e: MouseEvent): void {
        if (!this.isEditMode) return;

        this.updateMousePosition(e);
        const cell = this.getCellUnderMouse();

        if (cell) {
            this.hoverIndicator!.visible = true;
            this.hoverIndicator!.position.set(cell.x + 0.5, 0.05, cell.y + 0.5);

            if (this.isDragging && this.lastCell &&
                (this.lastCell.x !== cell.x || this.lastCell.y !== cell.y)) {
                this.onCellToggle(cell.x, cell.y, this.dragState);
                this.lastCell = cell;
            }
        } else {
            this.hoverIndicator!.visible = false;
        }
    }

    private handleMouseDown(e: MouseEvent): void {
        if (!this.isEditMode || e.button !== 0) return;

        const cell = this.getCellUnderMouse();
        if (cell) {
            // Determine if we're painting or erasing based on current cell state
            // For simplicity, toggle the first cell and use that state for dragging
            this.isDragging = true;
            this.dragState = true; // Will be set by callback response if needed
            this.lastCell = cell;
            this.onCellToggle(cell.x, cell.y, this.dragState);
        }
    }

    private handleMouseUp(): void {
        this.isDragging = false;
        this.lastCell = null;
    }

    private handleMouseLeave(): void {
        this.hoverIndicator!.visible = false;
        this.isDragging = false;
        this.lastCell = null;
    }

    private updateMousePosition(e: MouseEvent): void {
        const rect = this.renderer.domElement.getBoundingClientRect();
        this.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
        this.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    }

    private getCellUnderMouse(): { x: number, y: number } | null {
        this.raycaster.setFromCamera(this.mouse, this.camera);

        const intersects = this.raycaster.intersectObject(this.gridPlane!);
        if (intersects.length > 0) {
            const point = intersects[0].point;
            const x = Math.floor(point.x);
            const y = Math.floor(point.z);

            if (x >= 0 && x < this.gridSize && y >= 0 && y < this.gridSize) {
                return { x, y };
            }
        }
        return null;
    }

    public setGridSize(size: number): void {
        this.gridSize = size;

        // Recreate grid overlay with new size
        if (this.gridPlane) {
            this.scene.remove(this.gridPlane);
            this.scene.remove(this.gridHelper!);
        }
        this.createGridOverlay();

        if (this.isEditMode) {
            this.scene.add(this.gridPlane!);
            this.scene.add(this.gridHelper!);
            this.gridHelper!.visible = true;
        }
    }

    public destroy(): void {
        this.setEditMode(false);
        // Remove event listeners (would need stored references)
    }
}
```

### 2. GameEngine.ts

Add method to toggle individual cells:

```typescript
public toggleCell(x: number, y: number): boolean {
    if (x < 0 || x >= this.gridSize || y < 0 || y >= this.gridSize) {
        return false;
    }

    // Get generation 0
    const gen0 = this.generations[0];
    if (!gen0) return false;

    // Toggle the cell
    gen0.cells[x][y] = !gen0.cells[x][y];

    // Update liveCells array
    this.updateLiveCells(gen0);

    // Clear computed generations (they're now invalid)
    this.generations = [gen0];

    return gen0.cells[x][y];
}

public setCell(x: number, y: number, alive: boolean): void {
    if (x < 0 || x >= this.gridSize || y < 0 || y >= this.gridSize) {
        return;
    }

    const gen0 = this.generations[0];
    if (!gen0) return;

    gen0.cells[x][y] = alive;
    this.updateLiveCells(gen0);
    this.generations = [gen0];
}

public getCellState(x: number, y: number): boolean {
    const gen0 = this.generations[0];
    if (!gen0 || x < 0 || x >= this.gridSize || y < 0 || y >= this.gridSize) {
        return false;
    }
    return gen0.cells[x][y];
}

public clearAllCells(): void {
    const gen0 = this.generations[0];
    if (!gen0) return;

    for (let x = 0; x < this.gridSize; x++) {
        for (let y = 0; y < this.gridSize; y++) {
            gen0.cells[x][y] = false;
        }
    }

    gen0.liveCells = [];
    this.generations = [gen0];
}

private updateLiveCells(gen: Generation): void {
    gen.liveCells = [];
    for (let x = 0; x < this.gridSize; x++) {
        for (let y = 0; y < this.gridSize; y++) {
            if (gen.cells[x][y]) {
                gen.liveCells.push({ x, y, z: gen.index });
            }
        }
    }
}
```

### 3. UIControls.ts

Add edit mode button and clear button:

```typescript
private createEditControls(): void {
    const editBtn = document.getElementById('edit-mode-btn');
    const clearBtn = document.getElementById('clear-cells-btn');

    editBtn.addEventListener('click', () => {
        this.cellEditor.toggleEditMode();
        this.updateEditButtonState();
    });

    clearBtn.addEventListener('click', () => {
        if (confirm('Clear all cells in generation 0?')) {
            this.gameEngine.clearAllCells();
            this.renderer.render();
        }
    });
}

private updateEditButtonState(): void {
    const editBtn = document.getElementById('edit-mode-btn');
    if (this.cellEditor.isActive()) {
        editBtn.classList.add('active');
        editBtn.textContent = 'Exit Edit Mode';
    } else {
        editBtn.classList.remove('active');
        editBtn.textContent = 'Edit Cells';
    }
}
```

### 4. index.html

Add edit controls:

```html
<div class="control-group">
    <button id="edit-mode-btn" title="Press E to toggle">Edit Cells</button>
    <button id="clear-cells-btn">Clear All</button>
</div>
```

### 5. styles.css

```css
#edit-mode-btn.active {
    background: rgba(0, 255, 136, 0.3);
    border-color: #00ff88;
    color: #00ff88;
}

.edit-mode-indicator {
    position: fixed;
    top: 10px;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(0, 255, 136, 0.9);
    color: black;
    padding: 8px 16px;
    border-radius: 4px;
    font-weight: bold;
    z-index: 100;
}
```

### 6. main.ts

Initialize the editor:

```typescript
import { CellEditor } from './CellEditor.js';

const cellEditor = new CellEditor({
    camera: camera,
    scene: scene,
    renderer: renderer,
    gridSize: gameEngine.getGridSize(),
    onCellToggle: (x, y, state) => {
        gameEngine.toggleCell(x, y);
        renderer.render(gameEngine.getGenerations(), displayRange);
    },
    onEditModeChange: (active) => {
        // Disable camera controls while editing? Or allow both?
        // Show/hide edit mode indicator
        updateEditModeUI(active);
    }
});

// When grid size changes
cellEditor.setGridSize(newGridSize);
```

## UX Considerations

### Camera Control Conflict

When in edit mode, user might want to:
1. Only edit cells (disable camera)
2. Edit cells AND navigate camera

**Recommendation**: Keep camera controls active but use different mouse buttons:
- Left click: Edit cells
- Right click / Middle click: Camera controls
- Or: Hold Shift while clicking to edit, normal click for camera

### Visual Clarity

1. Generation 0 should be visually distinct in edit mode
2. Consider dimming/hiding other generations while editing
3. Show a clear "Edit Mode" indicator
4. Cursor should change to crosshair over editable area

### Recomputation

After editing:
1. Clear all computed generations (they're now invalid)
2. User can click "Compute" to regenerate
3. Or: Auto-compute a small preview (e.g., 10 generations)

## Testing Checklist

- [ ] E key toggles edit mode
- [ ] Escape exits edit mode
- [ ] Click toggles cell state
- [ ] Drag paints multiple cells
- [ ] Hover indicator shows correct cell
- [ ] Grid overlay visible in edit mode only
- [ ] Clear All clears generation 0
- [ ] Editing clears computed generations
- [ ] Grid size change updates editor
- [ ] Camera controls still work (right click)
- [ ] Works with different grid sizes
- [ ] Visual indicator when in edit mode

## Effort Estimate

- **Code changes**: ~200 lines (new file + integrations)
- **Files modified**: 5 (new CellEditor.ts, GameEngine.ts, UIControls.ts, main.ts, styles.css)
- **Risk**: Medium (Three.js raycasting, interaction handling)

## Future Enhancements

- Brush sizes (1x1, 3x3, 5x5)
- Shape tools (line, rectangle, ellipse)
- Symmetry modes (mirror horizontal/vertical, rotational)
- Pattern stamp tool (place saved patterns)
- Undo/redo history
- Cell count display while editing
- Touch support for mobile/tablet
- Selection tool (select, copy, paste, move)
