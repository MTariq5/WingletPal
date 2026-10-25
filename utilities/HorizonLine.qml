import QtQuick
import QtQuick.Shapes

// Render the narrow horizon strip offscreen so its curved edges remain
// filtered when the attitude group rotates or moves by fractional pixels.
Shape {
    id: root

    property color lineColor: "#FFFFFF"
    property real lineWidth: 2
    property real curvatureDepth: 4

    implicitHeight: curvatureDepth * 2 + lineWidth + 4
    antialiasing: true
    layer.enabled: true
    layer.smooth: true
    layer.samples: 4
    layer.textureSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio * 2),
                               Math.ceil(height * Screen.devicePixelRatio * 2))

    ShapePath {
        strokeColor: root.lineColor
        strokeWidth: root.lineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        startX: 0
        startY: root.height / 2 - root.curvatureDepth
        PathQuad {
            x: root.width
            y: root.height / 2 - root.curvatureDepth
            controlX: root.width / 2
            controlY: root.height / 2 + root.curvatureDepth
        }
    }
}
