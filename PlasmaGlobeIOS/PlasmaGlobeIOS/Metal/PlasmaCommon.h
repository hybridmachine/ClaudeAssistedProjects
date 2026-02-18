#ifndef PlasmaCommon_h
#define PlasmaCommon_h

#include <metal_stdlib>
using namespace metal;

// === Shared structs ===

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
    float3 worldDir;
    float _padTP;
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

// === Constants ===

constant int MAX_TENDRILS = 20;
constant int MAX_TOUCHES = 5;
constant int VOL_STEPS = 32;
constant float SPHERE_R = 1.0;
constant float CORE_R = 0.06;
constant float POST_RADIUS_MAX = 0.095;
constant float POST_BOTTOM = -SPHERE_R;
constant float POST_TOP = 0.0;
constant float ELECTRODE_R = 0.095;
constant float QUICK_REJECT_DIST = 0.25;

// === Utility functions ===

static float tnoise(float3 p, texture2d<float> tex, sampler s) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float2 uv0 = (i.xy + float2(37.0, 17.0) * i.z + f.xy) / 256.0;
    float2 uv1 = (i.xy + float2(37.0, 17.0) * (i.z + 1.0) + f.xy) / 256.0;

    return mix(tex.sample(s, uv0).r, tex.sample(s, uv1).r, f.z);
}

static float2 sphereHit(float3 ro, float3 rd, float r) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if (h < 0.0) return float2(-1.0);
    h = sqrt(h);
    return float2(-b - h, -b + h);
}

static float fastPow(float x, float n) {
    return fast::exp2(n * fast::log2(max(x, 1e-10)));
}

// === Profiled center post ===

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
    for (int i = 0; i < 10; i++) {
        float3 p = ro + rd * t;
        float d = postSDF(p);
        if (d < 0.001) {
            result.t = t;
            // Tetrahedron normal: 4 SDF samples instead of 6
            float eps = 0.001;
            float3 e1 = float3( 1, -1, -1);
            float3 e2 = float3(-1, -1,  1);
            float3 e3 = float3(-1,  1, -1);
            float3 e4 = float3( 1,  1,  1);
            float3 n = e1 * postSDF(p + e1 * eps)
                     + e2 * postSDF(p + e2 * eps)
                     + e3 * postSDF(p + e3 * eps)
                     + e4 * postSDF(p + e4 * eps);
            result.normal = normalize(n);
            return result;
        }
        t += max(d * 0.9, 0.002);
        if (t > tExit) break;
    }

    return result;
}

// === Tendril data ===

struct TendrilInfo {
    float3 dir;
    float _pad0;
    float3 right;
    float _pad1;
    float3 fwd;
    float _pad2;
    float touchBias;
    float forceScale;
    float forkPoint;
    float _pad3;
    float3 branchOffset1;
    float _pad4;
    float3 branchOffset2;
    float _pad5;
    int branchCount;
    float flicker;
    float colorSeed;
    float _pad6;
};

// computeTendril() has been moved to CPU (PlasmaRenderer.swift) for performance.
// Tendrils are pre-computed once per frame and passed via buffer(3).

// === Branch contribution helper ===

static half3 computeBranchContribution(float3 perp, float3 branchDisp,
                                        float along, float thickness, float forceWidth,
                                        half fade, half forceBright, half branchFadeIn,
                                        half3 whiteCore, half3 glowColor) {
    float bDist = length(perp - branchDisp);
    float bTaper = 1.0 - along * 0.3;
    float bCoreW = 0.009 * thickness * forceWidth * bTaper;
    float bGlowW = (0.015 + along * 0.008) * thickness * forceWidth;
    float bCoreArg = bDist / max(bCoreW, 0.001);
    half bCore = half(exp(-(bCoreArg * bCoreArg)));
    half bGlow = half(fast::exp(-bDist * bDist / (bGlowW * bGlowW)));
    half bFade = fade * branchFadeIn * 0.4h;
    return whiteCore * bCore * bFade * forceBright * 0.6h
         + glowColor * bGlow * bFade * 0.18h * forceBright;
}

// === Rainbow palette ===

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

#endif /* PlasmaCommon_h */
