# PRANA UI/UX Polish — Implementation Plan

## Overview

The existing PRANA codebase has a **solid foundation**: a coherent color palette (`AppColors`), a clean typography system (`AppTypography`), a spacing system (`AppSpacing`/`AppRadius`/`AppShadows`), well-abstracted shared widgets (`AppCard`, `StatusPill`, `SectionHeader`, `HealthMetricCard`, `StatTile`, etc.), and a Material 3 theme. The business logic is completely separate from the UI layer.

The **gaps** that this plan addresses:

1. **Dashboard header** — Lacks greeting/context. The title is a plain logo. The offline badge is small and easy to miss.
2. **Dashboard risk hero** — `RiskScoreGauge` at size 200 is a large decorative centrepiece in a card; replacing it with a more compact, information-dense layout will make the card feel premium, not template-y.
3. **Dashboard connection banner** — Plain card + ElevatedButton. Should be a polished empty state.
4. **HealthMetricCard grid** — `childAspectRatio: 1.12` may clip on small screens. Cards look functional but not premium.
5. **Health screen** — Large `displayMedium` metric on a white card is stark. Chart area needs breathing room. The "EDGE AI BASELINE INSIGHT" label is slightly heavy.
6. **Insights `_DomainCard`** — Looks reasonable; needs consistent spacing, slightly better progress bar treatment.
7. **Emergency screen** — Idle state icon (circle + emergency icon) is basic. The countdown state has `displayLarge.fontSize: 68` which is right, but the surrounding layout could be tighter and more authoritative.
8. **Device screen** — No disconnected empty state. Shows '--' values when disconnected rather than a clear message.
9. **Profile screen** — `SectionHeader` top padding creates a large gap; the page feels long. Settings section has no visual grouping separating it from emergency contacts.
10. **Privacy screen** — Dark gradient hero card is a strong choice but text contrast can be improved.
11. **Demo Lab** — Looks fine as a debug screen. Minor polish only.
12. **Missing shared components** — No `EmptyState` widget, no `LoadingShimmer` widget. Many screens show `--` text in place of proper empty states.
13. **Page transitions** — Default `MaterialPageRoute` pushes are instant. A gentle horizontal slide is more polished.
14. **SOS button** — The glow shadow (`AppShadows.glow`) is a strong colour. Can be toned down slightly while keeping the button prominent.
15. **OfflineStatusBadge** — Shows `labelCaps` which doubles as letter-spacing; at size 11 with full uppercase it reads as tiny. Better: slightly larger text or a different hierarchy.
16. **Typography** — The comment in `app_theme.dart` says "No fontFamily override because pubspec declares no font assets". We should add Google Fonts (`Inter` or `DM Sans`) via the `google_fonts` package **if it's already a dependency**; otherwise not, per the performance rule.
17. **AppSegmentedControl** — Let me check its implementation to assess if improvements are needed.

---

## Assessment: What's Already Good

The following are **already well-implemented** and need only minor or zero changes:
- `AppColors` — restrained, semantic, excellent palette
- `AppTypography` — clear scale, tabular figures for metrics
- `AppSpacing` / `AppRadius` / `AppShadows` — complete token system
- `AppCard` — single canonical container, no drift
- `StatusPill` — single canonical badge
- `SectionHeader` — consistent, uses design tokens
- `RiskScoreGauge` — animated arc is professional; keep as-is, just reduce size from 200 → 160 for density
- `HealthMetricCard` — well-structured; fix aspect ratio
- `DemoLabScreen` — already uses dark terminal code-block style appropriately
- `PrivacyScreen` — hero card is fine; only minor text contrast adjustment needed

---

## Proposed Changes

---

### Component Layer — New Shared Widgets

#### [NEW] `lib/shared/widgets/empty_state.dart`
A reusable widget for disconnected / no-data / error states:
```
icon (large, muted)
title (headline)
subtitle (body)
optional action button
```
Used across: Dashboard disconnect banner, Device screen (disconnected), Health/Insights (no data).

#### [NEW] `lib/shared/widgets/loading_shimmer.dart`
A simple shimmer skeleton using `AnimatedBuilder` + `LinearGradient` (no extra package).
Used on: metric cards while `hasData == false`.

---

### Design System — Minor Theme Fixes

#### [MODIFY] `lib/core/theme/app_theme.dart`
- Remove `splashFactory: InkSparkle.splashFactory` — `InkSparkle` can produce visual noise on some Android versions; replace with `InkRipple.splashFactory` which is quieter
- Add `scrolledUnderElevation: 1` so AppBar gets a subtle shadow when scrolled (production polish cue)
- `progressIndicatorTheme.linearMinHeight` → `6` (slightly slimmer bars look more refined than 8)

#### [MODIFY] `lib/core/constants/app_colors.dart`
No color changes — palette is correct. Add two helpers:
- `static const Color surfaceHero = Color(0xFFF0F4F8);` — a slightly blue-tinted off-white for hero card backgrounds, slightly distinct from `background`
- `static Color riskColorFor(double score)` — static helper so screens don't repeat the if-chain

---

### App Shell

