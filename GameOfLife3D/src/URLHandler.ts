export interface URLConfig {
    pattern?: string;
    rle?: string;
    grid?: number;
    rule?: string;
    gens?: number;
    toroidal?: boolean;
    padding?: number;
    colors?: boolean;
    range?: { min: number; max: number };
}

export class URLHandler {
    private static readonly BUILT_IN_PATTERNS = [
        'r-pentomino', 'glider', 'blinker', 'pulsar', 'glider-gun'
    ];

    /**
     * Parse URL parameters into configuration object
     */
    public static parseURL(): URLConfig {
        const params = new URLSearchParams(window.location.search);
        const config: URLConfig = {};

        // Pattern (built-in name)
        if (params.has('pattern')) {
            const pattern = params.get('pattern')!;
            if (this.BUILT_IN_PATTERNS.includes(pattern)) {
                config.pattern = pattern;
            }
        }

        // RLE data (URL-encoded)
        if (params.has('rle')) {
            try {
                config.rle = decodeURIComponent(params.get('rle')!);
            } catch {
                console.warn('Invalid RLE encoding in URL');
            }
        }

        // Grid size
        if (params.has('grid')) {
            const grid = parseInt(params.get('grid')!, 10);
            if (!isNaN(grid) && grid >= 25 && grid <= 200) {
                config.grid = grid;
            }
        }

        // Rule
        if (params.has('rule')) {
            config.rule = params.get('rule')!;
        }

        // Generations
        if (params.has('gens')) {
            const gens = parseInt(params.get('gens')!, 10);
            if (!isNaN(gens) && gens >= 1 && gens <= 1000) {
                config.gens = gens;
            }
        }

        // Toroidal
        if (params.has('toroidal')) {
            config.toroidal = params.get('toroidal') === 'true';
        }

        // Padding
        if (params.has('padding')) {
            const padding = parseInt(params.get('padding')!, 10);
            if (!isNaN(padding) && padding >= 0 && padding <= 100) {
                config.padding = padding;
            }
        }

        // Color cycling
        if (params.has('colors')) {
            config.colors = params.get('colors') === 'true';
        }

        // Display range
        if (params.has('range')) {
            const rangeStr = params.get('range')!;
            const parts = rangeStr.split('-').map(Number);
            if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                config.range = { min: parts[0], max: parts[1] };
            }
        }

        return config;
    }

    /**
     * Check if the URL has any configuration parameters
     */
    public static hasURLConfig(): boolean {
        const params = new URLSearchParams(window.location.search);
        return params.has('pattern') || params.has('rle') || params.has('grid') ||
               params.has('rule') || params.has('gens') || params.has('toroidal') ||
               params.has('padding') || params.has('colors') || params.has('range');
    }

    /**
     * Generate shareable URL from current configuration
     */
    public static generateURL(config: URLConfig): string {
        const params = new URLSearchParams();
        const baseURL = window.location.origin + window.location.pathname;

        if (config.pattern) {
            params.set('pattern', config.pattern);
        } else if (config.rle) {
            params.set('rle', encodeURIComponent(config.rle));
        }

        if (config.grid !== undefined) {
            params.set('grid', config.grid.toString());
        }
        if (config.rule) {
            params.set('rule', config.rule);
        }
        if (config.gens !== undefined && config.gens > 0) {
            params.set('gens', config.gens.toString());
        }
        if (config.toroidal !== undefined) {
            params.set('toroidal', config.toroidal.toString());
        }
        if (config.padding !== undefined) {
            params.set('padding', config.padding.toString());
        }
        if (config.colors !== undefined) {
            params.set('colors', config.colors.toString());
        }
        if (config.range) {
            params.set('range', `${config.range.min}-${config.range.max}`);
        }

        const queryString = params.toString();
        return queryString ? `${baseURL}?${queryString}` : baseURL;
    }

    /**
     * Copy URL to clipboard and return success status
     */
    public static async copyToClipboard(url: string): Promise<boolean> {
        try {
            await navigator.clipboard.writeText(url);
            return true;
        } catch {
            // Fallback for older browsers or restricted contexts
            const textarea = document.createElement('textarea');
            textarea.value = url;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            const success = document.execCommand('copy');
            document.body.removeChild(textarea);
            return success;
        }
    }

    /**
     * Check if the URL is within reasonable length limits
     */
    public static isURLTooLong(url: string): boolean {
        return url.length > 2000;
    }
}
