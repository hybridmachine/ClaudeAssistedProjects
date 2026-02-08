import * as THREE from 'three';

const SEGMENTS = 24;
const BRANCH_SEGMENTS = 10;

const FILAMENT_VERTEX_SHADER = `
    attribute float alpha;
    varying float vAlpha;
    void main() {
        vAlpha = alpha;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
`;

const FILAMENT_FRAGMENT_SHADER = `
    uniform vec3 color;
    uniform float brightness;
    varying float vAlpha;
    void main() {
        gl_FragColor = vec4(color * brightness * vAlpha, vAlpha);
    }
`;

export class PlasmaFilament {
    private line: THREE.Line;
    private material: THREE.ShaderMaterial;
    private positionArray: Float32Array;
    private alphaArray: Float32Array;
    private geometry: THREE.BufferGeometry;

    // Branch sub-filament
    private branchLine: THREE.Line | null = null;
    private branchMaterial: THREE.ShaderMaterial | null = null;
    private branchPositionArray: Float32Array | null = null;
    private branchAlphaArray: Float32Array | null = null;
    private branchGeometry: THREE.BufferGeometry | null = null;
    private branchParentIndex = 0;
    private branchDirection = new THREE.Vector3();

    // Target point on sphere surface
    target = new THREE.Vector3();

    // Pooled vectors
    private _dir = new THREE.Vector3();
    private _perp1 = new THREE.Vector3();
    private _perp2 = new THREE.Vector3();
    private _point = new THREE.Vector3();

    // Noise seed for this filament
    private seed: number;

    constructor(scene: THREE.Scene, color: THREE.Color, hasBranch: boolean = false) {
        this.seed = Math.random() * 1000;

        const vertexCount = SEGMENTS + 1;
        this.positionArray = new Float32Array(vertexCount * 3);
        this.alphaArray = new Float32Array(vertexCount);

        this.geometry = new THREE.BufferGeometry();
        this.geometry.setAttribute('position', new THREE.BufferAttribute(this.positionArray, 3));
        this.geometry.setAttribute('alpha', new THREE.BufferAttribute(this.alphaArray, 1));

        this.material = new THREE.ShaderMaterial({
            uniforms: {
                color: { value: color },
                brightness: { value: 3.0 },
            },
            vertexShader: FILAMENT_VERTEX_SHADER,
            fragmentShader: FILAMENT_FRAGMENT_SHADER,
            transparent: true,
            blending: THREE.AdditiveBlending,
            depthWrite: false,
        });

        this.line = new THREE.Line(this.geometry, this.material);
        scene.add(this.line);

        if (hasBranch) {
            this.initBranch(scene, color);
        }
    }

    private initBranch(scene: THREE.Scene, color: THREE.Color): void {
        const vertexCount = BRANCH_SEGMENTS + 1;
        this.branchPositionArray = new Float32Array(vertexCount * 3);
        this.branchAlphaArray = new Float32Array(vertexCount);

        this.branchGeometry = new THREE.BufferGeometry();
        this.branchGeometry.setAttribute('position', new THREE.BufferAttribute(this.branchPositionArray, 3));
        this.branchGeometry.setAttribute('alpha', new THREE.BufferAttribute(this.branchAlphaArray, 1));

        this.branchMaterial = new THREE.ShaderMaterial({
            uniforms: {
                color: { value: color.clone().multiplyScalar(0.7) },
                brightness: { value: 2.0 },
            },
            vertexShader: FILAMENT_VERTEX_SHADER,
            fragmentShader: FILAMENT_FRAGMENT_SHADER,
            transparent: true,
            blending: THREE.AdditiveBlending,
            depthWrite: false,
        });

        this.branchLine = new THREE.Line(this.branchGeometry, this.branchMaterial);
        scene.add(this.branchLine);

        // Branch forks off from ~40-60% along the parent
        this.branchParentIndex = Math.floor(SEGMENTS * (0.4 + Math.random() * 0.2));
        this.branchDirection.set(
            Math.random() - 0.5,
            Math.random() - 0.5,
            Math.random() - 0.5,
        ).normalize();
    }