#### [MODIFY] `lib/app/app.dart`
**Navigation bar:**
- The SOS button glow shadow: reduce `alpha` from `0.32` → `0.22`
- Add `HapticFeedback.lightImpact()` on nav tile tap (already there via `selectionClick`, which is fine — keep)
- Nav bar `height: 72` → `68` — slightly more compact on small phones

**Page transitions:**
- Wrap `Navigator.of(context).push(MaterialPageRoute(...))` calls with a custom `_slideRoute()` helper that produces a gentle horizontal slide (150ms, `easeOut`)

---

### Dashboard Screen

#### [MODIFY] `lib/features/dashboard/dashboard_screen.dart`

**AppBar header (lines 46–80):**
- Replace plain `Text('PRANA')` title with a two-line greeting:
  - Line 1: small caps time-of-day greeting ("Good morning" / "Good afternoon" / "Good evening")
  - Line 2: `PRANA` brand in its current style
- Move `OfflineStatusBadge` to be a `leading`-positioned indicator dot (not an action)
- Add a circular avatar button (initial letter, primary color) in `actions`

**Risk hero card (lines 92–126):**
- Reduce `RiskScoreGauge` size from `200` → `160`
- Add a one-line contextual explanation below the trend ("Based on your last 20 minutes of telemetry")
- Hero card: change `elevated: true` to use a custom `AppColors.surfaceHero` tint background rather than plain white — makes it feel elevated without a heavy shadow

**Connection banner (lines 350–387):**
- Replace with new `EmptyState` widget (icon: `Icons.bluetooth_searching_rounded`, title: "Wearable not connected", subtitle: "Connect your PRANA sensor band to start receiving live biometrics.", CTA: "Connect Sensor")

**Section spacing:**
- The gap between the hero card and `SectionHeader("What's Driving It")` jumps from `gapSm` to a `SectionHeader` with `top: 24` — total 36px. Reduce the `SectionHeader` top padding from 24 → 20 for a tighter rhythm.

---

### Vitals / Health Screen

#### [MODIFY] `lib/features/health/health_screen.dart`

**`_MetricDetailView` hero card (lines 277–323):**
- Add a coloured left accent border `(4px wide, `accent` color)` to the hero card so each metric has instant visual identity
- The big `displayMedium` value on white is stark; add a subtle tinted background: `accent.withValues(alpha: 0.04)`
- `baselineText` → style upgrade: make it a labelled row with an icon (`Icons.tune_rounded` already used in `HealthMetricCard`) instead of plain body text

**No-data state:**
- When `!hasData`, the chart shows an empty grid. Add an `EmptyState` overlay inside the chart area instead of the empty chart.

**`EDGE AI BASELINE INSIGHT` label:**
- Change from `labelCaps` to a smaller `labelMedium` variant — less aggressive while still distinctive

---

### Insights Screen

#### [MODIFY] `lib/features/insights/insights_screen.dart`

**`_DomainCard`:**
- Add `animateValue: true` — animate the `LinearProgressIndicator` from 0 using `AnimatedBuilder` (reuse the same pattern as `RiskScoreGauge`)
- Add a small colored left-border accent (4px) to the domain card matching `color` parameter — visual consistency with the health screen hero

**`_AnalysisView` clinical feed:**
- The `InfoRow` stack in a card with no header label feels anonymous — add a `CLINICAL ANALYSIS` caps label at the top of the card

---

### Environment Screen

#### [MODIFY] `lib/features/environment/environment_screen.dart`

**`_EnvCard` grid:**
- Currently `childAspectRatio: 1.15`. On a 360dp screen each cell is ~163px wide × 141px tall — fine for the icon/value/label, but could clip on older devices. Change to `childAspectRatio: 1.1` and add `mainAxisAlignment: MainAxisAlignment.start` with explicit spacing.
- Add a risk-state colored dot on each card when values exceed thresholds (e.g., humidity > 70, AQI > 150)

**Disconnect state:**
- The `ElevatedButton.icon` at the top is a functional action but looks like an inline control dropped onto the scroll view. Replace with an `EmptyState` widget when not connected and not in mock mode.

---

### Emergency Screen

#### [MODIFY] `lib/features/emergency/emergency_screen.dart`

**Idle state:**
- The plain circle + `Icons.emergency_rounded` is too simple for the critical function of this screen
- Improve layout: use a larger ring (80px diameter, 3px border), the icon centered inside, and place it inside a dedicated hero area with a subtle ambient background wash
- Add a "How it works" info card below the SOS button explaining the two-step trigger: "Pressing this starts a 10-second countdown. You can cancel at any time."

**Countdown state:**
- Already strong. Add a `CountdownProgressArc` — a thin circular arc around the icon container that sweeps from 100% to 0% in 10 seconds using a `StreamBuilder` on `countdownStream`. This gives spatial and temporal context.
- Make "SEND SOS NOW" button's bottom margin slightly larger (from `gapSm` → `gapMd`) so it doesn't feel squeezed

**SOS Sent state:**
- The dark `(2A1A1E)` card on a dark `(1A1013)` background has very low contrast for labels. Increase `_SosDetail.label` color from `0xFF94A3B8` → `0xFFCBD5E1` (already used for body text in this state)

