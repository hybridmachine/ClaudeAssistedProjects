# Feature: URL Sharing

## Overview

Enable users to share specific simulation configurations via URL parameters. When someone opens a shared URL, the simulation automatically loads with the specified pattern, grid size, rules, and visual settings.

## Motivation

- Easy sharing on social media, forums, and chat
- No account or backend needed
- Bookmarkable configurations
- Educational links for specific patterns
- Instant collaboration without file transfers

## URL Structure

```
https://example.com/gameoflife3d/?pattern=glider&grid=100&rule=conway&gens=50
```

### Supported Parameters

| Parameter | Type | Values | Example |
|-----------|------|--------|---------|
| `pattern` | string | Built-in name or RLE | `pattern=glider` |
| `rle` | string | URL-encoded RLE data | `rle=bo%24obo%24o2bo%21` |
| `grid` | number | 25-200 | `grid=100` |
| `rule` | string | Preset name or B/S notation | `rule=highlife` or `rule=B36S23` |
| `gens` | number | 1-1000 | `gens=200` |
| `toroidal` | boolean | true/false | `toroidal=true` |
| `padding` | number | 0-100 | `padding=20` |
| `colors` | boolean | true/false (color cycling) | `colors=true` |
| `range` | string | min-max | `range=0-50` |

### Example URLs

```
# Simple glider
?pattern=glider

# Glider gun with HighLife rules
?pattern=gosper-gun&rule=highlife&grid=150&gens=300

# Custom RLE pattern
?rle=bo$2bo$3o!&grid=50

# Full configuration
?pattern=r-pentomino&grid=100&rule=conway&gens=500&toroidal=true&padding=15&colors=true&range=0-100
```

## Implementation

### 1. New File: URLHandler.ts

```typescript
interface URLConfig {
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

    /**
     * Parse URL parameters into configuration object
     */
    public static parseURL(): URLConfig {
        const params = new URLSearchParams(window.location.search);
        const config: URLConfig = {};

        // Pattern (built-in name)
        if (params.has('pattern')) {
            config.pattern = params.get('pattern')!;
        }

        // RLE data (URL-encoded)
        if (params.has('rle')) {
            config.rle = decodeURIComponent(params.get('rle')!);
        }

        // Grid size
        if (params.has('grid')) {
            const grid = parseInt(params.get('grid')!, 10);
            if (grid >= 25 && grid <= 200) {
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
            if (gens >= 1 && gens <= 1000) {
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
            if (padding >= 0 && padding <= 100) {
                config.padding = padding;
            }
        }

        // Color cycling
        if (params.has('colors')) {
            config.colors = params.get('colors') === 'true';
        }

        // Display range
        if (params.has('range')) {
            const [min, max] = params.get('range')!.split('-').map(Number);
            if (!isNaN(min) && !isNaN(max)) {
                config.range = { min, max };
            }
        }

        return config;
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

        if (config.grid) params.set('grid', config.grid.toString());
        if (config.rule) params.set('rule', config.rule);
        if (config.gens) params.set('gens', config.gens.toString());
        if (config.toroidal !== undefined) params.set('toroidal', config.toroidal.toString());
        if (config.padding !== undefined) params.set('padding', config.padding.toString());
        if (config.colors !== undefined) params.set('colors', config.colors.toString());
        if (config.range) params.set('range', `${config.range.min}-${config.range.max}`);

        const queryString = params.toString();
        return queryString ? `${baseURL}?${queryString}` : baseURL;
    }

    /**
     * Copy URL to clipboard and show feedback
     */
    public static async copyToClipboard(url: string): Promise<boolean> {
        try {
            await navigator.clipboard.writeText(url);
            return true;
        } catch {
            // Fallback for older browsers
            const textarea = document.createElement('textarea');
            textarea.value = url;
            document.body.appendChild(textarea);
            textarea.select();
            const success = document.execCommand('copy');
            document.body.removeChild(textarea);
            return success;
        }
    }
}
```

### 2. main.ts

Apply URL config on load:

