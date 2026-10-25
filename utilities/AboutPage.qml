import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    Text {
        id: title
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: "About"
        color: "#D9A441"
        font.bold: true
        font.pixelSize: 18
        font.letterSpacing: 1
    }

    // Summary text is long enough at a readable font size that it won't
    // reliably fit the ~150px of vertical space left over on a 240px-tall
    // panel once the title and footer are accounted for — wrapped in a
    // Flickable so it scrolls rather than overflowing/clipping silently.
    Flickable {
        id: summaryFlick
        anchors.top: title.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 14
        anchors.topMargin: 8
        anchors.bottomMargin: 6
        clip: true
        contentWidth: width
        contentHeight: summaryText.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Text {
            id: summaryText
            width: summaryFlick.width
            wrapMode: Text.WordWrap
            color: "white"
            font.pixelSize: 11
            lineHeight: 1.3
            textFormat: Text.RichText
            text: qsTr("<b>AvionicsClock · Desk Companion</b><br>"
                     + "A spare-time C++ and Qt/QML project combining an interactive desk companion with aviation-inspired clocks.<br><br>"
                     + "<b>See &amp; interact</b><br>"
                     + "Animated eyes follow a selected face using OpenCV detection and Kalman tracking. Stable face presence triggers a wave and an English voice greeting. Faces are tracked, not identified by name.<br><br>"
                     + "<b>Focus &amp; reminders</b><br>"
                     + "Start a 25-minute focus session with a countdown. Greetings and health reminders pause during focus; a smile, wave and voice alert mark its end.<br><br>"
                     + "<b>Make it yours</b><br>"
                     + "The top settings drawer controls camera access, sound and diagnostics. Search cities in Arabic or English; the selected English name and coordinates are saved for weather and maps. Text entry uses your physical keyboard.<br><br>"
                     + "<b>Clocks &amp; information</b><br>"
                     + "PFD and HSI clock faces, local weather, and a nearby-aircraft map complement the eyes page. The animated attitude background is a visual demo, not flight telemetry.<br><br>"
                     + "<b>Built with</b><br>"
                     + "C++17, Qt 6, QML / Qt Quick, OpenCV, Qt Multimedia and CMake. Camera processing runs on a worker thread. Face processing stays on the device.<br><br>"
                     + "<b>Data services</b><br>"
                     + "Open-Meteo weather and city search, GeoNames location data, OpenSky aircraft data and OpenStreetMap maps. Online features need internet.")
        }
    }

    Column {
        id: footer
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Tarek"
            color: "#888888"
            font.pixelSize: 10
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "m.tariq.farooq4@gmail.com"
            color: "#888888"
            font.pixelSize: 10
        }
    }
}
