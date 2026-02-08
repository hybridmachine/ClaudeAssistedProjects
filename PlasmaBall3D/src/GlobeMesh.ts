import * as THREE from 'three';

const FRESNEL_VERTEX_SHADER = `
    varying vec3 vNormal;
    varying vec3 vViewDir;
    void main() {
        vNormal = normalize(normalMatrix * normal);
        vec4 worldPosition = modelViewMatrix * vec4(position, 1.0);
        vViewDir = normalize(-worldPosition.xyz);
        gl_Position = projectionMatrix * worldPosition;
    }
`;

const FRESNEL_FRAGMENT_SHADER = `
    varying vec3 vNormal;
    varying vec3 vViewDir;
    void main() {
        float fresnel = pow(1.0 - abs(dot(vNormal, vViewDir)), 2.5);
        vec3 rimColor = vec3(0.3, 0.5, 0.8);
        vec3 color = rimColor * fresnel;
        float alpha = fresnel * 0.25;
        gl_FragColor = vec4(color * 0.1, alpha);
    }
`;

export class GlobeMesh {
    private mesh: THREE.Mesh;
    private material: THREE.ShaderMaterial;
    readonly radius: number;

    constructor(scene: THREE.Scene, radius: number = 2.0) {
        this.radius = radius;

        const geometry = new THREE.SphereGeometry(radius, 64, 64);
        this.material = new THREE.ShaderMaterial({
            vertexShader: FRESNEL_VERTEX_SHADER,
            fragmentShader: FRESNEL_FRAGMENT_SHADER,
            transparent: true,
            side: THREE.FrontSide,
            depthWrite: false,
        });

        this.mesh = new THREE.Mesh(geometry, this.material);
        scene.add(this.mesh);
    }

    getMesh(): THREE.Mesh {
        return this.mesh;
    }

    dispose(): void {
        this.mesh.geometry.dispose();
        this.material.dispose();
    }
}
