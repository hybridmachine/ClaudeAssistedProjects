export interface CellState {
    x: number;
    y: number;
}

export interface Generation {
    index: number;
    cells: boolean[][];
    liveCells: CellState[];
}

export interface GameState {
    gridSize: number;
    generations: Generation[];
    currentGeneration: number;
}

const MAX_GENERATIONS = 1000;

export class GameEngine {
    private gridSize: number;
    private generations: Generation[] = [];

    constructor(gridSize: number = 50) {
        this.gridSize = gridSize;
    }

    getMaxGenerations(): number {
        return MAX_GENERATIONS;
    }

    setGridSize(size: number): void {
        this.gridSize = size;
        this.generations = [];
    }

    getGridSize(): number {
        return this.gridSize;
    }

    initializeFromPattern(pattern: boolean[][]): void {
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

    initializeRandom(density: number = 0.3): void {
        this.generations = [];
        const grid = this.createEmptyGrid();

        for (let x = 0; x < this.gridSize; x++) {
            for (let y = 0; y < this.gridSize; y++) {
                grid[x][y] = Math.random() < density;
            }
        }

        this.addGeneration(grid);
    }

    computeGenerations(count: number): void {
        if (this.generations.length === 0) {
            throw new Error('No initial generation set. Call initializeFromPattern or initializeRandom first.');
        }

        const targetCount = Math.min(count, MAX_GENERATIONS);

        for (let i = this.generations.length; i < targetCount; i++) {
            const currentGrid = this.generations[i - 1].cells;
            const nextGrid = this.computeNextGeneration(currentGrid);
            this.addGeneration(nextGrid);
        }
    }

    /**
     * Computes a single next generation and adds it to the generations array.
     * @returns true if a new generation was computed, false if at max limit or no initial generation
     */
    computeSingleGeneration(): boolean {
        if (this.generations.length === 0) {
            return false;
        }

        if (this.generations.length >= MAX_GENERATIONS) {
            return false;
        }

        const currentGrid = this.generations[this.generations.length - 1].cells;
        const nextGrid = this.computeNextGeneration(currentGrid);
        this.addGeneration(nextGrid);
        return true;
    }

    private createEmptyGrid(): boolean[][] {
        return Array(this.gridSize).fill(null).map(() =>
            Array(this.gridSize).fill(false)
        );
    }

    private addGeneration(grid: boolean[][]): void {
        const liveCells: CellState[] = [];

        for (let x = 0; x < this.gridSize; x++) {
            for (let y = 0; y < this.gridSize; y++) {
                if (grid[x][y]) {
                    liveCells.push({ x, y });
                }
            }
        }

        this.generations.push({
            index: this.generations.length,
            cells: grid,
            liveCells
        });
    }

    private computeNextGeneration(currentGrid: boolean[][]): boolean[][] {
        const nextGrid = this.createEmptyGrid();

        for (let x = 0; x < this.gridSize; x++) {
            for (let y = 0; y < this.gridSize; y++) {
                const neighbors = this.countLiveNeighbors(currentGrid, x, y);
                const isAlive = currentGrid[x][y];

                if (isAlive) {
                    nextGrid[x][y] = neighbors === 2 || neighbors === 3;
                } else {
                    nextGrid[x][y] = neighbors === 3;
                }
            }
        }

        return nextGrid;
    }

    private countLiveNeighbors(grid: boolean[][], x: number, y: number): number {
        let count = 0;

        for (let dx = -1; dx <= 1; dx++) {
            for (let dy = -1; dy <= 1; dy++) {
                if (dx === 0 && dy === 0) continue;

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

    getGeneration(index: number): Generation | null {
        if (index >= 0 && index < this.generations.length) {
            return this.generations[index];
        }
        return null;
    }

    getGenerations(): Generation[] {
        return this.generations;
    }

    getGenerationCount(): number {
        return this.generations.length;
    }

    exportState(): GameState {
        return {
            gridSize: this.gridSize,
            generations: this.generations,
            currentGeneration: this.generations.length - 1
        };
    }

    importState(state: GameState): void {
        this.gridSize = state.gridSize;
        this.generations = state.generations;
    }

    clear(): void {
        this.generations = [];
    }
}