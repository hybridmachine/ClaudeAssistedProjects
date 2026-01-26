# Feature: Generation Scrubber

## Overview

Add a video-like timeline scrubber that allows users to smoothly navigate through computed generations. This provides intuitive, familiar controls similar to video players, making exploration more engaging.

## Motivation

- Current navigation uses step buttons and range inputs - functional but not intuitive
- Video scrubbing is universally understood UX
- Enables quick exploration of specific moments
- Visual timeline shows "shape" of the simulation
- Better for presentations and demonstrations
- Allows smooth playback with variable speed

## Proposed Design

### Visual Layout

```
+------------------------------------------------------------------+
|  [|<] [<] [>||] [>] [>|]     0:00 / 2:00     [1x v]              |
|  +============[====]====================================+  Gen 42 |
|  0          100         200         300         400     500      |
+------------------------------------------------------------------+
```

Components:
1. **Transport controls**: First, Previous, Play/Pause, Next, Last
2. **Timeline slider**: Draggable scrubber with current position
3. **Time display**: Current position / Total (in generation time)
4. **Speed control**: Playback speed dropdown
5. **Generation display**: Current generation number
6. **Optional**: Mini population graph in timeline background

### Interaction Modes

1. **Click on timeline**: Jump to that generation
2. **Drag scrubber**: Smoothly scrub through generations
3. **Keyboard shortcuts**:
   - Space: Play/Pause
   - Left/Right: Step back/forward
   - Home/End: First/Last generation
   - +/-: Speed up/slow down
4. **Mouse wheel on timeline**: Fine-grained scrubbing

## Implementation

### 1. New File: TimelineScrubber.ts

