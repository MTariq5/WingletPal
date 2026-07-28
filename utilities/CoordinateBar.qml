import QtQuick

// Top overlay bar for Page 5 (ATD) — shows the user's current position in
// degrees/minutes/seconds (DMS), the format pilots/ATC actually use, rather
// than raw decimal degrees. Purely presentational: takes latitude/longitude/
// hasFix as plain properties (mirroring AircraftMarker's "no idea where its
// data comes from" convention) so it has no dependency on LocationProvider
// or AirTrafficPage's own fix-gating logic beyond what's handed to it.
//
// Sits at y:0, under main.qml's transparent 40px window-drag Rectangle —
// that's fine, this bar is text-only with no interactive elements, so it
// never needs the mouse events that Rectangle intercepts for dragging.
Item {
    id: root

    property double latitude: 0
    property double longitude: 0
    property bool hasFix: false

    width: parent ? parent.width * 0.6 : 0
    height: 22
    anchors.horizontalCenter: parent.horizontalCenter

    // Converts one decimal-degree value into a "D°MM'SS\"H" string, where H
    // is positiveSuffix/negativeSuffix depending on sign (N/S for latitude,
    // E/W for longitude). Rounding seconds to the nearest whole second can
    // carry into minutes (59.6" -> 60" -> next minute), and a carried minute
    // can in turn carry into degrees (59' -> 60' -> next degree); both carries
    // are handled explicitly rather than left to overflow into a "60"" or
    // "60'" display.
    function formatDms(value, positiveSuffix, negativeSuffix) {
        const suffix = value >= 0 ? positiveSuffix : negativeSuffix
        const absValue = Math.abs(value)

        let degrees = Math.floor(absValue)
        const minutesFloat = (absValue - degrees) * 60
        let minutes = Math.floor(minutesFloat)
        let seconds = Math.round((minutesFloat - minutes) * 60)

        if (seconds === 60) {
            seconds = 0
            minutes += 1
        }
        if (minutes === 60) {
            minutes = 0
            degrees += 1
        }

        const pad = (n) => n < 10 ? "0" + n : "" + n
        return degrees + "°" + pad(minutes) + "'" + pad(seconds) + "\"" + suffix
    }

    Rectangle {
        anchors.fill: parent
        color: "#80121212"
        radius: 4
    }

    Text {
        anchors.centerIn: parent
        color: "white"
        font.bold: true
        font.pixelSize: 14
        text: root.hasFix
              ? root.formatDms(root.latitude, "N", "S") + "   " + root.formatDms(root.longitude, "E", "W")
              : "Acquiring position…"
    }
}
