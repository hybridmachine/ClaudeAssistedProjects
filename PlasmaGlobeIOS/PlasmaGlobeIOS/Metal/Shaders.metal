#include <metal_stdlib>
using namespace metal;

// Plasma Globe Fragment Shader
// Ray-marched volumetric tendrils radiating from a central electrode
// inside a glass sphere. Supports multi-touch (up to 5 fingers),
// force/pressure modulation, configurable colors, and discharge flash.

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float time;
    float2 resolution;
    float cameraDistance;
    float cameraTime;
    int touchCount;
    float dischargeTime;
    float2 gyroTilt;
};

struct TouchPoint {
    float2 position;
    float force;
    float active;
};

struct PlasmaConfig {
    float4 coreColorA;
    float4 coreColorB;
    float4 glowColorA;
    float4 glowColorB;
    float4 shellTint;
    float4 contactColor;
    int tendrilCount;
    float brightness;
    float speed;
    float tendrilThickness;
    float respawnRate;
    int rainbowMode;
};

constant int MAX_TENDRILS = 20;
constant int MAX_TOUCHES = 5;
constant int VOL_STEPS = 40;
constant float SPHERE_R = 1.0;
constant float CORE_R = 0.06;
constant float POST_RADIUS_MAX = 0.095;
constant float POST_BOTTOM = -SPHERE_R;
constant float POST_TOP = 0.0;
constant float ELECTRODE_R = 0.095;
constant float QUICK_REJECT_DIST = 0.25;

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

// --- Profiled center post ---

struct PostResult {
    float t;
    float3 normal;
};

static float postRadius(float y) {
    float t = (y - POST_BOTTOM) / (POST_TOP - POST_BOTTOM);
    t = clamp(t, 0.0, 1.0);

    float baseR = 0.08;
    float dome = 1.0 + 0.15 * smoothstep(0.15, 0.0, t);
    float bottom = baseR * dome;

    float midTop = 0.028;
    float midBot = 0.045;
    float midT = smoothstep(0.3, 0.8, t);
    float middle = mix(midBot, midTop, midT);

    float stemR = 0.028;
    float flare = 1.0 + 0.08 * smoothstep(0.9, 1.0, t);
    float top = stemR * flare;

    float blend1 = smoothstep(0.2, 0.35, t);
    float blend2 = smoothstep(0.7, 0.85, t);
    float r = mix(bottom, middle, blend1);
    r = mix(r, top, blend2);

    return r;
}

static float postSDF(float3 p) {
    float radialDist = length(float2(p.x, p.z));
    float y = p.y;

    float yc = clamp(y, POST_BOTTOM, POST_TOP);
    float profileR = postRadius(yc);
    float dRadial = radialDist - profileR;

    float dVertical = 0.0;
    if (y < POST_BOTTOM) dVertical = POST_BOTTOM - y;
    else if (y > POST_TOP) dVertical = y - POST_TOP;

    float dPost;
    if (dVertical > 0.0) {
        if (dRadial > 0.0) {
            dPost = sqrt(dRadial * dRadial + dVertical * dVertical);
        } else {
            dPost = dVertical;
        }
    } else {
        dPost = dRadial;
    }

    float dSphere = length(p - float3(0.0, POST_TOP, 0.0)) - ELECTRODE_R;
    return min(dPost, dSphere);
}

