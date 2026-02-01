export interface TimelineConfig {
  container: HTMLElement;
  onRangeChange: (start: number, end: number) => void;
  onPlayToggle: (playing: boolean) => void;
  onSpeedChange: (multiplier: number) => void;
  onReset: () => void;
}

export class TimelineScrubber {
  private container: HTMLElement;
  private track!: HTMLElement;
  private startHandle!: HTMLElement;
  private endHandle!: HTMLElement;
  private rangeFill!: HTMLElement;
  private playButton!: HTMLButtonElement;
  private resetButton!: HTMLButtonElement;
  private timeDisplay!: HTMLElement;
  private speedSelect!: HTMLSelectElement;

  private totalGenerations = 0;
  private startGeneration = 0;
  private endGeneration = 0;
  private isPlaying = false;
  private isDragging = false;
  private activeHandle: 'start' | 'end' = 'end';
  private dragHandleTarget: HTMLElement | null = null;

  private onRangeChange: (start: number, end: number) => void;
  private onPlayToggle: (playing: boolean) => void;
  private onSpeedChange: (multiplier: number) => void;
  private onReset: () => void;

  private readonly boundHandleContainerClick = (event: Event) => this.handleContainerClick(event);
  private readonly boundHandlePointerDown = (event: PointerEvent) => this.handlePointerDown(event);
  private readonly boundHandlePointerMove = (event: PointerEvent) => this.handlePointerMove(event);
  private readonly boundHandlePointerUp = (event: PointerEvent) => this.handlePointerUp(event);
  private readonly boundHandleWheel = (event: WheelEvent) => this.handleWheel(event);
  private readonly boundHandleKeyDown = (event: KeyboardEvent) => this.handleKeyDown(event);
  private readonly boundHandleSpeedChange = () => this.handleSpeedChange();

  constructor(config: TimelineConfig) {
    this.container = config.container;
    this.onRangeChange = config.onRangeChange;
    this.onPlayToggle = config.onPlayToggle;
    this.onSpeedChange = config.onSpeedChange;
    this.onReset = config.onReset;

    this.createDOM();
    this.attachEventListeners();
  }

