# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

This is a CMake-based Qt6 GUI application (no `.pro`/qmake file, no CMakePresets.json — it's driven directly through Qt Creator kits or manual CMake invocation).

Requires Qt 6.2+ with the `Quick`, `Core`, `Network`, and `Multimedia` modules, plus the `Qt5Compat.GraphicalEffects`, `QtQuick.VirtualKeyboard`, and `QtQuick.Shapes` QML modules (used by `main.qml` and `utilities/HorizonLine.qml` respectively). The two build directories checked into this tree were generated from two Qt Creator kits: "Desktop Qt 6.6.0 MSVC2019 64bit" (Release) and "Replacement for Desktop Qt 6.4.3 MinGW 64bit" (Debug) — point `CMAKE_PREFIX_PATH` at whichever Qt install/kit is available. The `Multimedia` component is not installed by default with every Qt kit; if `find_package(Qt6 REQUIRED COMPONENTS Multimedia)` fails during configure, add it to that kit's Qt installation via the Qt Maintenance Tool:

```
cmake -S . -B build -DCMAKE_PREFIX_PATH="<path-to-Qt>\6.6.0\msvc2019_64"
cmake --build build
```

The resulting executable target is `appAvionicsClock` (`WIN32_EXECUTABLE`, GUI app, no console).

There is no automated test suite and no configured linter in this repo.

## Architecture

The app is a 320×240 frameless, fixed-size rectangular "avionics clock" widget, targeting embedded LCD panels (e.g. a Raspberry Pi driving a 320×240 display) rather than a desktop window a user resizes. All QML resources (files under `Resources/`, `utilities/`, `Brightness-Control/`) are compiled into the binary via `qt_add_qml_module(... URI AvionicsClock ...)` in `CMakeLists.txt`, and loaded at runtime through `qrc:/AvionicsClock/...` paths — there is no filesystem asset loading. When adding a new QML file or resource, it must be added to the `qt_add_qml_module` call in `CMakeLists.txt` or it won't be bundled. The one exception is `Resources/audio/*.mp3` (see `ReminderManager` below), which is bundled via `file(GLOB AUDIO_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "Resources/audio/*.mp3")` — the `RELATIVE` keyword is required, since `file(GLOB)` returns absolute paths by default and `qt_add_qml_module`'s resource system rejects those with a `QT_RESOURCE_ALIAS` error.

### C++ ⇄ QML bridge

Three `QObject` classes are registered as QML types in `main.cpp` (`qmlRegisterType`, each under its own module name/version, e.g. `import WeatherProvider 1.0`) and instantiated once at the top of `main.qml`:

- **`TimeDateProvider`** — self-contained 1s `QTimer` exposing `hours` (24h), `hours12` (1–12, derived from `hours` each tick), `minutes`/`seconds`/`timeString`/`amPm`/`date` as properties. Drives every clock face in the UI. Any 12-hour display should bind to `hours12` rather than doing `% 12` conversion in QML.
- **`LocationProvider`** — fetches IP-based geolocation from `ip-api.com` on `Component.onCompleted`, exposing `city`/`latitude`/`longitude`/`error`. Retries every 5s on failure until it succeeds.
- **`WeatherProvider`** — fetches current conditions + 24h hourly forecast from Open-Meteo (no API key required), exposing `currentTemperature`/`currentWeatherCode`/`currentWeatherDescription`/`currentWeatherIcon`/`currentWindSpeed`/`hourlyForecast` (a `QVariantList` of per-hour maps) plus `loading`/`errorString`. Auto-refreshes every 30 minutes once a location is set. WMO weather codes are mapped to description/icon in `codeToDescription`/`codeToIcon`; day-vs-night icon selection uses sunrise/sunset parsed from the API's `daily` block, but only weather code 0 (clear sky) currently has a distinct night icon — extend `codeToIcon` the same way to add more.

These three are independent — the one cross-wire is in `main.qml`: a `Connections` block calls `weather.setLocation(location.latitude, location.longitude)` whenever `LocationProvider.locationChanged` fires, which is what actually triggers the first weather fetch. A second, similarly independent `Connections` block wires `utilities/ReminderManager.qml`'s `reminderStarted`/`reminderFinished` signals to `funnyEyes.lookAtUser()`/`resumeAutonomy()` (see below).

### QML UI structure (`main.qml`)

A single `Window` with `Qt.FramelessWindowHint`, fully opaque (`color: "#121212"`) and pinned to a fixed `320×240` size (`minimumWidth/maximumWidth`/`minimumHeight/maximumHeight` all equal `width`/`height` — no native resize, no circular clipping/`OpacityMask` anywhere). A 40px transparent `Rectangle` (`dragArea`) at the top handles window dragging via mouse deltas, since the window has no native title bar.

Sizing is driven entirely by a handful of properties declared on the root `Window` (`screenWidth`, `screenHeight`, `uiScale`, `gaugeSize`, `fontLarge`/`fontMedium`/`fontSmall`) — every page's clock-face size and font size derives from these rather than hardcoded pixel values, so porting to another panel (480×320, 800×480, ...) means changing `screenWidth`/`screenHeight` and nothing else.

The body is a 4-page `SwipeView`:
1. **PFD clock** — `utilities/PfdBackground.qml` fills the page with a synthetic sky/ground/horizon (see below); on top sits `Resources/eaid/clock-pfd.svg` (a transparent-background attitude-indicator/clock face with pitch ladder, aircraft symbol, and hour markers) plus `hourArrow.svg`/`minuitesArrow.svg` needle overlays, all sized to `gaugeSize` and `anchors.centerIn` the page. Needle `rotation` bound to `timeDate.hours/minutes/seconds`, same formulas as the HSI page below.
2. **Analog HSI clock** — stacked SVG layers from `Resources/ehsi/` (dial → bezel → hour needle → minute needle → seconds bug), each sized to `gaugeSize` and centered; each needle's `rotation` bound directly to `timeDate.hours/minutes/seconds`.
3. **Digital clock ("cockpit" theme)** — restyled as a premium avionics display: dark radial gradient background (`#2B2B2B` center → `#121212` edge via `RadialGradient`), and the `hh:mm:ss AM/PM` clock row (bound to `timeDate.hours12`, zero-padded in QML) rendered in gold/amber (`#D9A441`) with a subtle `DropShadow` for lift, not glow. Below the clock sits `utilities/FunnyEyes.qml` (see below), then date/temperature/city. Temperature is bound to `weather.currentTemperature`, rounded, `°C` suffix — not hardcoded. The settings-gear button (`settingBtn`) is currently `visible: false` (hidden but still wired to open the settings drawer if re-enabled).
4. **Weather page** — background photo + `FastBlur`-based glassmorphism panel, live time (also `hours12`, 12-hour) + date + city — the top info block (location row / clock row / date) is centered as a whole via `Layout.alignment: Qt.AlignHCenter` on each row (no hardcoded left margins) — and a horizontal `ListView` bound to `weather.hourlyForecast`, delegating each entry to `utilities/CustomTempContainer.qml`.

A slide-down settings drawer (`settingsCarbet`, animated via a `Behavior on y`) hosts `Brightness-Control/BritnessControl.qml` — this is a self-contained slider (0–254) with no effect on the actual system/display brightness; it's UI-only. `utilities/CloseButton.qml` exists but is unused and references a resource path that isn't in the qml module (`/Resources/flpn/closeIcon.svg`).

Reusable QML components live under `utilities/` and `Brightness-Control/`, imported into `main.qml` via relative directory imports (`import "./utilities"`, `import "./Brightness-Control"`) rather than a versioned module.

### `utilities/FunnyEyes.qml` — desktop companion eyes

A pair of cartoon eyes drawn entirely from QML primitives (no images/emoji/SVG): each eye is `Rectangle` circles (sclera → gradient iris → pupil → highlight) plus a soft-gray eyelid `Rectangle`, all clipped to a circle via `OpacityMask` so the eyelid reads as covering a round eye. A single `blinkAmount` property (0 = open, 1 = closed) drives both eyes' eyelids; a `Timer` re-randomizes its own `interval` (2–3s) after each firing and triggers a short `SequentialAnimation` (close/hold/open, ~200ms total) via the exposed `blinkOnce()` function. `expression` exists as a no-op hook for future expressions (wink, sleepy, happy, etc.) without reworking the blink mechanics. Instantiated once on Page 3, between the clock and the date.

`lookX`/`lookY` (-1..1, offsetting the iris/pupil via `anchors.horizontalCenterOffset`/`verticalCenterOffset`) are no longer just hooks — they're driven by a second, independent `Timer` (3–6s, re-randomized each firing) that calls `lookAround()`: picks one of left/right/up/down (never diagonal, and avoids repeating the previous direction when another choice exists), then animates out and back to center via a `SequentialAnimation` (`InOutQuad` move out → `PauseAnimation` → `InOutCubic` move back), all fully independent of `blinkAnim` so the two never visually collide.

`autonomousLookEnabled` gates only that random look-around timer (blinking is never affected). Two functions build on top of it for external callers (currently `ReminderManager`, below): `lookAtUser()` disables autonomous look-around, cancels any in-flight look, animates the pupils back to dead center, and blinks once; `resumeAutonomy()` re-enables random look-around. This is how the health-reminder feature makes the eyes "look at the user" without any popup/UI.

### `utilities/PfdBackground.qml` — Garmin/Dynon-style synthetic horizon

Composes three small components into Page 1's background, replacing the old flat blue/brown rectangles: `SkyGradient.qml` (vertical gradient, deep aviation blue at the top fading to a pale horizon haze), `GroundGradient.qml` (flat-shaded brown gradient, no texture/noise), and `HorizonLine.qml` (a `QtQuick.Shapes` quadratic path giving a crisp anti-aliased white horizon line with a barely-visible Earth-curvature bow — ends curve up, center dips slightly).

Sky, ground and horizon all live inside an internal `horizonGroup` Item, sized to 3x the max of `PfdBackground`'s own width/height and clipped by the root (`clip: true`), so it can move/rotate without ever exposing an edge. `pitch`/`roll` properties are already wired into `horizonGroup`'s `x`/`y`/`rotation` (via `pixelsPerDegree`), but both default to `0` — no attitude animation is driven yet. Wiring them to real flight/attitude data is a future change that should only ever touch `PfdBackground.qml`, not `SkyGradient`/`GroundGradient`/`HorizonLine`.

### `utilities/ReminderManager.qml` — hourly developer-health voice reminders

A self-contained scheduler, instantiated once in `main.qml` as `healthReminder`, independent of every other provider (same "cross-wired only via `Connections`" pattern as `LocationProvider`/`WeatherProvider`). A `Timer` fires every `reminderIntervalMs` (`60 * 60 * 1000`, the real 60-minute cadence) relative to app startup, not synced to the clock. On each tick, `triggerReminder()`:

- no-ops if `remindersEnabled` is `false` (the property reserved for a future Do-Not-Disturb setting — the timer keeps ticking regardless, it just skips playback/signals), or if a clip is already playing (`player.playbackState === MediaPlayer.PlayingState`), guaranteeing no overlap;
- otherwise picks a random entry from `reminderSources` (never repeating `lastReminderIndex`), sets it as the `MediaPlayer`'s `source`, emits `reminderStarted()`, and calls `player.play()`.

`onPlaybackStateChanged` emits `reminderFinished()` when the player transitions to `StoppedState` (i.e. playback naturally ends). Playback goes through Qt Multimedia's `MediaPlayer`/`AudioOutput` QML types, so it's async and never blocks the UI thread.

`reminderSources` is a hardcoded list of `qrc:/AvionicsClock/Resources/audio/reminderN.mp3` paths (currently `reminder1`–`reminder5`, though only 1–4 exist as real files — see `Resources/audio/README.md`). Adding a new clip means: drop the `.mp3` into `Resources/audio/` (auto-bundled by CMake's glob, no `CMakeLists.txt` edit needed) and append one line to this array.

`main.qml` wires `reminderStarted`/`reminderFinished` to `funnyEyes.lookAtUser()`/`resumeAutonomy()` — `ReminderManager` itself has zero knowledge of `FunnyEyes` or any UI, so swapping in a different reaction (or adding more, e.g. a future "wave" animation) only touches that one `Connections` block.
