import QtQuick
import Qt5Compat.GraphicalEffects

// Reusable "desktop companion" eyes, drawn entirely from QML primitives
// (no images/emoji/SVG). Exposes lookX/lookY/expression as no-op hooks so
// future iterations (look direction, wink, sleepy, happy, ...) can drive
// the same shapes without reworking the blink mechanics below.
Item {
    id: root

    // ── Appearance ───────────────────────────────────────────────────────
    property real eyeSize: 34
    property real eyeSpacing: 14
    property color scleraColor: "#FAFAFA"
    property color irisColor: "#6B4423"
    property color pupilColor: "#141414"
    property color highlightColor: "#FFFFFF"
    property color eyelidColor: "#B0B0B0"

    // ── Blink timing (ms) ────────────────────────────────────────────────
    property int closeDuration: 80
    property int closedHold: 40
    property int openDuration: 80
    property real blinkIntervalMin: 2000
    property real blinkIntervalMax: 3000

    // ── Reserved for future expressions (unused for now) ────────────────
    property real lookX: 0   // -1 (left) .. 1 (right), offsets iris/pupil
    property real lookY: 0   // -1 (up) .. 1 (down)
    property string expression: "neutral"

    // 0 = fully open, 1 = fully closed — drives the eyelid on both eyes
    property real blinkAmount: 0

    implicitWidth: eyeSize * 2 + eyeSpacing
    implicitHeight: eyeSize

    function blinkOnce() {
        blinkAnim.restart()
    }

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "blinkAmount"; to: 1; duration: root.closeDuration; easing.type: Easing.InQuad }
        PauseAnimation { duration: root.closedHold }
        NumberAnimation { target: root; property: "blinkAmount"; to: 0; duration: root.openDuration; easing.type: Easing.OutQuad }
    }

    // Only ticks every 2-3s and starts a ~200ms animation — no continuous
    // rendering or per-frame work while the eyes are simply open.
    Timer {
        running: true
        repeat: true
        interval: root.blinkIntervalMin + Math.random() * (root.blinkIntervalMax - root.blinkIntervalMin)
        onTriggered: {
            root.blinkOnce()
            interval = root.blinkIntervalMin + Math.random() * (root.blinkIntervalMax - root.blinkIntervalMin)
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.eyeSpacing

        Repeater {
            model: 2

            delegate: Item {
                id: eye
                width: root.eyeSize
                height: root.eyeSize

                // Clips every layer below (including the eyelid) to a
                // perfect circle so the lid reads as covering a round eye.
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: eye.width
                        height: eye.height
                        radius: width / 2
                    }
                }

                // SCLERA
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.scleraColor
                }

                // IRIS
                Rectangle {
                    id: iris
                    width: parent.width * 0.55
                    height: width
                    radius: width / 2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.lookX * (parent.width - width) / 2
                    anchors.verticalCenterOffset: root.lookY * (parent.height - height) / 2

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.irisColor, 1.25) }
                        GradientStop { position: 1.0; color: Qt.darker(root.irisColor, 1.15) }
                    }
                }

                // PUPIL
                Rectangle {
                    id: pupil
                    width: iris.width * 0.5
                    height: width
                    radius: width / 2
                    color: root.pupilColor
                    anchors.centerIn: iris
                }

                // HIGHLIGHT
                Rectangle {
                    width: pupil.width * 0.35
                    height: width
                    radius: width / 2
                    color: root.highlightColor
                    x: pupil.x + pupil.width * 0.18
                    y: pupil.y + pupil.height * 0.18
                }

                // EYELID — height driven by root.blinkAmount (0 = open, 1 = closed)
                Rectangle {
                    width: parent.width
                    height: root.blinkAmount * parent.height
                    anchors.top: parent.top
                    color: root.eyelidColor
                }
            }
        }
    }
}
