# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

This is a CMake-based Qt6 GUI application (no `.pro`/qmake file, no CMakePresets.json — it's driven directly through Qt Creator kits or manual CMake invocation).

Camera face detection also requires an OpenCV 4 C++ build with `core`, `imgproc`, `objdetect`, and `videoio`. Set `OpenCV_DIR` to the directory containing its `OpenCVConfig.cmake`; match the Qt kit's compiler and architecture. See `vision/README.md` for camera behavior and setup.

Requires Qt 6.2+ with the `Quick`, `Core`, `Network`, `Multimedia`, `Location`, and `Positioning` modules, plus the `Qt5Compat.GraphicalEffects`, `QtQuick.Shapes`, and `QtLocation`/`QtPositioning` QML modules (used by `main.qml`, `utilities/HorizonLine.qml`, and `utilities/TrafficMap.qml` respectively). The two build directories checked into this tree were generated from two Qt Creator kits: "Desktop Qt 6.6.0 MSVC2019 64bit" (Release) and "Replacement for Desktop Qt 6.4.3 MinGW 64bit" (Debug) — point `CMAKE_PREFIX_PATH` at whichever Qt install/kit is available. The `Multimedia` and `Location`/`Positioning` components are not installed by default with every Qt kit; if `find_package(Qt6 REQUIRED COMPONENTS Multimedia)` or `find_package(Qt6 REQUIRED COMPONENTS Location Positioning)` fails during configure, add the missing component(s) to that kit's Qt installation via the Qt Maintenance Tool:

```
cmake -S . -B build -DCMAKE_PREFIX_PATH="<path-to-Qt>\6.6.0\msvc2019_64"
cmake --build build
```

The resulting executable target is `appAvionicsClock` (`WIN32_EXECUTABLE`, GUI app, no console).

`qt_add_qml_module` currently raises two CMake dev warnings on every configure — `QTP0001` (default QML resource prefix) and `QTP0004` (missing per-directory `qmldir` for a multi-directory module) — because the module's `QML_FILES` span several subdirectories (`utilities/`, `Brightness-Control/`, `G5/Utilities/`, ...) without the newer per-directory-`qmldir` policy set. These are informational only, not build failures; safe to ignore unless bumping to a Qt version where the policy default flips.

If a Qt Creator **Run** fails with `Process failed: The program "appman-controller" does not exist or is not executable`, a kit's deploy configuration got set to `ApplicationManagerPlugin.Deploy.Configuration` (Qt Application Manager packaging/install steps) instead of the plain empty deploy — check `.qtcreator/CMakeLists.txt.user`'s `ProjectExplorer.Target.ActiveDeployConfiguration` for that kit and point it back at index `0` (`ProjectExplorer.DefaultDeployConfiguration`), or fix it from Qt Creator's Projects → Run panel. This has already recurred once after being fixed via the UI, so the `.user` file is the more durable fix.

For a quick headless sanity build/run outside Qt Creator (e.g. to reproduce a runtime QML error), this machine also has a Qt 6.8.3 MinGW kit at `C:/Qt/6.8.3/mingw_64` paired with the bundled compiler at `C:/Qt/Tools/mingw1310_64` (GCC 13.1) — neither of the two Qt Creator-managed kits above has a working `cl.exe`/Ninja combo reachable from a plain shell. Configure into a scratch build dir (not `build/`, which Qt Creator owns) with `-DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/mingw_64 -DCMAKE_CXX_COMPILER=C:/Qt/Tools/mingw1310_64/bin/g++.exe`, then put `C:/Qt/6.8.3/mingw_64/bin` and `C:/Qt/Tools/mingw1310_64/bin` on `PATH` before running the built `.exe` (its DLLs aren't found otherwise). Because it's a `WIN32_EXECUTABLE`, `qDebug`/`qWarning` output is silently dropped unless `QT_ASSUME_STDERR_HAS_CONSOLE=1` is set in the environment first.

**Customizing a `QtQuick.Controls` control's `background`/`contentItem`** (`Button`, `Slider`, etc.) throws `"The current style does not support customization of this control"` at runtime unless the file also does `import QtQuick.Controls.Basic` alongside the plain `import QtQuick.Controls` — this app doesn't set an app-wide `QQuickStyle`/`QT_QUICK_CONTROLS_STYLE`, so controls otherwise fall back to a platform default style that locks down customization inconsistently per control type. `Brightness-Control/BritnessControl.qml` and `utilities/CustomButtonIcon.qml` both already do this; any new file that styles a Control needs the same import.

Deterministic target-association and Kalman tests live in `tests/vision` as a standalone CMake/QtTest project; see `vision/README.md` for commands. There is no configured linter.

The startup Wi-Fi setup page (`.claude/rules/startup-connectivity.md`) shells out to an external CLI tool that isn't a Qt/CMake dependency and so isn't checked for at configure time: `nmcli` on Linux (present by default on current Raspberry Pi OS), `netsh` on Windows (built into the OS). If neither is on `PATH`, the splash/connectivity check itself still works fine — only Wi-Fi scanning/joining silently fails (`WifiManager.errorString` surfaces whatever the process reported).

## Architecture

The app is a 320×240 frameless, fixed-size rectangular "avionics clock" widget, targeting embedded LCD panels (e.g. a Raspberry Pi driving a 320×240 display) rather than a desktop window a user resizes. All QML resources (files under `Resources/`, `utilities/`, `Brightness-Control/`) are compiled into the binary via `qt_add_qml_module(... URI AvionicsClock ...)` in `CMakeLists.txt`, and loaded at runtime through `qrc:/AvionicsClock/...` paths — there is no filesystem asset loading. When adding a new QML file or resource, it must be added to the `qt_add_qml_module` call in `CMakeLists.txt` or it won't be bundled. The one exception is `Resources/audio/*.mp3` (see `ReminderManager` below), which is bundled via `file(GLOB AUDIO_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "Resources/audio/*.mp3")` — the `RELATIVE` keyword is required, since `file(GLOB)` returns absolute paths by default and `qt_add_qml_module`'s resource system rejects those with a `QT_RESOURCE_ALIAS` error.

### C++ ⇄ QML bridge

Several `QObject` classes are registered as QML types in `main.cpp` (`qmlRegisterType`, each under its own module name/version, e.g. `import WeatherProvider 1.0`). The first three are instantiated once at the top of `main.qml`:

- **`TimeDateProvider`** — self-contained 1s `QTimer` exposing `hours` (24h), `hours12` (1–12, derived from `hours` each tick), `minutes`/`seconds`/`timeString`/`amPm`/`date` as properties. Drives every clock face in the UI. Any 12-hour display should bind to `hours12` rather than doing `% 12` conversion in QML.
- **`LocationProvider`** — stores a manually selected city/latitude/longitude using `QSettings` (INI, user scope, organization `AvionicsClock`, application `Location`). First use defaults to العاشر من رمضان at 30.306503 N, 31.741455 E. The Location settings search saves the selected city and its returned coordinates together; IP geolocation is no longer used. `cityChanged` updates labels and `locationChanged` refreshes weather/map consumers.
- **`WeatherProvider`** — fetches current conditions + 24h hourly forecast from Open-Meteo (no API key required), exposing `currentTemperature`/`currentWeatherCode`/`currentWeatherDescription`/`currentWeatherIcon`/`currentWindSpeed`/`hourlyForecast` (a `QVariantList` of per-hour maps) plus `loading`/`errorString`. Auto-refreshes every 30 minutes once a location is set. WMO weather codes are mapped to description/icon in `codeToDescription`/`codeToIcon`; day-vs-night icon selection uses sunrise/sunset parsed from the API's `daily` block, but only weather code 0 (clear sky) currently has a distinct night icon — extend `codeToIcon` the same way to add more.

The fourth, **`FlightTrackerProvider`**, is instantiated later and differently — inside `utilities/AirTrafficPage.qml` (Page 5), not at the top of `main.qml` alongside the other three — since it's specific to the Air Traffic Display page and gates its own polling on that page's visibility. See `.claude/rules/air-traffic-display.md` (auto-loads when touching ATD files) for it and the rest of that feature's backend (`OpenSkyTokenManager`, `OpenSkyFlightSource`, `AircraftListModel`, etc.).

Two more, **`ConnectivityChecker`** and **`WifiManager`**, are instantiated at the top of `main.qml` alongside the first three, but exist purely to gate startup — see "Startup connectivity gating" below and `.claude/rules/startup-connectivity.md` (auto-loads when touching those files) for the full picture. `WifiManager` is abstract; `main.cpp` registers one of two platform-specific subclasses (`WifiManagerLinux`/`WifiManagerWindows`) under that same QML type name depending on which platform the app was built for.

Weather is initialized from the saved location on component completion. Subsequent changes are connected in `main.qml`: a `Connections` block calls `weather.setLocation(location.latitude, location.longitude)` whenever `LocationProvider.locationChanged` fires, which refreshes weather after a manual location change. `RobotBehavior.qml` combines camera, tracking, greeting and reminder inputs into seven behavior states and supplies the eyes' rendering inputs (see below).

### Startup connectivity gating (splash screen + Wi-Fi setup)

The app doesn't show its normal UI until real internet access is confirmed — not just a network interface being up. `main.qml`'s root `Window` has an `appState` property (`"splash"` | `"wifiSetup"` | `"ready"`) that decides what's on screen; the existing `SwipeView`/settings drawer/drag handle (`mainRec`) is never unmounted, it's simply painted over by `utilities/SplashScreen.qml` or `utilities/WifiSetupPage.qml`, declared as `Window`-level siblings after `mainRec` so whichever is visible covers everything inside it. `SplashScreen` shows for a guaranteed minimum ~2s (`splashMinTimer`) while `ConnectivityChecker` probes real connectivity (a lightweight HTTP request, not an OS-reported link state); if that fails, `WifiSetupPage` lets the user scan for and join a nearby network via `WifiManager`, then re-checks connectivity before `appState` moves on to `"ready"`. Full architecture, the `nmcli`/`netsh` platform split, and known limitations (localized `netsh` output, WPA2-only new profiles, no in-app password storage) live in `.claude/rules/startup-connectivity.md`.

### QML UI structure (`main.qml`)

A single `Window` with `Qt.FramelessWindowHint`, fully opaque (`color: "#121212"`) and pinned to a fixed `320×240` size (`minimumWidth/maximumWidth`/`minimumHeight/maximumHeight` all equal `width`/`height` — no native resize, no circular clipping/`OpacityMask` anywhere). A transparent `Rectangle` (`dragArea`) at the top (40px normally, 8px on the camera page to keep controls accessible) handles window dragging via mouse deltas, since the window has no native title bar.

Sizing is driven entirely by a handful of properties declared on the root `Window` (`screenWidth`, `screenHeight`, `uiScale`, `gaugeSize`, `fontLarge`/`fontMedium`/`fontSmall`) — every page's clock-face size and font size derives from these rather than hardcoded pixel values, so porting to another panel (480×320, 800×480, ...) means changing `screenWidth`/`screenHeight` and nothing else.

The body is a `SwipeView` with 8 pages defined, 7 currently live:
0. **G5 test page** (unnumbered, no comment header beyond `//TEST PAGE`) — instantiates `G5Altimeter`/`G5AirspeedIndicator` directly on a plain green `Rectangle`. See `.claude/rules/g5-test-page.md` (auto-loads when touching `G5/**` or its two `utilities/` copies) — this page is a work-in-progress import from another project, not part of the "real" clock UI. **Currently commented out** — wrapped in a `/* ... */` block in `main.qml`, so it is not one of `swipeView`'s live children today. Re-enabling it shifts every other page's live child index up by one.
1. **PFD clock** — `utilities/PfdBackground.qml` fills the page with a synthetic sky/ground/horizon (see below); on top sits `Resources/eaid/clock-pfd.svg` (a transparent-background attitude-indicator/clock face with aircraft symbol and hour markers, printed with a static pitch ladder graphic that the live `pitchLadder` overlay — see below — sits on top of and replaces visually) plus `hourArrow.svg`/`minuitesArrow.svg` needle overlays, all sized to `gaugeSize` and `anchors.centerIn` the page. Needle `rotation` bound to `timeDate.hours/minutes/seconds`, same formulas as the HSI page below.
2. **Analog HSI clock** — stacked SVG layers from `Resources/ehsi/` (dial → bezel → hour needle → minute needle → seconds bug), each sized to `gaugeSize` and centered; each needle's `rotation` bound directly to `timeDate.hours/minutes/seconds`.
3. **Digital clock ("cockpit" theme)** — restyled as a premium avionics display: dark radial gradient background (`#2B2B2B` center → `#121212` edge via `RadialGradient`), and the `hh:mm:ss AM/PM` clock row (bound to `timeDate.hours12`, zero-padded in QML) rendered in gold/amber (`#D9A441`) with a subtle `DropShadow` for lift, not glow. Below the clock sits `utilities/FunnyEyes.qml` (see below), then date/temperature/city. Temperature is bound to `weather.currentTemperature`, rounded, `°C` suffix — not hardcoded. The application initially selects this page. Its Settings button opens `CompanionSettings.qml` with camera/diagnostics navigation and shared sound mute/volume controls for greetings and reminders. Sound settings last for the current session. The camera page has a Back button returning here.
4. **Weather page** — background photo + `FastBlur`-based glassmorphism panel, live time (also `hours12`, 12-hour) + date + city — the top info block (location row / clock row / date) is centered as a whole via `Layout.alignment: Qt.AlignHCenter` on each row (no hardcoded left margins) — and a horizontal `ListView` bound to `weather.hourlyForecast`, delegating each entry to `utilities/CustomTempContainer.qml`.
5. **Air Traffic Display (ATD)** — `utilities/AirTrafficPage.qml`. Live OSM map centered on the current location with a fixed center crosshair, zoom controls, a map-style picker, and (as of Phase 4) live nearby-aircraft markers polled from OpenSky every 30s while the page is visible. Tapping a marker highlights it orange and slides in a left floating `AircraftDetailPanel` with its telemetry; tapping again (or the panel's "✕") closes it. A `CoordinateBar` overlay (top, DMS position) and `StatusBar` overlay (bottom-left, city/temperature/date/time) reuse `main.qml`'s existing `location`/`weather`/`timeDate` instances. See `.claude/rules/air-traffic-display.md` (auto-loads when touching ATD files) for the full backend and what's still missing (marker motion animation, traffic-count readout).
6. **About** — `utilities/AboutPage.qml`. The final swipe page: an updated companion/project summary covering camera tracking, focus sessions, location search, physical keyboard input and the technology/data services. A scroll indicator accompanies the content. Developer contact is retained. The summary uses `Text` with `wrapMode: Text.WordWrap`, wrapped in a `Flickable` since it doesn't reliably fit the ~150px of vertical space left over on a 240px-tall panel once the title/footer are accounted for, plus developer name/email at the bottom, mirroring the same contact line already shown briefly on `utilities/SplashScreen.qml`'s startup screen — this page is where that stays permanently visible/reachable rather than only during the ~2s splash window.

7. **Face detection** — `utilities/CameraPage.qml`. Explicit camera start/stop, camera index selection, and per-frame face count through `vision/CameraController`. The main `Window` owns the `appCamera` instance and passes it to the page's required `camera` property. OpenCV runs on a separate thread in `FaceDetectionWorker`; the camera continues running when this page is hidden, until explicitly stopped or the application closes. Optional Preview shows mirrored live frames, boxes, measured/filtered centers, target state and timing; no identity recognition. Preview images exist only in memory while that page is visible and Preview is checked. `FaceGreeting.qml` uses this shared detection on the digital/eyes page: 800 ms presence triggers a 3-second wave/smiling expression and bundled male English greeting ("Hello, nice to meet you."); 10 seconds of absence or camera stop rearms it. Leaving the eyes page stops the greeting. `ReminderManager.active` and `FaceGreeting.active` prevent audio overlap; `RobotBehavior` selects eye attention from their activity. See `vision/README.md` and `Resources/audio/README.md`.

Numbering above matches the descriptive labels used historically, not raw `SwipeView` index. Since the G5 page is commented out, today's actual live child order is Digital/eyes (index 0) → PFD (1) → HSI (2) → Weather (3) → ATD (4) → Face detection (5) → About (6); re-enabling G5 would shift all of these up by one.

`CompanionSettings.qml` is a modal top-edge Drawer on the eyes page. A centered down-arrow button opens it with a slide-down transition; the up-arrow closes it. Camera opens the camera page with Preview off; Diagnostics opens it with Preview on. Both require explicit camera start. Other pages remain available through swiping. The top drag strip is 8px on the eyes and camera pages so it does not intercept their controls.

Reusable QML components live under `utilities/` and `Brightness-Control/`, imported into `main.qml` via relative directory imports (`import "./utilities"`, `import "./Brightness-Control"`) rather than a versioned module.

### `utilities/FunnyEyes.qml` — desktop companion eyes

Camera detection runs a frontal Haar pass and two profile passes (original and horizontally mirrored grayscale) per frame. Both OpenCV 4.12.0 cascades are bundled under `Resources/models/`. `vision/FaceDetections.h` maps mirrored boxes back and suppresses duplicate overlapping boxes, preserving frontal results first. The largest remaining box initializes a target; `FaceTracker` then associates nearby plausible boxes and estimates center/velocity with a constant-velocity Kalman filter. A missing target is predicted for at most 600 ms before reacquisition is allowed. This adds processing cost but leaves greeting timing unchanged; see `vision/README.md` for limitations.

A pair of cartoon eyes drawn from QML primitives, with a bundled SVG waving hand shown during greetings: each eye is `Rectangle` circles (sclera → gradient iris → pupil → highlight) plus a soft-gray eyelid `Rectangle`, all clipped to a circle via `OpacityMask` so the eyelid reads as covering a round eye. A single `blinkAmount` property (0 = open, 1 = closed) drives both eyes' eyelids; a `Timer` re-randomizes its own `interval` (2–3s) after each firing and triggers a short `SequentialAnimation` (close/hold/open, ~200ms total) via the exposed `blinkOnce()` function. Instantiated once on Page 3, between the clock and the date.

`lookX`/`lookY` (-1..1, offsetting the iris/pupil via `anchors.horizontalCenterOffset`/`verticalCenterOffset`) are no longer just hooks — they're driven by a second, independent `Timer` (3–6s, re-randomized each firing) that calls `lookAround()`: picks one of left/right/up/down (never diagonal, and avoids repeating the previous direction when another choice exists), then animates out and back to center via a `SequentialAnimation` (`InOutQuad` move out → `PauseAnimation` → `InOutCubic` move back), all fully independent of `blinkAnim` so the two never visually collide.

`RobotBehavior.qml` is the single behavioral state selector: priority is Break, Focus, Reminder, Greeting (with camera running), Searching/Attentive (valid predicted/measured target), then Idle. Its outputs bind `FunnyEyes.followingFace`, `attentionActive`, `greetingActive`, and `autonomousLookEnabled`. Only Idle permits random looks; audio expressions can coexist with following. `FunnyEyes` handles drawing, blinking and pose-reset animation, with no loss timer or imperative speaking-mode setters. The tracker owns the 600 ms prediction limit. The diagnostic camera page displays `Robot: <stateName>`. State transitions and eye interactions have standalone Qt Quick tests under `tests/behavior`.

Face following overrides autonomous/speaking direction while `followingFace` is true. `RobotBehavior.followingFace` requires both a running camera and `CameraController.trackingValid`, without an additional QML grace period. `facePosition` uses the Kalman estimate by default; the camera page's **Kalman gaze** switch selects the last measured center instead, while the filter still runs for association/diagnostics. `gazeX` mirrors camera X, `gazeY` keeps Y, with 180 ms drawing interpolation. The worker emits `FaceFrame` snapshots (detections, target index/number, raw and estimated centers, timing, optional copied QImage); `CameraPreview` paints the GUI copy. A controller timer expires stale targets even if frames stop arriving. Greeting presence remains raw detection-based. Stop/error clears target state and preview. See `vision/README.md` for filter tuning, coordinates and geometric-association limitations.

### `utilities/PfdBackground.qml` — Garmin/Dynon-style synthetic horizon

Composes three components into Page 1's background: `SkyGradient.qml` uses royal blue `#2428F5`, fading to `#6685E5` at the horizon; `GroundGradient.qml` fades from golden brown `#947022` at the horizon to dark brown `#4B3815`. The palette follows the supplied Garmin reference without its glass reflection. The fade spans 28% of the visible viewport height for sky and 30% for ground, independent of the oversized backing canvas. `HorizonLine.qml` draws the thin white horizon with a subtle curvature. Clock overlays and attitude animation remain independent of the palette.

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

A self-contained scheduler, instantiated once in `main.qml` as `healthReminder`, connected to the greeting component through `main.qml`. A `Timer` fires every `reminderIntervalMs` (`60 * 60 * 1000`, the real 60-minute cadence) relative to app startup, not synced to the clock. On each tick, `triggerReminder()`:

- no-ops if `remindersEnabled` is `false` (disabled by `main.qml` during greetings; the timer keeps ticking but skips that reminder), or if a clip is loading or playing (`active`), guaranteeing no overlap;
- otherwise picks a random entry from `reminderSources` (never repeating `lastReminderIndex`), sets it as the `MediaPlayer`'s `source`, sets `active`, emits `reminderStarted()`, and calls `player.play()`.

`active` clears and `reminderFinished()` fires when playback stops or reports an error. Playback errors are logged. Playback goes through Qt Multimedia's `MediaPlayer`/`AudioOutput` QML types, so it's async and never blocks the UI thread.

`reminderSources` is a hardcoded list of `qrc:/AvionicsClock/Resources/audio/reminderN.mp3` paths (currently `reminder1`–`reminder5`, though only 1–4 exist as real files — see `Resources/audio/README.md`). Adding a new clip means: drop the `.mp3` into `Resources/audio/` (auto-bundled by CMake's glob, no `CMakeLists.txt` edit needed) and append one line to this array.

`main.qml` passes reminder and greeting activity to `RobotBehavior`, which selects the attention expression. `ReminderManager` has no direct dependency on the eyes.


### Page 5 — Air Traffic Display (ATD) — see `.claude/rules/air-traffic-display.md`

Full architecture (QML layer, C++ backend chain, OSM tile setup gotchas, zoom/style implementation notes, what's built vs. not per the phase plan) lives in that rules file — it loads automatically whenever any ATD-related file is touched (`utilities/AirTrafficPage.qml`, `TrafficMap.qml`, `AircraftMarker.qml`, the `OpenSky*`/`FlightTracker*`/`Aircraft*`/`GeoBoundingBox*` C++ files, or `AIR_TRAFFIC_DISPLAY_PLAN.md`).

### Focus sessions

`FocusSession` is registered from C++ as `FocusSession 1.0`. `start()` begins a
25-minute session; calling it while active leaves the deadline intact. `cancel()`
clears the countdown without emitting `completed`. Remaining seconds are rounded
up from a monotonic elapsed timer, rather than counting timer callbacks. Sessions
continue across page changes but are not persisted across application restarts.

The eyes-page settings drawer starts or cancels a session. Starting stops current
greeting/reminder/completion audio. Greetings and reminders are suppressed during
Focus and the six-second Break celebration, while face following continues.
The date line beneath the eyes displays the countdown, then a break message.
`FocusCompletion.qml` plays the bundled male Arabic completion clip and drives the
happy/waving pose through `RobotBehavior`; mute and volume apply to this clip too.
Standalone C++ lifecycle tests live in `tests/focus` (configure with the Qt kit,
build, then run `ctest --test-dir build-focus-tests --output-on-failure`).

### City search and saved location

The companion drawer's Location button opens `LocationSettings.qml`. Users enter
a city name in Arabic or English. Search runs after a 350 ms typing pause (at least two characters); Enter searches immediately. Results request English names and show city,
region and country; tapping a result saves its coordinates and name together.
Back leaves the saved location unchanged. Existing saved coordinates remain
valid; the initial preset is still 10th of Ramadan for a fresh installation.

`CitySearch` uses the Open-Meteo geocoding API (GeoNames data) asynchronously.
Arabic input searches with language=ar, then resolves each returned GeoNames ID
through the get endpoint with language=en before publishing results. English
input searches directly with language=en. Selection saves the returned English
name. The former Arabic 10th of Ramadan preset is migrated to its English name
without changing its saved coordinates.
Typing a new query or closing the popup cancels the debounce timer, aborts the pending request and clears
results. A revision check rejects obsolete replies. Requests time out after
15 seconds; errors and empty results are displayed without changing the saved
location. Search needs internet; displaying the saved city does not.
API reference: https://open-meteo.com/en/docs/geocoding-api

`LocationProvider` persists the selected city using QSettings. `WeatherProvider`
tags requests with a location revision and ignores responses from earlier
locations. Search, persistence, invalid-response and cancellation tests live in
`tests/location`. Tests use a local HTTP server and isolated temporary settings.

### Text input

Text fields use the user's physical keyboard and system input language. The app
does not create an on-screen keyboard or force a Qt input-method plugin. Qt
Virtual Keyboard is not an application dependency.
