import { Generation } from './GameEngine.js';

export type GraphSize = 'small' | 'medium' | 'large';

export class PopulationGraph {
    private canvas: HTMLCanvasElement;
    private ctx: CanvasRenderingContext2D;
    private visible: boolean = true;
    private size: GraphSize = 'medium';

    private readonly SIZES = {
        small: { width: 150, height: 80 },
        medium: { width: 250, height: 120 },
        large: { width: 400, height: 200 }
    };

    private hoveredGeneration: number | null = null;
    private hoveredPopulation: number | null = null;

    // Bound handlers for proper cleanup
    private boundHandleMouseMove = (e: MouseEvent) => this.handleMouseMove(e);
    private boundHandleMouseLeave = () => this.handleMouseLeave();

    // Dirty-state tracking to skip redundant redraws
    private lastGenCount = -1;
    private lastRangeMin = -1;
    private lastRangeMax = -1;
    private isDirty = true;

    constructor() {
        this.canvas = document.createElement('canvas');
        this.canvas.id = 'population-graph';
        this.canvas.style.cssText = `
            position: absolute;
            bottom: 60px;
            right: 10px;
            background: rgba(0, 0, 0, 0.7);
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 4px;
            pointer-events: auto;
            cursor: crosshair;
        `;
        this.ctx = this.canvas.getContext('2d')!;
        this.setSize('medium');

        this.setupEventListeners();

        document.body.appendChild(this.canvas);
    }

    private setupEventListeners(): void {
        this.canvas.addEventListener('mousemove', this.boundHandleMouseMove);
        this.canvas.addEventListener('mouseleave', this.boundHandleMouseLeave);
    }

    private handleMouseMove(e: MouseEvent): void {
        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        // Store coordinates for tooltip rendering
        const padding = { top: 20, right: 10, bottom: 25, left: 40 };

        // Check if mouse is in the graph area
        if (x >= padding.left && x <= this.canvas.width - padding.right &&
            y >= padding.top && y <= this.canvas.height - padding.bottom) {
            this.canvas.dataset.mouseX = x.toString();
            this.canvas.dataset.mouseY = y.toString();
        } else {
            delete this.canvas.dataset.mouseX;
            delete this.canvas.dataset.mouseY;
        }
        this.isDirty = true;
    }

    private handleMouseLeave(): void {
        delete this.canvas.dataset.mouseX;
        delete this.canvas.dataset.mouseY;
        this.hoveredGeneration = null;
        this.hoveredPopulation = null;
        this.isDirty = true;
    }

    public setSize(size: GraphSize): void {
        this.size = size;
        const dims = this.SIZES[size];
        this.canvas.width = dims.width;
        this.canvas.height = dims.height;
        this.isDirty = true;
    }

    public getSize(): GraphSize {
        return this.size;
    }

    public setVisible(visible: boolean): void {
        this.visible = visible;
        this.canvas.style.display = visible ? 'block' : 'none';
        if (visible) this.isDirty = true;
    }

    public isVisible(): boolean {
        return this.visible;
    }

