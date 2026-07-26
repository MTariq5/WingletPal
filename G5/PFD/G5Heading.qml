import QtQuick 2.9
import QtQuick.Controls 2.15
import QtQuick.Extras 1.4
import QtQuick.Controls.Styles 1.4

import "../Utilities"

Rectangle {
    id:hdgROOT
    color: "transparent"
    clip: true

    property double scaleRatio: 1
    property double bugValue: 0
    property bool heading_gtoundTrk_Flage: true //select between magnometer heading {true} , ground Track from GPS {false}
    property real hdgVal: 0
    property real heading: hdgVal.toFixed(0)  // The current heading of the aircraft

    property double altitudeBugDeltaX: 209.8

    property double maximumHeading: 360
    property double minimumHeading: 0

    property int tickmarkStepSize: 1 // For every 1 degrees a tick mark
    property int labelStepSize: 10  // For every 10 degrees a label
    property real pixelPerDegree: width/40 //4.2 // Pixels per degree in the tape

    readonly property int tickmarkCount: (maximumHeading - minimumHeading) / tickmarkStepSize //360
    readonly property int visibleTickmarkCount: parent.width / (tickmarkStepSize * pixelPerDegree) //40


    property real duration: 500

    property real displayedheading: 0
    Behavior on displayedheading {
        NumberAnimation{
            duration: hdgROOT.duration
            easing.type: Easing.InOutQuad
        }
    }

    onDisplayedheadingChanged: update(displayedheading)

    //onHeadingChanged: displayedheading = heading
    onHeadingChanged: {
        displayedheading = shortestHeadingTransition(displayedheading, heading);
    }

    onBugValueChanged: {
        update(displayedheading);
    }

    Component.onCompleted: {
        update();
    }

    function update(val) {
        altitudeBugDeltaX = (bugValue - val) * pixelPerDegree + (hdgROOT.width * 0.5) + 3;
//        console.log("Heading           : " ,val);
//        console.log("altitudeBugDeltaX : " ,altitudeBugDeltaX);

        if      ( altitudeBugDeltaX <= -7 ) altitudeBugDeltaX = -7;
        else if ( altitudeBugDeltaX >=  199 ) altitudeBugDeltaX =  199;



        canvas.requestPaint();
    }

    function shortestHeadingTransition(oldValue, newValue) {
        let delta = newValue - oldValue;
        if (delta > 180) {
            newValue -= 360;
        } else if (delta < -180) {
            newValue += 360;
        }
        return newValue;
    }

    //OverLay
    Rectangle{
        width: parent.width
        height: parent.height
        color: "black"
        opacity: 0.3
    }


    Canvas {
        id: canvas
        width: (parent.width) * scaleRatio
        height: parent.height * scaleRatio
        antialiasing: true
        scale: 1 / scaleRatio
        transformOrigin: Item.TopLeft

        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext('2d');
            ctx.reset();
            ctx.scale(scaleRatio, scaleRatio);

            let width = parent.width;
            let height = parent.height;
            let centered = parent.width * 0.565;

            // Wrap heading into 0..360
            let currentHeading = displayedheading % 360;
            if (currentHeading < 0) currentHeading += 360;

            // ==== TICK MARKS ====
            {
                let lowestIndex = Math.round(currentHeading / tickmarkStepSize - visibleTickmarkCount / 2);
                let highestIndex = lowestIndex + visibleTickmarkCount;

                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = hdgROOT.width * 0.008;

                for (let i = lowestIndex; i <= highestIndex; i++) {
                    let tickHeading = (i * tickmarkStepSize) % 360;
                    if (tickHeading < 0) tickHeading += 360;

                    let xPosition = (i * tickmarkStepSize * pixelPerDegree) - (currentHeading * pixelPerDegree) + centered;

                    // normalize into [0, width)
                    while (xPosition < 0) xPosition += width;
                    while (xPosition >= width) xPosition -= width;

                    if (!(i % (labelStepSize / tickmarkStepSize))) {
                        ctx.beginPath();
                        ctx.moveTo(xPosition, height);
                        ctx.lineTo(xPosition, height * 0.75);
                        ctx.stroke();
                    } else {
                        ctx.beginPath();
                        ctx.moveTo(xPosition, height);
                        ctx.lineTo(xPosition, height * 0.86);
                        ctx.stroke();
                    }
                }
            }

            // ==== LABELS ====
            {
                ctx.fillStyle = "#ffffff";
                ctx.font = "bold 16px Arial";

                let lowestIndex = Math.floor(currentHeading / tickmarkStepSize - visibleTickmarkCount / 2);
                let highestIndex = lowestIndex + visibleTickmarkCount;

                for (let l = lowestIndex; l <= highestIndex; l++) {
                    let tickHeading = (l * tickmarkStepSize) % 360;
                    if (tickHeading < 0) tickHeading += 360;

                    // same formula as ticks
                    let xPosition_Label = (l * tickmarkStepSize * pixelPerDegree) - (currentHeading * pixelPerDegree) + centered;

                    // no wrapping here, just check visible range
                    if (xPosition_Label >= 0 && xPosition_Label <= width) {
                        if (tickHeading % labelStepSize === 0) {
                            let label = tickHeading.toString().padStart(3, '0');
                            ctx.fillText(label, xPosition_Label - ctx.measureText(label).width / 2, height * 0.65);
                        }
                    }
                }
            }
        }
    }


    //HEADING BUG
    CImage{
        id:hdgBug
        anchors.bottom: parent.bottom
        height: 12
        source: "/Resources/G5/Heading_bug.svg"
        duration: hdgROOT.duration

        transform: Translate {
            x: altitudeBugDeltaX
        }
    }


    //Container of Text Value
    Rectangle{
        id:valRect
        width: hdgROOT.width * 0.2 //80
        height: hdgROOT.width * 0.1 //45
        color: "black"
        x: (parent.width * 0.565) - width/2
        y:3

        //HEADING FRAME
        CImage {
            id: hdgFrame
            width: valRect.width * 1.14
            height: valRect.height * 1.4
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/Resources/G5/Heading/hdg_Frame.svg"
            visible: heading_gtoundTrk_Flage
        }

        //HEADING FRAME
        CImage {
            id: hdg_groundTrackFrame
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/Resources/G5/Heading/hdg_groundTrack_Frame.svg"
            visible: !heading_gtoundTrk_Flage

            Text {
                text: qsTr("TRK")
                font.bold: true
                font.pixelSize: hdgROOT.width * 0.02
                color: "white"
                anchors.left: parent.left
                anchors.leftMargin: 2
            }
        }

        //VALUE
        Text {
            id: valHdg
            text: {
                if(heading < 0){
                    return (360 + heading).toString().padStart(3, '0') + "°"
                }
                else if(heading == 360){
                    return (0).toString().padStart(3, '0') + "°"
                }
                else{
                   return heading.toString().padStart(3, '0') +"°"
                }
            }
            color:heading_gtoundTrk_Flage ? "white" : "magenta"
            font.bold: true
            font.pixelSize: heading_gtoundTrk_Flage ? hdgROOT.width * 0.07 : hdgROOT.width * 0.065
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }


}
