import { PlasmaGlobe } from './PlasmaGlobe.js';

const canvas = document.getElementById('canvas') as HTMLCanvasElement;
const fpsDisplay = document.getElementById('status-fps') as HTMLSpanElement;

const plasmaGlobe = new PlasmaGlobe(canvas);

let frameCount = 0;
let lastFpsTime = performance.now();

function animate(): void {
    requestAnimationFrame(animate);

    plasmaGlobe.update();

    frameCount++;
    const now = performance.now();
    if (now - lastFpsTime >= 1000) {
        const fps = Math.round(frameCount * 1000 / (now - lastFpsTime));
        fpsDisplay.textContent = `FPS: ${fps}`;
        frameCount = 0;
        lastFpsTime = now;
    }
}

animate();
