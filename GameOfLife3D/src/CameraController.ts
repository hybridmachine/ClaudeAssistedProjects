import * as THREE from 'three';

export interface CameraState {
    position: THREE.Vector3;
    target: THREE.Vector3;
    distance: number;
    phi: number;
    theta: number;
}

export class CameraController {
    private camera: THREE.PerspectiveCamera;
    private canvas: HTMLCanvasElement;

    private target = new THREE.Vector3(0, 25, 0);
    private spherical = new THREE.Spherical(50, Math.PI / 3, Math.PI / 4);
    private panSpeed = 0.1;
    private rotateSpeed = 0.01;
    private zoomSpeed = 2;
    private moveSpeed = 0.5;
    private orbitSpeed = 0.02;

    // Pooled math objects to avoid per-frame allocations
    private _cameraDir = new THREE.Vector3();
    private _right = new THREE.Vector3();
    private _up = new THREE.Vector3();
    private _forward = new THREE.Vector3();
    private _moveVec = new THREE.Vector3();
    private _tmpPos = new THREE.Vector3();
    private _relPos = new THREE.Vector3();
    private _rotMat = new THREE.Matrix4();
    private _sphericalTmp = new THREE.Spherical();

    private keys = {
        w: false,
        a: false,
        s: false,
        d: false,
        q: false,
        e: false,
        r: false,
        f: false,
        o: false,
        p: false,
        arrowUp: false,
        arrowDown: false,
        arrowLeft: false,
        arrowRight: false
    };

    private mouse = {
        x: 0,
        y: 0,
        isDragging: false,
        button: -1
    };

    // Touch state for gesture handling
    private touch = {
        isActive: false,
        touchCount: 0,
        // Single touch tracking (for orbit)
        startX: 0,
        startY: 0,
        currentX: 0,
        currentY: 0,
        // Two-finger tracking (for pan and pinch)
        touch1: { x: 0, y: 0 },
        touch2: { x: 0, y: 0 },
        initialPinchDistance: 0,
        lastPinchDistance: 0
    };

    private isEnabled = true;

    // Bound event handlers for proper cleanup
    private boundOnKeyDown: (event: KeyboardEvent) => void;
    private boundOnKeyUp: (event: KeyboardEvent) => void;
    private boundOnMouseDown: (event: MouseEvent) => void;
    private boundOnMouseMove: (event: MouseEvent) => void;
    private boundOnMouseUp: (event: MouseEvent) => void;
    private boundOnWheel: (event: WheelEvent) => void;
    private boundOnTouchStart: (event: TouchEvent) => void;
    private boundOnTouchMove: (event: TouchEvent) => void;
    private boundOnTouchEnd: (event: TouchEvent) => void;
    private boundOnContextMenu: (event: Event) => void;

    constructor(camera: THREE.PerspectiveCamera, canvas: HTMLCanvasElement) {
        this.camera = camera;
        this.canvas = canvas;

        // Bind event handlers to preserve references for cleanup
        this.boundOnKeyDown = (event: KeyboardEvent) => this.onKeyDown(event);
        this.boundOnKeyUp = (event: KeyboardEvent) => this.onKeyUp(event);
        this.boundOnMouseDown = (event: MouseEvent) => this.onMouseDown(event);
        this.boundOnMouseMove = (event: MouseEvent) => this.onMouseMove(event);
        this.boundOnMouseUp = (event: MouseEvent) => this.onMouseUp(event);
        this.boundOnWheel = (event: WheelEvent) => this.onWheel(event);
        this.boundOnTouchStart = (event: TouchEvent) => this.onTouchStart(event);
        this.boundOnTouchMove = (event: TouchEvent) => this.onTouchMove(event);
        this.boundOnTouchEnd = (event: TouchEvent) => this.onTouchEnd(event);
        this.boundOnContextMenu = (event: Event) => event.preventDefault();

        this.setupEventListeners();
        this.updateCameraPosition();
    }

    private setupEventListeners(): void {
        document.addEventListener('keydown', this.boundOnKeyDown);
        document.addEventListener('keyup', this.boundOnKeyUp);

        this.canvas.addEventListener('mousedown', this.boundOnMouseDown);
        this.canvas.addEventListener('mousemove', this.boundOnMouseMove);
        this.canvas.addEventListener('mouseup', this.boundOnMouseUp);
        this.canvas.addEventListener('wheel', this.boundOnWheel);

        this.canvas.addEventListener('contextmenu', this.boundOnContextMenu);

        // Touch event listeners for mobile/tablet support
        this.canvas.addEventListener('touchstart', this.boundOnTouchStart, { passive: false });
        this.canvas.addEventListener('touchmove', this.boundOnTouchMove, { passive: false });
        this.canvas.addEventListener('touchend', this.boundOnTouchEnd, { passive: false });
        this.canvas.addEventListener('touchcancel', this.boundOnTouchEnd, { passive: false });

        this.canvas.setAttribute('tabindex', '0');
        this.canvas.focus();
    }

