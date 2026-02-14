#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float time;
    float2 resolution;
    float2 touchPosition;
    float touchActive;
    float cameraDistance;
    float cameraTime;
};

// Hash function for pseudo-random star placement
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// Single star layer
static float starLayer(float2 uv, float scale, float time, float seed) {
    float2 gv = fract(uv * scale) - 0.5;
    float2 id = floor(uv * scale);

    float brightness = 0.0;

    // Check 2x2 neighborhood for stars
    for (int y = 0; y <= 1; y++) {
        for (int x = 0; x <= 1; x++) {
            float2 offset = float2(x, y);
            float2 cellId = id + offset;

            float n = hash21(cellId + seed);
            float2 starPos = float2(hash21(cellId * 1.3 + seed), hash21(cellId * 2.7 + seed + 100.0)) - 0.5;

            float dist = length(gv - offset - starPos);

            // Star brightness with twinkling
            float twinkle = sin(time * (1.5 + n * 3.0) + n * 6.28) * 0.3 + 0.7;
            float star = smoothstep(0.05, 0.0, dist) * n * twinkle;

            // Only show brighter stars (threshold controls density, lowered for 2x2 neighborhood)
            star *= step(0.45, n);

            brightness += star;
        }
    }

    return brightness;
}

// Galaxy patch - rare soft elliptical glow
static float3 galaxyPatch(float2 uv, float scale, float seed) {
    float2 id = floor(uv * scale);
    float n = hash21(id + seed);

    // Very rare: only ~0.2% of cells get a galaxy
    if (n > 0.002) return float3(0.0);

    float2 gv = fract(uv * scale) - 0.5;
    float2 center = float2(hash21(id * 3.1 + seed) - 0.5, hash21(id * 5.7 + seed) - 0.5) * 0.4;

    float2 d = gv - center;

    // Elliptical shape with rotation
    float angle = hash21(id + seed + 50.0) * 3.14159;
    float ca = cos(angle), sa = sin(angle);
    d = float2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);
    d.y *= 2.0; // Elliptical stretch

    float dist = length(d);
    float glow = exp(-dist * 8.0) * 0.3;

    // Blue/purple tint
    float3 color = mix(float3(0.3, 0.4, 0.8), float3(0.6, 0.3, 0.7), hash21(id + 200.0));
    return color * glow;
}

fragment float4 starfieldFragment(VertexOut in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;

    // Slow drift (freezes with camera during touch)
    float driftTime = uniforms.cameraTime * 0.008;
    uv += float2(driftTime, driftTime * 0.7);

    float3 color = float3(0.005, 0.005, 0.015);

    // Multiple star layers with parallax
    color += float3(0.8, 0.85, 1.0) * starLayer(uv, 15.0, uniforms.time, 0.0) * 0.6;
    color += float3(0.9, 0.9, 1.0)  * starLayer(uv * 1.02 + 0.5, 25.0, uniforms.time, 100.0) * 0.4;
    color += float3(1.0, 0.95, 0.8) * starLayer(uv * 1.05 + 1.3, 40.0, uniforms.time, 200.0) * 0.3;
    color += float3(0.7, 0.8, 1.0)  * starLayer(uv * 1.08 + 2.1, 60.0, uniforms.time, 300.0) * 0.2;

    // Galaxy patches
    color += galaxyPatch(uv, 3.0, 500.0);
    color += galaxyPatch(uv, 5.0, 700.0);

    return float4(color, 1.0);
}
