import * as THREE from 'three';

export class CameraController {
    private camera: THREE.PerspectiveCamera;
    private canvas: HTMLCanvasElement;

    private target = new THREE.Vector3(0, 0, 0);
    private spherical = new THREE.Spherical(6, Math.PI / 2, 0);
    private rotateSpeed = 0.005;
    private autoRotateSpeed = 0.016;

    // Pooled math objects
    private _tmpPos = new THREE.Vector3();

    private mouse = {
        x: 0,
        y: 0,
        isDragging: false,
        button: -1,
    };

    private touch = {
        isActive: false,
        touchCount: 0,
        currentX: 0,
        currentY: 0,
        touch1: { x: 0, y: 0 },
        touch2: { x: 0, y: 0 },
        lastPinchDistance: 0,
    };

    private isEnabled = true;

    // Bound handlers for cleanup
    private boundOnMouseDown: (e: MouseEvent) => void;
    private boundOnMouseMove: (e: MouseEvent) => void;
    private boundOnMouseUp: (e: MouseEvent) => void;
    private boundOnWheel: (e: WheelEvent) => void;
    private boundOnTouchStart: (e: TouchEvent) => void;
    private boundOnTouchMove: (e: TouchEvent) => void;
    private boundOnTouchEnd: (e: TouchEvent) => void;
    private boundOnContextMenu: (e: Event) => void;

    constructor(camera: THREE.PerspectiveCamera, canvas: HTMLCanvasElement) {
        this.camera = camera;
        this.canvas = canvas;

        this.boundOnMouseDown = (e) => this.onMouseDown(e);
        this.boundOnMouseMove = (e) => this.onMouseMove(e);
        this.boundOnMouseUp = (e) => this.onMouseUp(e);
        this.boundOnWheel = (e) => this.onWheel(e);
        this.boundOnTouchStart = (e) => this.onTouchStart(e);
        this.boundOnTouchMove = (e) => this.onTouchMove(e);
        this.boundOnTouchEnd = (e) => this.onTouchEnd(e);
        this.boundOnContextMenu = (e) => e.preventDefault();

        this.setupEventListeners();
        this.updateCameraPosition();
    }

    private setupEventListeners(): void {
        this.canvas.addEventListener('mousedown', this.boundOnMouseDown);
        this.canvas.addEventListener('mousemove', this.boundOnMouseMove);
        this.canvas.addEventListener('mouseup', this.boundOnMouseUp);
        this.canvas.addEventListener('wheel', this.boundOnWheel);
        this.canvas.addEventListener('contextmenu', this.boundOnContextMenu);
        this.canvas.addEventListener('touchstart', this.boundOnTouchStart, { passive: false });
        this.canvas.addEventListener('touchmove', this.boundOnTouchMove, { passive: false });
        this.canvas.addEventListener('touchend', this.boundOnTouchEnd, { passive: false });
        this.canvas.addEventListener('touchcancel', this.boundOnTouchEnd, { passive: false });
    }

    private onMouseDown(event: MouseEvent): void {
        if (!this.isEnabled) return;
        // Only orbit on right-click (button 2)
        if (event.button !== 2) return;
        this.mouse.isDragging = true;
        this.mouse.button = event.button;
        this.mouse.x = event.clientX;
        this.mouse.y = event.clientY;
        event.preventDefault();
    }

