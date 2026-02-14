#include <metal_stdlib>
using namespace metal;

// Plasma Globe Fragment Shader
// Ray-marched volumetric tendrils radiating from a central electrode
// inside a glass sphere. Uses 3D perpendicular distance to noise-displaced
// tendril lines for smooth, continuous lightning-like appearance.

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
};

constant int NUM_TENDRILS = 7;
constant int VOL_STEPS = 28;
constant float SPHERE_R = 1.0;
constant float CORE_R = 0.06;

// --- Smooth 3D noise from 2D texture ---

static float tnoise(float3 p, texture2d<float> tex, sampler s) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float2 uv0 = (i.xy + float2(37.0, 17.0) * i.z + f.xy) / 256.0;
    float2 uv1 = (i.xy + float2(37.0, 17.0) * (i.z + 1.0) + f.xy) / 256.0;

    return mix(tex.sample(s, uv0).r, tex.sample(s, uv1).r, f.z);
}

// --- Sphere intersection ---

static float2 sphereHit(float3 ro, float3 rd, float r) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if (h < 0.0) return float2(-1.0);
    h = sqrt(h);
    return float2(-b - h, -b + h);
}

// --- Pre-computed tendril data ---

struct TendrilInfo {
    float3 dir;
    float3 right;
    float3 fwd;
};

static TendrilInfo computeTendril(int idx, float time, float3 touchDir, float touchActive) {
    float fi = float(idx);

    float theta = fi * 2.39996 + time * 0.13 + sin(time * 0.09 + fi * 0.7) * 0.5;
    float cosArg = clamp(1.0 - 2.0 * fract(fi * 0.618034 + 0.5)
                         + sin(time * 0.07 + fi * 1.1) * 0.12,
                         -1.0, 1.0);
    float phi = acos(cosArg);

    float3 baseDir = normalize(float3(
        sin(phi) * cos(theta),
        cos(phi),
        sin(phi) * sin(theta)
    ));

    if (touchActive > 0.5) {
        float bias = 0.35 + 0.25 * fract(fi * 0.37);
        baseDir = normalize(mix(baseDir, touchDir, bias));
    }

    float3 up = abs(baseDir.y) < 0.99 ? float3(0, 1, 0) : float3(1, 0, 0);
    float3 rt = normalize(cross(baseDir, up));
    float3 fw = cross(rt, baseDir);

    TendrilInfo info;
    info.dir = baseDir;
    info.right = rt;
    info.fwd = fw;
    return info;
}

