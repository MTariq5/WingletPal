import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import CameraController 1.0

Item {
    id: root

    required property CameraController camera
    required property string behaviorState
    property alias diagnosticsVisible: diagnostics.checked
    signal backRequested()

    Binding {
        target: root.camera
        property: "diagnosticsEnabled"
        value: root.visible && diagnostics.checked
    }

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Text {
            text: qsTr("Face detection")
            visible: !diagnostics.checked
            color: "#D9A441"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Text {
                text: qsTr("Camera")
                color: "white"
            }
            SpinBox {
                id: cameraNumber
                from: 0
                to: 9
                value: 0
                enabled: camera.state === CameraController.Stopped || camera.state === CameraController.Error
                Layout.preferredWidth: 110
                Layout.preferredHeight: 32
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 34
                text: camera.running || camera.state === CameraController.Starting
                      ? qsTr("Stop camera") : qsTr("Start camera")
                enabled: camera.state !== CameraController.Stopping
                onClicked: {
                    if (camera.running || camera.state === CameraController.Starting)
                        camera.stop()
                    else
                        camera.start(cameraNumber.value)
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Button {
                text: qsTr("Back")
                Layout.preferredWidth: 52
                Layout.preferredHeight: 30
                onClicked: root.backRequested()
            }
            CheckBox {
                id: diagnostics
                text: qsTr("Preview")
                Layout.preferredHeight: 32
                palette.windowText: "#EAEAEA"
                font.pixelSize: 12
                padding: 2
            }
            CheckBox {
                text: qsTr("Kalman gaze")
                checked: camera.kalmanEnabled
                onToggled: camera.kalmanEnabled = checked
                Layout.preferredHeight: 32
                palette.windowText: "#EAEAEA"
                font.pixelSize: 12
                padding: 2
            }
        }

        CameraPreview {
            camera: root.camera
            visible: diagnostics.checked
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 50
        }

        Text {
            visible: diagnostics.checked
            text: qsTr("Green: target  ·  White: measured  ·  Blue: Kalman")
            color: "#B9D7E5"
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }

        Flickable {
            id: statusArea
            Layout.fillWidth: true
            Layout.fillHeight: !diagnostics.checked
            Layout.preferredHeight: diagnostics.checked ? 44 : 60
            clip: true
            contentWidth: width
            contentHeight: statusText.height
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: statusText
                width: statusArea.width
                height: Math.max(implicitHeight, statusArea.height)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font.pixelSize: diagnostics.checked ? 11 : 13
                color: camera.state === CameraController.Error ? "#FF8888"
                       : camera.facePresent ? "#8CD790" : "white"
                text: {
                    switch (camera.state) {
                    case CameraController.Starting: return qsTr("Opening camera…")
                    case CameraController.Stopping: return qsTr("Stopping camera…")
                    case CameraController.Error: return camera.errorString
                    case CameraController.Running:
                        if (diagnostics.checked)
                            return qsTr("%1 faces · Target %2 · %3\n%4 ms processing · %5 FPS\nRobot: %6")
                                .arg(camera.faceCount)
                                .arg(camera.trackingValid ? camera.targetId : "—")
                                .arg(camera.predicting ? qsTr("Predicting")
                                     : camera.trackingValid ? qsTr("Measured") : qsTr("Searching"))
                                .arg(camera.processingMs.toFixed(0)).arg(camera.fps.toFixed(1))
                                .arg(root.behaviorState)
                        return camera.facePresent ? qsTr("Faces detected: %1").arg(camera.faceCount)
                                                  : qsTr("No face detected")
                    default: return qsTr("Start the camera and face the screen.")
                    }
                }
            }
        }


    }
}
