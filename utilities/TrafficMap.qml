import QtQuick
import QtLocation
import QtPositioning

// Owns the Map + OpenStreetMap plugin: camera (center/zoom), tile caching,
// and (Phase 4) the on-map aircraft marker layer. No networking beyond map
// tiles, and — despite hosting a MapItemView below — zero knowledge of
// FlightTrackerProvider, OpenSky, or Aircraft's fields beyond the four role
// names (latitude/longitude/heading/onGround) the delegate binds to. Qt
// Location requires a MapItemView to be a Map's child to position items in
// map coordinates at all, which is the one reason this file knows about
// aircraft markers rather than AirTrafficPage compositing them on top —
// there is no way to anchor a MapQuickItem to a Map from outside the Map
// itself. `aircraftModel` is supplied by the caller (AirTrafficPage, from
// FlightTrackerProvider.model); this file never constructs or owns a model.
//
// `center` defaults to a placeholder coordinate for standalone use; as of
// Phase 2, AirTrafficPage always overrides it with the live LocationProvider
// fix (or its own placeholder while waiting on the first fix) — nothing in
// this file changed to support that, only the caller's binding.
Item {
    id: root

    property var center: QtPositioning.coordinate(30.245393, 31.754506) // standalone-use default
    // Default chosen to roughly match FlightTrackerProvider's default
    // searchRadiusKm (50km, i.e. a ~100km-wide query box): at zoom 8 a
    // 320px-wide viewport shows on the order of 100+ km across, so most
    // aircraft already fetched are visible on first render without the
    // user having to zoom out manually. Zoom and search radius are still
    // independent knobs (per the plan, radius is fixed "for now") — this
    // is just a better-matched starting point, not a coupling between them.
    property real zoomLevel: 8
    readonly property real minZoomLevel: map.minimumZoomLevel
    readonly property real maxZoomLevel: map.maximumZoomLevel

    // Bound from AirTrafficPage to FlightTrackerProvider.model. Left null
    // until then (e.g. if TrafficMap is ever used standalone), in which
    // case MapItemView below simply renders nothing.
    property var aircraftModel: null

    // "standard" | "dark". Satellite isn't offered here yet — see
    // darkOverlay comment and MapStyleMenu.qml for why.
    property string mapStyle: "standard"

    // icao24 of the currently-tapped aircraft, or "" if none. The single
    // source of truth for which marker is highlighted orange (each
    // delegate below compares its own model.icao against this); the
    // caller (AirTrafficPage) only ever reads it indirectly via the two
    // signals below, or clears it directly (e.g. from a detail panel's
    // close button) — it's a plain property, not read-only, specifically
    // so that reset path works without needing a dedicated function call.
    property string selectedIcao: ""

    // Emitted with a snapshot object — {icao, callsign, latitude,
    // longitude, heading, altitude, groundSpeed, verticalSpeed, lastUpdate,
    // onGround} — whenever a marker is tapped and becomes the new
    // selection. A snapshot, not a live binding into aircraftModel: the
    // caller's detail panel shows this data as of the moment of the tap,
    // not continuously refreshed as AircraftListModel::upsert updates the
    // row underneath it.
    signal aircraftSelected(var aircraft)

    // Emitted when the currently-selected marker is tapped again (toggling
    // selection off). Carries no data — the caller just needs to know to
    // close whatever it opened in response to aircraftSelected.
    signal aircraftDeselected()

    // Single entry point every delegate's AircraftMarker.onClicked calls.
    // Toggles: tapping the already-selected aircraft clears the selection
    // instead of re-selecting it, which is what lets "tap it again" double
    // as the close gesture the plan calls for, without the caller having to
    // track "is this the same one I already had open" itself.
    function handleMarkerClicked(aircraft) {
        if (root.selectedIcao === aircraft.icao) {
            root.selectedIcao = ""
            root.aircraftDeselected()
        } else {
            root.selectedIcao = aircraft.icao
            root.aircraftSelected(aircraft)
        }
    }

    // root.zoomLevel is the single source of truth; map.zoomLevel is a pure
    // one-way binding to it (see below). Previously these mutated
    // map.zoomLevel directly, which — because map.zoomLevel already had an
    // active binding to root.zoomLevel — silently *deleted* that binding on
    // the very first click (imperative assignment always breaks a QML
    // binding). Mutating root.zoomLevel instead leaves the binding intact,
    // and is also what the Behavior below needs in order to animate.
    function zoomIn() {
        root.zoomLevel = Math.min(root.zoomLevel + 1, map.maximumZoomLevel)
    }

    function zoomOut() {
        root.zoomLevel = Math.max(root.zoomLevel - 1, map.minimumZoomLevel)
    }

    Plugin {
        id: osmPlugin
        name: "osm"

        // Keeps tiles on disk so the map still renders (from cache) when
        // offline or freshly restarted — required for "keep displaying the
        // map" under Error Handling in the plan. Directory is created by Qt
        // if missing.
        PluginParameter {
            name: "osm.mapping.cache.directory"
            value: "AvionicsClock/osm-tile-cache"
        }

        // Verified against Qt's own osm plugin source
        // (qgeotiledmappingmanagerengineosm.cpp): the built-in "Street Map"
        // type's *primary* server is Qt's own "maps-redirect.qt.io"
        // redirect/resolution service — that is the "now-default Qt
        // Location OSM tile provider" QTBUG-114118 says now serves the
        // "API Key Required" watermark for gated content. (Earlier
        // suspicion that this was zoom-level-specific, e.g. cached low
        // zooms vs. fresh high zooms, was a guess and turned out not to be
        // the real mechanism — see the activeMapType note on Map below for
        // what actually fixed it.)
        //
        // Disabling the providers repository here only stops the *built-in*
        // map types (Street/Satellite/Cycle/...) from performing their
        // online "resolution" step against that redirect service — it does
        // NOT change which server they point at. It's kept as defense in
        // depth in case activeMapType selection below ever fails and Map
        // falls back to "Street Map": at least it will fail fast to that
        // type's hardcoded c.tile.openstreetmap.org backup instead of
        // hanging on maps-redirect.qt.io.
        PluginParameter {
            name: "osm.mapping.providersrepository.disabled"
            value: true
        }

        // osm.mapping.host does NOT override "Street Map" — per the source,
        // it registers an entirely separate map type ("Custom URL Map") that
        // nothing selects by default. Map.activeMapType must be pointed at
        // it explicitly (done in Map.Component.onCompleted below); this
        // parameter only supplies the URL template that new type uses. That
        // custom provider also has its redirection/resolution unconditionally
        // disabled at construction, so it never talks to maps-redirect.qt.io
        // at all — this is what actually removes the watermark, at every
        // zoom level.
        // NOTE: tile.openstreetmap.org's usage policy is for light/dev use
        // only (low volume, identifying User-Agent below). Before shipping
        // this to real users, switch to a proper tile provider (self-hosted
        // tile server, or a keyed provider like Thunderforest/MapTiler).
        PluginParameter {
            name: "osm.mapping.host"
            value: "https://tile.openstreetmap.org/%z/%x/%y.png"
        }

        // OSM's tile usage policy requires a real identifying User-Agent;
        // an unset/default one risks tiles being throttled or refused.
        PluginParameter {
            name: "osm.useragent"
            value: "AvionicsClock/1.0"
        }
    }

    Map {
        id: map
        anchors.fill: parent
        plugin: osmPlugin
        center: root.center
        zoomLevel: root.zoomLevel
        copyrightsVisible: false

        // Select the "Custom URL Map" type (added by the osm.mapping.host
        // parameter above) as active — otherwise Map silently keeps using
        // its default "Street Map" type, whose primary server is Qt's
        // key-gated maps-redirect.qt.io, and none of the plugin parameters
        // above have any visible effect. Matched by name rather than a
        // hardcoded index since supportedMapTypes' order/count depends on
        // which plugin parameters are present.
        Component.onCompleted: {
            for (let i = 0; i < supportedMapTypes.length; i++) {
                if (supportedMapTypes[i].name === "Custom URL Map") {
                    activeMapType = supportedMapTypes[i]
                    break
                }
            }
        }

        // Smooths the zoomLevel binding's value changes on screen — without
        // this, zoomIn()/zoomOut() snap the view by a whole level instantly.
        // Behavior animates a bound property's transitions the same as an
        // imperatively-set one; it does not interfere with the `zoomLevel:
        // root.zoomLevel` binding above.
        Behavior on zoomLevel {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }

        // The user's position is represented by the fixed CenterCrosshair
        // overlay in AirTrafficPage, not by panning — the map itself always
        // recenters on `root.center` (bound to live location by the caller).
        //
        // Unlike Qt5's QtLocation (which bundled pan/pinch via a `gesture:
        // MapGestureArea` property on Map), Qt6's Map has no built-in
        // gesture property at all — QML input handlers (PinchHandler,
        // DragHandler, WheelHandler) would need to be added explicitly to
        // make it interactive. We deliberately add none, so the map is
        // already non-interactive by default and can't fight the center
        // binding; zoom is only ever driven by the +/- buttons via
        // zoomIn()/zoomOut(). Revisit if a manual "pan away" mode is added.

        // One AircraftMarker per row in aircraftModel, positioned by
        // MapQuickItem at its (latitude, longitude) and rotated by
        // heading. MapItemView/AircraftListModel handle add/remove
        // automatically as aircraft enter/leave the model (see
        // AircraftListModel::upsert) — this delegate only ever reacts to
        // role changes on rows that already exist, it never decides
        // whether a marker should exist at all.
        MapItemView {
            model: root.aircraftModel

            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(model.latitude, model.longitude)
                // Center the marker on its coordinate rather than anchoring
                // by a corner (MapQuickItem's default anchorPoint is (0,0),
                // i.e. the sourceItem's top-left) — otherwise every aircraft
                // would appear offset down-and-right of its real position.
                anchorPoint: Qt.point(sourceItem.width / 2, sourceItem.height / 2)

                sourceItem: AircraftMarker {
                    heading: model.heading
                    onGround: model.onGround
                    selected: model.icao === root.selectedIcao
                    onClicked: root.handleMarkerClicked({
                        icao: model.icao,
                        callsign: model.callsign,
                        latitude: model.latitude,
                        longitude: model.longitude,
                        heading: model.heading,
                        altitude: model.altitude,
                        groundSpeed: model.groundSpeed,
                        verticalSpeed: model.verticalSpeed,
                        lastUpdate: model.lastUpdate,
                        onGround: model.onGround
                    })
                }
            }
        }
    }

    // "Dark" style — a flat, semi-transparent tint drawn on top of the same
    // standard tiles, not a second tile source. Deliberately the cheapest
    // possible option: plain alpha compositing, no shader/ShaderEffect pass,
    // so it costs effectively nothing extra on weak GPUs (Pi Zero 2 W is an
    // explicit target). A proper multiply-blend or a real dark vector
    // basemap would look nicer but isn't worth the per-frame shader cost
    // for a 320x240 panel; revisit if this ever needs to look sharper.
    //
    // True satellite imagery isn't offered yet: the OSM plugin ships no
    // free/keyless satellite backup at all (confirmed in its own source),
    // so it needs either a keyed provider (Mapbox/MapTiler/Bing) or a free-
    // but-usage-restricted source like ESRI World Imagery — either way, a
    // second Plugin+Map pair, since this plugin only supports one custom
    // tile slot. Deferred until a provider is chosen.
    Rectangle {
        anchors.fill: map
        color: "#0A0E17"
        opacity: 0.55
        visible: root.mapStyle === "dark"
    }
}
