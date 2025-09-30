export interface PatternInfo {
    name: string;
    description: string;
    author?: string;
    pattern: boolean[][];
}

export class PatternLoader {
    private builtInPatterns: Map<string, PatternInfo> = new Map();

    constructor() {
        this.initializeBuiltInPatterns();
    }

    private initializeBuiltInPatterns(): void {
        this.builtInPatterns.set('r-pentomino', {
            name: 'R-pentomino',
            description: 'A methuselah that evolves for 1103 generations',
            pattern: [
                [false, true, true],
                [true, true, false],
                [false, true, false]
            ]
        });
        
        this.builtInPatterns.set('glider', {
            name: 'Glider',
            description: 'A simple spaceship that travels diagonally',
            pattern: [
                [false, true, false],
                [false, false, true],
                [true, true, true]
            ]
        });

        this.builtInPatterns.set('blinker', {
            name: 'Blinker',
            description: 'A simple oscillator with period 2',
            pattern: [
                [true, true, true]
            ]
        });

        this.builtInPatterns.set('pulsar', {
            name: 'Pulsar',
            description: 'A period 3 oscillator',
            pattern: [
                [false, false, true, true, true, false, false, false, true, true, true, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false],
                [true, false, false, false, false, true, false, true, false, false, false, false, true],
                [true, false, false, false, false, true, false, true, false, false, false, false, true],
                [true, false, false, false, false, true, false, true, false, false, false, false, true],
                [false, false, true, true, true, false, false, false, true, true, true, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, true, true, true, false, false, false, true, true, true, false, false],
                [true, false, false, false, false, true, false, true, false, false, false, false, true],
                [true, false, false, false, false, true, false, true, false, false, false, false, true],
                [true, false, false, false, false, true, false, true, false, false, false, false, true],
                [false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, true, true, true, false, false, false, true, true, true, false, false]
            ]
        });

        this.builtInPatterns.set('glider-gun', {
            name: 'Gosper Glider Gun',
            description: 'The first known finite pattern with unbounded growth',
            author: 'Bill Gosper',
            pattern: [
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true],
                [false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true],
                [true, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [true, true, false, false, false, false, false, false, false, false, true, false, false, false, true, false, true, true, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        });
    }

    parseRLE(rleContent: string): boolean[][] {
        const lines = rleContent.split('\n').map(line => line.trim());

        let width = 0;
        let height = 0;
        let rule = '';
        let name = '';

        for (const line of lines) {
            if (line.startsWith('#N ')) {
                name = line.substring(3);
            } else if (line.startsWith('#C ') || line.startsWith('#c ')) {
            } else if (line.startsWith('x ')) {
                const match = line.match(/x\s*=\s*(\d+),\s*y\s*=\s*(\d+)(?:,\s*rule\s*=\s*([^,\s]+))?/i);
                if (match) {
                    width = parseInt(match[1]);
                    height = parseInt(match[2]);
                    rule = match[3] || 'B3/S23';
                }
                break;
            }
        }

        if (width === 0 || height === 0) {
            throw new Error('Invalid RLE format: missing dimensions');
        }

        const rleDataLines = lines.filter(line =>
            !line.startsWith('#') &&
            !line.startsWith('x ') &&
            line.length > 0
        );

        const rleData = rleDataLines.join('');

        const pattern: boolean[][] = Array(height).fill(null).map(() => Array(width).fill(false));

        let x = 0;
        let y = 0;
        let count = '';

        for (let i = 0; i < rleData.length; i++) {
            const char = rleData[i];

            if (char >= '0' && char <= '9') {
                count += char;
            } else {
                const repeatCount = count === '' ? 1 : parseInt(count);
                count = '';

                switch (char) {
                    case 'b':
                        x += repeatCount;
                        break;
                    case 'o':
                        for (let j = 0; j < repeatCount; j++) {
                            if (x < width && y < height) {
                                pattern[y][x] = true;
                            }
                            x++;
                        }
                        break;
                    case '$':
                        y += repeatCount;
                        x = 0;
                        break;
                    case '!':
                        return pattern;
                    default:
                        break;
                }

                if (x >= width) {
                    x = 0;
                    y++;
                }
            }
        }

        return pattern;
    }

    patternToRLE(pattern: boolean[][], name?: string): string {
        const height = pattern.length;
        const width = pattern[0]?.length || 0;

        let rle = '';
        if (name) {
            rle += `#N ${name}\n`;
        }
        rle += `x = ${width}, y = ${height}, rule = B3/S23\n`;

        for (let y = 0; y < height; y++) {
            let currentChar = '';
            let count = 0;

            for (let x = 0; x < width; x++) {
                const char = pattern[y][x] ? 'o' : 'b';

                if (char === currentChar) {
                    count++;
                } else {
                    if (currentChar !== '') {
                        if (count === 1) {
                            rle += currentChar;
                        } else {
                            rle += count + currentChar;
                        }
                    }
                    currentChar = char;
                    count = 1;
                }
            }

            if (currentChar !== '' && currentChar === 'o') {
                if (count === 1) {
                    rle += currentChar;
                } else {
                    rle += count + currentChar;
                }
            }

            if (y < height - 1) {
                rle += '$';
            }
        }

        rle += '!';
        return rle;
    }

    getBuiltInPattern(name: string): boolean[][] | null {
        const patternInfo = this.builtInPatterns.get(name);
        return patternInfo ? patternInfo.pattern : null;
    }

    getBuiltInPatternInfo(name: string): PatternInfo | null {
        return this.builtInPatterns.get(name) || null;
    }

    getAllBuiltInPatterns(): PatternInfo[] {
        return Array.from(this.builtInPatterns.values());
    }

    validatePattern(pattern: boolean[][]): boolean {
        if (!pattern || pattern.length === 0) {
            return false;
        }

        const width = pattern[0].length;
        for (const row of pattern) {
            if (row.length !== width) {
                return false;
            }
        }

        return true;
    }

    resizePattern(pattern: boolean[][], newWidth: number, newHeight: number): boolean[][] {
        const resized: boolean[][] = Array(newHeight).fill(null).map(() => Array(newWidth).fill(false));

        const startX = Math.floor((newWidth - pattern[0].length) / 2);
        const startY = Math.floor((newHeight - pattern.length) / 2);

        for (let y = 0; y < pattern.length; y++) {
            for (let x = 0; x < pattern[y].length; x++) {
                const newX = startX + x;
                const newY = startY + y;

                if (newX >= 0 && newX < newWidth && newY >= 0 && newY < newHeight) {
                    resized[newY][newX] = pattern[y][x];
                }
            }
        }

        return resized;
    }

    rotatePattern(pattern: boolean[][], clockwise: boolean = true): boolean[][] {
        const height = pattern.length;
        const width = pattern[0].length;

        const rotated: boolean[][] = Array(width).fill(null).map(() => Array(height).fill(false));

        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                if (clockwise) {
                    rotated[x][height - 1 - y] = pattern[y][x];
                } else {
                    rotated[width - 1 - x][y] = pattern[y][x];
                }
            }
        }

        return rotated;
    }

    flipPattern(pattern: boolean[][], horizontal: boolean = true): boolean[][] {
        const height = pattern.length;
        const width = pattern[0].length;

        const flipped: boolean[][] = Array(height).fill(null).map(() => Array(width).fill(false));

        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                if (horizontal) {
                    flipped[y][width - 1 - x] = pattern[y][x];
                } else {
                    flipped[height - 1 - y][x] = pattern[y][x];
                }
            }
        }

        return flipped;
    }
}