import QtQuick

// Reusable PFD attitude background: sky + ground + horizon, styled after
// Garmin G1000/G3X and Dynon SkyView synthetic horizons. Sized to the
// visible gauge area by the caller (anchors.fill/width+height); internally
// it renders onto an oversized, clipped backing square so it is already
// pitch/roll-ready.
//
// `pitch`/`roll` are wired into the transform math below but nothing
// drives them yet — today's rendering is the same flat horizon as before,
// just with real gradients and a curved horizon line instead of solid
// colors. Wiring these to real flight data is a future change that should
// only ever touch horizonGroup's x/y/rotation, not the children below.
Item {
    id: root

    property real pitch: 0            // degrees nose-up
    property real roll: 0             // degrees right-wing-down
    property real pixelsPerDegree: height / 20

    property real horizonLineWidth: 2
    property real horizonCurvature: height * 0.02

    clip: true

    // Sky, ground and horizon move and rotate together as one unit for
    // pitch/roll — kept 3x oversized relative to the visible viewport so
    // no edge is ever exposed while animating.
    Item {
        id: horizonGroup
        width: Math.max(root.width, root.height) * 3
        height: width
        x: root.width / 2 - width / 2
        y: root.height / 2 - height / 2 - root.pitch * root.pixelsPerDegree
        rotation: root.roll

        SkyGradient {
            id: sky
            width: parent.width
            height: parent.height / 2
        }

        GroundGradient {
            id: ground
            width: parent.width
            height: parent.height / 2
            anchors.top: sky.bottom
        }

        HorizonLine {
            width: parent.width
            y: sky.height - height / 2
            lineWidth: root.horizonLineWidth
            curvatureDepth: root.horizonCurvature
        }
    }
}
