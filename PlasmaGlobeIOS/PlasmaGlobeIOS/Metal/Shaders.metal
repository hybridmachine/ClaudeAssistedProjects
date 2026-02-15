#include <metal_stdlib>
using namespace metal;

// Plasma Globe Fragment Shader
// Ray-marched volumetric tendrils radiating from a central electrode
// inside a glass sphere. Uses 3D perpendicular distance to noise-displaced
// tendril lines for smooth, continuous lightning-like appearance.
// Features: center post, tendril branching, quick-reject optimization.

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

constant int NUM_TENDRILS = 12;
constant int VOL_STEPS = 28;
constant float SPHERE_R = 1.0;
constant float CORE_R = 0.06;
constant float POST_RADIUS_MAX = 0.095;
constant float POST_BOTTOM = -SPHERE_R;
constant float POST_TOP = 0.0;
constant float ELECTRODE_R = 0.095;       // radius of the rounded electrode ball at top of post
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

// --- Profiled center post (tapered/lathe-turned shape via SDF) ---

struct PostResult {
    float t;          // hit distance along ray (-1 if miss)
    float3 normal;    // surface normal at hit point
};

// Profile function: returns radius of post as a function of Y position.
// Bottom (y=POST_BOTTOM) is a wide rounded base, top (y=POST_TOP) is a narrow stem.
static float postRadius(float y) {
    // Normalize y: 0 = bottom, 1 = top
    float t = (y - POST_BOTTOM) / (POST_TOP - POST_BOTTOM);
    t = clamp(t, 0.0, 1.0);

    // Bottom dome/base region (t=0..0.3): wide rounded base
    float baseR = 0.08;
    // Subtle dome bulge near the very bottom
    float dome = 1.0 + 0.15 * smoothstep(0.15, 0.0, t);
    float bottom = baseR * dome;

    // Middle taper region (t=0.3..0.8): gentle taper from ~0.045 to ~0.028
    float midTop = 0.028;
    float midBot = 0.045;
    float midT = smoothstep(0.3, 0.8, t);
    float middle = mix(midBot, midTop, midT);

    // Top stem region (t=0.8..1.0): narrow stem with slight flare at electrode
    float stemR = 0.028;
    float flare = 1.0 + 0.08 * smoothstep(0.9, 1.0, t);
    float top = stemR * flare;

    // Blend regions together smoothly
    float blend1 = smoothstep(0.2, 0.35, t);  // bottom -> middle
    float blend2 = smoothstep(0.7, 0.85, t);  // middle -> top
    float r = mix(bottom, middle, blend1);
    r = mix(r, top, blend2);

    return r;
}

// Signed distance function for the profiled post + electrode sphere.
// Negative = inside, positive = outside.
// Union of the tapered post body and a sphere at the top (electrode ball).
static float postSDF(float3 p) {
    // --- Tapered post body (surface of revolution) ---
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

    // --- Electrode sphere at top of post ---
    float dSphere = length(p - float3(0.0, POST_TOP, 0.0)) - ELECTRODE_R;

    // Union: take the closer (minimum) surface
    return min(dPost, dSphere);
}

