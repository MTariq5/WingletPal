import QtQuick

Rectangle {
    property real horizonFadeHeight: height * 0.35

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#947022" }
        GradientStop { position: Math.min(1, horizonFadeHeight / Math.max(1, height)); color: "#4B3815" }
        GradientStop { position: 1.0; color: "#4B3815" }
    }
}
