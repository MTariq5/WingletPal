import QtQuick
import Qt5Compat.GraphicalEffects

// QML companion eyes with a bundled waving-hand SVG for face greetings.
Item {
    id: root

    // ── Appearance ───────────────────────────────────────────────────────
    property real eyeSize: 42
    property real eyeSpacing: 12
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

    // Autonomous look direction; face following takes precedence below.
    property real lookX: 0   // -1 (left) .. 1 (right), offsets iris/pupil
    property real lookY: 0   // -1 (up) .. 1 (down)
    property bool greetingActive: false
    property bool attentionActive: false
    property bool followingFace: false
    property point facePosition: Qt.point(0, 0)

    // Mirror camera X into screen space: the pupils look toward the viewer.
    property real gazeX: followingFace ? Math.max(-1, Math.min(1, -facePosition.x)) : lookX
    property real gazeY: followingFace ? Math.max(-1, Math.min(1, facePosition.y)) : lookY
    Behavior on gazeX { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    Behavior on gazeY { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    onFollowingFaceChanged: {
        resetLook()
    }
    onAttentionActiveChanged: {
        resetLook()
        if (attentionActive)
            attentionAnim.restart()
    }

    // 0 = fully open, 1 = fully closed — drives the eyelid on both eyes
    property real blinkAmount: 0

    // ── Look-around timing (ms) ──────────────────────────────────────────
    property real lookIntervalMin: 3000
    property real lookIntervalMax: 6000
    property int lookMoveDurationMin: 600
    property int lookMoveDurationMax: 800
    property int lookPauseDurationMin: 300
    property int lookPauseDurationMax: 500

    // Tracked so consecutive look-arounds avoid repeating the same direction.
    property string lastLookDirection: ""

    // RobotBehavior owns the decision to allow autonomous movement.
    property bool autonomousLookEnabled: true

    implicitWidth: eyeSize * 2 + eyeSpacing
    implicitHeight: eyeSize

    Image {
        id: wavingHand
        anchors.left: parent.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: root.eyeSize * 0.8
        height: width * 72 / 64
        source: "qrc:/AvionicsClock/Resources/waving-hand.svg"
        visible: root.greetingActive
        transformOrigin: Item.Bottom
        SequentialAnimation on rotation {
            running: root.greetingActive
            loops: Animation.Infinite
            NumberAnimation { from: -18; to: 18; duration: 220; easing.type: Easing.InOutSine }
            NumberAnimation { from: 18; to: -18; duration: 220; easing.type: Easing.InOutSine }
        }
    }

    function blinkOnce() {
        blinkAnim.restart()
    }

    function resetLook() {
        lookAroundAnim.stop()
        attentionAnim.stop()
        lookX = 0
        lookY = 0
    }

    // Picks a random left/right/up/down direction (never the previous one,
    // when another choice exists) and animates lookX/lookY out and back.
    // Independent of blinkAmount, so a blink mid-look just plays over it.
    function lookAround() {
        var directions = ["left", "right", "up", "down"]
        var choices = directions.filter(function (d) { return d !== root.lastLookDirection })
        var direction = choices[Math.floor(Math.random() * choices.length)]
        root.lastLookDirection = direction

        lookAroundAnim.targetX = (direction === "left") ? -1 : (direction === "right") ? 1 : 0
        lookAroundAnim.targetY = (direction === "up") ? -1 : (direction === "down") ? 1 : 0
        lookAroundAnim.moveDuration = root.lookMoveDurationMin + Math.random() * (root.lookMoveDurationMax - root.lookMoveDurationMin)
        lookAroundAnim.pauseDuration = root.lookPauseDurationMin + Math.random() * (root.lookPauseDurationMax - root.lookPauseDurationMin)
        lookAroundAnim.restart()
    }

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "blinkAmount"; to: 1; duration: root.closeDuration; easing.type: Easing.InQuad }
        PauseAnimation { duration: root.closedHold }
        NumberAnimation { target: root; property: "blinkAmount"; to: 0; duration: root.openDuration; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: lookAroundAnim
        property real targetX: 0
        property real targetY: 0
        property int moveDuration: 700
        property int pauseDuration: 400

        ParallelAnimation {
            NumberAnimation { target: root; property: "lookX"; to: lookAroundAnim.targetX; duration: lookAroundAnim.moveDuration; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "lookY"; to: lookAroundAnim.targetY; duration: lookAroundAnim.moveDuration; easing.type: Easing.InOutQuad }
        }
        PauseAnimation { duration: lookAroundAnim.pauseDuration }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lookX"; to: 0; duration: lookAroundAnim.moveDuration; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "lookY"; to: 0; duration: lookAroundAnim.moveDuration; easing.type: Easing.InOutCubic }
        }
    }

    // Brings the pupils back to center (in case a random look-around was
    // mid-flight) and blinks once. Independent of blinkAnim/lookAroundAnim
    // so it can't visually collide with either.
    SequentialAnimation {
        id: attentionAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "lookX"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "lookY"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
        }
        ScriptAction { script: root.blinkOnce() }
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

    // Only ticks every 3-6s and starts a ~1.5-2s animation — eyes stay idle
    // (no per-frame work) the rest of the time, same pattern as blinkTimer.
    // Disabled (not destroyed) while autonomousLookEnabled is false, e.g.
    // during a reminder's "look at the user" moment.
    Timer {
        running: root.autonomousLookEnabled && !root.followingFace
        repeat: true
        interval: root.lookIntervalMin + Math.random() * (root.lookIntervalMax - root.lookIntervalMin)
        onTriggered: {
            root.lookAround()
            interval = root.lookIntervalMin + Math.random() * (root.lookIntervalMax - root.lookIntervalMin)
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
                    anchors.horizontalCenterOffset: root.gazeX * (parent.width - width) / 2
                    anchors.verticalCenterOffset: root.gazeY * (parent.height - height) / 2

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

                // A raised lower lid gives the greeting a smiling expression.
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: root.greetingActive ? parent.height * 0.23 : 0
                    radius: width / 2
                    color: root.eyelidColor
                    Behavior on height { NumberAnimation { duration: 180 } }
                }
            }
        }
    }
}