    private onMouseMove(event: MouseEvent): void {
        if (!this.isEnabled || !this.mouse.isDragging) return;
        if (this.mouse.button !== 2) return;

        const deltaX = event.clientX - this.mouse.x;
        const deltaY = event.clientY - this.mouse.y;

        this.spherical.theta -= deltaX * this.rotateSpeed;
        this.spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, this.spherical.phi + deltaY * this.rotateSpeed));
        this.updateCameraPosition();

        this.mouse.x = event.clientX;
        this.mouse.y = event.clientY;
        event.preventDefault();
    }

    private onMouseUp(event: MouseEvent): void {
        this.mouse.isDragging = false;
        this.mouse.button = -1;
    }

    private onWheel(event: WheelEvent): void {
        if (!this.isEnabled) return;
        const delta = event.deltaY > 0 ? 1.08 : 0.92;
        this.spherical.radius = Math.max(3.5, Math.min(15, this.spherical.radius * delta));
        this.updateCameraPosition();
        event.preventDefault();
    }

    private getPinchDistance(t1: Touch, t2: Touch): number {
        const dx = t2.clientX - t1.clientX;
        const dy = t2.clientY - t1.clientY;
        return Math.sqrt(dx * dx + dy * dy);
    }

    private onTouchStart(event: TouchEvent): void {
        if (!this.isEnabled) return;
        event.preventDefault();
        const touches = event.touches;
        this.touch.isActive = true;
        this.touch.touchCount = touches.length;

        if (touches.length === 2) {
            this.touch.touch1.x = touches[0].clientX;
            this.touch.touch1.y = touches[0].clientY;
            this.touch.touch2.x = touches[1].clientX;
            this.touch.touch2.y = touches[1].clientY;
            this.touch.lastPinchDistance = this.getPinchDistance(touches[0], touches[1]);
        } else if (touches.length >= 3) {
            // 3-finger: orbit
            this.touch.currentX = touches[0].clientX;
            this.touch.currentY = touches[0].clientY;
        }
    }

    private onTouchMove(event: TouchEvent): void {
        if (!this.isEnabled || !this.touch.isActive) return;
        event.preventDefault();
        const touches = event.touches;

        if (touches.length === 2) {
            // Pinch zoom
            const dist = this.getPinchDistance(touches[0], touches[1]);
            const pinchDelta = this.touch.lastPinchDistance / dist;
            if (Math.abs(pinchDelta - 1) > 0.01) {
                this.spherical.radius = Math.max(3.5, Math.min(15, this.spherical.radius * pinchDelta));
                this.updateCameraPosition();
            }
            this.touch.lastPinchDistance = dist;
        } else if (touches.length >= 3) {
            // 3-finger drag: orbit
            const deltaX = touches[0].clientX - this.touch.currentX;
            const deltaY = touches[0].clientY - this.touch.currentY;
            const touchRotateSpeed = this.rotateSpeed * 1.5;
            this.spherical.theta -= deltaX * touchRotateSpeed;
            this.spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, this.spherical.phi + deltaY * touchRotateSpeed));
            this.updateCameraPosition();
            this.touch.currentX = touches[0].clientX;
            this.touch.currentY = touches[0].clientY;
        }
    }

    private onTouchEnd(event: TouchEvent): void {
        event.preventDefault();
        const touches = event.touches;
        if (touches.length === 0) {
            this.touch.isActive = false;
            this.touch.touchCount = 0;
        } else {
            this.touch.touchCount = touches.length;
            if (touches.length === 2) {
                this.touch.lastPinchDistance = this.getPinchDistance(touches[0], touches[1]);
            }
        }
    }

    update(deltaTime: number): void {
        if (!this.isEnabled) return;
        if (!this.mouse.isDragging && !this.touch.isActive) {
            this.spherical.theta += this.autoRotateSpeed * deltaTime;
            this.updateCameraPosition();
        }
    }

    private updateCameraPosition(): void {
        this._tmpPos.setFromSpherical(this.spherical);
        this._tmpPos.add(this.target);
        this.camera.position.copy(this._tmpPos);
        this.camera.lookAt(this.target);
    }

    /** Check if orbit drag is currently active (for suppressing interaction) */
    isOrbitDragging(): boolean {
        return this.mouse.isDragging || (this.touch.isActive && this.touch.touchCount >= 3);
    }

    dispose(): void {
        this.canvas.removeEventListener('mousedown', this.boundOnMouseDown);
        this.canvas.removeEventListener('mousemove', this.boundOnMouseMove);
        this.canvas.removeEventListener('mouseup', this.boundOnMouseUp);
        this.canvas.removeEventListener('wheel', this.boundOnWheel);
        this.canvas.removeEventListener('contextmenu', this.boundOnContextMenu);
        this.canvas.removeEventListener('touchstart', this.boundOnTouchStart);
        this.canvas.removeEventListener('touchmove', this.boundOnTouchMove);
        this.canvas.removeEventListener('touchend', this.boundOnTouchEnd);
        this.canvas.removeEventListener('touchcancel', this.boundOnTouchEnd);
    }
}