```typescript
import { URLHandler } from './URLHandler.js';

// On initialization, after default setup
const urlConfig = URLHandler.parseURL();

if (Object.keys(urlConfig).length > 0) {
    applyURLConfig(urlConfig);
}

function applyURLConfig(config: URLConfig): void {
    // Apply grid size first (affects pattern placement)
    if (config.grid) {
        gameEngine.setGridSize(config.grid);
        // Update UI dropdown
    }

    // Apply rule
    if (config.rule) {
        if (config.rule.match(/^B\d*S\d*$/i)) {
            // Custom B/S notation
            const match = config.rule.match(/B(\d*)S(\d*)/i);
            if (match) {
                const birth = match[1].split('').map(Number);
                const survival = match[2].split('').map(Number);
                gameEngine.setCustomRule(birth, survival);
            }
        } else {
            // Preset name
            gameEngine.setRule(config.rule);
        }
    }

    // Apply toroidal
    if (config.toroidal !== undefined) {
        gameEngine.setToroidal(config.toroidal);
    }

    // Load pattern
    if (config.pattern) {
        const pattern = patternLoader.getBuiltInPattern(config.pattern);
        if (pattern) {
            gameEngine.initializeFromPattern(pattern);
        }
    } else if (config.rle) {
        const pattern = patternLoader.parseRLE(config.rle);
        gameEngine.initializeFromPattern(pattern);
    }

    // Compute generations
    if (config.gens) {
        gameEngine.computeGenerations(config.gens);
    }

    // Apply visual settings
    if (config.padding !== undefined) {
        renderer.setCellPadding(config.padding / 100);
    }
    if (config.colors !== undefined) {
        renderer.setColorCycling(config.colors);
    }

    // Set display range
    if (config.range) {
        uiControls.setDisplayRange(config.range.min, config.range.max);
    }
}
```

### 3. UIControls.ts

Add "Share" button:

```typescript
private createShareButton(): void {
    const shareBtn = document.getElementById('share-button');

    shareBtn.addEventListener('click', async () => {
        const config = this.getCurrentConfig();
        const url = URLHandler.generateURL(config);

        const success = await URLHandler.copyToClipboard(url);

        if (success) {
            this.showToast('Link copied to clipboard!');
        } else {
            // Show URL in a modal for manual copy
            this.showShareModal(url);
        }
    });
}

private getCurrentConfig(): URLConfig {
    return {
        pattern: this.gameEngine.getCurrentPatternName(),
        // or rle: this.gameEngine.exportCurrentPatternAsRLE(),
        grid: this.gameEngine.getGridSize(),
        rule: this.gameEngine.getCurrentRule(),
        gens: this.gameEngine.getGenerationCount(),
        toroidal: this.gameEngine.isToroidal(),
        padding: Math.round(this.renderer.getCellPadding() * 100),
        colors: this.renderer.isColorCycling(),
        range: this.getDisplayRange()
    };
}

private showToast(message: string): void {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('fade-out');
        setTimeout(() => toast.remove(), 300);
    }, 2000);
}
```

### 4. index.html

Add share button:

```html
<div class="button-group">
    <button id="share-button" title="Copy shareable link">
        Share Link
    </button>
</div>
```

### 5. styles.css

Toast notification styling:

```css
.toast {
    position: fixed;
    bottom: 80px;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(0, 255, 136, 0.9);
    color: black;
    padding: 10px 20px;
    border-radius: 4px;
    font-weight: bold;
    z-index: 1000;
    animation: slideUp 0.3s ease;
}

.toast.fade-out {
    opacity: 0;
    transition: opacity 0.3s ease;
}

@keyframes slideUp {
    from {
        transform: translateX(-50%) translateY(20px);
        opacity: 0;
    }
    to {
        transform: translateX(-50%) translateY(0);
        opacity: 1;
    }
}
```

## URL Length Considerations

- Most browsers support URLs up to 2048 characters
- RLE patterns can get long; consider compression for large patterns
- For very large patterns, show warning or suggest using session save/load instead

### Optional: URL Compression

For long RLE patterns, use base64 encoding with simple compression:

```typescript
// Compress RLE for URL
function compressRLE(rle: string): string {
    return btoa(rle); // Base64 encode
}

function decompressRLE(compressed: string): string {
    return atob(compressed); // Base64 decode
}
```

## Testing Checklist

- [ ] Built-in patterns load from URL (?pattern=glider)
- [ ] Custom RLE loads from URL (?rle=...)
- [ ] Grid size applies correctly
- [ ] Rule presets apply correctly
- [ ] Custom B/S rules parse correctly
- [ ] Generation count respected
- [ ] Visual settings apply
- [ ] Share button generates correct URL
- [ ] URL copied to clipboard
- [ ] Toast notification appears
- [ ] Long URLs handled gracefully
- [ ] Invalid parameters ignored gracefully

## Effort Estimate

- **Code changes**: ~120 lines (new file + integrations)
- **Files modified**: 4 (new URLHandler.ts, main.ts, UIControls.ts, styles.css)
- **Risk**: Low (isolated feature, graceful degradation)

## Future Enhancements

- Short URL service integration
- QR code generation for sharing
- Social media preview cards (Open Graph meta tags)
- Import from URL button (paste a link)
