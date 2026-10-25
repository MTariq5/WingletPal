import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Drawer {
    id: root
    edge: Qt.TopEdge
    dragMargin: 0
    enter: Transition {
        NumberAnimation { property: "position"; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "position"; to: 0; duration: 220; easing.type: Easing.InCubic }
    }
    modal: true
    focus: true
    leftPadding: 12
    rightPadding: 12
    topPadding: 12
    bottomPadding: 12
    property bool focusActive: false
    signal focusRequested()
    signal locationRequested()
    property real volume: 1.0
    property bool muted: false
    signal volumeEdited(real level)
    signal mutedEdited(bool silent)
    signal cameraRequested(bool showDiagnostics)

    background: Rectangle { color: "#191919"; border.color: "#D9A441" }

    contentItem: ScrollView {
        id: settingsScroll
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: settingsScroll.availableWidth
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("Companion settings")
                    color: "#D9A441"
                    font.pixelSize: 17
                    Layout.fillWidth: true
                }
                Button {
                    text: "⌃"
                    font.pixelSize: 24
                    Accessible.name: qsTr("Close companion settings")
                    onClicked: root.close()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("Camera")
                    Layout.fillWidth: true
                    onClicked: root.cameraRequested(false)
                }
                Button {
                    text: qsTr("Diagnostics")
                    Layout.fillWidth: true
                    onClicked: root.cameraRequested(true)
                }
            }
            Button {
                Layout.fillWidth: true
                text: root.focusActive ? qsTr("Cancel focus session") : qsTr("Start focus · 25 min")
                onClicked: root.focusRequested()
            }
            Button {
                text: qsTr("Location")
                Layout.fillWidth: true
                onClicked: root.locationRequested()
            }
            Switch {
                text: qsTr("Sound")
                palette.windowText: "white"
                checked: !root.muted
                onToggled: root.mutedEdited(!checked)
            }
            RowLayout {
                Text { text: qsTr("Volume"); color: "white" }
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: root.volume
                    enabled: !root.muted
                    onMoved: root.volumeEdited(value)
                }
                Text { text: Math.round(root.volume * 100) + "%"; color: "white" }
            }
        }
    }
}
