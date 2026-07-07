import QtQuick

// Synthetic-terrain gradient: dark brown near the horizon lightening
// slightly toward the bottom for subtle depth — no texture/noise, matching
// the flat-shaded ground used on Garmin/Dynon PFDs.
Rectangle {
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#F2A61F" }
        GradientStop { position: 1.0; color: "#C47A00" }
    }
}
