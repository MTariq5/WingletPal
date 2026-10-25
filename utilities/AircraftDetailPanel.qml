import QtQuick

// Left floating "aircraft details" card for Page 5 (ATD) — slides in from
// off the left edge when a marker is tapped (see TrafficMap.qml's
// selectedIcao/aircraftSelected/aircraftDeselected) and shows that
// aircraft's telemetry. A compact vertically-centered card, not a full-
// height drawer, to actually read as "floating" rather than a docked panel.
//
// Purely presentational: `aircraft` is a plain JS object — {icao, callsign,
// latitude, longitude, heading, altitude, groundSpeed, verticalSpeed,
// lastUpdate, onGround} — the exact snapshot TrafficMap.qml's
// aircraftSelected signal carries. It's a snapshot, not a live binding into
// AircraftListModel, so the numbers here can go slightly stale if the panel
// is left open across a 30s refresh; the close button exists specifically
// so this is never a dead end even if the selected aircraft's marker is
// later removed from the map entirely (out of range) and so can no longer
// be tapped again to close it the other way.
Item {
    id: root

    property var aircraft: null
    property bool open: false

    signal closeRequested()

    readonly property int panelWidth: 130

    width: panelWidth
    height: content.implicitHeight + 10
    anchors.verticalCenter: parent.verticalCenter

    // Closed state parks the card just off the left edge of the page
    // (rather than toggling visible: false) so there's something for the
    // slide animation to animate from/to; sitting at a negative x is
    // enough to make it both invisible and unclickable with no extra
    // bookkeeping.
    x: root.open ? 8 : -panelWidth - 8
    Behavior on x {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    // Row data recomputed whenever `aircraft` changes — a plain array
    // bound through a Repeater below rather than one Text per field, so
    // adding/removing a row later is a one-line change here instead of a
    // matching pair of edits in two places.
    readonly property var detailRows: aircraft ? [
        { label: "ICAO", value: aircraft.icao },
        { label: "Altitude", value: Math.round(aircraft.altitude) + " m" },
        { label: "Speed", value: Math.round(aircraft.groundSpeed) + " m/s" },
        { label: "Heading", value: Math.round(aircraft.heading) + "°" },
        { label: "V/S", value: Math.round(aircraft.verticalSpeed) + " m/s" },
        { label: "Status", value: aircraft.onGround ? "On Ground" : "Airborne" }
    ] : []

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#CC121212"
        border.color: "#FFA500"
        border.width: 1
    }

    Column {
        id: content
        x: 8
        y: 8
        width: parent.width - 16
        spacing: 2

        Row {
            width: parent.width

            Text {
                width: parent.width - 20
                color: "#FFA500"
                font.bold: true
                font.pixelSize: 13
                elide: Text.ElideRight
                text: root.aircraft
                      ? (root.aircraft.callsign && root.aircraft.callsign !== "" ? root.aircraft.callsign : root.aircraft.icao)
                      : ""
            }

            Text {
                width: 20
                horizontalAlignment: Text.AlignRight
                color: "white"
                font.pixelSize: 12
                text: "✕"

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.closeRequested()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#40ffffff"
        }

        Repeater {
            model: root.detailRows

            delegate: Row {
                width: content.width
                spacing: 4

                Text {
                    width: 56
                    color: "#AAAAAA"
                    font.pixelSize: 10
                    text: modelData.label
                }

                Text {
                    color: "white"
                    font.bold: true
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    text: modelData.value
                }
            }
        }
    }
}
