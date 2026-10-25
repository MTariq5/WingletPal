import QtQuick

Rectangle {
    // Limit the haze to the visible horizon despite the oversized attitude canvas.
    property real horizonFadeHeight: height * 0.35

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#2428F5" }
        GradientStop { position: Math.max(0, 1 - horizonFadeHeight / Math.max(1, height)); color: "#2428F5" }
        GradientStop { position: 1.0; color: "#6685E5" }
    }
}