  private createDOM(): void {
    this.container.innerHTML = `
      <div class="timeline-scrubber" aria-label="Generation scrubber">
        <div class="transport-controls" role="group" aria-label="Playback controls">
          <button class="transport-btn" data-action="first" title="First (Home)" aria-label="First generation">|&lt;</button>
          <button class="transport-btn" data-action="prev" title="Previous (Left)" aria-label="Previous generation">&lt;</button>
          <button class="transport-btn play-btn" data-action="play" title="Play/Pause (Space)" aria-label="Play">Play</button>
          <button class="transport-btn" data-action="next" title="Next (Right)" aria-label="Next generation">&gt;</button>
          <button class="transport-btn" data-action="last" title="Last (End)" aria-label="Last generation">&gt;|</button>
          <button class="transport-btn reset-btn" data-action="reset" title="Reset simulation" aria-label="Reset simulation">Reset</button>
        </div>

        <div class="timeline-track-container">
          <div class="timeline-track" aria-label="Generation range" role="slider" aria-valuemin="0" aria-valuemax="0" aria-valuenow="0" aria-valuetext="Gen 0-0">
            <div class="timeline-range"></div>
            <div class="timeline-scrubber-handle start-handle" data-handle="start" aria-hidden="true"></div>
            <div class="timeline-scrubber-handle end-handle" data-handle="end" aria-hidden="true"></div>
          </div>
          <div class="timeline-labels" aria-hidden="true">
            <span class="timeline-label-start">0</span>
            <span class="timeline-label-end">0</span>
          </div>
        </div>

        <div class="timeline-info">
          <span class="time-display" role="status" aria-live="polite">Gen 0 / 0</span>
          <label class="speed-label" for="timeline-speed">Speed</label>
          <select id="timeline-speed" class="speed-select" aria-label="Playback speed">
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

    this.track = this.container.querySelector('.timeline-track') as HTMLElement;
    this.startHandle = this.container.querySelector('.start-handle') as HTMLElement;
    this.endHandle = this.container.querySelector('.end-handle') as HTMLElement;
    this.rangeFill = this.container.querySelector('.timeline-range') as HTMLElement;
    this.playButton = this.container.querySelector('.play-btn') as HTMLButtonElement;
    this.resetButton = this.container.querySelector('.reset-btn') as HTMLButtonElement;
    this.timeDisplay = this.container.querySelector('.time-display') as HTMLElement;
    this.speedSelect = this.container.querySelector('.speed-select') as HTMLSelectElement;
  }

  private attachEventListeners(): void {
    this.container.addEventListener('click', this.boundHandleContainerClick);
    this.track.addEventListener('pointerdown', this.boundHandlePointerDown);
    this.startHandle.addEventListener('pointerdown', this.boundHandlePointerDown);
    this.endHandle.addEventListener('pointerdown', this.boundHandlePointerDown);
    this.track.addEventListener('wheel', this.boundHandleWheel, { passive: false });
    this.speedSelect.addEventListener('change', this.boundHandleSpeedChange);
    document.addEventListener('keydown', this.boundHandleKeyDown);
  }

  private handleContainerClick(event: Event): void {
    const target = event.target as HTMLElement | null;
    if (!target) return;
    const button = target.closest('.transport-btn') as HTMLElement | null;
    if (!button || !this.container.contains(button)) return;

    const action = button.dataset.action;
    if (action) {
      this.handleTransportAction(action);
    }
  }

  private handleTransportAction(action: string): void {
    switch (action) {
      case 'first':
        this.seekEndTo(0);
        break;
      case 'prev':
        this.seekEndTo(this.endGeneration - 1);
        break;
      case 'play':
        this.togglePlayback();
        break;
      case 'next':
        this.seekEndTo(this.endGeneration + 1);
        break;
      case 'last':
        this.seekEndTo(this.totalGenerations - 1);
        break;
      case 'reset':
        this.onReset();
        break;
      default:
        break;
    }
  }

  private handlePointerDown(event: PointerEvent): void {
    if (event.button !== 0) return;
    event.preventDefault();
    this.isDragging = true;
    this.setActiveHandleFromEvent(event);
    if (event.currentTarget instanceof HTMLElement) {
      this.dragHandleTarget = event.currentTarget;
      event.currentTarget.setPointerCapture(event.pointerId);
    }
    this.updatePositionFromPointer(event);
    window.addEventListener('pointermove', this.boundHandlePointerMove);
    window.addEventListener('pointerup', this.boundHandlePointerUp);
    window.addEventListener('pointercancel', this.boundHandlePointerUp);
  }

  private handlePointerMove(event: PointerEvent): void {
    if (!this.isDragging) return;
    this.updatePositionFromPointer(event);
  }

  private handlePointerUp(event?: PointerEvent): void {
    if (!this.isDragging) return;
    if (this.dragHandleTarget) {
      try {
        this.dragHandleTarget.releasePointerCapture(event?.pointerId ?? 0);
      } catch {
        // Ignore if pointer capture was already released
      }
    }
    this.isDragging = false;
    this.dragHandleTarget = null;
    window.removeEventListener('pointermove', this.boundHandlePointerMove);
    window.removeEventListener('pointerup', this.boundHandlePointerUp);
    window.removeEventListener('pointercancel', this.boundHandlePointerUp);
  }

  private updatePositionFromPointer(event: PointerEvent): void {
    if (this.totalGenerations <= 0) return;
    const rect = this.track.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const percent = Math.max(0, Math.min(1, x / rect.width));
    const generation = Math.round(percent * (this.totalGenerations - 1));
    this.seekHandleTo(this.activeHandle, generation);
  }

  private handleWheel(event: WheelEvent): void {
    if (this.totalGenerations <= 0) return;
    event.preventDefault();
    const delta = event.deltaY > 0 ? 1 : -1;
    this.seekEndTo(this.endGeneration + delta);
  }

  private handleKeyDown(event: KeyboardEvent): void {
    const target = event.target as HTMLElement | null;
    if (target) {
      const isFormField = target instanceof HTMLInputElement
        || target instanceof HTMLTextAreaElement
        || target instanceof HTMLSelectElement
        || target.isContentEditable;
      if (isFormField) return;
    }

    switch (event.code) {
      case 'Space':
        event.preventDefault();
        this.togglePlayback();
        break;
      case 'ArrowLeft':
        event.preventDefault();
        this.seekEndTo(this.endGeneration - (event.shiftKey ? 10 : 1));
        break;
      case 'ArrowRight':
        event.preventDefault();
        this.seekEndTo(this.endGeneration + (event.shiftKey ? 10 : 1));
        break;
      case 'Home':
        event.preventDefault();
        this.seekEndTo(0);
        break;
      case 'End':
        event.preventDefault();
        this.seekEndTo(this.totalGenerations - 1);
        break;
      default:
        break;
    }
  }

  private handleSpeedChange(): void {
    const multiplier = parseFloat(this.speedSelect.value);
    if (!Number.isFinite(multiplier)) return;
    this.onSpeedChange(multiplier);
  }

  private togglePlayback(): void {
    this.setPlaying(!this.isPlaying);
    this.onPlayToggle(this.isPlaying);
  }

  public setPlaying(playing: boolean): void {
    this.isPlaying = playing;
    this.playButton.textContent = this.isPlaying ? 'Pause' : 'Play';
    this.playButton.setAttribute('aria-label', this.isPlaying ? 'Pause' : 'Play');
  }

  private seekHandleTo(handle: 'start' | 'end', generation: number): void {
    if (this.totalGenerations <= 0) return;
    const maxGeneration = Math.max(0, this.totalGenerations - 1);
    const clamped = Math.max(0, Math.min(maxGeneration, generation));

    if (handle === 'start') {
      this.startGeneration = clamped;
    } else {
      this.endGeneration = clamped;
    }

    if (this.startGeneration > this.endGeneration) {
      const temp = this.startGeneration;
      this.startGeneration = this.endGeneration;
      this.endGeneration = temp;
      this.activeHandle = handle === 'start' ? 'end' : 'start';
    }

    this.updateDisplay();
    this.onRangeChange(this.startGeneration, this.endGeneration);
  }

  private seekEndTo(generation: number): void {
    this.activeHandle = 'end';
    this.seekHandleTo('end', generation);
  }

  public setEndGeneration(generation: number): void {
    this.seekEndTo(generation);
  }

  public setTotalGenerations(total: number): void {
    this.totalGenerations = Math.max(0, total);
    const maxGeneration = Math.max(0, this.totalGenerations - 1);
    this.startGeneration = Math.min(this.startGeneration, maxGeneration);
    this.endGeneration = Math.min(this.endGeneration, maxGeneration);
    this.updateDisplay();

    const endLabel = this.container.querySelector('.timeline-label-end');
    if (endLabel) endLabel.textContent = maxGeneration.toString();
    this.track.setAttribute('aria-valuemax', maxGeneration.toString());
  }

  public setRange(start: number, end: number): void {
    const maxGeneration = Math.max(0, this.totalGenerations - 1);
    const clampedStart = Math.max(0, Math.min(maxGeneration, start));
    const clampedEnd = Math.max(0, Math.min(maxGeneration, end));
    this.startGeneration = Math.min(clampedStart, clampedEnd);
    this.endGeneration = Math.max(clampedStart, clampedEnd);
    this.updateDisplay();
  }

  private updateDisplay(): void {
    const maxGeneration = Math.max(0, this.totalGenerations - 1);
    const startPercent = maxGeneration > 0 ? (this.startGeneration / maxGeneration) * 100 : 0;
    const endPercent = maxGeneration > 0 ? (this.endGeneration / maxGeneration) * 100 : 0;
    const rangeLeft = Math.min(startPercent, endPercent);
    const rangeWidth = Math.abs(endPercent - startPercent);

    this.startHandle.style.left = `${startPercent}%`;
    this.endHandle.style.left = `${endPercent}%`;
    this.rangeFill.style.left = `${rangeLeft}%`;
    this.rangeFill.style.width = `${rangeWidth}%`;

    this.timeDisplay.textContent = `Gen ${this.startGeneration}-${this.endGeneration} / ${maxGeneration}`;
    this.track.setAttribute('aria-valuenow', this.endGeneration.toString());
    this.track.setAttribute('aria-valuetext', `Gen ${this.startGeneration}-${this.endGeneration}`);
  }

  private setActiveHandleFromEvent(event: PointerEvent): void {
    const target = event.target as HTMLElement | null;
    const handle = target?.closest('.timeline-scrubber-handle') as HTMLElement | null;
    if (handle?.dataset.handle === 'start' || handle?.dataset.handle === 'end') {
      this.activeHandle = handle.dataset.handle;
      return;
    }

    this.activeHandle = event.shiftKey ? 'start' : 'end';
  }

  public destroy(): void {
    window.removeEventListener('pointermove', this.boundHandlePointerMove);
    window.removeEventListener('pointerup', this.boundHandlePointerUp);
    window.removeEventListener('pointercancel', this.boundHandlePointerUp);
    document.removeEventListener('keydown', this.boundHandleKeyDown);
    this.container.removeEventListener('click', this.boundHandleContainerClick);
    this.track.removeEventListener('pointerdown', this.boundHandlePointerDown);
    this.startHandle.removeEventListener('pointerdown', this.boundHandlePointerDown);
    this.endHandle.removeEventListener('pointerdown', this.boundHandlePointerDown);
    this.track.removeEventListener('wheel', this.boundHandleWheel);
    this.speedSelect.removeEventListener('change', this.boundHandleSpeedChange);
  }
}
