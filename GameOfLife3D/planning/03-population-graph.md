# Feature: Population Graph

## Overview

Display a real-time graph showing population (live cell count) over generations. This provides visual insight into simulation dynamics - growth, oscillation, stability, and extinction patterns.

## Motivation

- Immediately visualize simulation dynamics without counting cells
- Identify oscillators by seeing repeating population patterns
- See growth/decay trends at a glance
- Educational tool for understanding different patterns
- Detect when simulation reaches stable state or dies out
- Popular feature in cellular automaton software

## Proposed Design

### Graph Display

A small, semi-transparent overlay graph in the corner of the 3D view:

```
Population
    ^
200 |      /\    /\
150 |     /  \  /  \
100 |    /    \/    \____
 50 |   /
  0 +--+--+--+--+--+--+---> Generation
    0  20 40 60 80 100
```

### Features

1. **Line graph** showing population over all computed generations
2. **Current position marker** showing where the display range is
3. **Hover tooltips** showing exact values
4. **Toggleable visibility** via settings panel
5. **Resizable** (small/medium/large presets or draggable)

## Implementation Approaches

### Option A: Three.js Canvas Overlay (Recommended)

Draw directly on a 2D canvas overlaid on the Three.js renderer.

Pros:
- No additional dependencies
- Full control over styling
- Matches existing approach (status bar uses HTML overlay)

Cons:
- Manual drawing code needed

### Option B: Chart.js

Use Chart.js library for the graph.

Pros:
- Rich features out of the box
- Smooth animations
- Responsive

Cons:
- Additional dependency (~200KB)
- May be overkill for simple line graph

### Option C: HTML/CSS Only

Use HTML elements with CSS transforms for bars.

Pros:
- No canvas needed
- Simple implementation

Cons:
- Less flexible for line graphs
- Performance concerns with many data points

**Recommendation**: Option A (Canvas overlay) to avoid dependencies and maintain consistency.

## Proposed Changes

### 1. New File: PopulationGraph.ts

```typescript
export class PopulationGraph {
    private canvas: HTMLCanvasElement;
    private ctx: CanvasRenderingContext2D;
    private visible: boolean = true;
    private size: 'small' | 'medium' | 'large' = 'medium';

    private readonly SIZES = {
        small: { width: 150, height: 80 },
        medium: { width: 250, height: 120 },
        large: { width: 400, height: 200 }
    };

    constructor() {
        this.canvas = document.createElement('canvas');
        this.canvas.id = 'population-graph';
        this.canvas.style.cssText = `
            position: absolute;
            bottom: 60px;
            left: 10px;
            background: rgba(0, 0, 0, 0.7);
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 4px;
            pointer-events: auto;
        `;
        this.ctx = this.canvas.getContext('2d')!;
        this.setSize('medium');
        document.body.appendChild(this.canvas);
    }

    public setSize(size: 'small' | 'medium' | 'large'): void {
        this.size = size;
        const dims = this.SIZES[size];
        this.canvas.width = dims.width;
        this.canvas.height = dims.height;
    }

    public setVisible(visible: boolean): void {
        this.visible = visible;
        this.canvas.style.display = visible ? 'block' : 'none';
    }

    public render(generations: Generation[], currentRange: { min: number, max: number }): void {
        if (!this.visible || generations.length === 0) return;

        const { width, height } = this.canvas;
        const padding = { top: 20, right: 10, bottom: 25, left: 40 };
        const graphWidth = width - padding.left - padding.right;
        const graphHeight = height - padding.top - padding.bottom;

        // Clear
        this.ctx.clearRect(0, 0, width, height);

        // Extract population data
        const populations = generations.map(g => g.liveCells.length);
        const maxPop = Math.max(...populations, 1);
        const numGens = populations.length;

        // Draw axes
        this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
        this.ctx.lineWidth = 1;
        this.ctx.beginPath();
        this.ctx.moveTo(padding.left, padding.top);
        this.ctx.lineTo(padding.left, height - padding.bottom);
        this.ctx.lineTo(width - padding.right, height - padding.bottom);
        this.ctx.stroke();

        // Draw labels
        this.ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
        this.ctx.font = '10px monospace';
        this.ctx.textAlign = 'center';
        this.ctx.fillText('Population', width / 2, 12);
        this.ctx.fillText(`Gen 0-${numGens - 1}`, width / 2, height - 5);

        // Y-axis labels
        this.ctx.textAlign = 'right';
        this.ctx.fillText(maxPop.toString(), padding.left - 5, padding.top + 4);
        this.ctx.fillText('0', padding.left - 5, height - padding.bottom + 4);

        // Draw population line
        this.ctx.strokeStyle = '#00ff88';
        this.ctx.lineWidth = 1.5;
        this.ctx.beginPath();

        populations.forEach((pop, i) => {
            const x = padding.left + (i / Math.max(numGens - 1, 1)) * graphWidth;
            const y = height - padding.bottom - (pop / maxPop) * graphHeight;

            if (i === 0) {
                this.ctx.moveTo(x, y);
            } else {
                this.ctx.lineTo(x, y);
            }
        });
        this.ctx.stroke();

        // Draw current range indicator
        if (currentRange.min < numGens) {
            const rangeStartX = padding.left + (currentRange.min / Math.max(numGens - 1, 1)) * graphWidth;
            const rangeEndX = padding.left + (Math.min(currentRange.max, numGens - 1) / Math.max(numGens - 1, 1)) * graphWidth;

            this.ctx.fillStyle = 'rgba(0, 255, 136, 0.2)';
            this.ctx.fillRect(rangeStartX, padding.top, rangeEndX - rangeStartX, graphHeight);
        }
    }

    public destroy(): void {
        this.canvas.remove();
    }
}
```

