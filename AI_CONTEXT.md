## 1. What this app is

**PRANA** is an **offline-first, edge-AI personal health companion** (Flutter, Android-first),
built for the Smart India Hackathon. A wearable band (ESP32 + sensors) streams vitals and motion
over **Bluetooth Low Energy**; the phone does **all** processing on-device — baseline learning,
feature extraction, ML inference, risk scoring, recommendations, fall detection, and emergency
SOS. **There is no backend and no cloud.** Everything works with the network off.

- **Package name:** `prana_health`
- **Flutter SDK:** `^3.13.2`, Material 3, light theme only.
- **State management:** `provider` + a single `ChangeNotifier` controller.
- **Dependencies (all of them):** `intl`, `shared_preferences`, `provider`, `flutter_blue_plus`.
  Keep this list small — do not add packages without a strong reason.

---

## 2. How to run

```bash
flutter pub get
flutter analyze          # must stay clean after any change
flutter run              # on a connected Android device
```

Note: in some sandboxed shells `flutter build` / Gradle fails with a loopback error; that is an
environment quirk, not a code problem. Static verification is `flutter analyze`.

---

## 3. The core mental model — the data pipeline

Everything flows through **one controller**:
[`lib/core/services/prana_health_controller.dart`](lib/core/services/prana_health_controller.dart).
It is the single source of truth the whole UI watches via `context.watch<PranaHealthController>()`.

```
Sensor source (BLE or Mock)
      │  emits HealthReading / MotionReading / EnvironmentReading / DeviceInfo
      ▼
PranaHealthController._onHealthReadingReceived(reading)
      │
      ├─ 1. buffer chart history (hrHistory / spo2History / tempHistory / riskScoreHistory)
      ├─ 2. BaselineService.recordReading()  → personal baseline (hardware mode only)
      ├─ 3. FeatureProcessor.extractFeatureVector()  → 16-dim feature vector
      ├─ 4. MLInferenceService.runInference(features) → PredictionResult
      ├─ 5. RiskEngine.calculateRisk(...)            → RiskResult (score + level + recommendation)
      └─ 6. raise alerts if risk is high/critical
      ▼
notifyListeners()  → all watching screens rebuild

Motion path (separate, higher frequency):
MotionReading → _onMotionReadingReceived → motionHistory buffer + FallDetectionService.processMotion
             → uses `motionTick` (a ValueNotifier) so ONLY the fall-detection graph repaints,
               not every screen.

Fall path:
FallDetectionService.fallAlertStream → EmergencyService.triggerFallDetected() → SOS countdown.
```

**Why two repaint channels:** vitals arrive ~1 Hz (fine to call `notifyListeners()`), motion
arrives ~10 Hz. Motion uses its own `motionTick` `ValueNotifier` so the accelerometer graph
repaints without rebuilding the entire app.

---

## 4. Directory map

