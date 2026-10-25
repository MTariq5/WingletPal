import QtQuick

// Reusable PFD attitude background: sky + ground + horizon, styled after
// the supplied Garmin reference's royal-blue sky and golden-brown ground. Sized to the
// visible gauge area by the caller (anchors.fill/width+height); internally
// it renders onto an oversized, clipped backing square so it is already
// pitch/roll-ready.
//
// `pitch`/`roll` are wired into the transform math below and are meant for
// real flight-telemetry data. Until telemetry exists, `useSimulatedAttitude`
// (default true) drives `simulatedRoll`/`simulatedPitch` through a looping
// demo animation instead; horizonGroup always renders off `effectiveRoll`/
// `effectivePitch`, which just pick whichever source is active. Swapping in
// real telemetry later means setting `useSimulatedAttitude: false` and
// binding `pitch`/`roll` to live data — no change to the rendering below.
Item {
    id: root

    property real pitch: 0            // degrees nose-up (real telemetry input)
    property real roll: 0             // degrees right-wing-down (real telemetry input)
    property real pixelsPerDegree: height / 20

    property bool useSimulatedAttitude: true
    property real simulatedRoll: 0
    property real simulatedPitch: 0

    readonly property real effectiveRoll: useSimulatedAttitude ? simulatedRoll : roll
    readonly property real effectivePitch: useSimulatedAttitude ? simulatedPitch : pitch

    property real horizonLineWidth: 2
    property real horizonCurvature: height * 0.02

    clip: true

    // Keep the demo gentle so the clock hands remain the visual focus.
    SequentialAnimation on simulatedRoll {
        running: root.useSimulatedAttitude
        loops: Animation.Infinite
        NumberAnimation { to: 7; duration: 6500; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 0; duration: 6500; easing.type: Easing.InOutQuad }
        NumberAnimation { to: -7; duration: 6500; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 0; duration: 6500; easing.type: Easing.InOutQuad }
    }

    // Different periods keep pitch and roll from moving in lockstep.
    SequentialAnimation on simulatedPitch {
        running: root.useSimulatedAttitude
        loops: Animation.Infinite
        NumberAnimation { to: 3; duration: 8000; easing.type: Easing.InOutCubic }
        NumberAnimation { to: 0; duration: 8000; easing.type: Easing.InOutCubic }
        NumberAnimation { to: -3; duration: 8000; easing.type: Easing.InOutCubic }
        NumberAnimation { to: 0; duration: 8000; easing.type: Easing.InOutCubic }
    }

    // Sky, ground and horizon move and rotate together as one unit for
    // pitch/roll — kept 3x oversized relative to the visible viewport so
    // no edge is ever exposed while animating.
    Item {
        id: horizonGroup
        width: Math.max(root.width, root.height) * 3
        height: width
        x: root.width / 2 - width / 2
        y: root.height / 2 - height / 2 - root.effectivePitch * root.pixelsPerDegree
        // Keep the roll pivot at the fixed gauge center after the pitch shift.
        transform: Rotation {
            origin.x: horizonGroup.width / 2
            origin.y: horizonGroup.height / 2 + root.effectivePitch * root.pixelsPerDegree
            angle: root.effectiveRoll
        }

        SkyGradient {
            id: sky
            width: parent.width
            height: parent.height / 2
            horizonFadeHeight: root.height * 0.28
        }

        GroundGradient {
            id: ground
            width: parent.width
            height: parent.height / 2
            horizonFadeHeight: root.height * 0.30
            anchors.top: sky.bottom
        }

        HorizonLine {
            width: parent.width
            height: root.horizonCurvature * 2 + root.horizonLineWidth + 4
            y: sky.height - height / 2
            lineWidth: root.horizonLineWidth
            curvatureDepth: root.horizonCurvature
        }
    }
}
