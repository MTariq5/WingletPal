import QtQuick

// Small reusable round button used for the map's "+"/"-" zoom controls.
// Deliberately dumb: it only renders a symbol and emits clicked() — it has
// no idea what "zoom" means. AirTrafficPage wires the two instances to
// TrafficMap's zoomIn()/zoomOut().
Item {
    id: root

    width: 40
    height: 40

    property string symbol: "+"
    property color backgroundColor: "#CC1E1E1E"
    property color borderColor: "#66FFFFFF"
    property color textColor: "white"

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.backgroundColor
        border.color: root.borderColor
        border.width: 1
    }

    Text {
        anchors.centerIn: parent
        text: root.symbol
        color: root.textColor
        font.bold: true
        font.pixelSize: root.height * 0.55
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
