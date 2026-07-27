import QtQuick

// Horizontal strip of round style buttons — same circular shape/size as
// ZoomButton (reused directly, not reimplemented) — that fans out leftward
// from the map-style toggle button in AirTrafficPage. Purely a picker: it
// knows the list of style ids/labels and emits styleSelected(id); it has no
// idea how "dark" actually renders (that's TrafficMap.mapStyle's job) and
// doesn't touch the map itself. Opened/closed and positioned by
// AirTrafficPage, which anchors this menu's right edge to the toggle
// button's left edge so it always grows further left as items are added.
//
// Satellite isn't in `styles` yet — see TrafficMap.qml's darkOverlay comment
// for why. Adding it back is just another entry in this list once a real
// provider is wired in, no layout change needed.
Item {
    id: root

    property string currentStyle: "standard"
    readonly property var styles: [
        { id: "standard", label: "S" },
        { id: "dark", label: "D" }
    ]

    signal styleSelected(string styleId)

    readonly property real buttonSize: 40
    readonly property real buttonSpacing: 6

    width: row.width
    height: buttonSize

    Row {
        id: row
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.buttonSpacing

        Repeater {
            model: root.styles

            delegate: ZoomButton {
                width: root.buttonSize
                height: root.buttonSize
                symbol: modelData.label
                backgroundColor: modelData.id === root.currentStyle ? "cyan" : "#CC1E1E1E"
                textColor: modelData.id === root.currentStyle ? "#1E1E1E" : "white"
                onClicked: root.styleSelected(modelData.id)
            }
        }
    }
}
