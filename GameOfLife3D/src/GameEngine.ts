export interface CellState {
    x: number;
    y: number;
}

export interface Generation {
    index: number;
    cells: boolean[][];
    liveCells: CellState[];
}

export interface Rule {
    name: string;
    birth: number[];
    survival: number[];
}

export const RULE_PRESETS: Record<string, Rule> = {
    'conway': { name: "Conway's Life", birth: [3], survival: [2, 3] },
    'highlife': { name: 'HighLife', birth: [3, 6], survival: [2, 3] },
    'daynight': { name: 'Day & Night', birth: [3, 6, 7, 8], survival: [3, 4, 6, 7, 8] },
    'seeds': { name: 'Seeds', birth: [2], survival: [] },
    'lifewithoutdeath': { name: 'Life without Death', birth: [3], survival: [0, 1, 2, 3, 4, 5, 6, 7, 8] },
    'diamoeba': { name: 'Diamoeba', birth: [3, 5, 6, 7, 8], survival: [5, 6, 7, 8] },
    '2x2': { name: '2x2', birth: [3, 6], survival: [1, 2, 5] },
    'morley': { name: 'Morley', birth: [3, 6, 8], survival: [2, 4, 5] },
    'anneal': { name: 'Anneal', birth: [4, 6, 7, 8], survival: [3, 5, 6, 7, 8] },
};

export interface GameState {
    gridSize: number;
    generations: Generation[];
    currentGeneration: number;
    toroidal?: boolean;
    ruleName?: string;
    birthRule?: number[];
    survivalRule?: number[];
}

const MAX_GENERATIONS = 1000;

export class GameEngine {
    private gridSize: number;
    private generations: Generation[] = [];
    private toroidal: boolean = false;
    private birthRule: Set<number> = new Set([3]);
    private survivalRule: Set<number> = new Set([2, 3]);
    private currentRuleName: string = 'conway';

    constructor(gridSize: number = 50) {
        this.gridSize = gridSize;
    }

    setToroidal(enabled: boolean): void {
        this.toroidal = enabled;
    }

    isToroidal(): boolean {
        return this.toroidal;
    }

    setRule(ruleKey: string): void {
        const rule = RULE_PRESETS[ruleKey];
        if (rule) {
            this.birthRule = new Set(rule.birth);
            this.survivalRule = new Set(rule.survival);
            this.currentRuleName = ruleKey;
        }
    }

    setCustomRule(birth: number[], survival: number[]): void {
        this.birthRule = new Set(birth);
        this.survivalRule = new Set(survival);
        this.currentRuleName = 'custom';
    }

    getCurrentRule(): string {
        return this.currentRuleName;
    }

    getRuleString(): string {
        const b = Array.from(this.birthRule).sort((a, c) => a - c).join('');
        const s = Array.from(this.survivalRule).sort((a, c) => a - c).join('');
        return `B${b}/S${s}`;
    }

    getBirthRule(): number[] {
        return Array.from(this.birthRule);
    }

    getSurvivalRule(): number[] {
        return Array.from(this.survivalRule);
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
                    nextGrid[x][y] = this.survivalRule.has(neighbors);
                } else {
                    nextGrid[x][y] = this.birthRule.has(neighbors);
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

                let nx = x + dx;
                let ny = y + dy;

                if (this.toroidal) {
                    // Wrap around edges
                    nx = (nx + this.gridSize) % this.gridSize;
                    ny = (ny + this.gridSize) % this.gridSize;
                    if (grid[nx][ny]) {
                        count++;
                    }
                } else {
                    // Finite boundaries - out of bounds cells are dead
                    if (nx >= 0 && nx < this.gridSize &&
                        ny >= 0 && ny < this.gridSize &&
                        grid[nx][ny]) {
                        count++;
                    }
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
            currentGeneration: this.generations.length - 1,
            toroidal: this.toroidal,
            ruleName: this.currentRuleName,
            birthRule: Array.from(this.birthRule),
            survivalRule: Array.from(this.survivalRule)
        };
    }

    importState(state: GameState): void {
        this.gridSize = state.gridSize;
        this.generations = state.generations;
        this.toroidal = state.toroidal ?? false;

        // Restore rule configuration
        if (state.ruleName && state.ruleName !== 'custom' && RULE_PRESETS[state.ruleName]) {
            this.setRule(state.ruleName);
        } else if (state.birthRule && state.survivalRule) {
            this.setCustomRule(state.birthRule, state.survivalRule);
        }
    }

    clear(): void {
        this.generations = [];
    }
}