```
lib/
├── main.dart                         App entry: init storage, create controller, run PranaApp
├── app/
│   ├── app.dart                      PranaApp (MaterialApp) + MainNavigationShell (bottom nav + SOS)
│   └── routes.dart                   Named routes: /onboarding /main /emergency /devices /privacy /demoLab /fallDetection /history
│
├── core/
│   ├── services/prana_health_controller.dart   ★ central state + pipeline (see §3)
│   ├── database/local_storage_service.dart      shared_preferences wrapper (mock-mode flag, profile, onboarding, daily summaries)
│   ├── constants/app_constants.dart             thresholds incl. fall detection (values in g)
│   ├── constants/ble_constants.dart             device names, scan timeouts, fallback prefix
│   └── theme/  app_colors · app_typography · app_spacing · app_theme   ← the design system tokens
│
├── shared/
│   ├── models/    health_reading · motion_reading · environment_reading · sleep_reading ·
│   │              user_baseline · user_profile · risk_result · alert_model · device_info ·
│   │              daily_summary          ← persisted per-day aggregate behind the History screen
│   └── widgets/   see §7 for the full list — prana_scaffold · greeting_header · app_card ·
│                  hero_metric_card · section_header · stat_tile · status_pill · icon_chip ·
│                  circle_icon_button · chip_strip · empty_state · fade_slide_in · info_row ·
│                  metric_sparkline · calendar_strip · timeline_row · swipe_to_confirm ·
│                  prana_action_sheet · prana_search_field · quick_search_sheet ·
│                  prana_line_chart (+ ChartDataPoint) · app_segmented_control ·
│                  risk_score_gauge · hypnogram_chart · scenario_banner · health_metric_card ·
│                  loading_shimmer · ambient_background · animated_metric_value
│
└── features/
    ├── dashboard/dashboard_screen.dart      "Home" tab — overview
    ├── health/health_screen.dart            "Vitals" tab — segments: Heart / Oxygen / Temp / Sleep
    ├── insights/insights_screen.dart         "Insights" tab — segments incl. Environment (segment 1)
    ├── profile/
    │   ├── profile_screen.dart              "Me" tab — profile, baseline, contacts, device & data
    │   └── profile_editor.dart              ★ the sheets that edit the profile + contacts
    ├── history/history_screen.dart          day-by-day record + today's alert log
    ├── environment/environment_screen.dart  environment detail
    ├── sleep/sleep_screen.dart              sleep detail
    ├── emergency/
    │   ├── emergency_screen.dart            SOS countdown / emergency UI  (reached via SOS button)
    │   ├── emergency_service.dart           SOS state machine (idle → countdown → sosSent)
    │   ├── fall_detection_service.dart      impact + stillness detector; honors `isFallSuspected`
    │   └── fall_detection_screen.dart       live MPU6050 accelerometer graph + fall status
    ├── devices/
    │   ├── sensor_data_source.dart          interface both sources implement
    │   ├── bluetooth_sensor_data_source.dart ★ real BLE (flutter_blue_plus)
    │   ├── mock_sensor_data_source.dart      simulated data for demos
    │   ├── sensor_parser.dart               JSON + GATT packet parsing / key normalization
    │   ├── ble_config.dart                  UUIDs, target device name
    │   └── device_screen.dart               device connection UI
    ├── baseline/baseline_service.dart       personal baseline learning
    ├── ai/
    │   ├── feature_processor.dart           16-dim feature extraction
    │   ├── inference_service.dart           MLInferenceService interface
    │   ├── mock_inference_service.dart      ★ default inference (active)
    │   ├── tflite_inference_service.dart     scaffolded; tflite dep NOT in pubspec (not wired)
    │   └── prediction_model.dart            PredictionResult
    ├── risk/risk_engine.dart                multi-domain risk synthesis → RiskResult
    ├── recommendations/recommendation_engine.dart
    ├── scenarios/disaster_scenario_engine.dart   demo disaster scenarios (heatwave, etc.)
    ├── privacy/privacy_service.dart · privacy_screen.dart
    ├── onboarding/onboarding_screen.dart
    └── demo/demo_lab_screen.dart            demo controls (scenario switching, test fall)

firmware/                                    ESP32 Arduino sketches (see §9)
docs/esp32_hardware_integration_guide.html   hardware wiring + packet reference
```

★ = the files you touch most often when changing behavior.

---

## 5. Navigation

Bottom nav has **4 tabs** + a center **SOS** button (defined in `MainNavigationShell` inside
[`lib/app/app.dart`](lib/app/app.dart)):

| Index | Tab | Screen | Notes |
|---|---|---|---|
| 0 | Home | `DashboardScreen` | overview; has callbacks to jump to other tabs/segments |
| 1 | Vitals | `HealthScreen` | segmented: **Heart**, **Oxygen**, **Temp**, **Sleep** |
| 2 | Insights | `InsightsScreen` | segmented; **Environment** is segment index 1 |
| 3 | Me | `ProfileScreen` | settings; "Device and data" card links to **Fall detection** |
| — | SOS | `EmergencyScreen` | **pushed**, not a tab. The SOS button never fires an alert directly — it opens the screen (a pocket mis-tap costs nothing). |

Tabs use `IndexedStack`, so each tab keeps its scroll position and controllers alive.
Pushed (non-tab) routes: Emergency, Device, Privacy, Demo Lab, Fall detection, History.

Two things reach History: the **unread-alert chip** in the Home greeting header (tap it to read
and acknowledge the alerts, which clears the chip) and **Me → Device and data → Day-by-day
history**. Profile is a *tab*, not a route, so a pushed screen cannot navigate to it — that's why
the Emergency screen says "open the Profile tab" instead of linking.

**Where the two live graphs are** (a common question):
- **Accelerometer / MPU6050 graph** → Me → Device and data → **Fall detection** (`fall_detection_screen.dart`).
- **Heart-rate & SpO₂ graphs** → Vitals → **Heart** / **Oxygen** (`health_screen.dart`, `PranaLineChart`).
These are deliberately separate screens fed by separate fields of the same packet.

---

## 6. Sensor data: Mock vs Bluetooth

Two implementations of `SensorDataSource`; the controller picks one based on a persisted
**mock-mode** flag (`storage.isMockModeEnabled()`), toggled via `controller.toggleMockMode(bool)`.

