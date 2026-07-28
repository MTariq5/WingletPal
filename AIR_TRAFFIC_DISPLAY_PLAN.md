# Master Implementation Plan v2 — Air Traffic Display (ATD) Page

## Goal

Add a new page to the existing `SwipeView` that behaves like a Garmin-style
traffic display: an OpenStreetMap map centred on the user's location, with
nearby aircraft drawn as heading-oriented, smoothly-animated symbols. It must
stay lightweight enough for a Raspberry Pi Zero 2 W driving the fixed 320×240
panel, and be structured so future features (labels, range rings, alerts,
Track-Up mode) drop in without a redesign.

## What changed from v1 (and why)

This revision keeps v1's module philosophy but corrects four things that would
have blocked or degraded the original plan:

1. **OpenSky is now OAuth2-only.** Basic auth was removed on 18 Mar 2026.
   Access requires a `client_id`/`client_secret` exchanged for a 30-minute
   Bearer token, and every `/states/all` call is billed against a daily credit
   budget (~4,000/day registered). A 10-second refresh (8,640 req/day) is not
   viable. → refresh default is **30 s**, polling is **paused when the page is
   not visible**, and a dedicated token manager owns the OAuth lifecycle.
2. **`QVariantList` cannot do incremental updates.** v1 asked for "update
   existing aircraft, don't recreate" while exposing a `QVariantList`, which
   forces a full teardown/rebuild of every marker each refresh. → the model is
   a **`QAbstractListModel`** keyed on ICAO, emitting per-row `dataChanged`.
3. **Qt Location / Qt Positioning are new build dependencies** and, like
   Multimedia before them, are probably not in the current kits. → a Phase 0
   "prove the toolchain" step precedes any feature code.
4. **320×240 is very small and there are already 5 SwipeView children** (the
   G5 test page sits at index 0). → the ATD page is the **6th** child, and the
   overlay is trimmed to what actually fits.

---

## Architecture (single responsibility per unit)

```
LocationProvider ── lat/lon ──►┐
                               │
                     FlightTrackerProvider  (orchestrator / QML facade)
                       │   owns: refresh QTimer, cache, status, "active" gate
                       │
        ┌──────────────┼───────────────────────────┐
        ▼              ▼                             ▼
 GeoBoundingBox   FlightDataSource (interface)   AircraftListModel
   (radius→bbox)        ▲                          (QAbstractListModel)
                        │                                │ roles
                 OpenSkyFlightSource                     │
                        │                                ▼
                 OpenSkyTokenManager             MapItemView delegate
                   (OAuth2 lifecycle)                    │
                                                         ▼
                                                  AircraftMarker.qml
```

Every box below has exactly one reason to change.

### C++ units

**`OpenSkyTokenManager` (QObject)** — *OAuth2 token lifecycle only.*
Holds `client_id`/`client_secret`, exchanges them for a Bearer token, caches
it, and refreshes ~1 minute before the 30-minute expiry. Exposes the current
valid token (async, via signal) and nothing about aircraft. Credentials are
loaded from config/env at construction — never hard-coded, never sent to QML,
never committed.

**`FlightDataSource` (abstract interface)** — *the contract.*
One pure-virtual method along the lines of `requestStates(GeoBoundingBox)` plus
a `statesReady(QVector<Aircraft>)` / `requestFailed(QString)` signal pair.
Exists so OpenSky can be swapped for another feed with zero UI or provider
changes.

**`OpenSkyFlightSource : FlightDataSource` (QObject)** — *talk to OpenSky.*
Builds the `/states/all?lamin=…&lamax=…&lomin=…&lomax=…` request, attaches the
Bearer token from `OpenSkyTokenManager`, performs the async
`QNetworkAccessManager` call (same pattern as `WeatherProvider`), and parses the
raw state-vector arrays into `Aircraft` values. Knows the OpenSky wire format
and nothing else — no timers, no caching, no UI.

**`Aircraft` (Q_GADGET / plain value type)** — *one aircraft's data.*
Fields: `icao`, `callsign`, `latitude`, `longitude`, `heading`, `altitude`,
`groundSpeed`, `verticalSpeed`, `lastUpdate`. Pure data, no behaviour.

