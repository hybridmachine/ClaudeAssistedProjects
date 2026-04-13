import * as THREE from 'https://unpkg.com/three@0.160.0/build/three.module.js';
import { OrbitControls } from 'https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js';

let scene, camera, renderer, controls;
let instancedMesh;
let gridHelper;
let dummy = new THREE.Object3D();
let maxInstances = 1000000;
let gridSize = 50;

export function init(containerId, initialGridSize) {
    gridSize = initialGridSize;
    const container = document.getElementById(containerId);
    if (!container) return;

    // Clean up if re-initializing
    if (renderer) {
        container.removeChild(renderer.domElement);
    }

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x050505);

    camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 2000);
    camera.position.set(gridSize, gridSize, gridSize * 1.5);

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.appendChild(renderer.domElement);

    controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;

    const ambientLight = new THREE.AmbientLight(0x404040);
    scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(1, 1, 1).normalize();
    scene.add(directionalLight);

    initInstancedMesh();
    updateGrid(gridSize);

    window.addEventListener('resize', () => {
        camera.aspect = container.clientWidth / container.clientHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(container.clientWidth, container.clientHeight);
    });

    animate();
}

function initInstancedMesh() {
    const geometry = new THREE.BoxGeometry(0.9, 0.9, 0.9);
    const material = new THREE.MeshPhongMaterial({
        color: 0xffffff,
        vertexColors: true
    });

    instancedMesh = new THREE.InstancedMesh(geometry, material, maxInstances);
    instancedMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    instancedMesh.count = 0;
    scene.add(instancedMesh);
}

function updateGrid(size) {
    if (gridHelper) scene.remove(gridHelper);
    gridHelper = new THREE.GridHelper(size, size, 0x444444, 0x222222);
    gridHelper.position.y = 0.5; // Slightly below the first layer
    scene.add(gridHelper);
}

export function updateInstances(instances) {
    const count = instances.length / 4;
    const color = new THREE.Color();

    for (let i = 0; i < count; i++) {
        const x = instances[i * 4];
        const y = instances[i * 4 + 1];
        const z = instances[i * 4 + 2];
        const t = instances[i * 4 + 3];

        dummy.position.set(x, y, z);
        dummy.updateMatrix();
        instancedMesh.setMatrixAt(i, dummy.matrix);

        // Color based on t (generation index relative to history)
        // From deep blue/purple (older) to cyan/white (newer)
        color.setHSL(0.5 + t * 0.2, 0.8, 0.2 + t * 0.6);
        instancedMesh.setColorAt(i, color);
    }

    instancedMesh.count = count;
    instancedMesh.instanceMatrix.needsUpdate = true;
    if (instancedMesh.instanceColor) instancedMesh.instanceColor.needsUpdate = true;
}

function animate() {
    requestAnimationFrame(animate);
    controls.update();
    renderer.render(scene, camera);
}
