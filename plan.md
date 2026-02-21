# PlasmaGlobeIOS Productization Plan

## Overview
Transform Phase Zen from a single-feature demo into a marketable product with a Free + IAP unlock model. Core additions: breathing/meditation mode, video capture & sharing, expanded theme library, and IAP infrastructure.

---

## Phase 1: Breathing / Meditation Mode

The flagship new feature — gives users a reason to open the app daily.

### 1A. Breathing Engine (`Breathing/BreathingEngine.swift`)
- New `BreathingEngine` ObservableObject that drives a breathing cycle state machine
- States: `.idle`, `.inhale`, `.hold`, `.exhale`, `.holdAfterExhale`
- Configurable patterns:
  - **Box Breathing**: 4s in / 4s hold / 4s out / 4s hold
  - **4-7-8 Relaxation**: 4s in / 7s hold / 8s out
  - **Calm Breathing**: 4s in / 6s out (no holds)
  - **Custom**: user-configurable durations
- Publishes `breathPhase: Float` (0.0→1.0 within each state) and `cyclePhase: Float` (0.0→1.0 across full cycle)
- Optional session timer (1, 3, 5, 10, 15, 20 minutes) with gentle fade-out at end

### 1B. Globe Visual Response
- Pass `breathPhase` + breathing state into `Uniforms` struct → shader
- During inhale: tendrils slowly brighten and expand outward (thickness + brightness ramp up)
- During hold: tendrils gently pulse at current intensity
- During exhale: tendrils dim and contract inward, slow their movement
- Subtle globe glow radius pulses with breathing cycle
- Tendrils move slower overall during breathing mode (calmer motion)

### 1C. Breathing UI Overlay
- Minimalist breathing guide overlay (does NOT obscure the globe):
  - Thin circular ring around the globe that expands/contracts with breath
  - Soft text label: "Breathe In" / "Hold" / "Breathe Out" — fades in/out
  - Small timer display showing remaining session time
- Tap to start/stop breathing mode
- Settings integration: breathing pattern picker, session duration picker
- Auto-dims other UI (gear icon fades to near-invisible during session)

### 1D. Audio Integration
- Hum tone gently modulates with breathing (pitch bends slightly down on exhale)
- Optional soft chime at phase transitions (reuse crystalline chime synthesizer)
- Volume follows breath: slightly louder on inhale, quieter on exhale

### 1E. Haptic Integration
- Gentle haptic pulse at start of each inhale (cue to breathe in)
- Softer pulse at start of exhale
- Session-complete haptic pattern (three gentle taps)

---

## Phase 2: Screenshot & Video Capture + Sharing

### 2A. Screenshot Capture
- Capture current Metal drawable to UIImage
- Add a "capture" button to the UI (camera icon, appears near gear icon)
- Save to Photos or present share sheet directly

### 2B. Video Recording
- Use `ReplayKit` (RPScreenRecorder) to record 5-15 second clips of the globe
- Or: capture Metal textures frame-by-frame into AVAssetWriter for higher quality
- Record button with visual indicator (pulsing red dot)
- Auto-stop after configurable duration (5s, 10s, 15s)
- Include audio from the procedural audio engine in the recording

### 2C. Share Sheet Integration
- Standard iOS share sheet (UIActivityViewController) for photos and videos
- Pre-populated share text: "Created with Phase Zen" (subtle app promotion)
- Support sharing to Instagram Stories, TikTok, iMessage, etc.

### 2D. Optional Watermark (Free tier)
- Small, semi-transparent "Phase Zen" watermark in corner for free-tier captures
- Removed when premium is unlocked (IAP incentive)

---

## Phase 3: Expanded Theme Library

### 3A. New Predefined Themes (8-10 total, up from 3)
Add these carefully designed themes:
- **Ember**: Warm oranges and deep reds — cozy campfire feel
- **Ocean**: Deep blues and cyan — underwater bioluminescence
- **Aurora**: Greens and teals shifting to purple — northern lights
- **Neon**: Hot pink and electric cyan — retro synthwave
- **Moonlight**: Silver-white and pale blue — cool, serene
- **Solar**: Bright yellow-orange to white — solar plasma
- **Lavender**: Soft purples and pinks — calming, feminine
- **Toxic**: Acid green and yellow — energetic, playful

### 3B. Theme Preview Enhancement
- Show all themes in a scrollable grid rather than 3 circles
- Each preview shows a small rendered globe thumbnail or color gradient
- Group into "Free" (Custom + 3-4 themes) and "Premium" (remaining themes)