**`AircraftListModel : QAbstractListModel`** — *hold + expose the aircraft rows.*
Roles for each `Aircraft` field. Provides an `upsert(QVector<Aircraft>)` that
matches incoming aircraft to existing rows **by ICAO** and emits `dataChanged`
for moved aircraft, `beginInsertRows` for new ones, and `beginRemoveRows` for
those gone past a staleness timeout. No networking, no timers of its own beyond
optional stale-sweeping.

**`GeoBoundingBox` (helper / static functions)** — *coordinate math only.*
Converts `(latitude, longitude, radiusKm)` → `{lamin, lamax, lomin, lomax}`,
accounting for longitude degrees shrinking with latitude. Keeps that arithmetic
out of the provider.

**`FlightTrackerProvider` (QObject, registered to QML)** — *orchestration only.*
The one type QML sees. It owns the refresh `QTimer`, an `AircraftListModel`, and
a `FlightDataSource`; it does **not** perform HTTP or parse JSON itself.
Responsibilities: take lat/lon from `LocationProvider` + `searchRadiusKm`,
compute the bbox via `GeoBoundingBox`, drive the source on each tick, feed
results into the model, keep the **last successful list cached**, expose a
`status` (`Ok` / `Unavailable`) so the UI can show "Traffic Unavailable"
without clearing the map, and gate all polling behind an `active` property.

Exposed to QML: `model` (the `AircraftListModel`), `aircraftCount`,
`searchRadiusKm` (default **50 km**, fixed for now), `status`/`errorString`,
`active`.

### QML units (each one visual responsibility)

- **`AirTrafficPage.qml`** — composition and layout only. Places the map, the
  crosshair, the overlay texts, and the zoom buttons; binds them to
  `FlightTrackerProvider` and `LocationProvider`. No networking, no math.
- **`TrafficMap.qml`** — the `Map` + `osm` plugin, tile **disk cache** config,
  and camera. Keeps itself centred on `LocationProvider` lat/lon and owns the
  zoom level. Hosts a `MapItemView { model: tracker.model; delegate: AircraftMarker {} }`.
- **`AircraftMarker.qml`** — one aircraft symbol (SVG, not a dot). Rotates to
  `heading`; animates position with `CoordinateAnimation` / `Behavior on
  coordinate`. Pure visual, fully driven by delegate model data.
- **`CenterCrosshair.qml`** — the fixed "+" at map centre. Never moves.
- **`ZoomButton.qml`** — one reusable button, instantiated twice (+ / −).

---

## Build & toolchain (Phase 0 — do this first)

Before any feature code, prove the dependencies configure and render:

- Add to `CMakeLists.txt`:
  `find_package(Qt6 REQUIRED COMPONENTS Location Positioning)` and link
  `Qt6::Location Qt6::Positioning`.
- If configure fails, install those modules into the kit via the Qt Maintenance
  Tool (same situation Multimedia was in — not present by default). Confirm the
  headless 6.8.3 MinGW kit has them too, for quick sanity runs.
- Stand up a throwaway QML file with a bare centred `Map { plugin: Plugin { name: "osm" } }`
  and confirm tiles render on the target before building the page. This
  de-risks everything downstream.
- Every new `.qml`, `.cpp/.h`, and resource must be added to
  `qt_add_qml_module` in `CMakeLists.txt` or it won't be bundled.

**File layout** (kept consistent with the existing repo — flat C++ at root, QML
under `utilities/` — to avoid multiplying the module's `QTP0004`
per-directory-`qmldir` warnings):

```
OpenSkyTokenManager.h/.cpp
FlightDataSource.h
OpenSkyFlightSource.h/.cpp
Aircraft.h
AircraftListModel.h/.cpp
GeoBoundingBox.h/.cpp
FlightTrackerProvider.h/.cpp
utilities/AirTrafficPage.qml
utilities/TrafficMap.qml
utilities/AircraftMarker.qml
utilities/CenterCrosshair.qml
utilities/ZoomButton.qml
Resources/traffic/aircraft.svg
```

Register the provider in `main.cpp` beside the others
(`qmlRegisterType<FlightTrackerProvider>("FlightTracker", 1, 0, "FlightTrackerProvider")`).

---

## Incremental delivery

