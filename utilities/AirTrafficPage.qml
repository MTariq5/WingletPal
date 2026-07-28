import QtQuick
import QtQuick.Controls
import QtPositioning
import FlightTracker 1.0

// PAGE 5 — AIR TRAFFIC DISPLAY (ATD) — Phases 1-4 + part of 6.
//
// Phase 1 gave a static map + fixed crosshair + zoom controls. Phase 2 wired
// the map's center to the existing LocationProvider (currentLatitude/
// currentLongitude bound down from main.qml, same pattern reused below).
// Phase 4 adds FlightTrackerProvider: it owns the OpenSky polling schedule
// and the AircraftListModel, handed straight to TrafficMap's aircraftModel
// property. This page still does no networking/parsing itself — it just
// wires currentLatitude/currentLongitude/currentCity/currentTemperature/
// timeProvider in from main.qml's existing LocationProvider/WeatherProvider/
// TimeDateProvider instances, and `active` (see below) to gate polling.
//
// CoordinateBar (top, DMS position) and StatusBar (bottom-left, city/temp/
// date/time) cover the readout half of Phase 6's overlay ahead of schedule,
// by explicit request — see AIR_TRAFFIC_DISPLAY_PLAN.md's Phase 6 section
// for what that phase originally sketched vs. what actually got built. A
// traffic-count readout is still not built.
Item {
    id: root

    // Bound from main.qml to location.latitude / location.longitude.
    // LocationProvider defaults both to 0.0 until the first successful
    // ip-api fetch completes, so we gate on hasLocationFix below rather than
    // snapping the map to (0, 0) (Gulf of Guinea) on startup.
    property double currentLatitude: 0
    property double currentLongitude: 0
    readonly property bool hasLocationFix: currentLatitude !== 0 || currentLongitude !== 0

    // Overlay data, bound from main.qml the same way as currentLatitude/
    // currentLongitude above — reusing LocationProvider/WeatherProvider/
    // TimeDateProvider's existing single instances, no new fetch logic here.
    // timeProvider is handed down as the whole object (rather than five
    // separate primitive properties) purely because it ticks every second;
    // CoordinateBar/StatusBar themselves still only ever receive primitives,
    // matching AircraftMarker's "purely visual" convention.
    property string currentCity: ""
    property real currentTemperature: 0
    property var timeProvider: null

    // Held here (not as a self-referencing binding on trafficMap.center)
    // so the pre-fix state is an explicit, stable value rather than an
    // invalid (0,0) QGeoCoordinate on first evaluation.
    readonly property var placeholderCenter: QtPositioning.coordinate(30.245393, 31.754506)

    // Owns the OpenSky polling schedule + AircraftListModel. `active` is
    // bound to SwipeView.isCurrentItem — an attached property Qt Quick
    // Controls puts on every direct child of a SwipeView (this Item is
    // one, instantiated inline in main.qml's swipeView) — so polling and
    // the 30s refresh timer both pause automatically whenever the user
    // swipes to a different page, rather than running forever in the
    // background.
    FlightTrackerProvider {
        id: flightTracker
        currentLatitude: root.currentLatitude
        currentLongitude: root.currentLongitude
        active: root.SwipeView.isCurrentItem
    }

    Rectangle {
        anchors.fill: parent
        color: "#121212"

        TrafficMap {
            id: trafficMap
            anchors.fill: parent
            center: root.hasLocationFix
                    ? QtPositioning.coordinate(root.currentLatitude, root.currentLongitude)
                    : root.placeholderCenter
            aircraftModel: flightTracker.model
        }

        // Fixed user-position marker — always dead center, never moves.
        CenterCrosshair {
            anchors.centerIn: parent
        }

        // Top overlay — current position in DMS. Spans the full width; safe
        // to sit under main.qml's transparent 40px window-drag Rectangle
        // since it's text-only (see CoordinateBar's own comment).
        CoordinateBar {
            anchors.top: parent.top
            // anchors.left: parent.left
            // anchors.right: parent.right
            latitude: root.currentLatitude
            longitude: root.currentLongitude
            hasFix: root.hasLocationFix
        }

        // Bottom-left floating overlay — city/temperature/date/time. Right
        // edge anchored to controlColumn's left (not parent.right) so it
        // never runs under the zoom/style buttons, matching the same
        // "anchor to controlColumn, not a specific button" approach
        // MapStyleMenu already uses below.
        StatusBar {
            anchors.left: parent.left
            anchors.right: controlColumn.left
            anchors.bottom: parent.bottom
            anchors.margins: 8
            anchors.rightMargin: 6
            city: root.currentCity
            temperatureC: root.currentTemperature
            dateText: root.timeProvider ? root.timeProvider.date : ""
            hours12: root.timeProvider ? root.timeProvider.hours12 : 12
            minutes: root.timeProvider ? root.timeProvider.minutes : 0
            seconds: root.timeProvider ? root.timeProvider.seconds : 0
            amPm: root.timeProvider ? root.timeProvider.amPm : ""
        }

        // Dismiss the style menu on any tap outside it. Placed below the
        // column/menu in paint order so it never blocks their own clicks.
        MouseArea {
            anchors.fill: parent
            visible: styleMenu.visible
            onClicked: styleMenu.visible = false
        }

        // Zoom + style controls, bottom-right corner. Style toggle sits
        // above the zoom buttons; tapping it drops the style menu open to
        // its left (staying clear of the +/- buttons below).
        Column {
            id: controlColumn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            spacing: 6

            ZoomButton {
                id: styleButton
                symbol: "≡"
                onClicked: styleMenu.visible = !styleMenu.visible
            }

            ZoomButton {
                symbol: "+"
                onClicked: trafficMap.zoomIn()
            }

            ZoomButton {
                symbol: "-"
                onClicked: trafficMap.zoomOut()
            }
        }

        MapStyleMenu {
            id: styleMenu
            visible: false
            currentStyle: trafficMap.mapStyle
            // Anchored to controlColumn (a true sibling), not styleButton
            // directly — styleButton's parent is the Column, so it isn't a
            // sibling of styleMenu and QML refuses that anchor. styleButton
            // is the Column's first/top child and both it and this menu are
            // the same 40px height, so aligning top-to-top lines their
            // vertical centers up exactly without needing styleButton itself.
            anchors.right: controlColumn.left
            anchors.rightMargin: 6
            anchors.top: controlColumn.top
            onStyleSelected: (styleId) => {
                trafficMap.mapStyle = styleId
                visible = false
            }
        }
    }
}
