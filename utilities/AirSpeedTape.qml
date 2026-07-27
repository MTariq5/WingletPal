import QtQuick 2.15

Item {
    id: airspeedTape
    width: 80
    height: 280

    //PROPERTIES
    property real airspeed: 0                 // live airspeed (knots)
    property real displayedAirspeed: 0        // smoothed airspeed
    property int tickmarkStepSize: 10         // 10 kts per tick
    property int labelStepSize: 20            // label every 50 kts
    property real pixelPerKnot: 2             // pixels per kt
    property int totalSteps: 500              // range of ticks up/down

    // define an offset in ft
    property real airSpeedOffset: 142

    //Limits Zones
    property int limitContainerWhiteWidth : 6
    property int limitContainerWidth : 4

    property real whiteLimitVal1: 51     //in knots
    property real whiteLimitVal2: 100     //in knots

    property real greenLimitVal1: 62    //in knots
    property real greenLimitVal2: 156    //in knots

    property real yellowLimitVal1: 156   //in knots
    property real yellowLimitVal2: 200   //in knots

    //Smooth animation
    property real duration: 250
    Behavior on displayedAirspeed {
        NumberAnimation {
            duration: airspeedTape.duration
            easing.type: Easing.InOutQuad
        }
    }
    onAirspeedChanged: displayedAirspeed = airspeed

    //CLIPPING WINDOW
    Rectangle {
        id: clipArea
        anchors.fill: parent
        color: "transparent"
        clip: true

        //MOVING CONTENT
        Item {
            id: tapeContent
            width: parent.width
            height: 99999

            // Shift tape so current speed is centered
            y: ((displayedAirspeed + airSpeedOffset) * pixelPerKnot) - (clipArea.height / 2)

            //Tick marks
            Repeater {
                model: totalSteps + 1    //only from 0 → max
                delegate: Rectangle {
                    property int spdValue: index * tickmarkStepSize

                    width: (spdValue % labelStepSize === 0) ? parent.width * 0.2 : parent.width * 0.15
                    height: 2
                    color: "white"

                    anchors.right: parent.right
                    y: -(spdValue * pixelPerKnot)
                }
            }

            //Labels
            Repeater {
                model: totalSteps + 1
                delegate: Text {
                    property int spdValue: index * tickmarkStepSize

                    visible: (spdValue % labelStepSize === 0)
                    text: spdValue.toString()
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true

                    anchors.right: parent.right
                    anchors.rightMargin: parent.width * 0.3 + 2
                    y: -(spdValue * pixelPerKnot) - height / 2
                }
            }

            //Speed Limits
            //white Limit
            Rectangle {
                id: whiteLimit
                width: limitContainerWhiteWidth
                color: "white"
                anchors.right: parent.right
                height: (whiteLimitVal2 - whiteLimitVal1) * pixelPerKnot
                y: -height - (whiteLimitVal1 * pixelPerKnot)
            }

            //green Limit
            Rectangle {
                id: greenLimit
                width: limitContainerWidth
                color: "green"
                anchors.right: parent.right
                height: (greenLimitVal2 - whiteLimitVal1) * pixelPerKnot
                y: - height - (whiteLimitVal1 * pixelPerKnot)
            }

            //Yellow Limit
            Rectangle {
                id: yellowLimit
                width: limitContainerWidth
                color: "yellow"
                anchors.right: parent.right
                height: (yellowLimitVal2 - yellowLimitVal1) * pixelPerKnot
                y: - height - (yellowLimitVal1 * pixelPerKnot)
            }

            //Red Limit
            Rectangle {
                width: limitContainerWidth
                color: "red"
                anchors.right: parent.right
                height: (totalSteps * tickmarkStepSize - yellowLimitVal2) * pixelPerKnot
                y: -height - (yellowLimitVal2 * pixelPerKnot)
            }
        }
    }
}