fragment float4 plasmaGlobeFragment(VertexOut in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(0)]],
                                     texture2d<float> noiseTex [[texture(0)]]) {

    constexpr sampler smp(filter::linear, address::repeat);

    float2 uv = (in.uv * uniforms.resolution - 0.5 * uniforms.resolution) / uniforms.resolution.y;
    float time = uniforms.time;

    // Camera — slow orbit
    float camAngle = time * 0.12;
    float3 ro = float3(sin(camAngle) * uniforms.cameraDistance, sin(time * 0.04) * 0.15, cos(camAngle) * uniforms.cameraDistance);
    float3 ww = normalize(-ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = cross(uu, ww);
    float3 rd = normalize(uv.x * uu + uv.y * vv + 1.6 * ww);

    // Map touch to world-space direction on sphere
    float3 touchDir = float3(0, 0, 1);
    if (uniforms.touchActive > 0.5) {
        float2 tuv = (uniforms.touchPosition - 0.5) * 2.0;
        tuv.x *= uniforms.resolution.x / uniforms.resolution.y;
        float3 touchRd = normalize(tuv.x * uu - tuv.y * vv + 1.6 * ww);
        float2 tHit = sphereHit(ro, touchRd, SPHERE_R);
        if (tHit.x > 0.0) {
            touchDir = normalize(ro + touchRd * tHit.x);
        }
    }

    // Pre-compute tendril data
    TendrilInfo tendrils[7];
    for (int j = 0; j < NUM_TENDRILS; j++) {
        tendrils[j] = computeTendril(j, time, touchDir, uniforms.touchActive);
    }

    float3 color = float3(0.0);
    float2 hit = sphereHit(ro, rd, SPHERE_R);

    if (hit.x > 0.0) {
        float3 entry = ro + rd * hit.x;
        float pathLen = hit.y - hit.x;
        float3 normal = normalize(entry);

        // === Glass shell ===
        float fresnel = pow(1.0 - abs(dot(rd, normal)), 3.0);
        float3 shellColor = float3(0.04, 0.05, 0.1) * fresnel;

        float3 lightDir = normalize(float3(0.5, 1.0, 0.8));
        float spec = pow(max(dot(reflect(rd, normal), lightDir), 0.0), 40.0);
        shellColor += float3(0.2, 0.22, 0.3) * spec * 0.25;

        // === Volumetric plasma tendrils ===
        half3 plasma = half3(0.0h);
        int stepCount = int(clamp(pathLen * 18.0, 12.0, float(VOL_STEPS)));
        float dt = pathLen / float(stepCount);

        for (int i = 0; i < stepCount; i++) {
            float rayT = hit.x + dt * (float(i) + 0.5);
            float3 pos = ro + rd * rayT;
            float r = length(pos);

            if (r < CORE_R * 0.5 || r > SPHERE_R) continue;

            half totalCore = 0.0h;
            half totalGlow = 0.0h;

            for (int j = 0; j < NUM_TENDRILS; j++) {
                float fj = float(j);
                float3 tDir = tendrils[j].dir;
                float3 tRight = tendrils[j].right;
                float3 tFwd = tendrils[j].fwd;

                // Project pos onto the tendril line (origin -> tDir)
                float along = dot(pos, tDir);
                float3 perp = pos - tDir * along;

                // Noise displacement perpendicular to tendril
                // First octave — large bends
                float3 np1 = float3(along * 3.0, fj * 13.7 + time * 0.3, fj * 7.1);
                float nx1 = tnoise(np1, noiseTex, smp) - 0.5;
                float ny1 = tnoise(np1 + float3(97, 0, 0), noiseTex, smp) - 0.5;

                // Displacement grows with distance from center
                float dispAmt = max(along, 0.0) * 0.3;
                float3 noiseDisp = (tRight * nx1 + tFwd * ny1) * dispAmt;

                // Second octave — fine lightning jitter (skip near center where displacement is ~0)
                if (along > 0.15) {
                    float3 np2 = float3(along * 7.0, fj * 23.1 + time * 0.5, fj * 17.3);
                    float nx2 = tnoise(np2, noiseTex, smp) - 0.5;
                    float ny2 = tnoise(np2 + float3(197, 0, 0), noiseTex, smp) - 0.5;
                    noiseDisp += (tRight * nx2 + tFwd * ny2) * dispAmt * 0.3;
                }

                // 3D distance from sample to displaced tendril
                float dist = length(perp - noiseDisp);

                // Tendril profile — Gaussian in 3D distance
                float coreW = 0.018 + along * 0.008;
                float glowW = 0.06 + along * 0.04;
                half core = half(exp(-dist * dist / (coreW * coreW)));
                half glow = half(fast::exp(-dist * dist / (glowW * glowW)));

                // Fade near center and surface
                half fade = half(smoothstep(CORE_R, CORE_R + 0.12, along) *
                             smoothstep(SPHERE_R, SPHERE_R - 0.05, along));

                totalCore += core * fade;
                totalGlow += glow * fade;
            }

            totalCore = min(totalCore, 5.0h);
            totalGlow = min(totalGlow, 8.0h);

            // Color: white/blue core, purple/pink glow
            half3 stepCol = half3(0.0h);
            stepCol += half3(0.95h, 0.95h, 1.0h) * totalCore * 1.5h;
            stepCol += half3(0.5h, 0.3h, 0.9h) * totalGlow * 0.35h;
            stepCol += half3(0.8h, 0.2h, 0.6h) * totalGlow * totalGlow * 0.008h;

            // Central electrode glow
            half cg = half(fast::exp(-r * 12.0)) * 3.0h;
            stepCol += half3(0.6h, 0.7h, 1.0h) * cg;

            plasma += stepCol * half(dt);

            // Early exit: values above ~3.0 per channel saturate after tone mapping
            if (dot(plasma, plasma) > 9.0h) break;
        }

        color = float3(plasma) + shellColor;

        // Rim glow on glass edge
        float rim = pow(1.0 - abs(dot(rd, normal)), 4.0);
        color += float3(0.1, 0.12, 0.25) * rim * 0.5;
    }

    // Vignette
    float2 q = in.uv;
    color *= 0.5 + 0.5 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.15);

    // Tone mapping
    color = 1.0 - fast::exp(-color * 2.5);

    return float4(max(color, float3(0.0)), 1.0);
}