    public render(generations: Generation[], currentRange: { min: number, max: number }): void {
        if (!this.visible || generations.length === 0) return;

        // Check if anything changed since the last render
        const genCount = generations.length;
        if (!this.isDirty &&
            genCount === this.lastGenCount &&
            currentRange.min === this.lastRangeMin &&
            currentRange.max === this.lastRangeMax) {
            return;
        }
        this.lastGenCount = genCount;
        this.lastRangeMin = currentRange.min;
        this.lastRangeMax = currentRange.max;
        this.isDirty = false;

        const { width, height } = this.canvas;
        const padding = { top: 20, right: 10, bottom: 25, left: 40 };
        const graphWidth = width - padding.left - padding.right;
        const graphHeight = height - padding.top - padding.bottom;

        // Clear canvas
        this.ctx.clearRect(0, 0, width, height);

        // Draw semi-transparent background
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        this.ctx.fillRect(0, 0, width, height);

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

        // Draw horizontal grid lines
        const gridLines = 4;
        this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
        for (let i = 1; i <= gridLines; i++) {
            const y = height - padding.bottom - (i / gridLines) * graphHeight;
            this.ctx.beginPath();
            this.ctx.moveTo(padding.left, y);
            this.ctx.lineTo(width - padding.right, y);
            this.ctx.stroke();
        }

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

        // Draw current range indicator (before the line so it appears behind)
        if (currentRange.min < numGens) {
            const rangeStartX = padding.left + (currentRange.min / Math.max(numGens - 1, 1)) * graphWidth;
            const rangeEndX = padding.left + (Math.min(currentRange.max, numGens - 1) / Math.max(numGens - 1, 1)) * graphWidth;

            this.ctx.fillStyle = 'rgba(0, 255, 136, 0.2)';
            this.ctx.fillRect(rangeStartX, padding.top, rangeEndX - rangeStartX, graphHeight);
        }

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

        // Draw points at each generation for better visibility when there are few generations
        if (numGens <= 50) {
            this.ctx.fillStyle = '#00ff88';
            populations.forEach((pop, i) => {
                const x = padding.left + (i / Math.max(numGens - 1, 1)) * graphWidth;
                const y = height - padding.bottom - (pop / maxPop) * graphHeight;
                this.ctx.beginPath();
                this.ctx.arc(x, y, 2, 0, Math.PI * 2);
                this.ctx.fill();
            });
        }

        // Handle hover tooltip
        const mouseX = this.canvas.dataset.mouseX ? parseFloat(this.canvas.dataset.mouseX) : null;
        const mouseY = this.canvas.dataset.mouseY ? parseFloat(this.canvas.dataset.mouseY) : null;

        if (mouseX !== null && mouseY !== null && numGens > 0) {
            // Calculate which generation is being hovered
            const relativeX = mouseX - padding.left;
            const genIndex = Math.round((relativeX / graphWidth) * Math.max(numGens - 1, 1));

            if (genIndex >= 0 && genIndex < numGens) {
                const pop = populations[genIndex];
                const pointX = padding.left + (genIndex / Math.max(numGens - 1, 1)) * graphWidth;
                const pointY = height - padding.bottom - (pop / maxPop) * graphHeight;

                // Draw vertical line at hover position
                this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
                this.ctx.lineWidth = 1;
                this.ctx.setLineDash([3, 3]);
                this.ctx.beginPath();
                this.ctx.moveTo(pointX, padding.top);
                this.ctx.lineTo(pointX, height - padding.bottom);
                this.ctx.stroke();
                this.ctx.setLineDash([]);

                // Draw highlight point
                this.ctx.fillStyle = '#ffffff';
                this.ctx.beginPath();
                this.ctx.arc(pointX, pointY, 4, 0, Math.PI * 2);
                this.ctx.fill();

                // Draw tooltip
                const tooltipText = `Gen ${genIndex}: ${pop} cells`;
                this.ctx.font = '10px monospace';
                const textWidth = this.ctx.measureText(tooltipText).width;
                const tooltipPadding = 4;

                // Position tooltip to avoid edges
                let tooltipX = pointX + 10;
                if (tooltipX + textWidth + tooltipPadding * 2 > width - padding.right) {
                    tooltipX = pointX - textWidth - tooltipPadding * 2 - 10;
                }

                let tooltipY = pointY - 20;
                if (tooltipY - 14 < padding.top) {
                    tooltipY = pointY + 20;
                }

                // Draw tooltip background
                this.ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
                this.ctx.fillRect(tooltipX - tooltipPadding, tooltipY - 12, textWidth + tooltipPadding * 2, 16);

                // Draw tooltip border
                this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
                this.ctx.lineWidth = 1;
                this.ctx.strokeRect(tooltipX - tooltipPadding, tooltipY - 12, textWidth + tooltipPadding * 2, 16);

                // Draw tooltip text
                this.ctx.fillStyle = '#ffffff';
                this.ctx.textAlign = 'left';
                this.ctx.fillText(tooltipText, tooltipX, tooltipY);
            }
        }
    }

    public destroy(): void {
        this.canvas.removeEventListener('mousemove', this.boundHandleMouseMove);
        this.canvas.removeEventListener('mouseleave', this.boundHandleMouseLeave);
        this.canvas.remove();
    }
}
