export class GameEngine {
    constructor(gridSize = 50) {
        this.generations = [];
        this.gridSize = gridSize;
    }
    setGridSize(size) {
        this.gridSize = size;
        this.generations = [];
    }
    getGridSize() {
        return this.gridSize;
    }
    initializeFromPattern(pattern) {
        this.generations = [];
        const grid = this.createEmptyGrid();
        const startX = Math.floor((this.gridSize - pattern.length) / 2);
        const startY = Math.floor((this.gridSize - pattern[0].length) / 2);
        for (let i = 0; i < pattern.length; i++) {
            for (let j = 0; j < pattern[i].length; j++) {
                if (startX + i >= 0 && startX + i < this.gridSize &&
                    startY + j >= 0 && startY + j < this.gridSize) {
                    grid[startX + i][startY + j] = pattern[i][j];
                }
            }
        }
        this.addGeneration(grid);
    }
    initializeRandom(density = 0.3) {
        this.generations = [];
        const grid = this.createEmptyGrid();
        for (let x = 0; x < this.gridSize; x++) {
            for (let y = 0; y < this.gridSize; y++) {
                grid[x][y] = Math.random() < density;
            }
        }
        this.addGeneration(grid);
    }
    computeGenerations(count) {
        if (this.generations.length === 0) {
            throw new Error('No initial generation set. Call initializeFromPattern or initializeRandom first.');
        }
        const targetCount = Math.min(count, 1000);
        for (let i = this.generations.length; i < targetCount; i++) {
            const currentGrid = this.generations[i - 1].cells;
            const nextGrid = this.computeNextGeneration(currentGrid);
            this.addGeneration(nextGrid);
        }
    }
    createEmptyGrid() {
        return Array(this.gridSize).fill(null).map(() => Array(this.gridSize).fill(false));
    }
    addGeneration(grid) {
        const liveCells = [];
        for (let x = 0; x < this.gridSize; x++) {
            for (let y = 0; y < this.gridSize; y++) {
                if (grid[x][y]) {
                    liveCells.push({ x, y, alive: true });
                }
            }
        }
        this.generations.push({
            index: this.generations.length,
            cells: grid.map(row => [...row]),
            liveCells
        });
    }
    computeNextGeneration(currentGrid) {
        const nextGrid = this.createEmptyGrid();
        for (let x = 0; x < this.gridSize; x++) {
            for (let y = 0; y < this.gridSize; y++) {
                const neighbors = this.countLiveNeighbors(currentGrid, x, y);
                const isAlive = currentGrid[x][y];
                if (isAlive) {
                    nextGrid[x][y] = neighbors === 2 || neighbors === 3;
                }
                else {
                    nextGrid[x][y] = neighbors === 3;
                }
            }
        }
        return nextGrid;
    }
    countLiveNeighbors(grid, x, y) {
        let count = 0;
        for (let dx = -1; dx <= 1; dx++) {
            for (let dy = -1; dy <= 1; dy++) {
                if (dx === 0 && dy === 0)
                    continue;
                const nx = x + dx;
                const ny = y + dy;
                if (nx >= 0 && nx < this.gridSize &&
                    ny >= 0 && ny < this.gridSize &&
                    grid[nx][ny]) {
                    count++;
                }
            }
        }
        return count;
    }
    getGeneration(index) {
        if (index >= 0 && index < this.generations.length) {
            return this.generations[index];
        }
        return null;
    }
    getGenerations() {
        return this.generations;
    }
    getGenerationCount() {
        return this.generations.length;
    }
    exportState() {
        return {
            gridSize: this.gridSize,
            generations: this.generations,
            currentGeneration: this.generations.length - 1
        };
    }
    importState(state) {
        this.gridSize = state.gridSize;
        this.generations = state.generations;
    }
    clear() {
        this.generations = [];
    }
}
//# sourceMappingURL=GameEngine.js.map