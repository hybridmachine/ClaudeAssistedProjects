# Feature: Toroidal Wrapping Toggle

## Overview

Add a toggle to switch between finite (dead edges) and toroidal (wrapping) boundary conditions. In toroidal mode, cells on the left edge consider cells on the right edge as neighbors, and cells on the top edge consider cells on the bottom edge as neighbors.

## Motivation

- Many classic Game of Life patterns (especially spaceships) work better or only work correctly with toroidal wrapping
- Eliminates "edge effects" where patterns behave differently near boundaries
- Standard feature in most Game of Life implementations
- Enables infinite/repeating universe visualization

## Current Behavior

In `GameEngine.ts`, the `countLiveNeighbors()` method treats out-of-bounds coordinates as dead cells:

```typescript
private countLiveNeighbors(grid: boolean[][], x: number, y: number): number {
    let count = 0;
    for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
            if (dx === 0 && dy === 0) continue;
            const nx = x + dx;
            const ny = y + dy;
            if (nx >= 0 && nx < this.gridSize && ny >= 0 && ny < this.gridSize) {
                if (grid[nx][ny]) count++;
            }
            // Out of bounds = dead (implicit)
        }
    }
    return count;
}
```

## Proposed Changes

### 1. GameEngine.ts

Add a `toroidal` property and update neighbor counting:

```typescript
// New property
private toroidal: boolean = false;

// New setter
public setToroidal(enabled: boolean): void {
    this.toroidal = enabled;
}

public isToroidal(): boolean {
    return this.toroidal;
}

// Updated neighbor counting
private countLiveNeighbors(grid: boolean[][], x: number, y: number): number {
    let count = 0;
    for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
            if (dx === 0 && dy === 0) continue;

            let nx = x + dx;
            let ny = y + dy;

            if (this.toroidal) {
                // Wrap around
                nx = (nx + this.gridSize) % this.gridSize;
                ny = (ny + this.gridSize) % this.gridSize;
                if (grid[nx][ny]) count++;
            } else {
                // Finite boundaries
                if (nx >= 0 && nx < this.gridSize && ny >= 0 && ny < this.gridSize) {
                    if (grid[nx][ny]) count++;
                }
            }
        }
    }
    return count;
}
```

### 2. UIControls.ts

Add toggle in the settings panel:

```html
<div class="control-group">
    <label>
        <input type="checkbox" id="toroidal-toggle">
        Toroidal Wrapping (edges connect)
    </label>
</div>
```

Wire up the event:

```typescript
const toroidalToggle = document.getElementById('toroidal-toggle') as HTMLInputElement;
toroidalToggle.addEventListener('change', () => {
    this.gameEngine.setToroidal(toroidalToggle.checked);
    // Note: Only affects future generations, not already-computed ones
});
```

### 3. index.html

Add the toggle in the Simulation Settings section, near the grid size selector.

## UI Placement

Place in the "Simulation Settings" panel, grouped with Grid Size:

```
Simulation Settings
-------------------
Grid Size: [dropdown]
[x] Toroidal Wrapping (edges connect)
```

## Behavioral Notes

1. **Recomputation**: Changing toroidal mode should prompt the user or automatically recompute generations since existing generations were computed with the old boundary rules

2. **Visual indicator**: Consider showing a subtle visual hint in the 3D view when toroidal mode is active (e.g., faded ghost cells at edges showing the wrap-around)

3. **Session persistence**: Include toroidal state in saved sessions

4. **Default**: Start with toroidal OFF (current behavior) to maintain backward compatibility

## Testing Checklist

- [ ] Toggle appears in UI and persists state
- [ ] Glider wraps around edges correctly in toroidal mode
- [ ] Glider disappears at edge in finite mode
- [ ] Large grids (200x200) perform well with toroidal math
- [ ] Saved sessions include toroidal setting
- [ ] Loaded sessions restore toroidal setting

## Effort Estimate

- **Code changes**: ~30 lines
- **Files modified**: 3 (GameEngine.ts, UIControls.ts, index.html)
- **Risk**: Low (isolated change to neighbor counting)

## Future Enhancements

- Visual wraparound indicators
- Cylindrical mode (wrap one axis only)
- Klein bottle topology (wrap with flip)
