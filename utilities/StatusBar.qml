import QtQuick

// Bottom floating overlay bar for Page 5 (ATD) — city + temperature on one
// line, date + time on the line below it, in a small rounded translucent
// panel rather than a full-width strip (hence "floating"). Purely
// presentational, same convention as CoordinateBar/AircraftMarker: plain
// primitive properties in, no dependency on LocationProvider/WeatherProvider/
// TimeDateProvider themselves, so AirTrafficPage is the only thing that knows
// where this data comes from.
//
// Deliberately a flat translucent Rectangle, not a FastBlur glass panel like
// the Weather page's — blurring would mean sampling the live, constantly-
// panning/zooming Map every frame instead of a static background image,
// which is a real per-frame cost this app can't spend on a Raspberry Pi Zero
// 2 W (the same reasoning TrafficMap.qml's "dark" map style comment already
// gives for skipping a shader-based tint).
Item {
    id: root

    property string city: ""
    property real temperatureC: 0
    property string dateText: ""
    property int hours12: 12
    property int minutes: 0
    property int seconds: 0
    property string amPm: ""

    readonly property string timeText: {
        const pad = (n) => n < 10 ? "0" + n : "" + n
        return pad(hours12) + ":" + pad(minutes) + ":" + pad(seconds) + " " + amPm
    }

    height: 44

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#80121212"
        border.color: "#40ffffff"
        border.width: 1
    }

    // Row 1 — city (left), temperature (right).
    Item {
        id: row1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        anchors.topMargin: 6
        height: 16

        Text {
            anchors.left: parent.left
            anchors.right: temp.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.bold: true
            font.pixelSize: 12
            elide: Text.ElideRight
            text: root.city === "" ? "NO INTERNET CONN." : root.city
        }

        Text {
            id: temp
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.bold: true
            font.pixelSize: 12
            text: Math.round(root.temperatureC) + "°C"
        }
    }

    // Row 2 — date (left), time (right).
    Item {
        anchors.top: row1.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 14

        Text {
            anchors.left: parent.left
            anchors.right: time.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: "white" //"#CCCCCC"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
            text: root.dateText
        }

        Text {
            id: time
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: "white"  //"#CCCCCC"
            font.pixelSize: 12
            font.bold: true
            text: root.timeText
        }
    }
}