### 2. main.ts

Initialize and update the graph:

```typescript
import { PopulationGraph } from './PopulationGraph.js';

// In initialization
const populationGraph = new PopulationGraph();

// In render loop or when generations change
populationGraph.render(
    gameEngine.getGenerations(),
    { min: displayRangeMin, max: displayRangeMax }
);
```

### 3. UIControls.ts

Add toggle and size controls:

```typescript
// Add to settings panel
const graphToggle = document.getElementById('graph-toggle') as HTMLInputElement;
graphToggle.addEventListener('change', () => {
    populationGraph.setVisible(graphToggle.checked);
});

const graphSize = document.getElementById('graph-size') as HTMLSelectElement;
graphSize.addEventListener('change', () => {
    populationGraph.setSize(graphSize.value as 'small' | 'medium' | 'large');
});
```

### 4. index.html

Add controls in Visual Settings:

```html
<div class="control-group">
    <label>
        <input type="checkbox" id="graph-toggle" checked>
        Population Graph
    </label>
    <select id="graph-size">
        <option value="small">Small</option>
        <option value="medium" selected>Medium</option>
        <option value="large">Large</option>
    </select>
</div>
```

### 5. styles.css

Style the graph canvas (if needed beyond inline styles).

## Additional Graph Features

### Phase 2 Enhancements

1. **Statistics display**: Show min/max/avg population
2. **Derivative graph**: Show rate of change (births - deaths)
3. **Multiple metrics**: Birth rate, death rate, density
4. **Zoom/pan**: Focus on specific generation ranges
5. **Export data**: CSV export of population data

## Testing Checklist

- [ ] Graph displays correctly in all three sizes
- [ ] Population line matches actual cell counts
- [ ] Current range indicator moves with display range
- [ ] Toggle shows/hides graph
- [ ] Graph updates when new generations computed
- [ ] Graph handles edge cases (0 cells, 1 generation, max generations)
- [ ] Performance acceptable with 1000 generations
- [ ] Graph doesn't interfere with 3D navigation

## Effort Estimate

- **Code changes**: ~150 lines (new file + integrations)
- **Files modified**: 4 (new PopulationGraph.ts, main.ts, UIControls.ts, index.html)
- **Risk**: Low (isolated visual component)

## Visual Mockup

```
+---------------------------+
| Population                |
|   ^                       |
| 50|    __/\              |
|   |   /    \_/\_____     |
|  0+-------------------->  |
|   Gen 0-100   [===]       |
+---------------------------+
```

The `[===]` represents the current view range highlighted on the graph.
