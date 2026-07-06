import QtQuick
import QtQuick.Shapes

// Crisp horizon reference with a barely-visible Earth-curvature bow (ends
// curve up, center dips slightly) drawn as a single quadratic Shape path —
// cheap to rasterize and stays smooth/anti-aliased at any width.
Shape {
    id: root

    property color lineColor: "#FFFFFF"
    property real lineWidth: 2
    property real curvatureDepth: 4

    implicitHeight: curvatureDepth * 2 + lineWidth + 4
    antialiasing: true

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
