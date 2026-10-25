import QtQuick

// Full-screen startup overlay, shown while main.qml's appState is "splash".
// Displayed for a guaranteed minimum ~2s while ConnectivityChecker's first
// check runs — the Timer/appState gating logic itself lives in main.qml,
// not here. Purely presentational: `checking` is the only input, just to
// swap the status line's wording; this component has no idea what happens
// next (WifiSetupPage vs. the main UI) — that decision belongs to main.qml
// alone.
Item {
    id: root

    property bool checking: true

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "FUNNY AVIONICS CLOCK"
            color: "#D9A441"
            font.bold: true
            font.pixelSize: 20
            font.letterSpacing: 2
        }

        // A plain rotating ring wouldn't visibly read as "spinning" — a
        // uniform circle looks identical at every rotation angle. The small
        // background-colored notch cut out of the top is what makes the
        // rotation actually visible, for the cost of one extra Rectangle
        // rather than a QtQuick.Shapes arc (already used elsewhere in this
        // app, e.g. utilities/HorizonLine.qml, but overkill for a two-
        // second cosmetic spinner).
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: "#D9A441"
                border.width: 3

                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: "#121212"
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: -3
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.checking ? "Checking connection…" : " "
            color: "#AAAAAA"
            font.pixelSize: 12
        }
    }

    // Developer contact — bottom-left, for anyone using this app who wants
    // to reach out. Purely static text, no other purpose than that.
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 1

        Text {
            text: "Tarek"
            color: "#888888"
            font.pixelSize: 9
        }
        Text {
            text: "m.tariq.farooq4@gmail.com"
            color: "#888888"
            font.pixelSize: 9
        }
    }
}