### 3C. Animated Theme Transitions
- When switching themes, colors cross-fade smoothly over ~2 seconds
- Interpolate tendril and endpoint colors in HSB space for natural-looking transitions

---

## Phase 4: IAP Infrastructure

### 4A. StoreKit 2 Integration (`Store/StoreManager.swift`)
- Single non-consumable product: "Phase Zen Premium" ($0.99 or $1.99)
- Use StoreKit 2 (modern async/await API, iOS 15+)
- Handle purchase, restoration, and receipt validation
- Persist entitlement via `Transaction.currentEntitlements`

### 4B. Feature Gating
- **Free tier includes:**
  - Full plasma globe interaction (touch, pinch, tilt, discharge)
  - Custom theme + 3-4 predefined themes
  - Basic sound (hum + 2 discharge styles)
  - Breathing mode with "Calm Breathing" pattern only
  - Screenshot capture (with watermark)
- **Premium unlock adds:**
  - All 10+ themes
  - All 5+ discharge sound styles
  - All breathing patterns + custom durations
  - Video capture
  - Watermark-free captures
  - Future content updates included

### 4C. Premium Upsell UI
- Non-intrusive: locked features show a small lock icon
- Tapping a locked feature shows a clean modal: "Unlock Phase Zen Premium"
- List of premium features, price, and "Purchase" / "Restore" buttons
- No dark patterns, no nagging — one-time purchase, permanent unlock

---

## Phase 5: Polish & Productization

### 5A. Onboarding (First Launch)
- 3-4 screen tutorial with animated illustrations:
  1. "Touch the globe" — tendrils follow your fingers
  2. "Double tap for discharge" — lightning flash demo
  3. "Tilt your device" — parallax effect
  4. "Breathe with the globe" — breathing mode intro
- Skip button always visible, auto-advances after 5s per screen
- Only shown once (persisted via @AppStorage)

### 5B. Sleep Timer
- Simple timer (15, 30, 45, 60 min) accessible from settings
- Globe and audio gradually fade to black over final 60 seconds
- Screen dims to minimum brightness
- Low implementation effort, high practical value for bedside use

### 5C. App Icon Variants
- 2-3 alternate app icons (different color themes) — premium perk
- Selectable from settings

---

## Implementation Order (Recommended)

| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| 1 | Breathing Engine + Globe Response | Medium | High — core differentiator |
| 2 | Breathing UI Overlay | Medium | High — makes feature usable |
| 3 | Expanded Themes (3B first, then 3A) | Low-Med | Medium — visual variety |
| 4 | Screenshot Capture + Share | Low | High — enables organic growth |
| 5 | Video Recording + Share | Medium | High — TikTok/IG content |
| 6 | IAP Infrastructure | Medium | Required for monetization |
| 7 | Feature Gating + Upsell UI | Low-Med | Required for monetization |
| 8 | Onboarding | Low | Medium — improves retention |
| 9 | Sleep Timer | Low | Medium — bedside use case |
| 10 | Watermark system | Low | Low — IAP incentive |

---

## Files to Create / Modify

**New files:**
- `Breathing/BreathingEngine.swift` — breathing state machine
- `Breathing/BreathingPattern.swift` — pattern definitions enum
- `Breathing/BreathingOverlayView.swift` — breathing UI overlay
- `Capture/CaptureManager.swift` — screenshot + video capture
- `Capture/ShareSheet.swift` — UIActivityViewController wrapper
- `Store/StoreManager.swift` — StoreKit 2 IAP manager
- `Store/PremiumUpsellView.swift` — purchase modal
- `Onboarding/OnboardingView.swift` — first-run tutorial

**Modified files:**
- `Uniforms.swift` — add breathing phase + state uniforms
- `Shaders.metal` — respond to breathing uniforms (brightness, thickness, speed modulation)
- `PlasmaRenderer.swift` — pass breathing data to GPU, capture Metal textures
- `PlasmaSettings.swift` — add breathing pattern, session duration, sleep timer settings
- `SettingsOverlay.swift` — add breathing, capture, and premium sections
- `ContentView.swift` — integrate breathing overlay, onboarding, capture UI
- `ColorTheme.swift` — add 7-8 new theme definitions
- `AudioManager.swift` — breathing-aware audio modulation
- `HapticManager.swift` — breathing haptic patterns
- `TouchHandler.swift` — breathing mode touch behavior (disable convergence during breathing?)
- `project.yml` — add new source groups, StoreKit configuration