**Phase 1 — Page skeleton.** Add `AirTrafficPage.qml` as the **6th** SwipeView
child (after the weather page). Static map, fixed `CenterCrosshair`, two
`ZoomButton`s bottom-right. No aircraft, no provider. *Do not touch any existing
page.* → verifies the page slots in without shifting indices or breaking swipe.

**Phase 2 — Map centred on location.** `TrafficMap` binds its centre to
`LocationProvider` lat/lon (reuse the existing provider — no new positioning),
zoom buttons adjust `Map.zoomLevel`, tile disk cache configured so tiles survive
offline and restarts. Crosshair stays pinned; map moves under it.

**Phase 3 — Token + data source (no UI).** Implement `OpenSkyTokenManager` and
`OpenSkyFlightSource` against a hard-coded bbox; log parsed aircraft to verify
auth, bbox query, and parsing work end to end. Credentials from config.

**Phase 4 — Model + static markers.** Add `Aircraft`, `AircraftListModel`, and
`FlightTrackerProvider` (30 s timer, radius→bbox, upsert-by-ICAO). Render
markers via `MapItemView` + `AircraftMarker`, rotated by heading. Still no
animation.

**Phase 5 — Smooth motion. Design agreed, not yet implemented (resume here).**
Discussed two options: a simple `Behavior`/`CoordinateAnimation` tween between
each ~30 s sample (low effort, but glides then freezes for ~28 s), vs. continuous
dead-reckoning (matches FlightRadar24, more moving parts). **Decided: dead-
reckoning.** A first implementation was written and then deliberately reverted
by request (to go back to the clean Phase 4 state) — the concrete design below
is what to build next session, so it doesn't need to be re-derived:

- In `TrafficMap.qml`, not `AircraftMarker.qml` — the position lives on
  `MapQuickItem.coordinate` in the delegate, so that's where extrapolation has
  to plug in, even though `AircraftMarker` is the visual/rotation piece.
- A 1 s repeating `Timer` (e.g. `extrapolationClock`) plus a pure function
  `extrapolatedCoordinate(lat, lon, headingDeg, groundSpeedMps, lastUpdateSecs, tick)`
  that projects the last known fix forward via
  `QtPositioning.coordinate(lat, lon).atDistanceAndAzimuth(groundSpeedMps * elapsedSecs, headingDeg)`,
  with `elapsedSecs` computed from wall-clock time vs. `lastUpdate` (a Unix
  timestamp in seconds), not the tick count — `tick` is read only to force the
  binding to re-evaluate every second.
- Clamp `elapsedSecs` (e.g. 90 s, ~3 missed refreshes) so a network outage —
  during which `FlightTrackerProvider` deliberately leaves stale rows in place
  rather than clearing the map — can't dead-reckon an aircraft arbitrarily far
  from its last real fix.
- A `Behavior on coordinate` (`CoordinateAnimation`, ~1000 ms, **linear**
  easing — matches the constant-velocity assumption the extrapolation itself
  makes) smooths both the once-a-second recompute steps and the small
  correction whenever a fresh sample lands and doesn't match the dead-reckoned
  guess exactly.
- Heading is separate and simpler: `AircraftMarker.qml`'s `rotation` (bound to
  `heading`, which only changes on a real ~30 s update, unlike position) needs
  a `Behavior on rotation` using `RotationAnimation` with
  `direction: RotationAnimation.Shortest` — without it, a turn from 350° to 10°
  animates the long way round through 360°/0° instead of the real 20° turn.
- Still open, not part of the reverted attempt: stale aircraft fade/remove
  after a timeout instead of vanishing instantly (today `AircraftListModel::
  upsert` removes a row the instant its icao is missing from a batch, which
  would look abrupt combined with the animation above).

**Phase 6 — Overlay. Partially done, built differently than originally
sketched here — done by explicit request ahead of Phase 5.** This section
originally planned city top-left + traffic count top-right; what actually
got built is two small purely-presentational components (`CoordinateBar.qml`,
`StatusBar.qml`), both following the same "primitive properties in, no
knowledge of where the data comes from" convention as `AircraftMarker.qml`:

- **`CoordinateBar.qml`** — full-width bar at the very top (safe to sit under
  main.qml's transparent 40px window-drag `Rectangle`, since it's text-only
  and needs no mouse events). Shows the live fix as DMS
  (`D°MM'SS"N   D°MM'SS"E`), not raw decimal degrees — `formatDms()` handles
  the rounding-carry edge cases (59.6" -> 60" -> next minute -> possibly next
  degree) explicitly. Shows "Acquiring position…" until `hasFix` is true.
- **`StatusBar.qml`** — small rounded translucent panel, bottom-left, two
  rows (city + temperature / date + time) rather than one, because
  `TimeDateProvider.date`'s `"dddd, MMMM d, yyyy"` format is too long to
  fit alongside city/time/temperature on a single line at 320px wide. Anchored
  `right: controlColumn.left` (not `parent.right`) so it never runs under the
  zoom/style buttons — same approach `MapStyleMenu` already uses. Deliberately
  a flat translucent `Rectangle`, not a `FastBlur` glass panel like the
  Weather page's: blurring would mean sampling the live, panning/zooming `Map`
  every frame instead of a static background image, a per-frame cost this app
  can't spend on a Pi Zero 2 W.
- `AirTrafficPage.qml` forwards `currentCity`/`currentTemperature`/
  `timeProvider` down from `main.qml`'s existing `location`/`weather`/
  `timeDate` instances — same "reuse the existing provider, no new fetch
  logic" pattern already used for `currentLatitude`/`currentLongitude`.
  `timeProvider` is the one exception to "primitives only": the whole
  `TimeDateProvider` is passed down as `property var`, and `AirTrafficPage`
  itself picks off `.date`/`.hours12`/`.minutes`/`.seconds`/`.amPm` into
  primitives when it hands them to `StatusBar` — ticking every second made
  five separate forwarded properties feel like needless ceremony one level up.
- **Still not built:** the traffic-count readout (`Traffic: N`) this phase
  originally planned.

**Phase 7 — Resilience.** Cache the last good list; on request failure keep the
map and last aircraft on screen and set `status = Unavailable` → overlay shows
"Traffic Unavailable". Never clear the map, never crash.

**Phase 8 — Performance pass.** Confirm polling **pauses when the page isn't the
current SwipeView item** and when the window is inactive (biggest credit/CPU
win). Verify no per-tick object churn, marker reuse via the model, and smooth
operation on Pi Zero 2 W and Pi 4.

---

## Fixed decisions

- **Refresh:** 30 s default (OpenSky data resolution is 5 s; faster wastes
  credits), exposed as a property. Polling gated on page visibility.
- **Search radius:** `searchRadiusKm = 50`, fixed for now; converted to a bbox,
  not sent as a radius. Future: derive from zoom.
- **Zoom** affects the map only; the backend keeps requesting on the fixed
  radius.
- **Tiles:** default OSM tile servers are for light/dev use only. For a deployed
  product, switch to an own tile source or a Thunderforest key before shipping.
- **Secrets:** OpenSky `client_id`/`client_secret` live in C++/config, never in
  QML, never committed.

## Must NOT change

Page 1 PFD clock, Page 2 analog HSI, Page 3 digital clock, Page 4 weather,
`LocationProvider`, `WeatherProvider`, `TimeDateProvider`, existing animations,
existing `SwipeView` behaviour and child indices.

## Acceptance criteria

- ✅ A 6th SwipeView page (ATD) is added; all existing pages and indices are
  untouched.
- ✅ OpenStreetMap map centred on the live user location, with a fixed centre
  crosshair and working +/− zoom.
- ✅ OAuth2 auth to OpenSky via a dedicated token manager; `/states/all` queried
  by bounding box.
- ✅ Networking/parsing live entirely in `OpenSkyFlightSource`; the UI depends
  only on `FlightTrackerProvider` + `AircraftListModel`, and the source is
  swappable behind `FlightDataSource`.
- ✅ Aircraft render as heading-rotated symbols with smoothly animated position
  and heading; markers are updated in place (no full recreate).
- ✅ Overlay shows city and traffic count; zoom control present.
- ✅ On network failure the map and last-known traffic remain, "Traffic
  Unavailable" is shown, nothing crashes.
- ✅ Polling pauses when the page is off-screen; runs smoothly on Pi Zero 2 W.
- ✅ Architecture supports future additions (labels, range rings, weather
  overlay, Track-Up, conflict alerts) without redesign.