- **`MockSensorDataSource`** — synthetic data for demos/screenshots. Mock mode sets
  `hasLiveData = true` and shows a simulated device. Also drives disaster scenarios.
  Mock mode must always be **visibly labelled** where its numbers are shown: the Home greeting
  carries a "Demo mode" chip, the band screen carries a notice with a working "Leave demo mode"
  action, and nothing generated in mock mode is written to the persisted daily history.
- **`BluetoothSensorDataSource`** — real hardware via `flutter_blue_plus`. **One** peripheral at a
  time, matched by name `PRANA_BAND_PRO`, prefix `PRANA_`, name `ESP32_DISTANCE_DEVICE`, or the
  service UUID. Requests MTU 256.

### BLE identifiers (must match firmware)
- **Service UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **JSON telemetry characteristic (notify):** `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Also supports standard GATT chars: Heart Rate `0x2A37`, SpO₂ `0x2A5F`, Temp `0x2A1C`,
  Battery `0x2A19`, plus a binary motion characteristic.

### JSON telemetry packet (the main path)
```json
{ "heartRate": 82, "spo2": 97, "temperature": 36.8,
  "accX": 0.02, "accY": -0.01, "accZ": 0.99, "steps": 1234,
  "activityLevel": "Moderate", "envTemp": 27.5, "envHumidity": 54,
  "aqi": 48, "battery": 86, "isFallSuspected": true }
