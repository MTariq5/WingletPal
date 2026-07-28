import QtQuick
import Qt5Compat.GraphicalEffects

// Single aircraft symbol on the ATD map. One instance exists per row in
// FlightTrackerProvider's AircraftListModel — TrafficMap.qml's MapItemView
// creates/destroys these as aircraft enter/leave the model (via
// AircraftListModel::upsert's insert/remove), and re-binds `heading`/
// `onGround`/`selected` whenever an existing row's data (or the page's
// selection) changes.
//
// Purely visual: has no idea where its data comes from, doesn't fetch
// anything, doesn't know about OpenSky or FlightTrackerProvider — and,
// likewise, has no idea what "selected" means beyond "recolor myself and
// tell whoever's listening that I was tapped." TrafficMap.qml owns the
// actual selection bookkeeping (see its selectedIcao/aircraftSelected/
// aircraftDeselected).
//
// Not a dot on purpose — a heading-rotated glyph makes direction of travel
// visible at a glance, matching real ATC/traffic-display conventions.
Item {
    id: root

    property real heading: 0
    property bool onGround: false
    property bool selected: false

    signal clicked()

    width: 18
    height: 18

    // Rotation lives on this wrapping Item rather than directly on the
    // Image, so both the glyph and its selection overlay below inherit the
    // same transform automatically through normal QML parent/child
    // composition — no need to duplicate the heading binding onto the
    // overlay (and no risk of the two drifting out of sync), which would be
    // the alternative if each rotated itself independently.
    Item {
        id: rotatedGlyph
        anchors.fill: parent
        rotation: root.heading
        transformOrigin: Item.Center

        // Heading only changes when a real ~30s update lands, so without
        // this the glyph would snap to its new bearing instantly.
        // RotationAnimation.Shortest is required, not optional: plain
        // numeric interpolation from e.g. 350° to 10° would animate through
        // 360°/0°, the long way round (340° of travel), instead of
        // recognizing it as a 20° turn.
        Behavior on rotation {
            RotationAnimation { duration: 800; direction: RotationAnimation.Shortest }
        }

        Image {
            id: image
            anchors.fill: parent
            source: "qrc:/AvionicsClock/Resources/traffic/aircraft.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
            // Ground traffic (taxiing/parked) is real but less operationally
            // interesting than airborne traffic on a display sized for
            // "what's near me right now" — dimmed rather than hidden, so
            // it's still there if you look for it.
            opacity: root.onGround ? 0.55 : 1.0
            // aircraft.svg is drawn nose-up (north = 0), matching the
            // clockwise-from-north convention of `heading` directly — no
            // offset needed here.
        }

        // Recolors the glyph (otherwise a fixed black silhouette — the SVG
        // has no explicit fill, so it defaults to solid black) orange while
        // selected, instead of swapping in a second image asset. Only ever
        // active on at most one marker at a time (TrafficMap.qml enforces
        // single selection), so the extra shader pass this needs is
        // negligible even on weak GPUs — nothing like the "no shader
        // tinting" constraint TrafficMap.qml's dark map style comment
        // describes, which is about a full-screen effect running every
        // frame regardless of anything being selected.
        ColorOverlay {
            anchors.fill: image
            source: image
            color: "#FFA500"
            visible: root.selected
        }
    }

    // Hit area extended a few px beyond the 18x18 glyph — this is a touch
    // target on an embedded panel, and the drawn icon alone is small.
    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        onClicked: root.clicked()
    }
}