static PostResult profiledPostHit(float3 ro, float3 rd) {
    PostResult result;
    result.t = -1.0;
    result.normal = float3(0.0);

    float tEntry = 1e20;
    float tExit = -1e20;

    float cylA = rd.x * rd.x + rd.z * rd.z;
    float cylB = 2.0 * (ro.x * rd.x + ro.z * rd.z);
    float cylC = ro.x * ro.x + ro.z * ro.z - POST_RADIUS_MAX * POST_RADIUS_MAX;
    float cylDisc = cylB * cylB - 4.0 * cylA * cylC;

    if (cylDisc >= 0.0 && cylA > 1e-8) {
        float sqrtDisc = sqrt(cylDisc);
        float cEntry = (-cylB - sqrtDisc) / (2.0 * cylA);
        float cExit  = (-cylB + sqrtDisc) / (2.0 * cylA);

        if (abs(rd.y) > 1e-8) {
            float tBot = (POST_BOTTOM - ro.y) / rd.y;
            float tTop = (POST_TOP - ro.y) / rd.y;
            cEntry = max(cEntry, min(tBot, tTop));
            cExit  = min(cExit,  max(tBot, tTop));
        } else if (ro.y < POST_BOTTOM || ro.y > POST_TOP) {
            cEntry = 1e20; cExit = -1e20;
        }

        if (cEntry < cExit) {
            tEntry = min(tEntry, cEntry);
            tExit  = max(tExit,  cExit);
        }
    }

    float3 sphereCenter = float3(0.0, POST_TOP, 0.0);
    float3 oc = ro - sphereCenter;
    float sB = dot(oc, rd);
    float sC = dot(oc, oc) - ELECTRODE_R * ELECTRODE_R;
    float sDisc = sB * sB - sC;

    if (sDisc >= 0.0) {
        float sqrtSD = sqrt(sDisc);
        float sEntry = -sB - sqrtSD;
        float sExit  = -sB + sqrtSD;
        if (sExit > 0.001) {
            tEntry = min(tEntry, sEntry);
            tExit  = max(tExit,  sExit);
        }
    }

    tEntry = max(tEntry, 0.001);
    if (tEntry >= tExit) return result;

    float t = tEntry;
    for (int i = 0; i < 16; i++) {
        float3 p = ro + rd * t;
        float d = postSDF(p);
        if (d < 0.001) {
            result.t = t;
            float eps = 0.001;
            float3 n = float3(
                postSDF(p + float3(eps, 0, 0)) - postSDF(p - float3(eps, 0, 0)),
                postSDF(p + float3(0, eps, 0)) - postSDF(p - float3(0, eps, 0)),
                postSDF(p + float3(0, 0, eps)) - postSDF(p - float3(0, 0, eps))
            );
            result.normal = normalize(n);
            return result;
        }
        t += max(d * 0.9, 0.002);
        if (t > tExit) break;
    }

    return result;
}

// --- Pre-computed tendril data ---

struct TendrilInfo {
    float3 dir;
    float3 right;
    float3 fwd;
    float touchBias;
    float forceScale;
    float forkPoint;
    float3 branchOffset1;
    float3 branchOffset2;
    int branchCount;
    float flicker;
    float colorSeed;
};