```
Rules parsers enforce (`sensor_parser.dart`, `bluetooth_sensor_data_source.dart`):
- Accepts short aliases: `hr`→heartRate, `temp`→temperature, `ax/ay/az`→accX/Y/Z.
- **Accelerometer values are in g** (firmware divides m/s² by 9.81). The 2.8 g fall threshold
  assumes g.
- The BLE layer emits a stream **only for fields the packet actually carries.** A motion-only
  packet does NOT create a fake HealthReading. This is what keeps the graphs honest and separate.
- `isFallSuspected: true` should be sent in **exactly one** packet per fall; the app treats it as
  a direct trigger for the SOS countdown. Repeating it would restart the countdown forever.

---

## 7. Design system — how to keep UI consistent

**Never hardcode colors, font sizes, or paddings.** Use the tokens:

- **`AppColors`** — a warm cream/sage palette. `background` (#F2EEE6 linen), `surface` (#FDFBF7),
  `surfaceWell` (#EAE5DA, recessed fields and inset panels), `surfaceDark` (#22261F),
  `primary` (#2F5D50 forest green), `primaryContainer`/`mint` (#D9E8CE), `accent` (#A8C8A0 —
  **fill only, too light for text**), `mintDeep` (#8FB585), `textPrimary` (#1C2118),
  `textSecondary`, `textTertiary`, `border`/`borderLight`, and the gradients `gradientMint`,
  `gradientCream`, `gradientDark`.
  **Medical colors are deliberately outside the palette** and must stay loud: `riskHigh`
  (#F97316), `riskCritical` (#EF4444), `heartRate` (#E11D48). Also per-metric pairs —
  `spo2`/`spo2Bg`, `temperature`, `activity`, `sleep`, `aqi`, `humidity`, `heatIndex` — each with
  a pastel `*Bg` for icon chips.
- **`AppTypography`** — text styles, including `displayHuge`/`metricHero`/`metricValue`/
  `metricSmall`/`metricUnit` (all tabular figures, so a changing digit doesn't shift the layout)
  and `labelCaps`/`mono`.
  **No font asset is bundled.** The app is offline-only, so a runtime font fetch
  (`google_fonts`) is not an option — character comes from size, weight and letter-spacing on
  the platform face. If you want the reference's geometric sans, drop a `.ttf` into `assets/`,
  declare it in `pubspec.yaml`, and set `fontFamily` once in `app_theme.dart`.
- **`AppSpacing`** — `xxs…xxl`, ready-made `gap*`/`hGap*` **widgets** (drop them straight into a
  children list), `pageH`, `navClearance` (bottom padding so content clears the nav bar), and
  `AppSpacing.card` which is an **`EdgeInsets`**, not a double.
- **`AppRadius`** — `xs 10 · sm 14 · md 18 · lg 24 · xl 30 · xxl 36 · pill 999`, plus `brXs…brPill`
  `BorderRadius` forms. Corners are generous by design. **`AppShadows`** — `card`, `raised`,
  `floating`, `glow()`; all very low alpha, because a warm canvas shows a heavy shadow as dirt.

**Reusable widgets** (compose these instead of building from scratch):
`PranaScaffold` (page shell w/ title/subtitle/back/ambient wash), `GreetingHeader` (avatar +
"Hey, {name} 👋" + caller-supplied state chips + overflow), `PranaSearchField` +
`QuickSearchSheet`, `AppCard` (+ `AppCard.well`), `HeroMetricCard` (big number + caption +
sparkline + action), `HealthMetricCard`, `SectionHeader` ("See All" + overflow), `StatTile`,
`StatusPill`, `IconChip`, `CircleIconButton`, `ChipStrip`, `EmptyState` (use for
"not connected"/"waiting" states), `FadeSlideIn` (staggered entrance; respects the platform's
reduce-motion setting), `LoadingShimmer`, `InfoRow` (list row w/ chevron — note `value` is
**ignored** when `trailing` is supplied), `MetricSparkline`, `CalendarStrip`, `TimelineRow`,
`SwipeToConfirm` (for anything irreversible), `showPranaActionSheet` (+ `PranaAction`),
`PranaLineChart` (+ `ChartDataPoint`), `AppSegmentedControl`, `RiskScoreGauge`,
`HypnogramChart`, `AmbientBackground`, `AnimatedMetricValue`.

`AppCard` gotcha: `gradient` takes a **`Gradient`**, not a `List<Color>` (so wrap
`AppColors.gradientDark` in a `LinearGradient`). `HeroMetricCard.gradient` takes a
`List<Color>`. They differ; check before you copy.

**Light theme only, and it is finalized.** Don't redesign the palette or the navigation style —
extend it. New UI must look like existing UI.

**Scalability is a requirement, not a polish pass.** Every screen has to survive a 320 dp width
and a 1.3 text scale: single-line text gets `maxLines` + `ellipsis`, chip clusters use `Wrap`
rather than `Row`, huge numerals go inside `FittedBox(fit: BoxFit.scaleDown)`, grid aspect
ratios account for the text scale, and every `CustomPainter` returns early on a zero-size or
zero-range input.

---

## 8. HARD RULES — read before editing (this is what protects the app)

1. **Offline-first. No network/cloud calls, ever.** All intelligence is on-device.
2. **Never display fake/placeholder sensor values in hardware mode.** If data is missing, show a
   "waiting" / "not connected" state (`EmptyState`). Mock mode is the *only* place simulated
   values are allowed, and it is explicitly labeled.
3. **Don't rewrite the engines without a clear reason:** BLE stack, sensor parsing, ML inference,
   `RiskEngine`, `BaselineService`, `FallDetectionService`, `EmergencyService`, storage. These are
   load-bearing. Extend at the edges; don't refactor the core to add a feature.
4. **One BLE connection.** The app connects to a single band. You cannot stream two separate
   boards simultaneously — put multiple sensors on one ESP32.
5. **Reuse the design system** (§7). New UI must look like existing UI.
6. **Keep history buffers bounded** (they already cap at 50–150 points) so long sessions don't
   grow memory without limit.
7. **Emergency is real, not a prop.** Route fall/SOS through the existing `EmergencyService`.
   Don't fake calls/messages or build a second emergency system.
8. **`flutter analyze` must stay clean.** Match the surrounding code's style and comment density.
9. **Don't invent hardware details** (UUIDs, device names, packet keys). They must match the
   firmware in `firmware/` and `ble_config.dart`.

---

## 9. Firmware (ESP32, Arduino)

Under `firmware/`. All advertise as `PRANA_BAND_PRO` with the UUIDs above and send JSON telemetry.
Pick **one** to flash:

- `prana_band_ble_test/` — link test, no sensors (synthetic values). Prove the BLE pipe first.
- `prana_band_mpu6050/` — MPU6050 only: 50 Hz motion + on-device fall detection, 10 Hz packets.
- `prana_band_mpu_max30102/` — MPU6050 **and** MAX30102 on one board (motion + heart rate + SpO₂),
  non-blocking so neither sensor stalls the other. Use this if you have both sensors.
- `prana_band/` — full build (adds DHT22 env sensor, optional MLX90614 body temp).

Fall detection runs **on the ESP32** (not the phone): an impact peak lasts 100–300 ms and would
fall between the 10 Hz packets, so the phone would miss it. The band sends `isFallSuspected` and
the app trusts it. Thresholds mirror `AppConstants` (impact 2.8 g, stillness band 0.25 g).

Full wiring/packet reference: `docs/esp32_hardware_integration_guide.html`.

---

## 10. Known gotchas

- **No trained model ships. The risk model is hand-tuned logistic regression.** `assets/models/
  prana_risk_model.tflite` is a 92-byte *text* placeholder, `tflite_flutter` is not in
  `pubspec.yaml`, and `TFLiteInferenceService` is never instantiated (it is a template showing
  where the real runner plugs in). What runs is `mock_inference_service.dart`: five sigmoids over
  weighted sums of the 16-feature vector, coefficients chosen by hand from published
  physiological thresholds — **not fitted to data, and not a neural network.** It does run for
  real, on device, with no network, so nothing downstream is simulated; it is the *provenance* of
  the weights that is weak. Do not describe it in UI copy or docs as a trained model, an MLP, or
  TFLite inference. "On-device model" and "on-device logistic risk model" are the honest phrasings
  already in use. `assets/models/README.md` holds the tensor contract a future `.tflite` must
  satisfy — `FeatureProcessor` already emits exactly that layout, so a real model is a drop-in.
- **PRANA cannot place a call or send an SMS.** There is no telephony plugin and no network by
  design, so what an SOS actually does is: raise a full-screen alarm on this phone, log the
  event, and *write out* the alert message (profile, medical notes, live vitals, GPS if any) for
  a human to send. `emergency_screen.dart` says exactly that and offers `Clipboard` hand-off for
  the message and the contact's number. **Do not reword it into "alert sent".** If you want real
  dispatch, add `url_launcher` and open a `tel:`/`sms:` intent — that is the upgrade path, and it
  still needs a human to press send.
- **Sleep is demo-only.** `controller.hasSleepData` is literally `_isMockMode`. Worse, the risk
  model does not know that: `feature_processor.dart` substitutes a standard adult night
  (450 min, quality 80) for `f[7]`/`f[8]` when there is no sleep source, and
  `mock_inference_service.dart` weights those at 3.2 and 2.6. So in hardware mode two of the
  sixteen model inputs are assumptions. The Demo Lab prints a warning under the feature vector
  when this is happening. Fixing it properly means a real sleep source or dropping those
  features — both engine changes (see HARD RULE 3).
- **Temp tab shows a flat 36.7 °C without a temperature sensor** — `HealthReading.fromJson`
  defaults `bodyTemperature` to 36.7 when the packet omits it. Only real if a temp sensor is wired.
- **TFLite is scaffolded but not active** — `MockInferenceService` is the default; the `tflite`
  dependency isn't in `pubspec.yaml`.
- **`UserProfile.defaultProfile()` and `DeviceInfo.defaultDevice()` are fabricated sample data.**
  The onboarding flow now collects the real profile (and offers the sample explicitly, labelled),
  because the SOS message quotes the name, age, blood group and medical notes verbatim.
- **Demo-mode readings are never persisted.** `_recordDailyAggregate` returns early when
  `_isMockMode`, so the History screen only ever shows real worn-band days. Keep it that way.
- **Light theme only** — no dark theme is wired, and none is planned. Dark *surfaces*
  (`surfaceDark`, `gradientDark`) are a component style, not a theme mode.
- **Text scale is clamped 0.9–1.3** in `app.dart` because gauges/charts have fixed heights.

---

## 11. A safe playbook for making a change

1. Read this file, then read the *specific* screen/service you're touching (paths in §4).
2. Reuse existing widgets and tokens (§7). Add the smallest new code that fits the pattern.
3. If the change involves data, respect the pipeline (§3) — feed the controller, let the UI watch.
4. Honor the hard rules (§8). If a request conflicts with one, say so instead of breaking it.
5. Run `flutter analyze`. Keep it clean.

---

## How to hand this project to another AI (Gemini / ChatGPT)

A **PDF of the code is the wrong tool** — it loses indentation and file boundaries and wastes
tokens. Do this instead:

1. **Pack the repo into one AI-friendly text file** with a free tool (run in the project root):
   ```bash
   npx repomix
   ```
   This produces `repomix-output.xml` (or `.md`) containing the directory tree + every source
   file, formatted for LLMs. Alternatives: `npx gitingest`, or Simon Willison's `files-to-prompt`.
   Exclude noise (already handled via `.gitignore`, but you can also skip `build/`, `.dart_tool/`,
   `android/`, `ios/`, `assets/`).

2. **Give the AI this file first**, then the packed code. This doc explains the *why* and the
   *rules*; the packed code is the *what*.

3. **Best tool for large context:** Gemini in **Google AI Studio** (aistudio.google.com) has a
   very large context window — upload the packed file there. ChatGPT works too (upload the file,
   or use its GitHub connector). If you have a GitHub repo, most AIs can also read it directly.

4. When asking for a change, paste the relevant **§8 hard rules** into your prompt so the other AI
   doesn't break the architecture.
