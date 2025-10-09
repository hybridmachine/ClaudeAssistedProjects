import * as THREE from 'three';
import { Generation } from './GameEngine.js';

export interface RenderSettings {
    cellPadding: number;
    cellColor: string;
    gradientStartColor?: string;
    gradientEndColor?: string;
    edgeColor?: string;
    edgeWidth?: number;
    showGridLines: boolean;
    showGenerationLabels: boolean;
}

export class Renderer3D {
    private scene: THREE.Scene;
    private camera!: THREE.PerspectiveCamera;
    private renderer!: THREE.WebGLRenderer;
    private instancedMesh: THREE.InstancedMesh | null = null;
    private wireframeMesh: THREE.InstancedMesh | null = null;
    private gridLines: THREE.LineSegments | null = null;
    private starField: THREE.Points | null = null;
    private generationLabels: THREE.Sprite[] = [];
    private starTwinkleIndices: number[] = [];
    private starBaseBrightness: Float32Array | null = null;
    private galaxies: THREE.Mesh[] = [];
    private explosionParticles: THREE.Points | null = null;

    private gridSize: number = 50;
    private cellPadding: number = 0.2;
    private cellColor: string = '#00ff88';
    private gradientStartColor: string = '#0000ff';
    private gradientEndColor: string = '#ffff00';
    private edgeColor: string = '#ffffff';
    private edgeWidth: number = 0.05;
    private showGridLines: boolean = true;
    private showGenerationLabels: boolean = true;

    private maxInstances: number = 200 * 200 * 100;
    private currentInstanceCount: number = 0;
    private animationStartTime: number = Date.now();

    private canvas: HTMLCanvasElement;

    constructor(canvas: HTMLCanvasElement) {
        this.canvas = canvas;
        this.scene = new THREE.Scene();
        this.setupCamera();
        this.setupRenderer();
        this.setupLighting();
        this.createStarField();
        this.createGalaxies();

        this.handleResize();
        window.addEventListener('resize', () => this.handleResize());
    }

    private setupCamera(): void {
        const aspect = window.innerWidth / window.innerHeight;
        this.camera = new THREE.PerspectiveCamera(60, aspect, 0.1, 10000);
        this.camera.position.set(30, 30, 30);
        this.camera.lookAt(0, 25, 0);
    }

    private setupRenderer(): void {
        this.renderer = new THREE.WebGLRenderer({
            canvas: this.canvas,
            antialias: true,
            alpha: true
        });
        this.renderer.setSize(window.innerWidth, window.innerHeight);
        this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        this.renderer.setClearColor(0x000000, 1);
        this.renderer.shadowMap.enabled = true;
        this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    }

