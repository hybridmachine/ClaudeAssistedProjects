import * as THREE from 'three';

export class Starfield {
    private stars: THREE.Points;
    private starGeometry: THREE.BufferGeometry;
    private starMaterial: THREE.PointsMaterial;
    private galaxies: THREE.Mesh[] = [];

    constructor(scene: THREE.Scene) {
        // --- Stars ---
        const starCount = 5000;
        const radius = 50;

        const positions = new Float32Array(starCount * 3);
        const colors = new Float32Array(starCount * 3);

        for (let i = 0; i < starCount; i++) {
            const i3 = i * 3;

            // Uniform distribution on sphere surface
            const u = Math.random();
            const v = Math.random();
            const theta = 2 * Math.PI * u;
            const phi = Math.acos(2 * v - 1);

            positions[i3] = radius * Math.sin(phi) * Math.cos(theta);
            positions[i3 + 1] = radius * Math.sin(phi) * Math.sin(theta);
            positions[i3 + 2] = radius * Math.cos(phi);

            // Vary between white and blue-white, all below bloom threshold (0.3)
            const brightness = 0.1 + Math.random() * 0.15;
            const blueShift = Math.random() * 0.03;
            colors[i3] = brightness - blueShift;
            colors[i3 + 1] = brightness - blueShift * 0.5;
            colors[i3 + 2] = brightness;
        }

        this.starGeometry = new THREE.BufferGeometry();
        this.starGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        this.starGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

        this.starMaterial = new THREE.PointsMaterial({
            size: 2.0,
            sizeAttenuation: false,
            vertexColors: true,
            depthWrite: false,
        });

        this.stars = new THREE.Points(this.starGeometry, this.starMaterial);
        scene.add(this.stars);

        // --- Galaxies ---
        this.createGalaxies(scene);
    }

    private createGalaxies(scene: THREE.Scene): void {
        const galaxyCount = 15;
        const skyRadius = 50;

        for (let i = 0; i < galaxyCount; i++) {
            // Random position on sphere
            const u = Math.random();
            const v = Math.random();
            const theta = 2 * Math.PI * u;
            const phi = Math.acos(2 * v - 1);

            const x = skyRadius * Math.sin(phi) * Math.cos(theta);
            const y = skyRadius * Math.sin(phi) * Math.sin(theta);
            const z = skyRadius * Math.cos(phi);

            // Galaxy size: 3-7 degrees of arc
            const arcDegrees = 3 + Math.random() * 4;
            const arcRadians = arcDegrees * Math.PI / 180;
            const galaxySize = 2 * skyRadius * Math.tan(arcRadians / 2);

            // Create galaxy texture procedurally
            const canvas = document.createElement('canvas');
            const size = 512;
            canvas.width = size;
            canvas.height = size;
            const ctx = canvas.getContext('2d');
            if (!ctx) continue;

            // Black background (additive blending makes black invisible)
            ctx.fillStyle = '#000000';
            ctx.fillRect(0, 0, size, size);

            // Radial gradient for galaxy core
            const gradient = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
            gradient.addColorStop(0, 'rgba(255, 255, 220, 0.9)');
            gradient.addColorStop(0.1, 'rgba(200, 200, 255, 0.6)');
            gradient.addColorStop(0.3, 'rgba(150, 150, 200, 0.3)');
            gradient.addColorStop(0.6, 'rgba(100, 100, 150, 0.1)');
            gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');

            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, size, size);

            // Add spiral arms with noise
            const armCount = 2 + Math.floor(Math.random() * 2);
            for (let arm = 0; arm < armCount; arm++) {
                const armAngle = (arm / armCount) * Math.PI * 2;

                for (let r = 0; r < 200; r++) {
                    const armRadius = (r / 200) * (size / 2);
                    const spiralTightness = 3 + Math.random() * 2;
                    const angle = armAngle + (r / 200) * Math.PI * spiralTightness;

                    const sx = size / 2 + armRadius * Math.cos(angle);
                    const sy = size / 2 + armRadius * Math.sin(angle);

                    const brightness = Math.random() * 0.3 * (1 - r / 200);
                    const starSize = Math.random() * 3 + 1;

                    ctx.fillStyle = `rgba(200, 200, 255, ${brightness})`;
                    ctx.beginPath();
                    ctx.arc(sx, sy, starSize, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            // Copy pixel data into DataTexture to release the canvas from memory
            const imageData = ctx.getImageData(0, 0, size, size);
            const texture = new THREE.DataTexture(
                imageData.data,
                size,
                size,
                THREE.RGBAFormat,
            );
            texture.needsUpdate = true;

            // Keep galaxies dim to stay below bloom threshold
            const galaxyMaterial = new THREE.MeshBasicMaterial({
                map: texture,
                transparent: true,
                opacity: 0.15,
                side: THREE.DoubleSide,
                depthWrite: false,
                blending: THREE.AdditiveBlending,
            });

            const aspectRatio = 0.5 + Math.random() * 0.5;
            const geometry = new THREE.PlaneGeometry(galaxySize, galaxySize * aspectRatio);
            const galaxy = new THREE.Mesh(geometry, galaxyMaterial);

            galaxy.position.set(x, y, z);

            // Face center, then apply random tilt for variety
            galaxy.lookAt(0, 0, 0);
            const tiltX = (Math.random() - 0.5) * Math.PI;
            const tiltY = (Math.random() - 0.5) * Math.PI;
            galaxy.rotateX(tiltX);
            galaxy.rotateY(tiltY);

            this.galaxies.push(galaxy);
            scene.add(galaxy);
        }
    }

    dispose(): void {
        this.starGeometry.dispose();
        this.starMaterial.dispose();

        for (const galaxy of this.galaxies) {
            galaxy.geometry.dispose();
            const material = galaxy.material as THREE.MeshBasicMaterial;
            if (material.map) {
                material.map.dispose();
            }
            material.dispose();
        }
    }
}
