import QtQuick

// Fixed "+" marking the user's position at the center of AirTrafficPage's
// map. Purely decorative/positional — it never moves; the map moves
// underneath it (bound to the live location in TrafficMap). Caller sizes
// this via width/height (square) and anchors it (typically anchors.centerIn
// the map viewport).
Item {
    id: root

    width: 20
    height: 20

    property color lineColor: "#39FF14"   // avionics-style bright green
    property real lineThickness: 2
    property real armLength: width

    Rectangle {
        // horizontal arm
        width: root.armLength
        height: root.lineThickness
        color: root.lineColor
        anchors.centerIn: parent
    }

    Rectangle {
        // vertical arm
        width: root.lineThickness
        height: root.armLength
        color: root.lineColor
        anchors.centerIn: parent
    }
}
