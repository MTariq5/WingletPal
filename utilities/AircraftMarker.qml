import QtQuick

// Single aircraft symbol on the ATD map. One instance exists per row in
// FlightTrackerProvider's AircraftListModel — TrafficMap.qml's MapItemView
// creates/destroys these as aircraft enter/leave the model (via
// AircraftListModel::upsert's insert/remove), and re-binds `heading`/
// `onGround` whenever an existing row's data changes.
//
// Purely visual: has no idea where its data comes from, doesn't fetch
// anything, doesn't know about OpenSky or FlightTrackerProvider. Not a
// dot/circle on purpose — a heading-rotated glyph makes direction of
// travel visible at a glance, matching real ATC/traffic-display
// conventions.
Item {
    id: root

    property real heading: 0
    property bool onGround: false

    width: 18
    height: 18

    Image {
        anchors.fill: parent
        source: "qrc:/AvionicsClock/Resources/traffic/aircraft.svg"
        fillMode: Image.PreserveAspectFit
        smooth: true
        // Ground traffic (taxiing/parked) is real but less operationally
        // interesting than airborne traffic on a display sized for "what's
        // near me right now" — dimmed rather than hidden, so it's still
        // there if you look for it.
        opacity: root.onGround ? 0.55 : 1.0
        // aircraft.svg is drawn nose-up (north = 0), matching the
        // clockwise-from-north convention of `heading` directly — no
        // offset needed here.
        rotation: root.heading
        transformOrigin: Item.Center
    }
}