static TendrilInfo computeTendril(int idx, float time, float realTime,
                                   thread float3 *touchDirs, thread float *touchForces,
                                   int touchCount, float speed, float respawnRate) {
    float fi = float(idx);

    // Lifecycle: each tendril lives 3-7 real seconds then respawns at a new position
    float lifeHash = fract(fi * 0.5281 + 0.321);
    float phaseHash = fract(fi * 0.8713 + 0.654);
    float period = (3.0 + lifeHash * 4.0) / max(respawnRate, 0.1);
    float lifecycleTime = realTime + phaseHash * period;
    float generation = floor(lifecycleTime / period);
    float timeInCycle = fract(lifecycleTime / period) * period;

    // Per-generation random offsets so the tendril respawns at a new position each cycle
    float genTheta = fract(sin(generation * 127.1 + fi * 311.7) * 43758.5453) * 6.2832;
    float genPhi = fract(sin(generation * 269.5 + fi * 183.3) * 43758.5453);
    float genSeed = generation * 7.31;

    // Organic meandering around spawn position (no continuous orbit)
    float wanderTheta = sin(time * 0.17 * speed + fi * 2.3 + genSeed) * 0.25
                      + sin(time * 0.11 * speed + fi * 4.1 + genSeed * 1.7) * 0.15
                      + sin(time * 0.07 * speed + fi * 6.7 + genSeed * 2.3) * 0.08;
    float theta = fi * 2.39996 + genTheta + wanderTheta;

    // Slow upward drift over lifecycle + vertical meandering
    float lifecycleProgress = timeInCycle / period;
    float upwardDrift = lifecycleProgress * 0.35;

    float wanderPhi = sin(time * 0.13 * speed + fi * 3.7 + genSeed * 1.3) * 0.08
                    + sin(time * 0.09 * speed + fi * 5.3 + genSeed * 2.1) * 0.05;

    float cosArg = clamp(1.0 - 2.0 * genPhi + upwardDrift + wanderPhi, -1.0, 1.0);
    float phi = acos(cosArg);

    float3 baseDir = normalize(float3(
        sin(phi) * cos(theta),
        cos(phi),
        sin(phi) * sin(theta)
    ));

    float bias = 0.0;
    float forceScale = 1.0;

    if (touchCount > 0) {
        // Find nearest touch
        float bestProximity = -1.0;
        int bestTouch = 0;
        for (int t = 0; t < touchCount && t < MAX_TOUCHES; t++) {
            float angularDist = acos(clamp(dot(baseDir, touchDirs[t]), -1.0, 1.0)) / M_PI_F;
            float proximity = 1.0 - angularDist;
            if (proximity > bestProximity) {
                bestProximity = proximity;
                bestTouch = t;
            }
        }

        // Tendrils near the touch converge on the finger — like a real plasma globe.
        // Influence starts at ~108°, full convergence within ~36°.
        float localFalloff = smoothstep(0.4, 0.8, bestProximity);
        float force = touchForces[bestTouch];
        // Convergence is primarily proximity-driven; force modulates intensity
        bias = localFalloff * (0.7 + 0.25 * force + 0.04 * fract(fi * 0.37));
        bias = clamp(bias, 0.0, 1.0);
        baseDir = normalize(mix(baseDir, touchDirs[bestTouch], bias));
        forceScale = 1.0 + force * 0.8 * localFalloff;
    }

    float3 up = abs(baseDir.y) < 0.99 ? float3(0, 1, 0) : float3(1, 0, 0);
    float3 rt = normalize(cross(baseDir, up));
    float3 fw = cross(rt, baseDir);

    float hash1 = fract(fi * 0.7631 + 0.123 + genSeed);
    float hash2 = fract(fi * 0.4519 + 0.789 + genSeed);
    float hash3 = fract(fi * 0.9137 + 0.456 + genSeed);

    TendrilInfo info;
    info.dir = baseDir;
    info.right = rt;
    info.fwd = fw;
    info.touchBias = bias;
    info.forceScale = forceScale;
    info.forkPoint = 0.3 + hash1 * 0.3;

    float angle1 = hash2 * M_PI_F * 2.0 + time * 0.05 * speed;
    info.branchOffset1 = normalize(rt * cos(angle1) + fw * sin(angle1));
    float angle2 = angle1 + M_PI_F * 0.6 + hash3 * 0.4;
    info.branchOffset2 = normalize(rt * cos(angle2) + fw * sin(angle2));
    info.branchCount = (hash3 > 0.4) ? 2 : 1;

    // Lifecycle fade: quick fade in/out at lifecycle boundaries
    float fadeIn = smoothstep(0.0, 0.2, timeInCycle);
    float fadeOut = smoothstep(0.0, 0.2, period - timeInCycle);
    info.flicker = fadeIn * fadeOut;

    // Per-tendril color seed for rainbow mode (changes each generation)
    info.colorSeed = fract(sin(generation * 53.7 + fi * 97.3) * 43758.5453);

    return info;
}

// --- Rainbow palette (8 bright colors) ---

constant half3 RAINBOW_PALETTE[8] = {
    half3(1.0h, 0.2h, 0.15h),   // Red
    half3(1.0h, 0.55h, 0.1h),   // Orange
    half3(1.0h, 0.85h, 0.1h),   // Yellow
    half3(0.2h, 0.9h, 0.3h),    // Green
    half3(0.1h, 0.8h, 0.8h),    // Teal
    half3(0.2h, 0.4h, 1.0h),    // Blue
    half3(0.45h, 0.2h, 0.95h),  // Indigo
    half3(0.9h, 0.2h, 0.7h)     // Magenta
};

static half3 rainbowColor(float seed) {
    int idx = int(seed * 8.0) % 8;
    return RAINBOW_PALETTE[idx];
}