    /** Sine-based layered noise (cheaper than Perlin, works well for plasma) */
    private noise(x: number, y: number, z: number): number {
        return Math.sin(x * 1.7 + y * 2.3) * 0.5
            + Math.sin(y * 3.1 + z * 1.3) * 0.3
            + Math.sin(z * 2.7 + x * 1.9) * 0.2;
    }

    update(time: number, globeRadius: number): void {
        const origin = new THREE.Vector3(0, 0, 0);
        this._dir.copy(this.target).sub(origin).normalize();

        // Build perpendicular basis for displacement
        if (Math.abs(this._dir.y) < 0.99) {
            this._perp1.set(0, 1, 0);
        } else {
            this._perp1.set(1, 0, 0);
        }
        this._perp1.cross(this._dir).normalize();
        this._perp2.crossVectors(this._dir, this._perp1).normalize();

        for (let i = 0; i <= SEGMENTS; i++) {
            const t = i / SEGMENTS;
            // Interpolate from origin to surface
            this._point.lerpVectors(origin, this.target, t);

            // Displacement: maximal at midpoint, zero at endpoints
            const envelope = Math.sin(t * Math.PI);
            const noiseScale = 0.35;
            const nx = this.noise(
                this.seed + t * 5.0 + time * 1.5,
                time * 0.8 + this.seed,
                t * 3.0
            );
            const ny = this.noise(
                this.seed + t * 5.0 + 100,
                time * 1.2 + this.seed + 50,
                t * 3.0 + 200
            );

            this._point.addScaledVector(this._perp1, nx * envelope * noiseScale);
            this._point.addScaledVector(this._perp2, ny * envelope * noiseScale);

            const idx = i * 3;
            this.positionArray[idx] = this._point.x;
            this.positionArray[idx + 1] = this._point.y;
            this.positionArray[idx + 2] = this._point.z;

            // Alpha: bright at center, fading at both ends
            this.alphaArray[i] = 0.3 + 0.7 * envelope;
        }

        (this.geometry.attributes.position as THREE.BufferAttribute).needsUpdate = true;
        (this.geometry.attributes.alpha as THREE.BufferAttribute).needsUpdate = true;

        // Update branch
        if (this.branchLine && this.branchPositionArray && this.branchAlphaArray) {
            this.updateBranch(time, globeRadius);
        }
    }

    private updateBranch(time: number, globeRadius: number): void {
        if (!this.branchPositionArray || !this.branchAlphaArray || !this.branchGeometry) return;

        // Get fork point from parent
        const forkIdx = this.branchParentIndex * 3;
        const forkX = this.positionArray[forkIdx];
        const forkY = this.positionArray[forkIdx + 1];
        const forkZ = this.positionArray[forkIdx + 2];

        // Branch end point: fork point + direction scaled to reach ~70% to the surface
        const branchLength = globeRadius * 0.4;
        const endX = forkX + this.branchDirection.x * branchLength;
        const endY = forkY + this.branchDirection.y * branchLength;
        const endZ = forkZ + this.branchDirection.z * branchLength;

        for (let i = 0; i <= BRANCH_SEGMENTS; i++) {
            const t = i / BRANCH_SEGMENTS;
            const idx = i * 3;

            this.branchPositionArray[idx] = forkX + (endX - forkX) * t;
            this.branchPositionArray[idx + 1] = forkY + (endY - forkY) * t;
            this.branchPositionArray[idx + 2] = forkZ + (endZ - forkZ) * t;

            // Add small noise
            const envelope = Math.sin(t * Math.PI) * 0.15;
            const n = this.noise(this.seed + 500 + t * 4.0 + time * 2.0, time * 1.5, t * 2.0);
            this.branchPositionArray[idx] += n * envelope;
            this.branchPositionArray[idx + 1] += n * envelope * 0.7;

            // Fade out along the branch
            this.branchAlphaArray[i] = (1.0 - t) * 0.6;
        }

        (this.branchGeometry.attributes.position as THREE.BufferAttribute).needsUpdate = true;
        (this.branchGeometry.attributes.alpha as THREE.BufferAttribute).needsUpdate = true;
    }

    dispose(): void {
        this.geometry.dispose();
        this.material.dispose();
        if (this.branchGeometry) this.branchGeometry.dispose();
        if (this.branchMaterial) this.branchMaterial.dispose();
    }
}