```typescript
export interface TimelineConfig {
    container: HTMLElement;
    onSeek: (generation: number) => void;
    onPlayStateChange: (playing: boolean) => void;
}

export class TimelineScrubber {
    private container: HTMLElement;
    private track: HTMLElement;
    private scrubber: HTMLElement;
    private playButton: HTMLElement;
    private timeDisplay: HTMLElement;
    private genDisplay: HTMLElement;
    private speedSelect: HTMLSelectElement;

    private totalGenerations: number = 0;
    private currentGeneration: number = 0;
    private isPlaying: boolean = false;
    private playbackSpeed: number = 1;
    private animationId: number | null = null;
    private lastFrameTime: number = 0;

    private onSeek: (generation: number) => void;
    private onPlayStateChange: (playing: boolean) => void;

    private readonly BASE_FRAME_DURATION = 200; // ms per generation at 1x

    constructor(config: TimelineConfig) {
        this.container = config.container;
        this.onSeek = config.onSeek;
        this.onPlayStateChange = config.onPlayStateChange;

        this.createDOM();
        this.attachEventListeners();
    }

    private createDOM(): void {
        this.container.innerHTML = `
            <div class="timeline-scrubber">
                <div class="transport-controls">
                    <button class="transport-btn" data-action="first" title="First (Home)">|&lt;</button>
                    <button class="transport-btn" data-action="prev" title="Previous (Left)">&lt;</button>
                    <button class="transport-btn play-btn" data-action="play" title="Play/Pause (Space)">&#9654;</button>
                    <button class="transport-btn" data-action="next" title="Next (Right)">&gt;</button>
                    <button class="transport-btn" data-action="last" title="Last (End)">&gt;|</button>
                </div>

                <div class="timeline-track-container">
                    <div class="timeline-track">
                        <div class="timeline-progress"></div>
                        <div class="timeline-scrubber-handle"></div>
                    </div>
                    <div class="timeline-labels">
                        <span class="timeline-label-start">0</span>
                        <span class="timeline-label-end">0</span>
                    </div>
                </div>

                <div class="timeline-info">
                    <span class="time-display">Gen 0 / 0</span>
                    <select class="speed-select">
                        <option value="0.25">0.25x</option>
                        <option value="0.5">0.5x</option>
                        <option value="1" selected>1x</option>
                        <option value="2">2x</option>
                        <option value="4">4x</option>
                        <option value="8">8x</option>
                    </select>
                </div>
            </div>
        `;

        this.track = this.container.querySelector('.timeline-track')!;
        this.scrubber = this.container.querySelector('.timeline-scrubber-handle')!;
        this.playButton = this.container.querySelector('.play-btn')!;
        this.timeDisplay = this.container.querySelector('.time-display')!;
        this.speedSelect = this.container.querySelector('.speed-select')!;
    }

    private attachEventListeners(): void {
        // Transport buttons
        this.container.querySelectorAll('.transport-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = (e.currentTarget as HTMLElement).dataset.action;
                this.handleTransportAction(action!);
            });
        });

        // Track click/drag
        this.track.addEventListener('mousedown', this.handleTrackMouseDown.bind(this));

        // Speed selector
        this.speedSelect.addEventListener('change', () => {
            this.playbackSpeed = parseFloat(this.speedSelect.value);
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', this.handleKeyDown.bind(this));

        // Mouse wheel on track
        this.track.addEventListener('wheel', (e) => {
            e.preventDefault();
            const delta = e.deltaY > 0 ? 1 : -1;
            this.seekTo(Math.max(0, Math.min(this.totalGenerations - 1, this.currentGeneration + delta)));
        });
    }

    private handleTransportAction(action: string): void {
        switch (action) {
            case 'first':
                this.seekTo(0);
                break;
            case 'prev':
                this.seekTo(Math.max(0, this.currentGeneration - 1));
                break;
            case 'play':
                this.togglePlayback();
                break;
            case 'next':
                this.seekTo(Math.min(this.totalGenerations - 1, this.currentGeneration + 1));
                break;
            case 'last':
                this.seekTo(this.totalGenerations - 1);
                break;
        }
    }

    private handleTrackMouseDown(e: MouseEvent): void {
        this.updatePositionFromMouse(e);

        const handleMouseMove = (e: MouseEvent) => {
            this.updatePositionFromMouse(e);
        };

        const handleMouseUp = () => {
            document.removeEventListener('mousemove', handleMouseMove);
            document.removeEventListener('mouseup', handleMouseUp);
        };

        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mouseup', handleMouseUp);
    }

    private updatePositionFromMouse(e: MouseEvent): void {
        const rect = this.track.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const percent = Math.max(0, Math.min(1, x / rect.width));
        const generation = Math.round(percent * (this.totalGenerations - 1));
        this.seekTo(generation);
    }

    private handleKeyDown(e: KeyboardEvent): void {
        // Ignore if focused on input
        if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
            return;
        }

        switch (e.code) {
            case 'Space':
                e.preventDefault();
                this.togglePlayback();
                break;
            case 'ArrowLeft':
                e.preventDefault();
                this.seekTo(Math.max(0, this.currentGeneration - (e.shiftKey ? 10 : 1)));
                break;
            case 'ArrowRight':
                e.preventDefault();
                this.seekTo(Math.min(this.totalGenerations - 1, this.currentGeneration + (e.shiftKey ? 10 : 1)));
                break;
            case 'Home':
                e.preventDefault();
                this.seekTo(0);
                break;
            case 'End':
                e.preventDefault();
                this.seekTo(this.totalGenerations - 1);
                break;
        }
    }

    public togglePlayback(): void {
        this.isPlaying = !this.isPlaying;
        this.playButton.innerHTML = this.isPlaying ? '&#10074;&#10074;' : '&#9654;';
        this.onPlayStateChange(this.isPlaying);

        if (this.isPlaying) {
            this.lastFrameTime = performance.now();
            this.animate();
        } else if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }
    }

    private animate(): void {
        if (!this.isPlaying) return;

        const now = performance.now();
        const frameDuration = this.BASE_FRAME_DURATION / this.playbackSpeed;

        if (now - this.lastFrameTime >= frameDuration) {
            this.lastFrameTime = now;

            if (this.currentGeneration < this.totalGenerations - 1) {
                this.seekTo(this.currentGeneration + 1);
            } else {
                // Reached end, stop playback
                this.togglePlayback();
                return;
            }
        }

        this.animationId = requestAnimationFrame(() => this.animate());
    }

    public seekTo(generation: number): void {
        this.currentGeneration = generation;
        this.updateDisplay();
        this.onSeek(generation);
    }

    public setTotalGenerations(total: number): void {
        this.totalGenerations = total;
        this.updateDisplay();

        const endLabel = this.container.querySelector('.timeline-label-end');
        if (endLabel) endLabel.textContent = (total - 1).toString();
    }

    public setCurrentGeneration(gen: number): void {
        this.currentGeneration = gen;
        this.updateDisplay();
    }

    private updateDisplay(): void {
        // Update scrubber position
        const percent = this.totalGenerations > 1
            ? (this.currentGeneration / (this.totalGenerations - 1)) * 100
            : 0;
        this.scrubber.style.left = `${percent}%`;

        // Update progress bar
        const progress = this.container.querySelector('.timeline-progress') as HTMLElement;
        if (progress) progress.style.width = `${percent}%`;

        // Update text display
        this.timeDisplay.textContent = `Gen ${this.currentGeneration} / ${this.totalGenerations - 1}`;
    }

    public destroy(): void {
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
        }
        document.removeEventListener('keydown', this.handleKeyDown.bind(this));
    }
}
```

