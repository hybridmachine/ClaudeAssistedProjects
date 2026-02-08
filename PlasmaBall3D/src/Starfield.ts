import * as THREE from 'three';

export class Starfield {
    private stars: THREE.Points;
    private starGeometry: THREE.BufferGeometry;
    private starMaterial: THREE.PointsMaterial;
    private galaxySprites: THREE.Sprite[] = [];
    private galaxyTextures: THREE.CanvasTexture[] = [];

    constructor(scene: THREE.Scene) {
        // --- Stars ---
        const starCount = 800;
        const radius = 40;

        const positions = new Float32Array(starCount * 3);
        const colors = new Float32Array(starCount * 3);

        for (let i = 0; i < starCount; i++) {
            // Uniform distribution on sphere surface
            const theta = Math.random() * Math.PI * 2;
            const phi = Math.acos(2 * Math.random() - 1);
            const r = radius * (0.9 + Math.random() * 0.1);

            positions[i * 3] = r * Math.sin(phi) * Math.cos(theta);
            positions[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta);
            positions[i * 3 + 2] = r * Math.cos(phi);

            // Vary between white and blue-white, all below bloom threshold (0.3)
            const brightness = 0.1 + Math.random() * 0.15;
            const blueShift = Math.random() * 0.03;
            colors[i * 3] = brightness - blueShift;
            colors[i * 3 + 1] = brightness - blueShift * 0.5;
            colors[i * 3 + 2] = brightness;

        }

        this.starGeometry = new THREE.BufferGeometry();
        this.starGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        this.starGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

        this.starMaterial = new THREE.PointsMaterial({
            size: 0.08,
            sizeAttenuation: true,
            vertexColors: true,
            depthWrite: false,
        });

        this.stars = new THREE.Points(this.starGeometry, this.starMaterial);
        scene.add(this.stars);

        // --- Galaxies ---
        // Brightness baked into tint color (no opacity property needed)
        const galaxyConfigs = [
            { pos: [25, 15, -20], tint: [0.08, 0.076, 0.068], scale: [18, 9], rotation: 0.4 },
            { pos: [-20, -10, 25], tint: [0.085, 0.09, 0.1], scale: [15, 8], rotation: -0.6 },
            { pos: [10, -25, -15], tint: [0.06, 0.053, 0.055], scale: [14, 7], rotation: 1.2 },
            { pos: [-15, 20, 20], tint: [0.081, 0.083, 0.09], scale: [12, 6], rotation: -0.3 },
        ];

        for (const cfg of galaxyConfigs) {
            const texture = this.createGalaxyTexture();
            this.galaxyTextures.push(texture);

            const material = new THREE.SpriteMaterial({
                map: texture,
                color: new THREE.Color(cfg.tint[0], cfg.tint[1], cfg.tint[2]),
                transparent: true,
                blending: THREE.AdditiveBlending,
                depthWrite: false,
                rotation: cfg.rotation,
            });

            const sprite = new THREE.Sprite(material);
            sprite.position.set(cfg.pos[0], cfg.pos[1], cfg.pos[2]);
            sprite.scale.set(cfg.scale[0], cfg.scale[1], 1);
            scene.add(sprite);
            this.galaxySprites.push(sprite);
        }
    }

    private createGalaxyTexture(): THREE.CanvasTexture {
        const size = 128;
        const canvas = document.createElement('canvas');
        canvas.width = size;
        canvas.height = size;
        const ctx = canvas.getContext('2d')!;

        // Black background — additive blending makes black invisible
        ctx.fillStyle = '#000000';
        ctx.fillRect(0, 0, size, size);

        // Extend gradient to corners (size * 0.71 ≈ half-diagonal)
        const gradient = ctx.createRadialGradient(
            size / 2, size / 2, 0,
            size / 2, size / 2, size * 0.71,
        );
        gradient.addColorStop(0, '#ffffff');
        gradient.addColorStop(0.15, '#aaaaaa');
        gradient.addColorStop(0.35, '#444444');
        gradient.addColorStop(0.6, '#111111');
        gradient.addColorStop(1, '#000000');

        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, size, size);

        const texture = new THREE.CanvasTexture(canvas);
        texture.needsUpdate = true;
        return texture;
    }

    dispose(): void {
        this.starGeometry.dispose();
        this.starMaterial.dispose();

        for (const sprite of this.galaxySprites) {
            (sprite.material as THREE.SpriteMaterial).dispose();
        }
        for (const texture of this.galaxyTextures) {
            texture.dispose();
        }
    }
}
