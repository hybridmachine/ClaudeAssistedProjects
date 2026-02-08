import * as THREE from 'three';

export class CentralElectrode {
    private mesh: THREE.Mesh;
    private light: THREE.PointLight;
    private material: THREE.MeshBasicMaterial;
    private baseIntensity = 1.0;

    constructor(scene: THREE.Scene) {
        const geometry = new THREE.SphereGeometry(0.15, 16, 16);
        this.material = new THREE.MeshBasicMaterial({
            color: new THREE.Color(1.2, 0.48, 0.9),
        });

        this.mesh = new THREE.Mesh(geometry, this.material);
        scene.add(this.mesh);

        this.light = new THREE.PointLight(0xffaacc, 0.6, 5, 2);
        scene.add(this.light);
    }

    update(time: number): void {
        const pulse = 1.0 + 0.3 * Math.sin(time * 3.0) + 0.15 * Math.sin(time * 7.1);
        this.light.intensity = this.baseIntensity * pulse;

        const brightness = 1.0 * pulse;
        this.material.color.setRGB(brightness, brightness * 0.4, brightness * 0.75);
    }

    dispose(): void {
        this.mesh.geometry.dispose();
        this.material.dispose();
        this.light.dispose();
    }
}
