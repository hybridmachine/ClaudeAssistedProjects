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
|  [|<] [<] [>||] [>] [>|]     Gen 42 / 500     [1x v]             |
|  +============[====]====================================+        |
|  0          100         200         300         400     500      |
+------------------------------------------------------------------+
```

Components:
1. **Transport controls**: First, Previous, Play/Pause, Next, Last
2. **Timeline slider**: Draggable scrubber with current position
3. **Generation display**: Current generation / Total
4. **Speed control**: Playback speed dropdown
5. **Optional**: Mini population graph in timeline background

### Interaction Modes

1. **Click on timeline**: Jump to that generation
2. **Drag scrubber**: Smoothly scrub through generations (mouse + touch)
3. **Keyboard shortcuts**:
   - Space: Play/Pause
   - Left/Right: Step back/forward (Shift = 10)
   - Home/End: First/Last generation
4. **Mouse wheel on timeline**: Fine-grained scrubbing

## Implementation

### 1. New File: TimelineScrubber.ts

Public API:
- `setTotalGenerations(total: number)`
- `setCurrentGeneration(gen: number)`
- `setPlaying(playing: boolean)`

Events:
- `onSeek(generation: number)`
- `onPlayToggle(playing: boolean)`
- `onSpeedChange(multiplier: number)`

Notes:
- Use pointer events (`pointerdown/move/up`) for track dragging.
- Bind handlers once and remove them reliably in `destroy()`.
- Keyboard shortcuts should ignore focused inputs.
- The scrubber does not own the simulation clock; it delegates play/pause to the engine/UI layer.

### 2. styles.css

Add scrubber styles near the status bar section:
- `.timeline-scrubber` bar pinned at bottom (above status bar)
- `:focus-visible` states for buttons/handle
- `touch-action: none` on the track for smooth drag on mobile

### 3. index.html

Add container at the bottom of the viewport:

```html
<div id="timeline-container"></div>
```

### 4. UIControls.ts

Integrate scrubber as the controller:

- Initialize `TimelineScrubber` with callbacks:
  - `onSeek(gen)`: update display range to center on gen
  - `onPlayToggle(playing)`: call existing `startAnimation` / `stopAnimation`
  - `onSpeedChange(multiplier)`: map to `animationSpeed`
- When animation advances or display range changes, update scrubber with:
  - `setTotalGenerations(gameEngine.getGenerationCount())`
  - `setCurrentGeneration(currentDisplayGeneration)`
- Prefer current display window centered on scrubbed generation (default mode)

## Integration Notes

1. **Replace or complement existing controls**: keep existing controls until parity is confirmed
2. **Scrub behavior**: default to centering the display window on the scrubbed generation
3. **Performance**: ensure seeking is O(1) per event; throttle if needed

## Testing Checklist

- [ ] Transport buttons work (first, prev, play, next, last)
- [ ] Click on timeline jumps to correct generation
- [ ] Drag scrubber smoothly updates view (mouse + touch)
- [ ] Playback advances generations at correct speed
- [ ] Speed selector changes playback rate
- [ ] Keyboard shortcuts work (Space, arrows, Home, End)
- [ ] Shift+Arrow jumps by 10 generations
- [ ] Mouse wheel on timeline scrubs
- [ ] Playback stops at end
- [ ] Timeline updates when generations computed
- [ ] Scrubber stays in sync when engine plays independently
- [ ] Works smoothly with 1000 generations

## Effort Estimate

- **Code changes**: ~300 lines (new file + styles + integration)
- **Files modified**: 4 (new TimelineScrubber.ts, UIControls.ts, index.html, styles.css)
- **Risk**: Medium (touches playback logic, keyboard handling)

## Future Enhancements

- Loop playback option
- Reverse playback
- Generation markers (bookmarks)
- Mini population graph in timeline background
- Frame-by-frame mode with visual feedback
