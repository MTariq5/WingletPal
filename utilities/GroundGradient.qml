import QtQuick

// Synthetic-terrain gradient: dark brown near the horizon lightening
// slightly toward the bottom for subtle depth — no texture/noise, matching
// the flat-shaded ground used on Garmin/Dynon PFDs.
Rectangle {
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#6A3D12" }
        GradientStop { position: 0.5; color: "#8A5323" }
        GradientStop { position: 1.0; color: "#A56B34" }
    }
}
