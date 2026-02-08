import * as THREE from 'three';
import { FilamentManager } from './FilamentManager.js';

export class InteractionController {
    private camera: THREE.PerspectiveCamera;
    private canvas: HTMLCanvasElement;
    private globeMesh: THREE.Mesh;
    private filamentManager: FilamentManager;
    private raycaster = new THREE.Raycaster();
    private mouse = new THREE.Vector2();
    private isOrbitDragging: () => boolean;

    private isMouseDown = false;
    private isTouching = false;

    // Bound handlers
    private boundOnMouseDown: (e: MouseEvent) => void;
    private boundOnMouseMove: (e: MouseEvent) => void;
    private boundOnMouseUp: (e: MouseEvent) => void;
    private boundOnMouseLeave: (e: MouseEvent) => void;
    private boundOnTouchStart: (e: TouchEvent) => void;
    private boundOnTouchMove: (e: TouchEvent) => void;
    private boundOnTouchEnd: (e: TouchEvent) => void;

    constructor(
        camera: THREE.PerspectiveCamera,
        canvas: HTMLCanvasElement,
        globeMesh: THREE.Mesh,
        filamentManager: FilamentManager,
        isOrbitDragging: () => boolean,
    ) {
        this.camera = camera;
        this.canvas = canvas;
        this.globeMesh = globeMesh;
        this.filamentManager = filamentManager;
        this.isOrbitDragging = isOrbitDragging;

        this.boundOnMouseDown = (e) => this.onMouseDown(e);
        this.boundOnMouseMove = (e) => this.onMouseMove(e);
        this.boundOnMouseUp = (e) => this.onMouseUp(e);
        this.boundOnMouseLeave = (e) => this.onMouseLeave(e);
        this.boundOnTouchStart = (e) => this.onTouchStart(e);
        this.boundOnTouchMove = (e) => this.onTouchMove(e);
        this.boundOnTouchEnd = (e) => this.onTouchEnd(e);

        this.canvas.addEventListener('mousedown', this.boundOnMouseDown);
        this.canvas.addEventListener('mousemove', this.boundOnMouseMove);
        this.canvas.addEventListener('mouseup', this.boundOnMouseUp);
        this.canvas.addEventListener('mouseleave', this.boundOnMouseLeave);
        this.canvas.addEventListener('touchstart', this.boundOnTouchStart, { passive: true });
        this.canvas.addEventListener('touchmove', this.boundOnTouchMove, { passive: true });
        this.canvas.addEventListener('touchend', this.boundOnTouchEnd, { passive: true });
        this.canvas.addEventListener('touchcancel', this.boundOnTouchEnd, { passive: true });
    }

    private updateMouse(clientX: number, clientY: number): void {
        const rect = this.canvas.getBoundingClientRect();
        this.mouse.x = ((clientX - rect.left) / rect.width) * 2 - 1;
        this.mouse.y = -((clientY - rect.top) / rect.height) * 2 + 1;
    }

    private raycastGlobe(): THREE.Vector3 | null {
        if (this.isOrbitDragging()) return null;
        this.raycaster.setFromCamera(this.mouse, this.camera);
        const intersects = this.raycaster.intersectObject(this.globeMesh);
        if (intersects.length > 0) {
            return intersects[0].point;
        }
        return null;
    }

    private onMouseDown(event: MouseEvent): void {
        if (event.button !== 0) return; // Left-click only
        this.isMouseDown = true;
        this.updateMouse(event.clientX, event.clientY);
        const hit = this.raycastGlobe();
        if (hit) {
            this.filamentManager.setTouchTarget(hit);
        }
    }

    private onMouseMove(event: MouseEvent): void {
        this.updateMouse(event.clientX, event.clientY);
        // Attract on hover (desktop behavior) or while dragging
        if (this.isMouseDown || !this.isTouching) {
            const hit = this.raycastGlobe();
            if (hit) {
                this.filamentManager.setTouchTarget(hit);
            } else if (!this.isMouseDown) {
                this.filamentManager.setTouchTarget(null);
            }
        }
    }

    private onMouseUp(_event: MouseEvent): void {
        this.isMouseDown = false;
        this.filamentManager.setTouchTarget(null);
    }

    private onMouseLeave(_event: MouseEvent): void {
        this.isMouseDown = false;
        this.filamentManager.setTouchTarget(null);
    }

    private onTouchStart(event: TouchEvent): void {
        if (event.touches.length !== 1) return; // Only single-finger touch interacts
        this.isTouching = true;
        const touch = event.touches[0];
        this.updateMouse(touch.clientX, touch.clientY);
        const hit = this.raycastGlobe();
        if (hit) {
            this.filamentManager.setTouchTarget(hit);
        }
    }

    private onTouchMove(event: TouchEvent): void {
        if (event.touches.length !== 1) return;
        const touch = event.touches[0];
        this.updateMouse(touch.clientX, touch.clientY);
        const hit = this.raycastGlobe();
        if (hit) {
            this.filamentManager.setTouchTarget(hit);
        } else {
            this.filamentManager.setTouchTarget(null);
        }
    }

    private onTouchEnd(_event: TouchEvent): void {
        this.isTouching = false;
        this.filamentManager.setTouchTarget(null);
    }

    dispose(): void {
        this.canvas.removeEventListener('mousedown', this.boundOnMouseDown);
        this.canvas.removeEventListener('mousemove', this.boundOnMouseMove);
        this.canvas.removeEventListener('mouseup', this.boundOnMouseUp);
        this.canvas.removeEventListener('mouseleave', this.boundOnMouseLeave);
        this.canvas.removeEventListener('touchstart', this.boundOnTouchStart);
        this.canvas.removeEventListener('touchmove', this.boundOnTouchMove);
        this.canvas.removeEventListener('touchend', this.boundOnTouchEnd);
        this.canvas.removeEventListener('touchcancel', this.boundOnTouchEnd);
    }
}
