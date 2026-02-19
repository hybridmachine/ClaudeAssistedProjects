#include "PlasmaCommon.h"

// Plasma Globe Fragment Shader
// Ray-marched volumetric tendrils radiating from a central electrode
// inside a glass sphere. Supports multi-touch (up to 5 fingers),
// force/pressure modulation, configurable colors, and discharge flash.

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
        int stepCount = int(clamp(pathLen * 18.0, 14.0, float(VOL_STEPS)));
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

                // Fork tongue: smooth-min blending of two displaced prongs
                float dist;
                float forkTaper = 1.0;
                if (tendrils[j].hasForkTongue != 0 && along > tendrils[j].forkTongueStart) {
                    float forkT = (along - tendrils[j].forkTongueStart)
                                / (SPHERE_R - tendrils[j].forkTongueStart);
                    float spread = forkT * forkT * 0.06;

                    float3 prong1 = noiseDisp + tendrils[j].forkTongueDir * spread;
                    float3 prong2 = noiseDisp - tendrils[j].forkTongueDir * spread;

                    float dist1 = length(perp - prong1);
                    float dist2 = length(perp - prong2);

                    // Polynomial smooth minimum (k=0.012) for organic junction
                    float k = 0.012;
                    float h = clamp(0.5 + 0.5 * (dist2 - dist1) / k, 0.0, 1.0);
                    float smin = mix(dist2, dist1, h) - k * h * (1.0 - h);

                    float singleDist = length(perp - noiseDisp);
                    // Blend from single tendril to forked over first 25% of fork zone
                    float blendIn = smoothstep(0.0, 0.25, forkT);
                    dist = mix(singleDist, smin, blendIn);

                    // Prongs thin to 80% width at tips
                    forkTaper = mix(1.0, 0.8, blendIn * forkT);
                } else {
                    dist = length(perp - noiseDisp);
                }

                // Force modulates width (+50% at max force)
                float forceWidth = 1.0 + (fScale - 1.0) * 0.625;
                float taper = (1.0 - along * 0.3) * forkTaper;
                float coreW = 0.015 * thickness * forceWidth * taper;
                float glowW = (0.035 + along * 0.015) * thickness * forceWidth * forkTaper;
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
                if (along > tendrils[j].forkPoint && dist < 0.12) {
                    float branchT = (along - tendrils[j].forkPoint) / (1.0 - tendrils[j].forkPoint);
                    half branchFadeIn = half(smoothstep(0.0, 0.15, branchT));
                    float spread = branchT * 0.07;

                    float3 branchDisp1 = noiseDisp + tendrils[j].branchOffset1 * spread;
                    totalColor += computeBranchContribution(perp, branchDisp1, along, thickness,
                                    forceWidth, fade, forceBright, branchFadeIn, whiteCore, glowColor);

                    if (tendrils[j].branchCount > 1) {
                        float3 branchDisp2 = noiseDisp + tendrils[j].branchOffset2 * spread;
                        totalColor += computeBranchContribution(perp, branchDisp2, along, thickness,
                                        forceWidth, fade, forceBright, branchFadeIn, whiteCore, glowColor);
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

            if (dot(plasma, plasma) > 4.0h) break;
        }

        // === Per-tendril glass termination glow ===
        for (int j = 0; j < numTendrils; j++) {
            float3 tDir = tendrils[j].dir;
            half3 haloBase = config.rainbowMode != 0
                ? rainbowColor(tendrils[j].colorSeed)
                : mix(half3(config.glowColorA.rgb), half3(config.glowColorB.rgb), 0.5h);

            if (tendrils[j].hasForkTongue != 0) {
                // Two glow spots for forked tendrils, one per prong endpoint
                float3 forkDir = tendrils[j].forkTongueDir;
                float forkSpread = 0.06; // max spread at surface
                float3 glassPoint1 = normalize(tDir + forkDir * forkSpread) * SPHERE_R;
                float3 glassPoint2 = normalize(tDir - forkDir * forkSpread) * SPHERE_R;

                for (int p = 0; p < 2; p++) {
                    float3 glassNormal = normalize(p == 0 ? glassPoint1 : glassPoint2);
                    float surfaceDot = max(dot(normal, glassNormal), 0.0);
                    if (surfaceDot < 0.05) continue;
                    half tightSpot = half(pow(surfaceDot, 60.0) * 0.07);
                    half wideHalo = half(pow(surfaceDot, 12.0) * 0.007);
                    half3 spotColor = half3(0.9h, 0.92h, 1.0h) * tightSpot;
                    half3 haloColor = haloBase * wideHalo;
                    plasma += spotColor + haloColor;
                }
            } else {
                // Single glow spot for non-forked tendrils
                float3 glassPoint = normalize(tDir) * SPHERE_R;
                float3 glassNormal = normalize(glassPoint);
                float surfaceDot = max(dot(normal, glassNormal), 0.0);
                if (surfaceDot < 0.05) continue;
                half tightSpot = half(pow(surfaceDot, 60.0) * 0.1);
                half wideHalo = half(pow(surfaceDot, 12.0) * 0.010);
                half3 spotColor = half3(0.9h, 0.92h, 1.0h) * tightSpot;
                half3 haloColor = haloBase * wideHalo;
                plasma += spotColor + haloColor;
            }
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

// Composite pass: samples half-res offscreen plasma texture and outputs for additive blend
fragment float4 compositeFragment(VertexOut in [[stage_in]],
                                   texture2d<float> offscreen [[texture(0)]]) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float2 uv = float2(in.uv.x, 1.0 - in.uv.y);
    return offscreen.sample(smp, uv);
}
