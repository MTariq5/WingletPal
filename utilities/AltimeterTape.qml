import QtQuick 2.15


Item {
    id: altitudeTape
    width: 50
    height: 350

    property real altitude: 0                // live altitude input
    property real displayedAltitude: 0       // smoothed altitude
    property int tickmarkStepSize: 20        // this mean at every 20ft there is a tick line
    property int labelStepSize: 100           // at each 100ft there is a label
    property real pixelPerAltitude: 1        // pixels per ft
    property int totalSteps: 1000            // range of ticks up/down


    // define an offset in ft
    property real altitudeOffset: 0 //305


    property real duration: 350
    // Smooth animation
    Behavior on displayedAltitude {
        NumberAnimation {
            duration: altitudeTape.duration
            easing.type: Easing.InOutQuad
        }
    }

    onAltitudeChanged: displayedAltitude = altitude

    Rectangle {
        id: clipArea
        anchors.fill: parent
        color: "transparent"
        clip: true

        // ==== MOVING CONTENT ====
        Item {
            id: tapeContent
            width: parent.width
            height: 99999   // large so we can scroll

            // Shift so that altitude = 0 is centered
            //y: (displayedAltitude * pixelPerAltitude) - (clipArea.height / 2)
            y: ((displayedAltitude + altitudeOffset) * pixelPerAltitude) - (clipArea.height / 2)

            // Tick marks
            Repeater {
                model: totalSteps * 2 + 1   // symmetric around 0
                delegate: Rectangle {

                    property int altValue: (index - totalSteps) * tickmarkStepSize

                    width: (altValue % labelStepSize === 0) ? parent.width * 0.1 : parent.width * 0.05
                    height: 2
                    color: "white"
                    x: 0
                    y: -(altValue * pixelPerAltitude)
                }
            }

            // Labels
            Repeater {
                model: totalSteps * 2 + 1
                delegate: Text {
                    property int altValue: (index - totalSteps) * tickmarkStepSize

                    visible: (altValue % labelStepSize === 0)
                    text: altValue.toString()
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    x: parent.width * 0.1 + 2
                    y: -(altValue * pixelPerAltitude) - height / 2
                }
            }
        }
    }
}