    private onKeyDown(event: KeyboardEvent): void {
        if (!this.isEnabled) return;

        // Allow typing in input fields
        const target = event.target as HTMLElement;
        if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT') {
            return;
        }

        switch (event.code) {
            case 'KeyW':
            case 'ArrowUp':
                this.keys.w = true;
                this.keys.arrowUp = true;
                break;
            case 'KeyS':
            case 'ArrowDown':
                this.keys.s = true;
                this.keys.arrowDown = true;
                break;
            case 'KeyA':
            case 'ArrowLeft':
                this.keys.a = true;
                this.keys.arrowLeft = true;
                break;
            case 'KeyD':
            case 'ArrowRight':
                this.keys.d = true;
                this.keys.arrowRight = true;
                break;
            case 'KeyQ':
                this.keys.q = true;
                break;
            case 'KeyE':
                this.keys.e = true;
                break;
            case 'KeyR':
                this.keys.r = true;
                break;
            case 'KeyF':
                this.keys.f = true;
                break;
            case 'KeyO':
                this.keys.o = true;
                break;
            case 'KeyP':
                this.keys.p = true;
                break;
        }
        event.preventDefault();
    }

    private onKeyUp(event: KeyboardEvent): void {
        if (!this.isEnabled) return;

        // Allow typing in input fields
        const target = event.target as HTMLElement;
        if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT') {
            return;
        }

        switch (event.code) {
            case 'KeyW':
            case 'ArrowUp':
                this.keys.w = false;
                this.keys.arrowUp = false;
                break;
            case 'KeyS':
            case 'ArrowDown':
                this.keys.s = false;
                this.keys.arrowDown = false;
                break;
            case 'KeyA':
            case 'ArrowLeft':
                this.keys.a = false;
                this.keys.arrowLeft = false;
                break;
            case 'KeyD':
            case 'ArrowRight':
                this.keys.d = false;
                this.keys.arrowRight = false;
                break;
            case 'KeyQ':
                this.keys.q = false;
                break;
            case 'KeyE':
                this.keys.e = false;
                break;
            case 'KeyR':
                this.keys.r = false;
                break;
            case 'KeyF':
                this.keys.f = false;
                break;
            case 'KeyO':
                this.keys.o = false;
                break;
            case 'KeyP':
                this.keys.p = false;
                break;
        }
        event.preventDefault();
    }

    private onMouseDown(event: MouseEvent): void {
        if (!this.isEnabled) return;

        this.mouse.isDragging = true;
        this.mouse.button = event.button;
        this.mouse.x = event.clientX;
        this.mouse.y = event.clientY;

        event.preventDefault();
    }

    private onMouseMove(event: MouseEvent): void {
        if (!this.isEnabled || !this.mouse.isDragging) return;

        const deltaX = event.clientX - this.mouse.x;
        const deltaY = event.clientY - this.mouse.y;

        if (this.mouse.button === 0) {
            this.spherical.theta -= deltaX * this.rotateSpeed;
            this.spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, this.spherical.phi + deltaY * this.rotateSpeed));

            this.updateCameraPosition();
        } else if (this.mouse.button === 1 || this.mouse.button === 2) {
            this.applyPan(-deltaX * this.panSpeed * 0.1, deltaY * this.panSpeed * 0.1);
        }

        this.mouse.x = event.clientX;
        this.mouse.y = event.clientY;

        event.preventDefault();
    }

    private onMouseUp(event: MouseEvent): void {
        this.mouse.isDragging = false;
        this.mouse.button = -1;
        event.preventDefault();
    }

    private onWheel(event: WheelEvent): void {
        if (!this.isEnabled) return;

        const delta = event.deltaY > 0 ? 1.1 : 0.9;
        this.spherical.radius = Math.max(1, Math.min(1000, this.spherical.radius * delta));

        this.updateCameraPosition();
        event.preventDefault();
    }

    /**
     * Calculate the distance between two touch points
     */
    private getPinchDistance(touch1: Touch, touch2: Touch): number {
        const dx = touch2.clientX - touch1.clientX;
        const dy = touch2.clientY - touch1.clientY;
        return Math.sqrt(dx * dx + dy * dy);
    }

    /**
     * Get the center point between two touches
     */
    private getTouchCenter(touch1: Touch, touch2: Touch): { x: number; y: number } {
        return {
            x: (touch1.clientX + touch2.clientX) / 2,
            y: (touch1.clientY + touch2.clientY) / 2
        };
    }

    /**
     * Handle touch start - initialize touch tracking
     * Single finger: prepare for orbit
     * Two fingers: prepare for pan and pinch
     */
    private onTouchStart(event: TouchEvent): void {
        if (!this.isEnabled) return;
        event.preventDefault();

        const touches = event.touches;
        this.touch.isActive = true;
        this.touch.touchCount = touches.length;

        if (touches.length === 1) {
            // Single touch - orbit mode
            this.touch.startX = touches[0].clientX;
            this.touch.startY = touches[0].clientY;
            this.touch.currentX = touches[0].clientX;
            this.touch.currentY = touches[0].clientY;
        } else if (touches.length === 2) {
            // Two finger touch - pan and pinch mode
            this.touch.touch1.x = touches[0].clientX;
            this.touch.touch1.y = touches[0].clientY;
            this.touch.touch2.x = touches[1].clientX;
            this.touch.touch2.y = touches[1].clientY;

            // Calculate initial pinch distance for zoom
            const pinchDistance = this.getPinchDistance(touches[0], touches[1]);
            this.touch.initialPinchDistance = pinchDistance;
            this.touch.lastPinchDistance = pinchDistance;
        }
    }

    /**
     * Handle touch move - process gestures
     * Single finger: orbit camera around target
     * Two fingers: pan view + pinch to zoom
     */
    private onTouchMove(event: TouchEvent): void {
        if (!this.isEnabled || !this.touch.isActive) return;
        event.preventDefault();

        const touches = event.touches;

        if (touches.length === 1 && this.touch.touchCount === 1) {
            // Single touch drag - orbit camera (like left mouse button)
            const deltaX = touches[0].clientX - this.touch.currentX;
            const deltaY = touches[0].clientY - this.touch.currentY;

            // Apply rotation with touch-specific sensitivity
            const touchRotateSpeed = this.rotateSpeed * 1.5;
            this.spherical.theta -= deltaX * touchRotateSpeed;
            this.spherical.phi = Math.max(
                0.1,
                Math.min(Math.PI - 0.1, this.spherical.phi + deltaY * touchRotateSpeed)
            );

            this.updateCameraPosition();

            // Update current position
            this.touch.currentX = touches[0].clientX;
            this.touch.currentY = touches[0].clientY;

        } else if (touches.length === 2) {
            // Two finger gesture - handle both pan and pinch

            // Calculate pinch zoom
            const currentPinchDistance = this.getPinchDistance(touches[0], touches[1]);
            const pinchDelta = this.touch.lastPinchDistance / currentPinchDistance;

            // Apply zoom based on pinch
            if (Math.abs(pinchDelta - 1) > 0.01) {
                this.spherical.radius = Math.max(
                    1,
                    Math.min(1000, this.spherical.radius * pinchDelta)
                );
            }
            this.touch.lastPinchDistance = currentPinchDistance;

            // Calculate pan (two-finger drag)
            const currentCenter = this.getTouchCenter(touches[0], touches[1]);
            const previousCenter = {
                x: (this.touch.touch1.x + this.touch.touch2.x) / 2,
                y: (this.touch.touch1.y + this.touch.touch2.y) / 2
            };

            const panDeltaX = currentCenter.x - previousCenter.x;
            const panDeltaY = currentCenter.y - previousCenter.y;

            // Apply pan (like right mouse button drag)
            const touchPanSpeed = this.panSpeed * 0.15;
            this.applyPan(-panDeltaX * touchPanSpeed, panDeltaY * touchPanSpeed);

            // Update touch positions
            this.touch.touch1.x = touches[0].clientX;
            this.touch.touch1.y = touches[0].clientY;
            this.touch.touch2.x = touches[1].clientX;
            this.touch.touch2.y = touches[1].clientY;
        }
    }

    /**
     * Handle touch end - reset touch state
     */
    private onTouchEnd(event: TouchEvent): void {
        event.preventDefault();

        const touches = event.touches;

        if (touches.length === 0) {
            // All fingers lifted - reset state
            this.touch.isActive = false;
            this.touch.touchCount = 0;
        } else if (touches.length === 1) {
            // Went from 2 fingers to 1 - switch to orbit mode
            this.touch.touchCount = 1;
            this.touch.currentX = touches[0].clientX;
            this.touch.currentY = touches[0].clientY;
        }
    }

    update(): void {
        if (!this.isEnabled) return;

        this.camera.getWorldDirection(this._cameraDir);
        this._right.crossVectors(this._cameraDir, this.camera.up).normalize();
        this._forward.copy(this._cameraDir).normalize();
        this._up.set(0, 0, 1);
        this._moveVec.set(0, 0, 0);

        if (this.keys.w || this.keys.arrowUp) {
            this._moveVec.add(this._forward);
        }
        if (this.keys.s || this.keys.arrowDown) {
            this._moveVec.sub(this._forward);
        }
        if (this.keys.a || this.keys.arrowLeft) {
            this._moveVec.sub(this._right);
        }
        if (this.keys.d || this.keys.arrowRight) {
            this._moveVec.add(this._right);
        }
        if (this.keys.r) {
            this._moveVec.add(this._up);
        }
        if (this.keys.f) {
            this._moveVec.sub(this._up);
        }

        if (this.keys.q) {
            this.spherical.theta -= this.rotateSpeed * 2;
            this.updateCameraPosition();
        }
        if (this.keys.e) {
            this.spherical.theta += this.rotateSpeed * 2;
            this.updateCameraPosition();
        }

        // Z-axis orbit (camera orbits around Z while always looking at center)
        if (this.keys.o) {
            this.orbitAroundZ(-this.orbitSpeed);
        }
        if (this.keys.p) {
            this.orbitAroundZ(this.orbitSpeed);
        }

        if (this._moveVec.length() > 0) {
            this._moveVec.normalize().multiplyScalar(this.moveSpeed);
            this.target.add(this._moveVec);
            this.updateCameraPosition();
        }
    }

    private applyPan(rightAmount: number, upAmount: number): void {
        this.camera.getWorldDirection(this._cameraDir);
        this._right.crossVectors(this._cameraDir, this.camera.up).normalize();
        this._up.crossVectors(this._right, this._cameraDir).normalize();
        this.target.addScaledVector(this._right, rightAmount);
        this.target.addScaledVector(this._up, upAmount);
        this.updateCameraPosition();
    }

    private updateCameraPosition(): void {
        this._tmpPos.setFromSpherical(this.spherical);
        this._tmpPos.add(this.target);

        this.camera.position.copy(this._tmpPos);
        this.camera.lookAt(this.target);
    }

    private orbitAroundZ(angle: number): void {
        // Calculate current position relative to target
        this._relPos.copy(this.camera.position).sub(this.target);

        // Rotate around Z-axis (up-down axis) in the X-Y plane
        this._rotMat.makeRotationZ(angle);
        this._relPos.applyMatrix4(this._rotMat);

        // Set new camera position
        this.camera.position.copy(this.target).add(this._relPos);

        // Always look at the target (center of the model)
        this.camera.lookAt(this.target);

        // Update spherical coordinates to match new position
        this._sphericalTmp.setFromVector3(this._relPos);
        this.spherical.theta = this._sphericalTmp.theta;
        this.spherical.phi = this._sphericalTmp.phi;
        this.spherical.radius = this._sphericalTmp.radius;
    }

    reset(): void {
        this.target.set(0, 25, 0);
        this.spherical.set(50, Math.PI / 3, Math.PI / 4);
        this.updateCameraPosition();
    }

    setTarget(x: number, y: number, z: number): void {
        this.target.set(x, y, z);
        this.updateCameraPosition();
    }

    setEnabled(enabled: boolean): void {
        this.isEnabled = enabled;
    }

    isControlEnabled(): boolean {
        return this.isEnabled;
    }

    getState(): CameraState {
        return {
            position: this.camera.position.clone(),
            target: this.target.clone(),
            distance: this.spherical.radius,
            phi: this.spherical.phi,
            theta: this.spherical.theta
        };
    }

    setState(state: CameraState): void {
        this.target.copy(state.target);
        this.spherical.radius = state.distance;
        this.spherical.phi = state.phi;
        this.spherical.theta = state.theta;
        this.updateCameraPosition();
    }

    dispose(): void {
        document.removeEventListener('keydown', this.boundOnKeyDown);
        document.removeEventListener('keyup', this.boundOnKeyUp);
        this.canvas.removeEventListener('mousedown', this.boundOnMouseDown);
        this.canvas.removeEventListener('mousemove', this.boundOnMouseMove);
        this.canvas.removeEventListener('mouseup', this.boundOnMouseUp);
        this.canvas.removeEventListener('wheel', this.boundOnWheel);
        this.canvas.removeEventListener('contextmenu', this.boundOnContextMenu);
        // Clean up touch event listeners
        this.canvas.removeEventListener('touchstart', this.boundOnTouchStart);
        this.canvas.removeEventListener('touchmove', this.boundOnTouchMove);
        this.canvas.removeEventListener('touchend', this.boundOnTouchEnd);
        this.canvas.removeEventListener('touchcancel', this.boundOnTouchEnd);
    }
}