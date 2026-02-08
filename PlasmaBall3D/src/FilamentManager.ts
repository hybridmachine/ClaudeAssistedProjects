import * as THREE from 'three';
import { PlasmaFilament } from './PlasmaFilament.js';

const FILAMENT_COUNT = 7;

interface IdleTarget {
    theta: number;
    phi: number;
    thetaSpeed: number;
    phiSpeed: number;
}

export class FilamentManager {
    private filaments: PlasmaFilament[] = [];
    private idleTargets: IdleTarget[] = [];
    private globeRadius: number;

    // Touch interaction state
    private touchTarget: THREE.Vector3 | null = null;
    private blendFactor = 0.0;
    private readonly blendSpeed = 3.0; // 1/0.33s

    // Pooled vector
    private _target = new THREE.Vector3();

    constructor(scene: THREE.Scene, globeRadius: number) {
        this.globeRadius = globeRadius;

        const colors = [
            new THREE.Color(0.5, 0.5, 1.0),  // blue-white
            new THREE.Color(0.6, 0.4, 1.0),  // purple
            new THREE.Color(0.4, 0.6, 1.0),  // light blue
            new THREE.Color(0.7, 0.3, 0.9),  // violet
            new THREE.Color(0.5, 0.5, 1.0),  // blue-white
            new THREE.Color(0.3, 0.5, 1.0),  // deep blue
            new THREE.Color(0.6, 0.3, 1.0),  // purple
        ];

        for (let i = 0; i < FILAMENT_COUNT; i++) {
            const hasBranch = i < 2; // First 2 filaments get branches
            const filament = new PlasmaFilament(scene, colors[i], hasBranch);
            this.filaments.push(filament);

            // Spread initial idle targets evenly around the sphere
            const theta = (i / FILAMENT_COUNT) * Math.PI * 2;
            const phi = Math.PI * 0.3 + Math.random() * Math.PI * 0.4;
            this.idleTargets.push({
                theta,
                phi,
                thetaSpeed: 0.3 + Math.random() * 0.4,
                phiSpeed: 0.2 + Math.random() * 0.3,
            });
        }
    }

    setTouchTarget(point: THREE.Vector3 | null): void {
        this.touchTarget = point;
    }

    update(time: number, deltaTime: number): void {
        // Blend toward/away from touch
        const targetBlend = this.touchTarget ? 1.0 : 0.0;
        this.blendFactor += (targetBlend - this.blendFactor) * Math.min(1.0, this.blendSpeed * deltaTime);

        for (let i = 0; i < FILAMENT_COUNT; i++) {
            const idle = this.idleTargets[i];

            // Update idle wandering angles
            idle.theta += idle.thetaSpeed * deltaTime;
            idle.phi += Math.sin(time * idle.phiSpeed + i * 1.5) * 0.3 * deltaTime;
            idle.phi = Math.max(0.3, Math.min(Math.PI - 0.3, idle.phi));

            // Compute idle target position on sphere surface
            const idleX = this.globeRadius * Math.sin(idle.phi) * Math.cos(idle.theta);
            const idleY = this.globeRadius * Math.sin(idle.phi) * Math.sin(idle.theta);
            const idleZ = this.globeRadius * Math.cos(idle.phi);

            if (this.touchTarget && this.blendFactor > 0.01) {
                // Blend between idle and touch target
                // Spread filaments slightly around the touch point
                const spread = 0.15;
                const offsetTheta = (i / FILAMENT_COUNT) * Math.PI * 2;
                const touchX = this.touchTarget.x + Math.cos(offsetTheta) * spread;
                const touchY = this.touchTarget.y + Math.sin(offsetTheta) * spread;
                const touchZ = this.touchTarget.z + Math.cos(offsetTheta + 1.0) * spread * 0.5;

                this._target.set(
                    idleX + (touchX - idleX) * this.blendFactor,
                    idleY + (touchY - idleY) * this.blendFactor,
                    idleZ + (touchZ - idleZ) * this.blendFactor,
                );
                // Re-project onto sphere surface
                this._target.normalize().multiplyScalar(this.globeRadius);
            } else {
                this._target.set(idleX, idleY, idleZ);
            }

            this.filaments[i].target.copy(this._target);
            this.filaments[i].update(time, this.globeRadius);
        }
    }

    dispose(): void {
        for (const f of this.filaments) {
            f.dispose();
        }
    }
}
