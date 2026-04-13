import * as THREE from 'https://unpkg.com/three@0.160.0/build/three.module.js';
import { OrbitControls } from 'https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js';

let scene, camera, renderer, controls;
let instancedMesh;
let gridHelper;
const dummy = new THREE.Object3D();
const maxInstances = 1000000;
let gridSize = 50;
let containerElement;
let resizeHandler;
let animationFrameId;

export function init(containerId, initialGridSize) {
    dispose();

    gridSize = initialGridSize;
    containerElement = document.getElementById(containerId);
    if (!containerElement) return;

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x050505);

    camera = new THREE.PerspectiveCamera(75, containerElement.clientWidth / containerElement.clientHeight, 0.1, 2000);
    camera.position.set(gridSize, gridSize, gridSize * 1.5);

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(containerElement.clientWidth, containerElement.clientHeight);
    containerElement.appendChild(renderer.domElement);

    controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;

    const ambientLight = new THREE.AmbientLight(0x404040);
    scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(1, 1, 1).normalize();
    scene.add(directionalLight);

    initInstancedMesh();
    updateGrid(gridSize);

    resizeHandler = () => {
        if (!camera || !renderer || !containerElement) return;
        camera.aspect = containerElement.clientWidth / containerElement.clientHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(containerElement.clientWidth, containerElement.clientHeight);
    };
    window.addEventListener('resize', resizeHandler);

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
    if (!scene) return;

    if (gridHelper) {
        scene.remove(gridHelper);
        gridHelper.geometry.dispose();
        disposeMaterial(gridHelper.material);
    }

    gridHelper = new THREE.GridHelper(size, size, 0x444444, 0x222222);
    gridHelper.position.y = 0.5; // Slightly below the first layer
    scene.add(gridHelper);
}

export function setGridSize(size) {
    gridSize = size;
    updateGrid(size);

    if (!camera) return;

    camera.position.set(size, size, size * 1.5);
    camera.lookAt(0, 0, 0);

    if (controls) {
        controls.target.set(0, 0, 0);
        controls.update();
    }
}

export function updateInstances(instances) {
    if (!instancedMesh) return;

    const count = Math.min(instances.length / 4, maxInstances);
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
    if (!renderer || !scene || !camera) return;

    animationFrameId = requestAnimationFrame(animate);
    if (controls) controls.update();
    renderer.render(scene, camera);
}

export function dispose() {
    if (animationFrameId !== undefined) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = undefined;
    }

    if (resizeHandler) {
        window.removeEventListener('resize', resizeHandler);
        resizeHandler = undefined;
    }

    if (scene && gridHelper) {
        scene.remove(gridHelper);
        gridHelper.geometry.dispose();
        disposeMaterial(gridHelper.material);
        gridHelper = undefined;
    }

    if (scene && instancedMesh) {
        scene.remove(instancedMesh);
        instancedMesh.geometry.dispose();
        disposeMaterial(instancedMesh.material);
        instancedMesh = undefined;
    }

    if (controls) {
        controls.dispose();
        controls = undefined;
    }

    if (renderer) {
        renderer.dispose();
        if (containerElement && renderer.domElement.parentElement === containerElement) {
            containerElement.removeChild(renderer.domElement);
        }
        renderer = undefined;
    }

    scene = undefined;
    camera = undefined;
    containerElement = undefined;
}

function disposeMaterial(material) {
    if (Array.isArray(material)) {
        for (const entry of material) {
            entry.dispose();
        }
        return;
    }

    material.dispose();
}