---

### Device Screen

#### [MODIFY] `lib/features/devices/device_screen.dart`

**Empty/disconnected state:**
- Currently shows device name "No device" with `--` values — looks like broken data
- When `device.connectionState != connected && device.id == ''` (no device ever paired), show an `EmptyState` widget:
  - Icon: `Icons.watch_off_rounded`
  - Title: "No device connected"
  - Subtitle: "Connect your PRANA ESP32 sensor band to start receiving live biometrics."
  - CTA: "Scan & Connect"

**Connected state:**
- Battery icon should reflect level: `Icons.battery_0_bar` through `Icons.battery_full` based on `device.batteryLevel`

---

### Profile Screen

#### [MODIFY] `lib/features/profile/profile_screen.dart`

**Profile hero card:**
- Current avatar is a gradient circle with a person icon — clean. Add initials text on top of the gradient (e.g., first letter of `profile.name`) instead of just the icon, making it feel more personal.

**Settings section:**
- The settings group (Watch, Privacy, Demo Lab) has no label separating it from Emergency Contacts. Change `SectionHeader(title: 'Settings')` to `SectionHeader(title: 'Connected & Data')` and add an additional `SectionHeader(title: 'Developer')` before Demo Lab.
- Demo Lab tile: add a `StatusPill(label: 'DEV', ...)` trailing badge to make it visually distinct from user-facing settings.

**`_BaselineRow`:**
- Values are right-aligned primary color text — fine. Change `bodyMedium` label to be slightly more muted (`textSecondary`) to create better contrast between label and value.

---

### Privacy Screen

#### [MODIFY] `lib/features/privacy/privacy_screen.dart`

**Hero card text contrast:**
- Body text `const Color(0xFFCBD5E1)` on the dark gradient is OK at ~4.5:1 contrast. No change needed.
- "100% offline-first edge AI" headline could be slightly smaller (`headlineSmall` instead of `headlineMedium`) — right now it reads as a shout.

**Wipe button:**
- Move the "Wipe all local data" destructive button inside a dedicated `SectionHeader(title: 'Danger Zone')` section with a warning description above it: "This cannot be undone. All learned baselines, historical telemetry and emergency contacts will be permanently deleted."
- Style: make the button full-width, red-outlined, with `Icons.warning_amber_rounded` instead of `Icons.delete_forever_rounded`

---

### Demo Lab

#### [MODIFY] `lib/features/demo/demo_lab_screen.dart`

Minor polish only — already has the right technical dark aesthetic:
- Add a `StatusPill(label: 'DEV BUILD', ...)` in the hero card next to the "SIH DEMONSTRATION LAB" caps label
- `_TensorRow` progress bar: add a `LinearProgressIndicator` under each tensor value for a visual representation (reuse the domain card pattern)

---

### Shared Widgets Improvements

#### [MODIFY] `lib/shared/widgets/section_header.dart`
- Reduce `top: AppSpacing.xl (24)` → `top: AppSpacing.lg (20)` — saves 4px per section, which on a long scroll page like Profile adds up
- Action button style: change `labelMedium` → `bodySmall + w600 + primaryLight` — the current one looks slightly heavier than needed

#### [MODIFY] `lib/shared/widgets/app_segmented_control.dart`
- View this file before editing (not yet read). Likely needs minor padding/typography polish.

#### [MODIFY] `lib/shared/widgets/info_row.dart`
- View this file before editing (not yet read). Likely needs minor padding consistency check.

---

## Verification Plan

### Automated Tests
```bash
flutter analyze
flutter test
```

### Manual Verification
- Open each screen and verify:
  - No overflow / clipping
  - `--` values replaced with `EmptyState` when disconnected
  - Typography hierarchy reads correctly
  - Section headers consistent spacing
  - Emergency screen: idle / countdown / sent states all render correctly
  - Demo Lab: tensor rows and GATT profile render correctly
  - Onboarding: not modified, should be unaffected
  - Navigation bar: SOS button prominent, nav items legible
  - Text scaling: force 1.3× and verify no clipping (already clamped in app.dart)

---

## Open Questions

> [!IMPORTANT]
> **Google Fonts dependency**: The theme comment says "no fontFamily override because pubspec declares no font assets". Should we add `google_fonts` to `pubspec.yaml` to use `Inter` or `DM Sans`? This would require a network fetch on first run (or bundling), which may conflict with the offline-first principle. **Recommendation: skip unless user confirms.**

> [!NOTE]
> **`AppColors.riskColorFor()` helper**: Adding a static color-from-score helper to `AppColors` is a pure addition (no breaking change) but modifying `app_colors.dart` touches the design system. The implementation plan includes it as a minor improvement.

> [!NOTE]
> **Onboarding screen**: Not in scope per instructions. Will not be modified.

> [!NOTE]
> **Animations**: The `CountdownProgressArc` in Emergency uses a `StreamBuilder` on the existing `countdownStream`, so it needs no new logic. The `_DomainCard` animated progress bar uses an `AnimationController` in a `StatefulWidget` — this is a new `StatefulWidget` but adds no external package.