fragment float4 plasmaGlobeFragment(VertexOut in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(0)]],
                                     constant TouchPoint *touches [[buffer(1)]],
                                     constant PlasmaConfig &config [[buffer(2)]],
                                     texture2d<float> noiseTex [[texture(0)]]) {

    constexpr sampler smp(filter::linear, address::repeat);

    float2 uv = (in.uv * uniforms.resolution - 0.5 * uniforms.resolution) / uniforms.resolution.y;
    float time = uniforms.time * config.speed;
    int numTendrils = clamp(config.tendrilCount, 1, MAX_TENDRILS);
    float thickness = config.tendrilThickness;

    // Camera — slow orbit (freezes during touch)
    float camAngle = uniforms.cameraTime * 0.12;
    float3 ro = float3(sin(camAngle) * uniforms.cameraDistance, sin(uniforms.cameraTime * 0.04) * 0.15, cos(camAngle) * uniforms.cameraDistance);
    float3 ww = normalize(-ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = cross(uu, ww);
    float3 rd = normalize(uv.x * uu + uv.y * vv + 1.6 * ww);

    // Map touches to world-space directions on sphere
    int touchCount = clamp(uniforms.touchCount, 0, MAX_TOUCHES);
    float3 touchDirs[MAX_TOUCHES];
    float touchForces[MAX_TOUCHES];
    for (int t = 0; t < MAX_TOUCHES; t++) {
        touchDirs[t] = float3(0, 0, 1);
        touchForces[t] = 0.5;
    }
    for (int t = 0; t < touchCount; t++) {
        if (touches[t].active > 0.5) {
            float2 tuv = touches[t].position - 0.5;
            tuv.x *= uniforms.resolution.x / uniforms.resolution.y;
            float3 touchRd = normalize(tuv.x * uu - tuv.y * vv + 1.6 * ww);
            float2 tHit = sphereHit(ro, touchRd, SPHERE_R);
            if (tHit.x > 0.0) {
                touchDirs[t] = normalize(ro + touchRd * tHit.x);
            }
            touchForces[t] = touches[t].force;
        }
    }

    // Apply gyro tilt sway to touch directions
    float2 tilt = uniforms.gyroTilt;
    float3 tiltOffset = float3(tilt.x, 0.0, tilt.y) * 0.15;

    // Pre-compute tendril data
    TendrilInfo tendrils[MAX_TENDRILS];
    for (int j = 0; j < numTendrils; j++) {
        tendrils[j] = computeTendril(j, time, uniforms.time, touchDirs, touchForces, touchCount, config.speed, config.respawnRate);
        // Subtle sway from device tilt
        tendrils[j].dir = normalize(tendrils[j].dir + tiltOffset);
    }

    float3 color = float3(0.0);
    float2 hit = sphereHit(ro, rd, SPHERE_R);

    if (hit.x > 0.0) {
        float3 entry = ro + rd * hit.x;
        float pathLen = hit.y - hit.x;
        float3 normal = normalize(entry);

        // === Center post ===
        PostResult postHit = profiledPostHit(ro, rd);
        bool hitPost = (postHit.t > 0.0 && postHit.t >= hit.x && postHit.t <= hit.y);
        float3 postColor = float3(0.0);

        if (hitPost) {
            pathLen = postHit.t - hit.x;

            float3 postNorm = postHit.normal;
            float3 lightDir = normalize(float3(0.5, 1.0, 0.8));
            float3 lightDir2 = normalize(float3(-0.3, 0.5, -0.6));

            float3 baseMetalColor = float3(0.04, 0.04, 0.05);
            float diff = max(dot(postNorm, lightDir), 0.0) * 0.3;
            float diff2 = max(dot(postNorm, lightDir2), 0.0) * 0.15;
            float spec = pow(max(dot(reflect(rd, postNorm), lightDir), 0.0), 60.0);
            float spec2 = pow(max(dot(reflect(rd, postNorm), lightDir2), 0.0), 40.0);

            postColor = baseMetalColor + float3(0.08, 0.08, 0.1) * (diff + diff2)
                       + float3(0.25, 0.25, 0.35) * spec * 0.4
                       + float3(0.15, 0.15, 0.25) * spec2 * 0.2;

            float3 postPoint = ro + rd * postHit.t;
            float topProximity = smoothstep(-0.15, 0.05, postPoint.y);
            float3 electrodeColor = config.rainbowMode != 0
                ? mix(float3(0.9, 0.9, 1.0), float3(1.0), 0.3)
                : mix(config.glowColorB.rgb, float3(1.0), 0.3);
            postColor += electrodeColor * topProximity * 1.2;
            // Hot-spot at dome apex
            float3 upDir = float3(0.0, 1.0, 0.0);
            float hotSpot = pow(max(dot(postHit.normal, upDir), 0.0), 3.0) * 0.8;
            postColor += electrodeColor * hotSpot;
        }

        // === Glass shell ===
        float fresnel = pow(1.0 - abs(dot(rd, normal)), 3.0);
        float3 shellColor = config.shellTint.rgb * fresnel;

        float3 lightDir = normalize(float3(0.5, 1.0, 0.8));
        float spec = pow(max(dot(reflect(rd, normal), lightDir), 0.0), 40.0);
        shellColor += float3(0.2, 0.22, 0.3) * spec * 0.25;

        // === Volumetric plasma tendrils ===
        half3 plasma = half3(0.0h);
        int stepCount = int(clamp(pathLen * 25.0, 20.0, float(VOL_STEPS)));
        float dt = pathLen / float(stepCount);

        for (int i = 0; i < stepCount; i++) {
            float rayT = hit.x + dt * (float(i) + 0.5);
            float3 pos = ro + rd * rayT;
            float r = length(pos);

            if (r < CORE_R * 0.5 || r > SPHERE_R) continue;
            if (postSDF(pos) < 0.0) continue;

            half3 totalColor = half3(0.0h);

            for (int j = 0; j < numTendrils; j++) {
                float fj = float(j);
                float3 tDir = tendrils[j].dir;
                float3 tRight = tendrils[j].right;
                float3 tFwd = tendrils[j].fwd;
                float fScale = tendrils[j].forceScale;

                float along = dot(pos, tDir);
                float3 perp = pos - tDir * along;

                float perpLen = length(perp);
                if (perpLen > QUICK_REJECT_DIST) continue;

                // Noise displacement
                float3 np1 = float3(along * 3.0, fj * 13.7 + time * 0.3, fj * 7.1);
                float nx1 = tnoise(np1, noiseTex, smp) - 0.5;
                float ny1 = tnoise(np1 + float3(97, 0, 0), noiseTex, smp) - 0.5;

                float dispAmt = max(along, 0.0) * 0.22;
                float3 noiseDisp = (tRight * nx1 + tFwd * ny1) * dispAmt;

                if (along > 0.15) {
                    float3 np2 = float3(along * 7.0, fj * 23.1 + time * 0.5, fj * 17.3);
                    float nx2 = tnoise(np2, noiseTex, smp) - 0.5;
                    float ny2 = tnoise(np2 + float3(197, 0, 0), noiseTex, smp) - 0.5;
                    noiseDisp += (tRight * nx2 + tFwd * ny2) * dispAmt * 0.3;
                }

                // Ridged noise for angular kinks in outer half
                if (along > 0.4) {
                    float3 np3 = float3(along * 14.0, fj * 31.7 + time * 0.7, fj * 21.9);
                    float rx = abs(tnoise(np3, noiseTex, smp) - 0.5);
                    float ry = abs(tnoise(np3 + float3(293, 0, 0), noiseTex, smp) - 0.5);
                    float kinkAmt = smoothstep(0.4, 0.7, along) * 0.15;
                    noiseDisp += (tRight * (rx * rx) + tFwd * (ry * ry)) * kinkAmt;
                }

                float dist = length(perp - noiseDisp);

                // Force modulates width (+50% at max force)
                float forceWidth = 1.0 + (fScale - 1.0) * 0.625;
                float taper = 1.0 - along * 0.3;
                float coreW = 0.015 * thickness * forceWidth * taper;
                float glowW = (0.035 + along * 0.015) * thickness * forceWidth;
                float coreArg = dist / max(coreW, 0.001);
                half core = half(exp(-(coreArg * coreArg)));
                half glow = half(fast::exp(-dist * dist / (glowW * glowW)));

                // Force modulates brightness (+80% at max force), per-tendril flicker
                half forceBright = half(fScale) * half(tendrils[j].flicker);

                float surfaceMargin = mix(0.05, 0.005, tendrils[j].touchBias);
                half fade = half(smoothstep(CORE_R, CORE_R + 0.12, along) *
                             smoothstep(SPHERE_R, SPHERE_R - surfaceMargin, along));

                // Color from config
                float t = saturate((along - CORE_R) / (SPHERE_R - CORE_R));
                half midBlend = half(smoothstep(0.0, 0.35, t) - smoothstep(0.65, 1.0, t));

                half3 themeCore, glowColor;
                if (config.rainbowMode != 0) {
                    half3 palColor = rainbowColor(tendrils[j].colorSeed);
                    themeCore = mix(palColor, half3(1.0h), 0.55h);
                    glowColor = palColor;
                } else {
                    themeCore = mix(half3(config.coreColorA.rgb), half3(config.coreColorB.rgb), midBlend);
                    glowColor = mix(half3(config.glowColorA.rgb), half3(config.glowColorB.rgb), midBlend);
                }
                half3 whiteCore = mix(mix(themeCore, half3(1.0h), 0.85h), half3(0.9h, 0.92h, 1.0h), 0.3h);

                half transW = half((coreW + glowW) * 0.5);
                half trans = half(exp(-dist * dist / (float(transW) * float(transW))));
                half3 transColor = mix(themeCore, glowColor, 0.5h);

                totalColor += whiteCore * core * fade * forceBright * 0.8h;
                totalColor += transColor * trans * fade * 0.15h * forceBright;
                totalColor += glowColor * glow * fade * 0.23h * forceBright;

                // === Branching (subtle thin filaments) ===
                if (along > tendrils[j].forkPoint) {
                    float branchT = (along - tendrils[j].forkPoint) / (1.0 - tendrils[j].forkPoint);
                    float branchFadeIn = smoothstep(0.0, 0.15, branchT);
                    float spread = branchT * 0.07;

                    float3 branchDisp1 = noiseDisp + tendrils[j].branchOffset1 * spread;
                    float bDist1 = length(perp - branchDisp1);
                    float bTaper = 1.0 - along * 0.3;
                    float bCoreW = 0.009 * thickness * forceWidth * bTaper;
                    float bGlowW = (0.015 + along * 0.008) * thickness * forceWidth;
                    float bCoreArg1 = bDist1 / max(bCoreW, 0.001);
                    half bCore1 = half(exp(-(bCoreArg1 * bCoreArg1)));
                    half bGlow1 = half(fast::exp(-bDist1 * bDist1 / (bGlowW * bGlowW)));
                    half bFade1 = fade * half(branchFadeIn) * 0.4h;
                    totalColor += whiteCore * bCore1 * bFade1 * forceBright * 0.6h;
                    totalColor += glowColor * bGlow1 * bFade1 * 0.18h * forceBright;

                    if (tendrils[j].branchCount > 1) {
                        float3 branchDisp2 = noiseDisp + tendrils[j].branchOffset2 * spread;
                        float bDist2 = length(perp - branchDisp2);
                        float bCoreArg2 = bDist2 / max(bCoreW, 0.001);
                        half bCore2 = half(exp(-(bCoreArg2 * bCoreArg2)));
                        half bGlow2 = half(fast::exp(-bDist2 * bDist2 / (bGlowW * bGlowW)));
                        half bFade2 = fade * half(branchFadeIn) * 0.4h;
                        totalColor += whiteCore * bCore2 * bFade2 * forceBright * 0.6h;
                        totalColor += glowColor * bGlow2 * bFade2 * 0.18h * forceBright;
                    }
                }
            }

            totalColor = min(totalColor, half3(5.0h));
            half3 stepCol = totalColor;

            half cg = half(fast::exp(-r * 10.0)) * 5.0h;
            half3 coreGlowColor = config.rainbowMode != 0
                ? half3(0.9h, 0.9h, 1.0h)
                : half3(config.coreColorB.rgb);
            stepCol += coreGlowColor * cg;
            // Soft ambient fill using average glow color
            half3 ambientColor = config.rainbowMode != 0
                ? half3(0.15h, 0.15h, 0.2h)
                : (half3(config.glowColorA.rgb) + half3(config.glowColorB.rgb)) * 0.5h;
            half ambient = half(fast::exp(-r * 3.5)) * 0.08h;
            stepCol += ambientColor * ambient;

            plasma += stepCol * half(dt);

            if (dot(plasma, plasma) > 9.0h) break;
        }

        // === Per-tendril glass termination glow ===
        for (int j = 0; j < numTendrils; j++) {
            float3 tDir = tendrils[j].dir;
            // Approximate glass endpoint: tendril direction scaled to sphere surface
            float3 glassPoint = normalize(tDir) * SPHERE_R;
            float3 glassNormal = normalize(glassPoint);
            float surfaceDot = max(dot(normal, glassNormal), 0.0);
            half tightSpot = half(pow(surfaceDot, 60.0) * 0.1);
            half wideHalo = half(pow(surfaceDot, 12.0) * 0.010);
            half3 spotColor = half3(0.9h, 0.92h, 1.0h) * tightSpot;
            half3 haloBase = config.rainbowMode != 0
                ? rainbowColor(tendrils[j].colorSeed)
                : mix(half3(config.glowColorA.rgb), half3(config.glowColorB.rgb), 0.5h);
            half3 haloColor = haloBase * wideHalo;
            plasma += spotColor + haloColor;
        }

        // === Discharge flash ===
        if (uniforms.dischargeTime >= 0.0) {
            float dTime = uniforms.dischargeTime;
            // Intensity envelope: attack (0-0.05s), sustain (0.05-0.3s), decay (0.3-1.5s)
            float envelope = 1.0;
            if (dTime < 0.05) {
                envelope = dTime / 0.05;
            } else if (dTime > 0.3) {
                envelope = 1.0 - smoothstep(0.3, 1.5, dTime);
            }
            envelope *= envelope; // sharper falloff

            // 8 lightning tendrils with rapidly rotating directions
            for (int lt = 0; lt < 8; lt++) {
                float flt = float(lt);
                float lTheta = flt * 0.785398 + dTime * 12.0 + sin(dTime * 7.0 + flt) * 2.0;
                float lPhi = acos(clamp(cos(flt * 1.3 + dTime * 5.0), -0.9, 0.9));
                float3 lDir = normalize(float3(sin(lPhi) * cos(lTheta), cos(lPhi), sin(lPhi) * sin(lTheta)));

                float along = dot(entry, lDir);
                float3 perp = entry - lDir * along;
                float perpLen = length(perp);
                if (perpLen > 0.4) continue;

                // High-frequency noise
                float3 lnp = float3(along * 10.0, flt * 17.3 + dTime * 8.0, flt * 11.7);
                float lnx = tnoise(lnp, noiseTex, smp) - 0.5;
                float lny = tnoise(lnp + float3(97, 0, 0), noiseTex, smp) - 0.5;

                float3 up = abs(lDir.y) < 0.99 ? float3(0, 1, 0) : float3(1, 0, 0);
                float3 lrt = normalize(cross(lDir, up));
                float3 lfw = cross(lrt, lDir);

                float dispAmt = max(along, 0.0) * 0.35;
                float dist = length(perp - (lrt * lnx + lfw * lny) * dispAmt);

                float lCore = exp(-dist * dist / (0.02 * 0.02));
                float lGlow = exp(-dist * dist / (0.06 * 0.06));

                half3 lightningCore = config.rainbowMode != 0
                    ? mix(RAINBOW_PALETTE[lt % 8], half3(1.0h), 0.5h)
                    : half3(0.9h, 0.9h, 1.0h);
                half3 lightningGlow = config.rainbowMode != 0
                    ? RAINBOW_PALETTE[lt % 8]
                    : half3(config.coreColorA.rgb);
                half3 lightningColor = lightningCore * half(lCore * envelope * 2.0);
                lightningColor += lightningGlow * half(lGlow * envelope * 0.5);
                plasma += lightningColor;
            }

            // Global brightness boost
            plasma *= half(1.0 + envelope * 1.5);

            // White flash on shell
            float shellFlash = envelope * 0.6;
            shellColor += float3(shellFlash);
        }

        // === Touch contact glow ===
        for (int t = 0; t < touchCount; t++) {
            if (touches[t].active > 0.5) {
                float surfaceDot = dot(normal, touchDirs[t]);
                float contactForce = touchForces[t];
                float contactGlow = pow(max(surfaceDot, 0.0), 80.0) * 2.5 * (1.0 + contactForce * 0.5);
                float contactHalo = pow(max(surfaceDot, 0.0), 15.0) * 0.4 * (1.0 + contactForce * 0.3);
                float3 contactGlowColor = config.rainbowMode != 0
                    ? float3(0.95, 0.95, 1.0) : config.contactColor.rgb;
                float3 contactHaloColor = config.rainbowMode != 0
                    ? float3(0.8, 0.8, 1.0) : config.glowColorB.rgb;
                float3 cColor = contactGlowColor * contactGlow
                              + contactHaloColor * contactHalo;
                plasma += half3(cColor);
            }
        }

        color = float3(plasma) * config.brightness + shellColor;

        if (hitPost) {
            color += postColor;
        }

        float rim = pow(1.0 - abs(dot(rd, normal)), 4.0);
        color += config.shellTint.rgb * rim * 2.0;
    }

    // Vignette
    float2 q = in.uv;
    color *= 0.5 + 0.5 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.15);

    // Tone mapping
    color = 1.0 - fast::exp(-color * 2.5);

    return float4(max(color, float3(0.0)), 1.0);
}
