import QtQuick

// Vertical aviation-sky gradient: deep aviation blue at the top, softening
// through a mid blue into a pale atmospheric haze near the horizon. Split
// out as its own component so other pages (e.g. a future synthetic-vision
// view) can reuse the same sky without duplicating the stops.
Rectangle {
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#0A5EB8" }
        GradientStop { position: 1.0; color: "#67D4FF" }
    }
}