// Ray vs profiled post + electrode sphere intersection.
// Uses hybrid analytical bounding + SDF sphere-tracing.
static PostResult profiledPostHit(float3 ro, float3 rd) {
    PostResult result;
    result.t = -1.0;
    result.normal = float3(0.0);

    // Compute bounding intervals for two regions:
    // 1) Bounding cylinder (POST_RADIUS_MAX) clamped to Y range for the tapered post
    // 2) Bounding sphere (ELECTRODE_R) for the electrode ball at top

    float tEntry = 1e20;
    float tExit = -1e20;

    // --- Bounding cylinder for tapered post body ---
    float cylA = rd.x * rd.x + rd.z * rd.z;
    float cylB = 2.0 * (ro.x * rd.x + ro.z * rd.z);
    float cylC = ro.x * ro.x + ro.z * ro.z - POST_RADIUS_MAX * POST_RADIUS_MAX;
    float cylDisc = cylB * cylB - 4.0 * cylA * cylC;

    if (cylDisc >= 0.0 && cylA > 1e-8) {
        float sqrtDisc = sqrt(cylDisc);
        float cEntry = (-cylB - sqrtDisc) / (2.0 * cylA);
        float cExit  = (-cylB + sqrtDisc) / (2.0 * cylA);

        // Clamp to Y range
        if (abs(rd.y) > 1e-8) {
            float tBot = (POST_BOTTOM - ro.y) / rd.y;
            float tTop = (POST_TOP - ro.y) / rd.y;
            cEntry = max(cEntry, min(tBot, tTop));
            cExit  = min(cExit,  max(tBot, tTop));
        } else if (ro.y < POST_BOTTOM || ro.y > POST_TOP) {
            cEntry = 1e20; cExit = -1e20; // invalidate
        }

        if (cEntry < cExit) {
            tEntry = min(tEntry, cEntry);
            tExit  = max(tExit,  cExit);
        }
    }

    // --- Bounding sphere for electrode ball ---
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
    if (tEntry >= tExit) return result; // no valid interval

    // SDF sphere-tracing within the combined bounded interval
    float t = tEntry;
    for (int i = 0; i < 16; i++) {
        float3 p = ro + rd * t;
        float d = postSDF(p);
        if (d < 0.001) {
            result.t = t;

            // Normal via central-difference gradient of SDF
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
    float forkPoint;       // parametric t along tendril where branching starts (0.3-0.6)
    float3 branchOffset1;  // perpendicular offset direction for branch 1
    float3 branchOffset2;  // perpendicular offset direction for branch 2
    int branchCount;       // 1 or 2 branches
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

    float bias = 0.0;
    if (touchActive > 0.5) {
        float angularDist = acos(clamp(dot(baseDir, touchDir), -1.0, 1.0)) / M_PI_F;
        float proximity = 1.0 - angularDist;
        float attraction = pow(proximity, 0.6);

        bias = mix(0.05, 0.92, attraction) + 0.08 * fract(fi * 0.37);
        bias = clamp(bias, 0.0, 1.0);
        baseDir = normalize(mix(baseDir, touchDir, bias));
    }

    float3 up = abs(baseDir.y) < 0.99 ? float3(0, 1, 0) : float3(1, 0, 0);
    float3 rt = normalize(cross(baseDir, up));
    float3 fw = cross(rt, baseDir);

    // Deterministic per-tendril hash for branch parameters
    float hash1 = fract(fi * 0.7631 + 0.123);
    float hash2 = fract(fi * 0.4519 + 0.789);
    float hash3 = fract(fi * 0.9137 + 0.456);

    TendrilInfo info;
    info.dir = baseDir;
    info.right = rt;
    info.fwd = fw;
    info.touchBias = bias;

    // Fork at 30-60% along tendril length
    info.forkPoint = 0.3 + hash1 * 0.3;

    // Branch divergence directions (perpendicular to tendril)
    float angle1 = hash2 * M_PI_F * 2.0 + time * 0.05;
    info.branchOffset1 = normalize(rt * cos(angle1) + fw * sin(angle1));
    float angle2 = angle1 + M_PI_F * 0.6 + hash3 * 0.4;
    info.branchOffset2 = normalize(rt * cos(angle2) + fw * sin(angle2));

    // ~60% get 2 branches, ~40% get 1
    info.branchCount = (hash3 > 0.4) ? 2 : 1;

    return info;
}

fragment float4 plasmaGlobeFragment(VertexOut in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(0)]],
                                     texture2d<float> noiseTex [[texture(0)]]) {

    constexpr sampler smp(filter::linear, address::repeat);

    float2 uv = (in.uv * uniforms.resolution - 0.5 * uniforms.resolution) / uniforms.resolution.y;
    float time = uniforms.time;

    // Camera — slow orbit (freezes during touch)
    float camAngle = uniforms.cameraTime * 0.12;
    float3 ro = float3(sin(camAngle) * uniforms.cameraDistance, sin(uniforms.cameraTime * 0.04) * 0.15, cos(camAngle) * uniforms.cameraDistance);
    float3 ww = normalize(-ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = cross(uu, ww);
    float3 rd = normalize(uv.x * uu + uv.y * vv + 1.6 * ww);

    // Map touch to world-space direction on sphere
    float3 touchDir = float3(0, 0, 1);
    if (uniforms.touchActive > 0.5) {
        float2 tuv = uniforms.touchPosition - 0.5;
        tuv.x *= uniforms.resolution.x / uniforms.resolution.y;
        float3 touchRd = normalize(tuv.x * uu - tuv.y * vv + 1.6 * ww);
        float2 tHit = sphereHit(ro, touchRd, SPHERE_R);
        if (tHit.x > 0.0) {
            touchDir = normalize(ro + touchRd * tHit.x);
        }
    }

    // Pre-compute tendril data
    TendrilInfo tendrils[12];
    for (int j = 0; j < NUM_TENDRILS; j++) {
        tendrils[j] = computeTendril(j, time, touchDir, uniforms.touchActive);
    }

    float3 color = float3(0.0);
    float2 hit = sphereHit(ro, rd, SPHERE_R);

    if (hit.x > 0.0) {
        float3 entry = ro + rd * hit.x;
        float pathLen = hit.y - hit.x;
        float3 normal = normalize(entry);

        // === Center post (profiled SDF intersection) ===
        PostResult postHit = profiledPostHit(ro, rd);
        bool hitPost = (postHit.t > 0.0 && postHit.t >= hit.x && postHit.t <= hit.y);
        float3 postColor = float3(0.0);

        if (hitPost) {
            // Clamp ray-march to stop at the post surface
            pathLen = postHit.t - hit.x;

            // Metallic post shading
            float3 postNorm = postHit.normal;
            float3 lightDir = normalize(float3(0.5, 1.0, 0.8));
            float3 lightDir2 = normalize(float3(-0.3, 0.5, -0.6));

            // Dark metallic base color
            float3 baseMetalColor = float3(0.04, 0.04, 0.05);

            // Diffuse
            float diff = max(dot(postNorm, lightDir), 0.0) * 0.3;
            float diff2 = max(dot(postNorm, lightDir2), 0.0) * 0.15;

            // Specular highlights (metallic sheen)
            float spec = pow(max(dot(reflect(rd, postNorm), lightDir), 0.0), 60.0);
            float spec2 = pow(max(dot(reflect(rd, postNorm), lightDir2), 0.0), 40.0);

            postColor = baseMetalColor + float3(0.08, 0.08, 0.1) * (diff + diff2)
                       + float3(0.25, 0.25, 0.35) * spec * 0.4
                       + float3(0.15, 0.15, 0.25) * spec2 * 0.2;

            // Subtle plasma glow reflection near the top (electrode region)
            float3 postPoint = ro + rd * postHit.t;
            float topProximity = smoothstep(-0.15, 0.0, postPoint.y);
            postColor += float3(0.15, 0.1, 0.3) * topProximity * 0.5;
        }

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

            // Skip samples inside the profiled post
            if (postSDF(pos) < 0.0) continue;

            half3 totalColor = half3(0.0h);

            for (int j = 0; j < NUM_TENDRILS; j++) {
                float fj = float(j);
                float3 tDir = tendrils[j].dir;
                float3 tRight = tendrils[j].right;
                float3 tFwd = tendrils[j].fwd;

                // Project pos onto the tendril line (origin -> tDir)
                float along = dot(pos, tDir);
                float3 perp = pos - tDir * along;

                // Quick-reject: skip tendril if sample is too far away
                float perpLen = length(perp);
                if (perpLen > QUICK_REJECT_DIST) continue;

                // Noise displacement perpendicular to tendril
                // First octave — large bends
                float3 np1 = float3(along * 3.0, fj * 13.7 + time * 0.3, fj * 7.1);
                float nx1 = tnoise(np1, noiseTex, smp) - 0.5;
                float ny1 = tnoise(np1 + float3(97, 0, 0), noiseTex, smp) - 0.5;

                // Displacement grows with distance from center (tighter for thin tendrils)
                float dispAmt = max(along, 0.0) * 0.22;
                float3 noiseDisp = (tRight * nx1 + tFwd * ny1) * dispAmt;

                // Second octave — fine lightning jitter (skip near center)
                if (along > 0.15) {
                    float3 np2 = float3(along * 7.0, fj * 23.1 + time * 0.5, fj * 17.3);
                    float nx2 = tnoise(np2, noiseTex, smp) - 0.5;
                    float ny2 = tnoise(np2 + float3(197, 0, 0), noiseTex, smp) - 0.5;
                    noiseDisp += (tRight * nx2 + tFwd * ny2) * dispAmt * 0.3;
                }

                // 3D distance from sample to displaced tendril (trunk)
                float dist = length(perp - noiseDisp);

                // Thinner tendril profile
                float coreW = 0.015 + along * 0.008;
                float glowW = 0.045 + along * 0.030;
                half core = half(exp(-dist * dist / (coreW * coreW)));
                half glow = half(fast::exp(-dist * dist / (glowW * glowW)));

                // Fade near center and surface
                float surfaceMargin = mix(0.05, 0.005, tendrils[j].touchBias);
                half fade = half(smoothstep(CORE_R, CORE_R + 0.12, along) *
                             smoothstep(SPHERE_R, SPHERE_R - surfaceMargin, along));

                // Position-dependent color: pink at base/tips, blue in middle
                float t = saturate((along - CORE_R) / (SPHERE_R - CORE_R));
                half midBlend = half(smoothstep(0.0, 0.35, t) - smoothstep(0.65, 1.0, t));

                half3 coreColor = mix(half3(1.0h, 0.7h, 0.85h),    // pink at extremes
                                      half3(0.85h, 0.85h, 1.0h),     // white-blue in middle
                                      midBlend);
                half3 glowColor = mix(half3(0.85h, 0.25h, 0.65h),   // magenta at extremes
                                      half3(0.45h, 0.25h, 0.9h),     // purple in middle
                                      midBlend);

                totalColor += coreColor * core * fade;
                totalColor += glowColor * glow * fade * 0.23h;
                totalColor += half3(0.8h, 0.2h, 0.6h) * glow * glow * fade * fade * 0.005h;

                // === Branching ===
                // Only evaluate branches past the fork point
                if (along > tendrils[j].forkPoint) {
                    float branchT = (along - tendrils[j].forkPoint) / (1.0 - tendrils[j].forkPoint);
                    // Smooth fade-in for branches
                    float branchFadeIn = smoothstep(0.0, 0.15, branchT);
                    // Branch spread increases with distance past fork
                    float spread = branchT * 0.12;

                    // Branch 1
                    float3 branchDisp1 = noiseDisp + tendrils[j].branchOffset1 * spread;
                    float bDist1 = length(perp - branchDisp1);
                    float bCoreW = 0.011 + along * 0.005;
                    float bGlowW = 0.030 + along * 0.018;
                    half bCore1 = half(exp(-bDist1 * bDist1 / (bCoreW * bCoreW)));
                    half bGlow1 = half(fast::exp(-bDist1 * bDist1 / (bGlowW * bGlowW)));
                    half bFade1 = fade * half(branchFadeIn) * 0.7h;
                    totalColor += coreColor * bCore1 * bFade1;
                    totalColor += glowColor * bGlow1 * bFade1 * 0.23h;

                    // Branch 2 (if this tendril has 2 branches)
                    if (tendrils[j].branchCount > 1) {
                        float3 branchDisp2 = noiseDisp + tendrils[j].branchOffset2 * spread;
                        float bDist2 = length(perp - branchDisp2);
                        half bCore2 = half(exp(-bDist2 * bDist2 / (bCoreW * bCoreW)));
                        half bGlow2 = half(fast::exp(-bDist2 * bDist2 / (bGlowW * bGlowW)));
                        half bFade2 = fade * half(branchFadeIn) * 0.7h;
                        totalColor += coreColor * bCore2 * bFade2;
                        totalColor += glowColor * bGlow2 * bFade2 * 0.23h;
                    }
                }
            }

            totalColor = min(totalColor, half3(5.0h));
            half3 stepCol = totalColor;

            // Central electrode glow
            half cg = half(fast::exp(-r * 12.0)) * 3.0h;
            stepCol += half3(0.6h, 0.7h, 1.0h) * cg;

            plasma += stepCol * half(dt);

            // Early exit: values above ~3.0 per channel saturate after tone mapping
            if (dot(plasma, plasma) > 9.0h) break;
        }

        // === Touch contact glow ===
        if (uniforms.touchActive > 0.5) {
            float surfaceDot = dot(normal, touchDir);
            float contactGlow = pow(max(surfaceDot, 0.0), 80.0) * 2.5;
            float contactHalo = pow(max(surfaceDot, 0.0), 15.0) * 0.4;
            float3 contactColor = float3(0.9, 0.9, 1.0) * contactGlow
                                + float3(0.4, 0.3, 0.8) * contactHalo;
            plasma += half3(contactColor);
        }

        color = float3(plasma) + shellColor;

        // Add post color (opaque, replaces background behind it)
        if (hitPost) {
            // Blend post with accumulated plasma in front of it
            color += postColor;
        }

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
