# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

This is a CMake-based Qt6 GUI application (no `.pro`/qmake file, no CMakePresets.json — it's driven directly through Qt Creator kits or manual CMake invocation).

Requires Qt 6.2+ with the `Quick`, `Core`, `Network`, `Multimedia`, `Location`, and `Positioning` modules, plus the `Qt5Compat.GraphicalEffects`, `QtQuick.VirtualKeyboard`, `QtQuick.Shapes`, and `QtLocation`/`QtPositioning` QML modules (used by `main.qml`, `utilities/HorizonLine.qml`, and `utilities/TrafficMap.qml` respectively). The two build directories checked into this tree were generated from two Qt Creator kits: "Desktop Qt 6.6.0 MSVC2019 64bit" (Release) and "Replacement for Desktop Qt 6.4.3 MinGW 64bit" (Debug) — point `CMAKE_PREFIX_PATH` at whichever Qt install/kit is available. The `Multimedia` and `Location`/`Positioning` components are not installed by default with every Qt kit; if `find_package(Qt6 REQUIRED COMPONENTS Multimedia)` or `find_package(Qt6 REQUIRED COMPONENTS Location Positioning)` fails during configure, add the missing component(s) to that kit's Qt installation via the Qt Maintenance Tool:

```
cmake -S . -B build -DCMAKE_PREFIX_PATH="<path-to-Qt>\6.6.0\msvc2019_64"
cmake --build build
```

The resulting executable target is `appAvionicsClock` (`WIN32_EXECUTABLE`, GUI app, no console).

`qt_add_qml_module` currently raises two CMake dev warnings on every configure — `QTP0001` (default QML resource prefix) and `QTP0004` (missing per-directory `qmldir` for a multi-directory module) — because the module's `QML_FILES` span several subdirectories (`utilities/`, `Brightness-Control/`, `G5/Utilities/`, ...) without the newer per-directory-`qmldir` policy set. These are informational only, not build failures; safe to ignore unless bumping to a Qt version where the policy default flips.

If a Qt Creator **Run** fails with `Process failed: The program "appman-controller" does not exist or is not executable`, a kit's deploy configuration got set to `ApplicationManagerPlugin.Deploy.Configuration` (Qt Application Manager packaging/install steps) instead of the plain empty deploy — check `.qtcreator/CMakeLists.txt.user`'s `ProjectExplorer.Target.ActiveDeployConfiguration` for that kit and point it back at index `0` (`ProjectExplorer.DefaultDeployConfiguration`), or fix it from Qt Creator's Projects → Run panel. This has already recurred once after being fixed via the UI, so the `.user` file is the more durable fix.

For a quick headless sanity build/run outside Qt Creator (e.g. to reproduce a runtime QML error), this machine also has a Qt 6.8.3 MinGW kit at `C:/Qt/6.8.3/mingw_64` paired with the bundled compiler at `C:/Qt/Tools/mingw1310_64` (GCC 13.1) — neither of the two Qt Creator-managed kits above has a working `cl.exe`/Ninja combo reachable from a plain shell. Configure into a scratch build dir (not `build/`, which Qt Creator owns) with `-DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/mingw_64 -DCMAKE_CXX_COMPILER=C:/Qt/Tools/mingw1310_64/bin/g++.exe`, then put `C:/Qt/6.8.3/mingw_64/bin` and `C:/Qt/Tools/mingw1310_64/bin` on `PATH` before running the built `.exe` (its DLLs aren't found otherwise). Because it's a `WIN32_EXECUTABLE`, `qDebug`/`qWarning` output is silently dropped unless `QT_ASSUME_STDERR_HAS_CONSOLE=1` is set in the environment first.

There is no automated test suite and no configured linter in this repo.

## Architecture

The app is a 320×240 frameless, fixed-size rectangular "avionics clock" widget, targeting embedded LCD panels (e.g. a Raspberry Pi driving a 320×240 display) rather than a desktop window a user resizes. All QML resources (files under `Resources/`, `utilities/`, `Brightness-Control/`) are compiled into the binary via `qt_add_qml_module(... URI AvionicsClock ...)` in `CMakeLists.txt`, and loaded at runtime through `qrc:/AvionicsClock/...` paths — there is no filesystem asset loading. When adding a new QML file or resource, it must be added to the `qt_add_qml_module` call in `CMakeLists.txt` or it won't be bundled. The one exception is `Resources/audio/*.mp3` (see `ReminderManager` below), which is bundled via `file(GLOB AUDIO_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "Resources/audio/*.mp3")` — the `RELATIVE` keyword is required, since `file(GLOB)` returns absolute paths by default and `qt_add_qml_module`'s resource system rejects those with a `QT_RESOURCE_ALIAS` error.

### C++ ⇄ QML bridge

Four `QObject` classes are registered as QML types in `main.cpp` (`qmlRegisterType`, each under its own module name/version, e.g. `import WeatherProvider 1.0`). The first three are instantiated once at the top of `main.qml`:

- **`TimeDateProvider`** — self-contained 1s `QTimer` exposing `hours` (24h), `hours12` (1–12, derived from `hours` each tick), `minutes`/`seconds`/`timeString`/`amPm`/`date` as properties. Drives every clock face in the UI. Any 12-hour display should bind to `hours12` rather than doing `% 12` conversion in QML.
- **`LocationProvider`** — fetches IP-based geolocation from `ip-api.com` on `Component.onCompleted`, exposing `city`/`latitude`/`longitude`/`error`. Retries every 5s on failure until it succeeds.
- **`WeatherProvider`** — fetches current conditions + 24h hourly forecast from Open-Meteo (no API key required), exposing `currentTemperature`/`currentWeatherCode`/`currentWeatherDescription`/`currentWeatherIcon`/`currentWindSpeed`/`hourlyForecast` (a `QVariantList` of per-hour maps) plus `loading`/`errorString`. Auto-refreshes every 30 minutes once a location is set. WMO weather codes are mapped to description/icon in `codeToDescription`/`codeToIcon`; day-vs-night icon selection uses sunrise/sunset parsed from the API's `daily` block, but only weather code 0 (clear sky) currently has a distinct night icon — extend `codeToIcon` the same way to add more.

The fourth, **`FlightTrackerProvider`**, is instantiated later and differently — inside `utilities/AirTrafficPage.qml` (Page 5), not at the top of `main.qml` alongside the other three — since it's specific to the Air Traffic Display page and gates its own polling on that page's visibility. See `.claude/rules/air-traffic-display.md` (auto-loads when touching ATD files) for it and the rest of that feature's backend (`OpenSkyTokenManager`, `OpenSkyFlightSource`, `AircraftListModel`, etc.).

The first three are independent — the one cross-wire is in `main.qml`: a `Connections` block calls `weather.setLocation(location.latitude, location.longitude)` whenever `LocationProvider.locationChanged` fires, which is what actually triggers the first weather fetch. A second, similarly independent `Connections` block wires `utilities/ReminderManager.qml`'s `reminderStarted`/`reminderFinished` signals to `funnyEyes.lookAtUser()`/`resumeAutonomy()` (see below).

### QML UI structure (`main.qml`)

A single `Window` with `Qt.FramelessWindowHint`, fully opaque (`color: "#121212"`) and pinned to a fixed `320×240` size (`minimumWidth/maximumWidth`/`minimumHeight/maximumHeight` all equal `width`/`height` — no native resize, no circular clipping/`OpacityMask` anywhere). A 40px transparent `Rectangle` (`dragArea`) at the top handles window dragging via mouse deltas, since the window has no native title bar.

Sizing is driven entirely by a handful of properties declared on the root `Window` (`screenWidth`, `screenHeight`, `uiScale`, `gaugeSize`, `fontLarge`/`fontMedium`/`fontSmall`) — every page's clock-face size and font size derives from these rather than hardcoded pixel values, so porting to another panel (480×320, 800×480, ...) means changing `screenWidth`/`screenHeight` and nothing else.

The body is a `SwipeView` with 6 pages defined, 5 currently live:
0. **G5 test page** (unnumbered, no comment header beyond `//TEST PAGE`) — instantiates `G5Altimeter`/`G5AirspeedIndicator` directly on a plain green `Rectangle`. See `.claude/rules/g5-test-page.md` (auto-loads when touching `G5/**` or its two `utilities/` copies) — this page is a work-in-progress import from another project, not part of the "real" clock UI. **Currently commented out** — wrapped in a `/* ... */` block in `main.qml`, so it is not one of `swipeView`'s live children today. Re-enabling it shifts every other page's live child index up by one.
1. **PFD clock** — `utilities/PfdBackground.qml` fills the page with a synthetic sky/ground/horizon (see below); on top sits `Resources/eaid/clock-pfd.svg` (a transparent-background attitude-indicator/clock face with aircraft symbol and hour markers, printed with a static pitch ladder graphic that the live `pitchLadder` overlay — see below — sits on top of and replaces visually) plus `hourArrow.svg`/`minuitesArrow.svg` needle overlays, all sized to `gaugeSize` and `anchors.centerIn` the page. Needle `rotation` bound to `timeDate.hours/minutes/seconds`, same formulas as the HSI page below.
2. **Analog HSI clock** — stacked SVG layers from `Resources/ehsi/` (dial → bezel → hour needle → minute needle → seconds bug), each sized to `gaugeSize` and centered; each needle's `rotation` bound directly to `timeDate.hours/minutes/seconds`.
3. **Digital clock ("cockpit" theme)** — restyled as a premium avionics display: dark radial gradient background (`#2B2B2B` center → `#121212` edge via `RadialGradient`), and the `hh:mm:ss AM/PM` clock row (bound to `timeDate.hours12`, zero-padded in QML) rendered in gold/amber (`#D9A441`) with a subtle `DropShadow` for lift, not glow. Below the clock sits `utilities/FunnyEyes.qml` (see below), then date/temperature/city. Temperature is bound to `weather.currentTemperature`, rounded, `°C` suffix — not hardcoded. The settings-gear button (`settingBtn`) is currently `visible: false` (hidden but still wired to open the settings drawer if re-enabled).
4. **Weather page** — background photo + `FastBlur`-based glassmorphism panel, live time (also `hours12`, 12-hour) + date + city — the top info block (location row / clock row / date) is centered as a whole via `Layout.alignment: Qt.AlignHCenter` on each row (no hardcoded left margins) — and a horizontal `ListView` bound to `weather.hourlyForecast`, delegating each entry to `utilities/CustomTempContainer.qml`.
5. **Air Traffic Display (ATD)** — `utilities/AirTrafficPage.qml`. Live OSM map centered on the current location with a fixed center crosshair, zoom controls, a map-style picker, and (as of Phase 4) live nearby-aircraft markers polled from OpenSky every 30s while the page is visible. Tapping a marker highlights it orange and slides in a left floating `AircraftDetailPanel` with its telemetry; tapping again (or the panel's "✕") closes it. A `CoordinateBar` overlay (top, DMS position) and `StatusBar` overlay (bottom-left, city/temperature/date/time) reuse `main.qml`'s existing `location`/`weather`/`timeDate` instances. See `.claude/rules/air-traffic-display.md` (auto-loads when touching ATD files) for the full backend and what's still missing (marker motion animation, traffic-count readout).

Numbering above matches the descriptive labels used historically, not raw `SwipeView` index. Since the G5 page is commented out, today's actual live child order is PFD (index 0) → HSI (1) → Digital (2) → Weather (3) → ATD (4); re-enabling G5 would shift all of these up by one.

A slide-down settings drawer (`settingsCarbet`, animated via a `Behavior on y`) hosts `Brightness-Control/BritnessControl.qml` — this is a self-contained slider (0–254) with no effect on the actual system/display brightness; it's UI-only. `utilities/CloseButton.qml` exists but is unused and references a resource path that isn't in the qml module (`/Resources/flpn/closeIcon.svg`).

Reusable QML components live under `utilities/` and `Brightness-Control/`, imported into `main.qml` via relative directory imports (`import "./utilities"`, `import "./Brightness-Control"`) rather than a versioned module.

### `utilities/FunnyEyes.qml` — desktop companion eyes

A pair of cartoon eyes drawn entirely from QML primitives (no images/emoji/SVG): each eye is `Rectangle` circles (sclera → gradient iris → pupil → highlight) plus a soft-gray eyelid `Rectangle`, all clipped to a circle via `OpacityMask` so the eyelid reads as covering a round eye. A single `blinkAmount` property (0 = open, 1 = closed) drives both eyes' eyelids; a `Timer` re-randomizes its own `interval` (2–3s) after each firing and triggers a short `SequentialAnimation` (close/hold/open, ~200ms total) via the exposed `blinkOnce()` function. `expression` exists as a no-op hook for future expressions (wink, sleepy, happy, etc.) without reworking the blink mechanics. Instantiated once on Page 3, between the clock and the date.

`lookX`/`lookY` (-1..1, offsetting the iris/pupil via `anchors.horizontalCenterOffset`/`verticalCenterOffset`) are no longer just hooks — they're driven by a second, independent `Timer` (3–6s, re-randomized each firing) that calls `lookAround()`: picks one of left/right/up/down (never diagonal, and avoids repeating the previous direction when another choice exists), then animates out and back to center via a `SequentialAnimation` (`InOutQuad` move out → `PauseAnimation` → `InOutCubic` move back), all fully independent of `blinkAnim` so the two never visually collide.

`autonomousLookEnabled` gates only that random look-around timer (blinking is never affected). Two functions build on top of it for external callers (currently `ReminderManager`, below): `lookAtUser()` disables autonomous look-around, cancels any in-flight look, animates the pupils back to dead center, and blinks once; `resumeAutonomy()` re-enables random look-around. This is how the health-reminder feature makes the eyes "look at the user" without any popup/UI.

### `utilities/PfdBackground.qml` — Garmin/Dynon-style synthetic horizon

Composes three small components into Page 1's background, replacing the old flat blue/brown rectangles: `SkyGradient.qml` (vertical gradient, deep aviation blue `#0A5EB8` at the top fading to a light cyan `#67D4FF` near the horizon — matched to a real Garmin PFD reference), `GroundGradient.qml` (vertical gradient, golden amber `#F2A61F` near the horizon deepening to `#C47A00` at the bottom, no texture/noise), and `HorizonLine.qml` (a `QtQuick.Shapes` quadratic path giving a crisp anti-aliased white horizon line with a barely-visible Earth-curvature bow — ends curve up, center dips slightly).

Sky, ground and horizon all live inside an internal `horizonGroup` Item, sized to 3x the max of `PfdBackground`'s own width/height and clipped by the root (`clip: true`), so it can move/rotate without ever exposing an edge. `horizonGroup`'s `x`/`y`/`rotation` (via `pixelsPerDegree`) are driven by `effectivePitch`/`effectiveRoll`, two `readonly` properties that pick between two sources: `pitch`/`roll` (real flight-telemetry inputs, default `0`, currently unused) and `simulatedRoll`/`simulatedPitch` (demo values), gated by `useSimulatedAttitude` (defaults to `true`). While simulating, two `SequentialAnimation on simulated*` loops continuously sweep roll through `0 → +15 → 0 → -15 → 0` (4.2s per leg) and pitch through `0 → +8 → 0 → -8 → 0` (5.3s per leg) — deliberately mismatched periods so the combined motion doesn't look mechanically synced — both `Easing.InOutQuad`/`InOutCubic`, `loops: Animation.Infinite`. Wiring up real telemetry later means setting `useSimulatedAttitude: false` and binding `pitch`/`roll` to live data in `main.qml` — no rendering code in `PfdBackground.qml`, `SkyGradient`, `GroundGradient`, or `HorizonLine` needs to change.

Page 1 in `main.qml` also overlays two `Text` elements on top of `PfdBackground`: current city (`location.city`, upper-left) and rounded temperature (`weather.currentTemperature`, `°C` suffix, upper-right), both white/bold/`fontMedium`. They sit in the 40px side margins left over because `clock-pfd.svg` (`Image.PreserveAspectFit`) is square and only ever grows to the page's full height (240px) inside the 320px-wide page, so they never overlap the round gauge or pitch ladder.

### Live pitch ladder overlay (`pitchLadder`, inline in `main.qml`)

`clock-pfd.svg` only prints a static pitch ladder graphic — `main.qml` overlays a live one directly on top so it moves with the same simulated (eventually real) attitude as `PfdBackground`. Structure, nested inside `clockSVG` (the `clock-pfd.svg` `Image`):

- `pitchLadderCont` — a circular `Rectangle` (`radius: width/2`, `clip: true`) centered in `clockSVG`, sized to `clockSVG.width * 0.4`. It's the fixed viewport: anything the ladder image draws outside this circle is clipped away, so it never has to be sized/positioned exactly.
- `pitchLadder` — the `Image` for `Resources/eaid/eadi_adi_ladd.svg`, a tall narrow scrolling tape (SVG `viewBox` ≈ 110×826, aspect ratio ~7.5:1 — degree markings run down its length). Its `width` is bound to `pitchLadderCont.width` and `height` derived from `sourceSize` to preserve that native aspect ratio; leaving `width`/`height` unset (as an earlier version did) makes the `Image` fall back to the SVG's raw pixel size, which throws off every pixels-per-degree calculation below.
- `pixelsPerDegree` is a local property on `pitchLadder`, defined against `pitchLadderCont.height` (the fixed viewport), not the image's own — oversized and pitch-shifted — height. This mirrors `PfdBackground`'s own `pixelsPerDegree: height / 20` convention (viewport-relative, not content-relative).
- `y` is offset by `-pfdBackground.effectivePitch * pixelsPerDegree` to scroll the tape vertically for pitch — reading `effectivePitch` directly off the `pfdBackground` instance (rather than keeping a second, duplicated `SequentialAnimation` pair) is what keeps the ladder perfectly in sync with the sky/ground horizon; two independent animations with matching durations can still drift apart since nothing ties their clocks together.
- Roll is applied via an explicit `transform: Rotation { origin.x; origin.y; angle: pfdBackground.effectiveRoll }` rather than the plain `rotation` property. `origin.y` is computed as `height/2 + effectivePitch * pixelsPerDegree` — i.e. it tracks backwards through the same pitch offset applied to `y` — so the rotation pivot always lands on `pitchLadderCont`'s fixed center regardless of the current pitch. Using the default `rotation` (which pivots around the image's own center) was tried first and rejected: once `y` is pitch-shifted, the image's own center is no longer the container's center, so rolling while pitched visibly dragged the tape off-center.

### G5 test page — see `.claude/rules/g5-test-page.md`

Duplicated-file gotcha (dead `G5/PFD`+`G5/Utilities` tree vs. the real compiled `utilities/G5Altimeter.qml`/`G5AirspeedIndicator.qml`), the Controls 1→2 `Tumbler` port, and known open issues all live in that rules file — it loads automatically whenever `G5/**`, `utilities/G5Altimeter.qml`, or `utilities/G5AirspeedIndicator.qml` are touched.

### `utilities/ReminderManager.qml` — hourly developer-health voice reminders

A self-contained scheduler, instantiated once in `main.qml` as `healthReminder`, independent of every other provider (same "cross-wired only via `Connections`" pattern as `LocationProvider`/`WeatherProvider`). A `Timer` fires every `reminderIntervalMs` (`60 * 60 * 1000`, the real 60-minute cadence) relative to app startup, not synced to the clock. On each tick, `triggerReminder()`:

- no-ops if `remindersEnabled` is `false` (the property reserved for a future Do-Not-Disturb setting — the timer keeps ticking regardless, it just skips playback/signals), or if a clip is already playing (`player.playbackState === MediaPlayer.PlayingState`), guaranteeing no overlap;
- otherwise picks a random entry from `reminderSources` (never repeating `lastReminderIndex`), sets it as the `MediaPlayer`'s `source`, emits `reminderStarted()`, and calls `player.play()`.

`onPlaybackStateChanged` emits `reminderFinished()` when the player transitions to `StoppedState` (i.e. playback naturally ends). Playback goes through Qt Multimedia's `MediaPlayer`/`AudioOutput` QML types, so it's async and never blocks the UI thread.

`reminderSources` is a hardcoded list of `qrc:/AvionicsClock/Resources/audio/reminderN.mp3` paths (currently `reminder1`–`reminder5`, though only 1–4 exist as real files — see `Resources/audio/README.md`). Adding a new clip means: drop the `.mp3` into `Resources/audio/` (auto-bundled by CMake's glob, no `CMakeLists.txt` edit needed) and append one line to this array.

`main.qml` wires `reminderStarted`/`reminderFinished` to `funnyEyes.lookAtUser()`/`resumeAutonomy()` — `ReminderManager` itself has zero knowledge of `FunnyEyes` or any UI, so swapping in a different reaction (or adding more, e.g. a future "wave" animation) only touches that one `Connections` block.


### Page 5 — Air Traffic Display (ATD) — see `.claude/rules/air-traffic-display.md`

Full architecture (QML layer, C++ backend chain, OSM tile setup gotchas, zoom/style implementation notes, what's built vs. not per the phase plan) lives in that rules file — it loads automatically whenever any ATD-related file is touched (`utilities/AirTrafficPage.qml`, `TrafficMap.qml`, `AircraftMarker.qml`, the `OpenSky*`/`FlightTracker*`/`Aircraft*`/`GeoBoundingBox*` C++ files, or `AIR_TRAFFIC_DISPLAY_PLAN.md`).
