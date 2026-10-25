# AvionicsClock

A small desktop companion for work and coding, with animated eyes, aviation-inspired clocks, and focus sessions. Built with **C++17, Qt 6 / QML, and OpenCV**.

The companion lives in a draggable, fixed-size 320 × 240 window. Its eyes can follow a face through the camera, greet a visitor, and celebrate the end of a focus session.

**Status:** personal project under development. Windows is the current development platform; Linux has a Wi-Fi backend but has not been validated as part of this publication preparation. See [known limitations](#known-limitations) before trying the app.

## Features

- Animated eyes with blinking, idle movement, face following, and a waving greeting.
- A 25-minute focus timer with a countdown and completion animation/audio. Greetings and health reminders pause during focus.
- Digital, PFD-inspired, and HSI-inspired clock faces. The attitude animation is a visual effect, not flight telemetry.
- Current weather and an hourly forecast from Open-Meteo.
- City search in Arabic or English, with the selected city and coordinates saved locally.
- Nearby aircraft from OpenSky on a Qt Location map, with selectable aircraft details.
- Camera diagnostics with optional preview, tracking overlays, and a raw/filtered gaze comparison.
- Session sound controls for mute and volume.

## Requirements

| Component | Requirement |
| --- | --- |
| Compiler | C++17; the same compiler family and architecture as Qt and OpenCV |
| CMake | 3.16 or newer, as declared by the project |
| Qt | Qt 6; the project declares 6.2 as its base minimum, but all listed modules must be available in the chosen kit |
| Qt libraries | Core, Quick, Network, Multimedia, Location, Positioning |
| QML modules | Qt Quick, Controls (including Basic), Layouts, Shapes, Qt5Compat.GraphicalEffects, QtLocation, QtPositioning, QtMultimedia |
| OpenCV | OpenCV 4 C++ development build: core, imgproc, objdetect, videoio |
| Optional hardware | A camera for face following and speakers for audio |

The current local development kit is Qt 6.8.3 / MinGW 64-bit. This is not a cross-platform compatibility guarantee. Python's `opencv-python` package does not provide the C++ dependency required here. Qt Virtual Keyboard is not required; text fields use the physical keyboard and system input language.

Internet access is currently required to pass the startup connectivity check, even when you only want to use the clocks or focus timer. Weather and city search need no API key in this implementation. Aircraft data requires your own OpenSky credentials.

## Build and run

1. Install a Qt desktop kit with the libraries and QML modules listed above, plus a matching compiler and CMake build tool.
2. Install or build OpenCV 4 for that same compiler and architecture. Find the directory containing `OpenCVConfig.cmake`.
3. Open this repository's `CMakeLists.txt` in Qt Creator and select the matching desktop kit.
4. In the project's CMake configuration, set `OpenCV_DIR` to that directory. Configure and build the `appAvionicsClock` target.
5. Run `appAvionicsClock` from Qt Creator. Allow the startup connectivity check to finish.

Do not mix an MSVC OpenCV build with a MinGW Qt kit. If using shared OpenCV libraries, their runtime DLLs must also be available when launching the application.

### Using the companion

- The application opens on the digital clock / eyes page. Drag the narrow top strip to move the window, and swipe horizontally to switch pages.
- Open the top settings drawer to start/cancel a focus session, change sound controls, or open Location, Camera, or Diagnostics.
- In Location, enter a city name and select a result. The English city name and coordinates are saved together. A new installation starts with a 10th of Ramadan City preset; this is not automatic location detection.
- In Camera, choose a camera index and press **Start camera**. Camera access is explicit. After starting it, return to the eyes page to see face following and the greeting.
- **Stop camera** releases the camera. It otherwise continues processing while you visit other pages. Closing the application also stops it.
- Diagnostics can display a mirrored preview and tracking overlays. See the [camera and tracker documentation](vision/README.md).

Focus sessions and sound settings are not persisted across application restarts.

### Configure aircraft data

Copy the example file into the source root. In PowerShell:

```powershell
Copy-Item opensky.ini.example opensky.ini
```

Fill in your own values under `[opensky]`:

```ini
[opensky]
client_id=
client_secret=
```

Obtain credentials through your [OpenSky account](https://opensky-network.org/my-opensky/account). `opensky.ini` is ignored by Git; never commit credentials or tokens.

The current implementation reads this file from the source directory recorded at build time. Restart the application after editing it. Without both values, aircraft authentication reports that credentials are not configured. A portable configuration path is still needed before distributing a standalone Windows package.

## Data and privacy

- Face detection and tracking run locally through OpenCV. The application does not record camera images or upload them. Preview images are held in memory while preview is enabled and visible.
- Tracking associates face positions temporarily; it does not identify people or recognize names.
- Camera processing continues after leaving the camera page until stopped or the application closes.
- The selected city and coordinates are stored through Qt's user-scoped settings. City queries go to Open-Meteo geocoding; selected coordinates go to the weather service, and the nearby-aircraft area goes to OpenSky. Map providers receive tile requests.
- Startup probes Google's `generate_204` endpoint to check connectivity. Network services receive normal request metadata such as your IP address.
- Greeting and reminder audio is bundled and played locally; speech generation is not performed at runtime. See [audio provenance](Resources/audio/README.md).

## Tests

Tests are separate CMake projects rather than part of the main app build:

| Directory | Coverage | Additional Qt modules |
| --- | --- | --- |
| `tests/focus` | Focus-session lifecycle and timing | Test |
| `tests/vision` | Face association and Kalman tracking using synthetic detections | Test; OpenCV core |
| `tests/behavior` | Companion state selection and eye interaction | QuickTest |
| `tests/location` | Saved location, city search, and request handling | Test, Network |

Open the desired test directory's `CMakeLists.txt` in Qt Creator using the same kit. For vision tests, also set `OpenCV_DIR`. Build into a separate directory and run CTest from the kit's environment, for example when the focus test build directory is `build-focus-tests`:

```powershell
ctest --test-dir build-focus-tests --output-on-failure
```

For a multi-configuration build, add the selected configuration, for example `-C Release`. Qt/compiler runtime libraries must be on `PATH`. These tests do not establish live camera accuracy or performance.

## Known limitations

- Startup is blocked until the connectivity check succeeds; there is currently no offline bypass.
- The window is fixed at 320 × 240 and is not configured to stay above other windows.
- Camera tracking can miss faces in poor lighting, occlusion, or fast movement, and can switch targets when people overlap. Camera-driver blocking can delay shutdown.
- `ReminderManager.qml` lists `reminder5.mp3`, but only reminders 1–4 are bundled. Selecting the missing clip produces a playback error.
- The focus completion clip is currently personalized in Arabic with the name Tarek.
- The OpenSky configuration path is tied to the original source directory. This repository currently documents building from source, not a portable download.
- Wi-Fi setup uses `netsh` on Windows and `nmcli` on Linux. Windows output parsing depends on the system language; use operating-system network settings if in-app setup fails.
- Data availability depends on external services and their access policies. The clocks and aircraft map are not navigation instruments.

## Project layout

| Path | Purpose |
| --- | --- |
| `main.cpp`, `main.qml` | Application entry point and page composition |
| `utilities/` | Companion, clocks, map, settings, and other QML components |
| `vision/` | Camera worker, face detection, tracking, and preview |
| `Resources/` | Bundled graphics, audio, and face-detection models |
| `tests/` | Standalone C++ and QML test projects |
| `opensky.ini.example` | Empty aircraft-service configuration template |

## Contributing

Bug reports should include your operating system, Qt kit/compiler, OpenCV version, reproduction steps, and relevant error output with credentials and personal paths removed. For changes, keep the scope focused and run the relevant existing test project. Do not include build folders, map caches, local tool settings, or API credentials.

## License and attribution

A license for the original project code has not yet been selected. Do not assume permission to reuse or redistribute it under MIT or another open-source license. Third-party components retain their own terms; see [third-party notices](THIRD_PARTY_NOTICES.md). The [asset publication review](docs/ASSET_REVIEW.md) identifies verified upstream resources and the files that still require permission, replacement, or removal before a public release.
