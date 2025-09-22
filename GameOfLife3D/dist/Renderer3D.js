import * as THREE from 'three';
export class Renderer3D {
    constructor(canvas) {
        this.instancedMesh = null;
        this.wireframeMesh = null;
        this.gridLines = null;
        this.starField = null;
        this.generationLabels = [];
        this.gridSize = 50;
        this.cellPadding = 0.2;
        this.cellColor = '#00ff88';
        this.gradientStartColor = '#ff0080';
        this.gradientEndColor = '#00ff88';
        this.edgeColor = '#ffffff';
        this.edgeWidth = 0.05;
        this.showGridLines = true;
        this.showGenerationLabels = true;
        this.maxInstances = 200 * 200 * 100;
        this.currentInstanceCount = 0;
        this.canvas = canvas;
        this.scene = new THREE.Scene();
        this.setupCamera();
        this.setupRenderer();
        this.setupLighting();
        this.createStarField();
        this.handleResize();
        window.addEventListener('resize', () => this.handleResize());
    }
    setupCamera() {
        const aspect = window.innerWidth / window.innerHeight;
        this.camera = new THREE.PerspectiveCamera(60, aspect, 0.1, 10000);
        this.camera.position.set(30, 30, 30);
        this.camera.lookAt(0, 0, 0);
    }
    setupRenderer() {
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
    setupLighting() {
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.8);
        this.scene.add(ambientLight);
        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.2);
        directionalLight.position.set(10, 10, 5);
        directionalLight.castShadow = true;
        directionalLight.shadow.mapSize.width = 2048;
        directionalLight.shadow.mapSize.height = 2048;
        this.scene.add(directionalLight);
    }
    createStarField() {
        const starCount = 5000;
        const positions = new Float32Array(starCount * 3);
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
        }
        const starGeometry = new THREE.BufferGeometry();
        starGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        const starMaterial = new THREE.PointsMaterial({
            color: 0xffffff,
            size: 2,
            sizeAttenuation: false
        });
        this.starField = new THREE.Points(starGeometry, starMaterial);
        this.scene.add(this.starField);
    }
    setGridSize(size) {
        this.gridSize = size;
        this.recreateInstancedMesh();
        this.updateGridLines();
    }
    setRenderSettings(settings) {
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
    recreateInstancedMesh() {
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
                maxZ: { value: 50.0 }
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
                varying vec3 vWorldPosition;

                void main() {
                    float t = clamp((vWorldPosition.z - minZ) / (maxZ - minZ), 0.0, 1.0);
                    vec3 color = mix(startColor, endColor, t);
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
    updateCellColor() {
        if (this.instancedMesh && this.instancedMesh.material instanceof THREE.ShaderMaterial) {
            this.instancedMesh.material.uniforms.startColor.value.set(this.gradientStartColor);
            this.instancedMesh.material.uniforms.endColor.value.set(this.gradientEndColor);
        }
        if (this.wireframeMesh && this.wireframeMesh.material instanceof THREE.MeshBasicMaterial) {
            this.wireframeMesh.material.color.set(this.edgeColor);
        }
    }
    updateGridLines() {
        if (this.gridLines) {
            this.scene.remove(this.gridLines);
            this.gridLines.geometry.dispose();
            if (this.gridLines.material instanceof THREE.Material) {
                this.gridLines.material.dispose();
            }
            this.gridLines = null;
        }
        if (!this.showGridLines)
            return;
        const points = [];
        const halfSize = this.gridSize / 2;
        for (let i = 0; i <= this.gridSize; i++) {
            const pos = i - halfSize;
            points.push(new THREE.Vector3(pos, -halfSize, 0));
            points.push(new THREE.Vector3(pos, halfSize, 0));
            points.push(new THREE.Vector3(-halfSize, pos, 0));
            points.push(new THREE.Vector3(halfSize, pos, 0));
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
    updateGenerationLabels() {
        this.generationLabels.forEach(label => {
            this.scene.remove(label);
            label.material.dispose();
        });
        this.generationLabels = [];
    }
    renderGenerations(generations, displayStart, displayEnd) {
        if (!this.instancedMesh) {
            this.recreateInstancedMesh();
        }
        // Update gradient Z range based on actual display range
        if (this.instancedMesh && this.instancedMesh.material instanceof THREE.ShaderMaterial) {
            this.instancedMesh.material.uniforms.minZ.value = displayStart;
            this.instancedMesh.material.uniforms.maxZ.value = displayEnd;
        }
        const matrix = new THREE.Matrix4();
        let instanceIndex = 0;
        const halfSize = this.gridSize / 2;
        for (let genIndex = displayStart; genIndex <= displayEnd && genIndex < generations.length; genIndex++) {
            const generation = generations[genIndex];
            if (!generation)
                continue;
            for (const cell of generation.liveCells) {
                if (instanceIndex >= this.maxInstances)
                    break;
                const x = cell.x - halfSize;
                const y = cell.y - halfSize;
                const z = genIndex;
                matrix.setPosition(x, y, z);
                this.instancedMesh.setMatrixAt(instanceIndex, matrix);
                this.wireframeMesh.setMatrixAt(instanceIndex, matrix);
                instanceIndex++;
            }
        }
        this.currentInstanceCount = instanceIndex;
        this.instancedMesh.count = this.currentInstanceCount;
        this.instancedMesh.instanceMatrix.needsUpdate = true;
        this.wireframeMesh.count = this.currentInstanceCount;
        this.wireframeMesh.instanceMatrix.needsUpdate = true;
        if (this.showGenerationLabels) {
            this.createGenerationLabels(displayStart, displayEnd);
        }
    }
    createGenerationLabels(start, end) {
        this.updateGenerationLabels();
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        if (!context)
            return;
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
            sprite.position.set(this.gridSize / 2 + 5, 0, i);
            sprite.scale.set(8, 2, 1);
            this.scene.add(sprite);
            this.generationLabels.push(sprite);
        }
    }
    getCamera() {
        return this.camera;
    }
    getRenderer() {
        return this.renderer;
    }
    render() {
        this.renderer.render(this.scene, this.camera);
    }
    handleResize() {
        const width = this.canvas.clientWidth;
        const height = this.canvas.clientHeight;
        this.camera.aspect = width / height;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(width, height, false);
    }
    dispose() {
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
        this.generationLabels.forEach(label => {
            label.material.dispose();
        });
        this.renderer.dispose();
    }
}
//# sourceMappingURL=Renderer3D.js.map