    private setupLighting(): void {
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.8);
        this.scene.add(ambientLight);

        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.2);
        directionalLight.position.set(10, 10, 5);
        directionalLight.castShadow = true;
        directionalLight.shadow.mapSize.width = 2048;
        directionalLight.shadow.mapSize.height = 2048;
        this.scene.add(directionalLight);
    }

    private createStarField(): void {
        const starCount = 5000;
        const positions = new Float32Array(starCount * 3);
        const brightness = new Float32Array(starCount);
        this.starBaseBrightness = new Float32Array(starCount);

        // Select 2% of stars to twinkle
        const twinkleCount = Math.floor(starCount * 0.02);
        const twinkleSet = new Set<number>();
        while (twinkleSet.size < twinkleCount) {
            twinkleSet.add(Math.floor(Math.random() * starCount));
        }
        this.starTwinkleIndices = Array.from(twinkleSet);

        for (let i = 0; i < starCount; i++) {
            const i3 = i * 3;
            const radius = 5000;

            const u = Math.random();
            const v = Math.random();
            const theta = 2 * Math.PI * u;
            const phi = Math.acos(2 * v - 1);

            positions[i3] = radius * Math.sin(phi) * Math.cos(theta);
            positions[i3 + 1] = radius * Math.sin(phi) * Math.sin(theta);
            positions[i3 + 2] = radius * Math.cos(phi);

            // Vary base brightness between 0.3 and 1.0
            const baseBrightness = 0.3 + Math.random() * 0.7;
            this.starBaseBrightness[i] = baseBrightness;
            brightness[i] = baseBrightness;
        }

        const starGeometry = new THREE.BufferGeometry();
        starGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        starGeometry.setAttribute('brightness', new THREE.BufferAttribute(brightness, 1));

        const starMaterial = new THREE.ShaderMaterial({
            uniforms: {
                pointSize: { value: 2.0 }
            },
            vertexShader: `
                attribute float brightness;
                uniform float pointSize;
                varying float vBrightness;
                void main() {
                    vBrightness = brightness;
                    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
                    gl_PointSize = pointSize;
                    gl_Position = projectionMatrix * mvPosition;
                }
            `,
            fragmentShader: `
                varying float vBrightness;
                void main() {
                    gl_FragColor = vec4(vBrightness, vBrightness, vBrightness, 1.0);
                }
            `
        });

        this.starField = new THREE.Points(starGeometry, starMaterial);
        this.scene.add(this.starField);
    }

    private createGalaxies(): void {
        const galaxyCount = 15;
        const skyRadius = 5000;

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

            // Create galaxy texture
            const canvas = document.createElement('canvas');
            const size = 512;
            canvas.width = size;
            canvas.height = size;
            const ctx = canvas.getContext('2d');
            if (!ctx) continue;

            // Create radial gradient for galaxy core
            const gradient = ctx.createRadialGradient(size/2, size/2, 0, size/2, size/2, size/2);
            gradient.addColorStop(0, 'rgba(255, 255, 220, 0.9)');
            gradient.addColorStop(0.1, 'rgba(200, 200, 255, 0.6)');
            gradient.addColorStop(0.3, 'rgba(150, 150, 200, 0.3)');
            gradient.addColorStop(0.6, 'rgba(100, 100, 150, 0.1)');
            gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');

            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, size, size);

            // Add spiral arms with noise
            const armCount = 2 + Math.floor(Math.random() * 2); // 2-3 spiral arms
            for (let arm = 0; arm < armCount; arm++) {
                const armAngle = (arm / armCount) * Math.PI * 2;

                for (let r = 0; r < 200; r++) {
                    const radius = (r / 200) * (size / 2);
                    const spiralTightness = 3 + Math.random() * 2;
                    const angle = armAngle + (r / 200) * Math.PI * spiralTightness;

                    const sx = size/2 + radius * Math.cos(angle);
                    const sy = size/2 + radius * Math.sin(angle);

                    const brightness = Math.random() * 0.3 * (1 - r / 200);
                    const starSize = Math.random() * 3 + 1;

                    ctx.fillStyle = `rgba(200, 200, 255, ${brightness})`;
                    ctx.beginPath();
                    ctx.arc(sx, sy, starSize, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            const texture = new THREE.CanvasTexture(canvas);

            const galaxyMaterial = new THREE.MeshBasicMaterial({
                map: texture,
                transparent: true,
                opacity: 0.8,
                side: THREE.DoubleSide,
                depthWrite: false
            });

            const aspectRatio = 0.5 + Math.random() * 0.5; // Random aspect for different orientations
            const geometry = new THREE.PlaneGeometry(galaxySize, galaxySize * aspectRatio);
            const galaxy = new THREE.Mesh(geometry, galaxyMaterial);

            galaxy.position.set(x, y, z);

            // Random orientation
            galaxy.rotation.x = Math.random() * Math.PI * 2;
            galaxy.rotation.y = Math.random() * Math.PI * 2;
            galaxy.rotation.z = Math.random() * Math.PI * 2;

            // Make galaxy face the camera initially, then apply random rotation
            galaxy.lookAt(0, 0, 0);
            const tiltX = (Math.random() - 0.5) * Math.PI; // -90 to +90 degrees
            const tiltY = (Math.random() - 0.5) * Math.PI;
            galaxy.rotateX(tiltX);
            galaxy.rotateY(tiltY);

            this.galaxies.push(galaxy);
            this.scene.add(galaxy);
        }
    }

    setGridSize(size: number): void {
        this.gridSize = size;
        this.recreateInstancedMesh();
        this.updateGridLines();
    }

    setRenderSettings(settings: Partial<RenderSettings>): void {
        if (settings.cellPadding !== undefined) {
            this.cellPadding = settings.cellPadding / 100;
        }
        if (settings.cellColor !== undefined) {
            this.cellColor = settings.cellColor;
            this.updateCellColor();
        }
        if (settings.gradientStartColor !== undefined) {
            this.gradientStartColor = settings.gradientStartColor;
            this.updateCellColor();
        }
        if (settings.gradientEndColor !== undefined) {
            this.gradientEndColor = settings.gradientEndColor;
            this.updateCellColor();
        }
        if (settings.edgeColor !== undefined) {
            this.edgeColor = settings.edgeColor;
            this.updateCellColor();
        }
        if (settings.edgeWidth !== undefined) {
            this.edgeWidth = settings.edgeWidth;
            this.updateCellColor();
        }
        if (settings.showGridLines !== undefined) {
            this.showGridLines = settings.showGridLines;
            this.updateGridLines();
        }
        if (settings.showGenerationLabels !== undefined) {
            this.showGenerationLabels = settings.showGenerationLabels;
            this.updateGenerationLabels();
        }
    }

    private recreateInstancedMesh(): void {
        if (this.instancedMesh) {
            this.scene.remove(this.instancedMesh);
            this.instancedMesh.dispose();
        }
        if (this.wireframeMesh) {
            this.scene.remove(this.wireframeMesh);
            this.wireframeMesh.dispose();
        }

        const cellSize = 1 - this.cellPadding;
        const geometry = new THREE.BoxGeometry(cellSize, cellSize, cellSize);

        // Create solid mesh with gradient material
        const material = new THREE.ShaderMaterial({
            uniforms: {
                startColor: { value: new THREE.Color(this.gradientStartColor) },
                endColor: { value: new THREE.Color(this.gradientEndColor) },
                minZ: { value: 0.0 },
                maxZ: { value: 50.0 },
                time: { value: 0.0 }
            },
            vertexShader: `
                varying vec3 vWorldPosition;
                void main() {
                    vec4 worldPosition = modelMatrix * instanceMatrix * vec4(position, 1.0);
                    vWorldPosition = worldPosition.xyz;
                    gl_Position = projectionMatrix * viewMatrix * worldPosition;
                }
            `,
            fragmentShader: `
                uniform vec3 startColor;
                uniform vec3 endColor;
                uniform float minZ;
                uniform float maxZ;
                uniform float time;
                varying vec3 vWorldPosition;

                #define PI 3.14159265359

                void main() {
                    float range = maxZ - minZ;
                    float offset = mod(time, range);
                    float adjustedY = mod(vWorldPosition.y - minZ - offset, range);

                    // Normalize position to 0-1 range
                    float t = adjustedY / range;

                    // Define colors: blue, green, yellow, black, purple
                    vec3 blue = vec3(0.0, 0.0, 1.0);
                    vec3 green = vec3(0.0, 1.0, 0.0);
                    vec3 yellow = vec3(1.0, 1.0, 0.0);
                    vec3 black = vec3(0.0, 0.0, 0.0);
                    vec3 purple = vec3(0.5, 0.0, 0.5);

                    // Cycle through 5 colors (0-0.2: blue->green, 0.2-0.4: green->yellow, 0.4-0.6: yellow->black, 0.6-0.8: black->purple, 0.8-1: purple->blue)
                    vec3 color;
                    float segment = t * 5.0;

                    if (segment < 1.0) {
                        color = mix(blue, green, segment);
                    } else if (segment < 2.0) {
                        color = mix(green, yellow, segment - 1.0);
                    } else if (segment < 3.0) {
                        color = mix(yellow, black, segment - 2.0);
                    } else if (segment < 4.0) {
                        color = mix(black, purple, segment - 3.0);
                    } else {
                        color = mix(purple, blue, segment - 4.0);
                    }

                    gl_FragColor = vec4(color, 1.0);
                }
            `
        });

        // Create wireframe mesh
        const wireframeMaterial = new THREE.MeshBasicMaterial({
            color: new THREE.Color(this.edgeColor),
            wireframe: true,
            transparent: true,
            opacity: 0.8
        });

        this.instancedMesh = new THREE.InstancedMesh(geometry, material, this.maxInstances);
        this.instancedMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
        this.instancedMesh.castShadow = true;
        this.instancedMesh.receiveShadow = true;
        this.scene.add(this.instancedMesh);

        this.wireframeMesh = new THREE.InstancedMesh(geometry, wireframeMaterial, this.maxInstances);
        this.wireframeMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
        this.scene.add(this.wireframeMesh);
    }

    private updateCellColor(): void {
        if (this.instancedMesh && this.instancedMesh.material instanceof THREE.ShaderMaterial) {
            this.instancedMesh.material.uniforms.startColor.value.set(this.gradientStartColor);
            this.instancedMesh.material.uniforms.endColor.value.set(this.gradientEndColor);
        }
        if (this.wireframeMesh && this.wireframeMesh.material instanceof THREE.MeshBasicMaterial) {
            this.wireframeMesh.material.color.set(this.edgeColor);
        }
    }

    private updateGridLines(): void {
        if (this.gridLines) {
            this.scene.remove(this.gridLines);
            this.gridLines.geometry.dispose();
            if (this.gridLines.material instanceof THREE.Material) {
                this.gridLines.material.dispose();
            }
            this.gridLines = null;
        }

        if (!this.showGridLines) return;

        const points: THREE.Vector3[] = [];
        const halfSize = this.gridSize / 2;

        for (let i = 0; i <= this.gridSize; i++) {
            const pos = i - halfSize;
            points.push(new THREE.Vector3(pos, 0, -halfSize));
            points.push(new THREE.Vector3(pos, 0, halfSize));
            points.push(new THREE.Vector3(-halfSize, 0, pos));
            points.push(new THREE.Vector3(halfSize, 0, pos));
        }

        const geometry = new THREE.BufferGeometry().setFromPoints(points);
        const material = new THREE.LineBasicMaterial({
            color: 0x888888,
            transparent: true,
            opacity: 0.8
        });

        this.gridLines = new THREE.LineSegments(geometry, material);
        this.scene.add(this.gridLines);
    }

    private updateGenerationLabels(): void {
        this.generationLabels.forEach(label => {
            this.scene.remove(label);
            label.material.dispose();
        });
        this.generationLabels = [];
    }

    renderGenerations(generations: Generation[], displayStart: number, displayEnd: number): void {
        if (!this.instancedMesh) {
            this.recreateInstancedMesh();
        }

        // Update gradient Y range based on actual display range (generations are now on Y axis)
        if (this.instancedMesh && this.instancedMesh.material instanceof THREE.ShaderMaterial) {
            this.instancedMesh.material.uniforms.minZ.value = displayStart;
            this.instancedMesh.material.uniforms.maxZ.value = displayEnd;
        }

        const matrix = new THREE.Matrix4();
        let instanceIndex = 0;

        const halfSize = this.gridSize / 2;

        for (let genIndex = displayStart; genIndex <= displayEnd && genIndex < generations.length; genIndex++) {
            const generation = generations[genIndex];
            if (!generation) continue;

            for (const cell of generation.liveCells) {
                if (instanceIndex >= this.maxInstances) break;

                const x = cell.x - halfSize;
                const y = genIndex;
                const z = cell.y - halfSize;

                matrix.setPosition(x, y, z);
                this.instancedMesh!.setMatrixAt(instanceIndex, matrix);
                this.wireframeMesh!.setMatrixAt(instanceIndex, matrix);
                instanceIndex++;
            }
        }

        this.currentInstanceCount = instanceIndex;
        this.instancedMesh!.count = this.currentInstanceCount;
        this.instancedMesh!.instanceMatrix.needsUpdate = true;

        this.wireframeMesh!.count = this.currentInstanceCount;
        this.wireframeMesh!.instanceMatrix.needsUpdate = true;

        if (this.showGenerationLabels) {
            this.createGenerationLabels(displayStart, displayEnd);
        }
    }

    private createGenerationLabels(start: number, end: number): void {
        this.updateGenerationLabels();

        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        if (!context) return;

        canvas.width = 128;
        canvas.height = 32;

        for (let i = start; i <= end; i += Math.max(1, Math.floor((end - start) / 10))) {
            context.clearRect(0, 0, canvas.width, canvas.height);
            context.fillStyle = '#ffffff';
            context.font = '16px Arial';
            context.textAlign = 'center';
            context.fillText(`Gen ${i}`, canvas.width / 2, canvas.height / 2 + 6);

            const texture = new THREE.CanvasTexture(canvas);
            const material = new THREE.SpriteMaterial({ map: texture });
            const sprite = new THREE.Sprite(material);

            sprite.position.set(this.gridSize / 2 + 5, i, 0);
            sprite.scale.set(8, 2, 1);

            this.scene.add(sprite);
            this.generationLabels.push(sprite);
        }
    }

    public startExplosion(generations: Generation[], gridSize: number): void {
        if (this.explosionParticles) {
            this.scene.remove(this.explosionParticles);
            this.explosionParticles.geometry.dispose();
            (this.explosionParticles.material as THREE.Material).dispose();
            this.explosionParticles = null;
        }

        const particles: THREE.Vector3[] = [];
        const velocities: THREE.Vector3[] = [];
        const colors: THREE.Color[] = [];
        const startTimes: number[] = [];

        const halfSize = gridSize / 2;

        for (const generation of generations) {
            for (const cell of generation.liveCells) {
                const x = cell.x - halfSize;
                const y = generation.index;
                const z = cell.y - halfSize;

                for (let i = 0; i < 10; i++) {
                    particles.push(new THREE.Vector3(x, y, z));
                    velocities.push(new THREE.Vector3(
                        (Math.random() - 0.5) * 20,
                        (Math.random() - 0.5) * 20,
                        (Math.random() - 0.5) * 20
                    ));
                    colors.push(new THREE.Color(this.cellColor));
                    startTimes.push(Date.now());
                }
            }
        }

        const geometry = new THREE.BufferGeometry().setFromPoints(particles);
        geometry.setAttribute('velocity', new THREE.Float32BufferAttribute(velocities.flatMap(v => v.toArray()), 3));
        geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors.flatMap(c => c.toArray()), 3));
        geometry.setAttribute('startTime', new THREE.Float32BufferAttribute(startTimes, 1));

        const material = new THREE.PointsMaterial({
            size: 0.1,
            vertexColors: true,
            transparent: true,
            opacity: 1.0
        });

        this.explosionParticles = new THREE.Points(geometry, material);
        this.scene.add(this.explosionParticles);

        setTimeout(() => {
            if (this.explosionParticles) {
                this.scene.remove(this.explosionParticles);
                this.explosionParticles.geometry.dispose();
                (this.explosionParticles.material as THREE.Material).dispose();
                this.explosionParticles = null;
            }
        }, 3000);
    }

    getCamera(): THREE.PerspectiveCamera {
        return this.camera;
    }

    getRenderer(): THREE.WebGLRenderer {
        return this.renderer;
    }

    render(): void {
        // Update animation time (5 second cycle)
        const elapsed = (Date.now() - this.animationStartTime) / 1000; // seconds
        const cycleTime = 5.0; // 5 seconds per cycle
        const normalizedTime = (elapsed % cycleTime) / cycleTime; // 0 to 1

        if (this.instancedMesh && this.instancedMesh.material instanceof THREE.ShaderMaterial) {
            const range = this.instancedMesh.material.uniforms.maxZ.value -
                         this.instancedMesh.material.uniforms.minZ.value;
            this.instancedMesh.material.uniforms.time.value = normalizedTime * range;
        }

        // Update star twinkle animation
        if (this.starField && this.starBaseBrightness) {
            const geometry = this.starField.geometry;
            const brightnessAttribute = geometry.getAttribute('brightness') as THREE.BufferAttribute;

            if (brightnessAttribute) {
                const twinkleCycle = 3.0; // 3 second twinkle cycle
                const twinklePhase = (elapsed % twinkleCycle) / twinkleCycle; // 0 to 1

                // Update brightness for twinkling stars
                for (const starIndex of this.starTwinkleIndices) {
                    const baseBrightness = this.starBaseBrightness[starIndex];
                    // Slow sine wave twinkle between 70% and 100% of base brightness
                    const twinkle = 0.7 + 0.3 * Math.sin(twinklePhase * Math.PI * 2);
                    brightnessAttribute.setX(starIndex, baseBrightness * twinkle);
                }

                brightnessAttribute.needsUpdate = true;
            }
        }

        if (this.explosionParticles) {
            const positions = this.explosionParticles.geometry.attributes.position as THREE.BufferAttribute;
            const velocities = this.explosionParticles.geometry.attributes.velocity as THREE.BufferAttribute;
            const startTimes = this.explosionParticles.geometry.attributes.startTime as THREE.BufferAttribute;
            const material = this.explosionParticles.material as THREE.PointsMaterial;

            const now = Date.now();
            for (let i = 0; i < positions.count; i++) {
                const elapsedTime = (now - startTimes.getX(i)) / 1000;
                if (elapsedTime > 3) {
                    continue;
                }

                const x = positions.getX(i) + velocities.getX(i) * 0.01;
                const y = positions.getY(i) + velocities.getY(i) * 0.01;
                const z = positions.getZ(i) + velocities.getZ(i) * 0.01;

                positions.setXYZ(i, x, y, z);

                material.opacity = 1.0 - (elapsedTime / 3.0);
            }
            positions.needsUpdate = true;
        }

        this.renderer.render(this.scene, this.camera);
    }

    private handleResize(): void {
        const width = this.canvas.clientWidth;
        const height = this.canvas.clientHeight;

        this.camera.aspect = width / height;
        this.camera.updateProjectionMatrix();

        this.renderer.setSize(width, height, false);
    }

    dispose(): void {
        this.instancedMesh?.dispose();
        this.wireframeMesh?.dispose();
        this.gridLines?.geometry.dispose();
        if (this.gridLines?.material instanceof THREE.Material) {
            this.gridLines.material.dispose();
        }
        this.starField?.geometry.dispose();
        if (this.starField?.material instanceof THREE.Material) {
            this.starField.material.dispose();
        }
        this.galaxies.forEach(galaxy => {
            galaxy.geometry.dispose();
            if (galaxy.material instanceof THREE.MeshBasicMaterial) {
                if (galaxy.material.map) {
                    galaxy.material.map.dispose();
                }
                galaxy.material.dispose();
            }
        });
        this.generationLabels.forEach(label => {
            label.material.dispose();
        });
        this.renderer.dispose();
    }
}