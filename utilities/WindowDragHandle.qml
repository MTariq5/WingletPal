import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes

Rectangle {
    id: handle
    required property var targetWindow

    width: 32
    height: 24
    radius: 5
    color: pointer.containsMouse ? "#D0303030" : "#90121212"
    Accessible.name: qsTr("Drag to move window")

    Shape {
        anchors.centerIn: parent
        width: 18
        height: 18
        antialiasing: true
        ShapePath {
            strokeColor: pointer.containsMouse ? "#F4CB71" : "#D9A441"
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M9 1 L9 17 M1 9 L17 9 "
                    + "M6 4 L9 1 L12 4 M6 14 L9 17 L12 14 "
                    + "M4 6 L1 9 L4 12 M14 6 L17 9 L14 12"
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property bool manualMove: false
        property point pressGlobal
        property point initialPosition

        onPressed: function(mouse) {
            pressGlobal = mapToGlobal(mouse.x, mouse.y)
            initialPosition = Qt.point(handle.targetWindow.x, handle.targetWindow.y)
            manualMove = !handle.targetWindow.startSystemMove()
        }
        onPositionChanged: function(mouse) {
            if (!pressed || !manualMove)
                return
            const currentGlobal = mapToGlobal(mouse.x, mouse.y)
            handle.targetWindow.x = initialPosition.x + currentGlobal.x - pressGlobal.x
            handle.targetWindow.y = initialPosition.y + currentGlobal.y - pressGlobal.y
        }
        onReleased: manualMove = false
        onCanceled: manualMove = false
    }

    ToolTip.visible: pointer.containsMouse && !pointer.pressed
    ToolTip.delay: 700
    ToolTip.text: qsTr("Drag to move window")
}
