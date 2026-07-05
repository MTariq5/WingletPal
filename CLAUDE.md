# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

This is a CMake-based Qt6 GUI application (no `.pro`/qmake file, no CMakePresets.json — it's driven directly through Qt Creator kits or manual CMake invocation).

Requires Qt 6.2+ with the `Quick`, `Core`, and `Network` modules, plus the `Qt5Compat.GraphicalEffects` and `QtQuick.VirtualKeyboard` QML modules (used by `main.qml`). The two build directories checked into this tree were generated from two Qt Creator kits: "Desktop Qt 6.6.0 MSVC2019 64bit" (Release) and "Replacement for Desktop Qt 6.4.3 MinGW 64bit" (Debug) — point `CMAKE_PREFIX_PATH` at whichever Qt install/kit is available:

```
cmake -S . -B build -DCMAKE_PREFIX_PATH="<path-to-Qt>\6.6.0\msvc2019_64"
cmake --build build
```

The resulting executable target is `appAvionicsClock` (`WIN32_EXECUTABLE`, GUI app, no console).

There is no automated test suite and no configured linter in this repo.

## Architecture

The app is a 400×400 frameless, circular "avionics clock" desktop widget. All QML resources (files under `Resources/`, `utilities/`, `Brightness-Control/`) are compiled into the binary via `qt_add_qml_module(... URI AvionicsClock ...)` in `CMakeLists.txt`, and loaded at runtime through `qrc:/AvionicsClock/...` paths — there is no filesystem asset loading. When adding a new QML file or resource, it must be added to the `qt_add_qml_module` call in `CMakeLists.txt` or it won't be bundled.

### C++ ⇄ QML bridge

Three `QObject` classes are registered as QML types in `main.cpp` (`qmlRegisterType`, each under its own module name/version, e.g. `import WeatherProvider 1.0`) and instantiated once at the top of `main.qml`:

- **`TimeDateProvider`** — self-contained 1s `QTimer` exposing `hours`/`minutes`/`seconds`/`timeString`/`amPm`/`date` as properties. Drives every clock face in the UI.
- **`LocationProvider`** — fetches IP-based geolocation from `ip-api.com` on `Component.onCompleted`, exposing `city`/`latitude`/`longitude`/`error`. Retries every 5s on failure until it succeeds.
- **`WeatherProvider`** — fetches current conditions + 24h hourly forecast from Open-Meteo (no API key required), exposing `currentTemperature`/`currentWeatherCode`/`currentWeatherDescription`/`currentWeatherIcon`/`currentWindSpeed`/`hourlyForecast` (a `QVariantList` of per-hour maps) plus `loading`/`errorString`. Auto-refreshes every 30 minutes once a location is set. WMO weather codes are mapped to description/icon in `codeToDescription`/`codeToIcon`; day-vs-night icon selection uses sunrise/sunset parsed from the API's `daily` block, but only weather code 0 (clear sky) currently has a distinct night icon — extend `codeToIcon` the same way to add more.

These three are independent — the one cross-wire is in `main.qml`: a `Connections` block calls `weather.setLocation(location.latitude, location.longitude)` whenever `LocationProvider.locationChanged` fires, which is what actually triggers the first weather fetch.

### QML UI structure (`main.qml`)

A single `Window` with `Qt.FramelessWindowHint` and a transparent background; the circular shape comes from an `OpacityMask` layered on the root `Rectangle` (`mainRec`), not from the window itself, so any new full-page content must live inside `mainRec` to get clipped to the circle. A 40px transparent `Rectangle` (`dragArea`) at the top handles window dragging via mouse deltas, since the window has no native title bar.

The body is a 3-page `SwipeView`:
1. **Analog HSI clock** — stacked SVG layers from `Resources/ehsi/` (dial → bezel → hour needle → minute needle → seconds bug), each needle's `rotation` bound directly to `timeDate.hours/minutes/seconds`.
2. **Digital clock** — time/date/city text bound to `timeDate`/`location`; the temperature line is currently a hardcoded string, not bound to `WeatherProvider`. A settings-gear button opens the settings drawer.
3. **Weather page** — background photo + `FastBlur`-based glassmorphism panel, live time/date/city, and a horizontal `ListView` bound to `weather.hourlyForecast`, delegating each entry to `utilities/CustomTempContainer.qml`.

A slide-down settings drawer (`settingsCarbet`, animated via a `Behavior on y`) hosts `Brightness-Control/BritnessControl.qml` — this is a self-contained slider (0–254) with no effect on the actual system/display brightness; it's UI-only. `utilities/CloseButton.qml` exists but is unused and references a resource path that isn't in the qml module (`/Resources/flpn/closeIcon.svg`).

Reusable QML components live under `utilities/` and `Brightness-Control/`, imported into `main.qml` via relative directory imports (`import "./utilities"`, `import "./Brightness-Control"`) rather than a versioned module.