### 2. styles.css

```css
.timeline-scrubber {
    display: flex;
    align-items: center;
    gap: 15px;
    padding: 10px 15px;
    background: rgba(0, 0, 0, 0.8);
    border-top: 1px solid rgba(255, 255, 255, 0.2);
}

.transport-controls {
    display: flex;
    gap: 5px;
}

.transport-btn {
    width: 32px;
    height: 32px;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 4px;
    color: white;
    cursor: pointer;
    font-size: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
}

.transport-btn:hover {
    background: rgba(255, 255, 255, 0.2);
}

.transport-btn.play-btn {
    width: 40px;
    background: rgba(0, 255, 136, 0.3);
    border-color: rgba(0, 255, 136, 0.5);
}

.timeline-track-container {
    flex: 1;
    padding: 0 10px;
}

.timeline-track {
    position: relative;
    height: 8px;
    background: rgba(255, 255, 255, 0.2);
    border-radius: 4px;
    cursor: pointer;
}

.timeline-progress {
    position: absolute;
    left: 0;
    top: 0;
    height: 100%;
    background: rgba(0, 255, 136, 0.5);
    border-radius: 4px;
    pointer-events: none;
}

.timeline-scrubber-handle {
    position: absolute;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 16px;
    height: 16px;
    background: #00ff88;
    border-radius: 50%;
    cursor: grab;
    box-shadow: 0 0 5px rgba(0, 255, 136, 0.5);
}

.timeline-scrubber-handle:active {
    cursor: grabbing;
    transform: translate(-50%, -50%) scale(1.2);
}

.timeline-labels {
    display: flex;
    justify-content: space-between;
    font-size: 10px;
    color: rgba(255, 255, 255, 0.5);
    margin-top: 4px;
}

.timeline-info {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 150px;
}

.time-display {
    font-family: monospace;
    font-size: 12px;
    color: rgba(255, 255, 255, 0.8);
    white-space: nowrap;
}

.speed-select {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 4px;
    color: white;
    padding: 4px 8px;
    font-size: 12px;
}
```

### 3. index.html

Add container at bottom of the viewport:

```html
<div id="timeline-container"></div>
```

### 4. main.ts

Initialize and connect:

```typescript
import { TimelineScrubber } from './TimelineScrubber.js';

const timelineScrubber = new TimelineScrubber({
    container: document.getElementById('timeline-container')!,
    onSeek: (generation) => {
        // Update display range to show this generation
        const windowSize = displayRangeMax - displayRangeMin;
        const newMin = Math.max(0, generation - Math.floor(windowSize / 2));
        const newMax = newMin + windowSize;
        setDisplayRange(newMin, newMax);
    },
    onPlayStateChange: (playing) => {
        // Sync with existing play/pause state if needed
    }
});

// When generations are computed
timelineScrubber.setTotalGenerations(gameEngine.getGenerationCount());

// When display range changes
timelineScrubber.setCurrentGeneration(currentGeneration);
```

## Integration Notes

1. **Replace or complement existing controls**: The scrubber can either replace the current step buttons or work alongside them

2. **Sync with display range**: When scrubbing, decide whether to:
   - Move a single-generation "window" (show one gen at a time)
   - Keep current window size and center on scrubbed generation
   - Let user choose viewing mode

3. **Performance**: Ensure seeking is fast enough for smooth scrubbing (current architecture should support this)

## Testing Checklist

- [ ] Transport buttons work (first, prev, play, next, last)
- [ ] Click on timeline jumps to correct generation
- [ ] Drag scrubber smoothly updates view
- [ ] Playback advances generations at correct speed
- [ ] Speed selector changes playback rate
- [ ] Keyboard shortcuts work (Space, arrows, Home, End)
- [ ] Shift+Arrow jumps by 10 generations
- [ ] Mouse wheel on timeline scrubs
- [ ] Playback stops at end
- [ ] Timeline updates when generations computed
- [ ] Works smoothly with 1000 generations

## Effort Estimate

- **Code changes**: ~250 lines (new file + styles + integration)
- **Files modified**: 4 (new TimelineScrubber.ts, main.ts, index.html, styles.css)
- **Risk**: Medium (touches playback logic, keyboard handling)

## Future Enhancements

- Loop playback option
- Reverse playback
- Generation markers (bookmarks)
- Mini population graph in timeline background
- Touch/swipe support for mobile
- Frame-by-frame mode with visual feedback
