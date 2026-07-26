import QtQuick 2.15

import QtQuick.Controls 2.15

import "../Utilities"

import "../Utilities/iirFilter.js" as IIR_Filter

Item {
    id:altROOT
    property double scaleRatio: 1

    property double bugValue: 0
    property bool   bugvisible: true

    property real baroVal: 1101

    //added 21/4/2026
    property double simAlt: 0
    property double altitude: 0
    property double maximumAltitude: 99999
    property double minimumAltitude: 0
    property double tickmarkStepSize: 20
    property double labelStepSize: 100

    property real mainLineTickMarks_LENGHT: altROOT.width * 0.12
    property real subLineTickMarks_LENGHT: altROOT.width * 0.08

    readonly property int tickmarkCount: (maximumAltitude - minimumAltitude) / tickmarkStepSize
    readonly property int visibleTickmarkCount: altROOT.height / (tickmarkStepSize * pixelPerAltitude)

    readonly property int labelCount: (maximumAltitude - minimumAltitude) / labelStepSize
    readonly property int visibleLabelCount: altROOT.height / (labelStepSize * pixelPerAltitude)

    readonly property double pixelPerAltitude:1

    property double altitudeBugDeltaY: 0

    property bool  altfail: false


    property real duration: 500


    //added 21/4/2026
    onSimAltChanged: {
        let newAlt = simAlt + (28 * (baroVal - 1013));
        altitude = newAlt;
    }
    onAltitudeChanged: update(altitude)


    onBugValueChanged: update(altitude);

    //added 21/4/2026
    onBaroValChanged: {
        if(baroVal > 1101) baroVal = 1101;
        else if(baroVal < 745) baroVal = 1101;

        //added @ 21/4/2026
        let newAlt = simAlt + (28 * (baroVal - 1013));
        altitude = newAlt
    }

    function update(altValue) {
        altitudeBugDeltaY = (altValue - bugValue) + 138
        if      ( altitudeBugDeltaY <= 20 ) altitudeBugDeltaY = 20;
        else if ( altitudeBugDeltaY >=  270 ) altitudeBugDeltaY =  270;
        altitude_tumblerupdate(altitude);
    }

    function altitude_tumblerupdate(val, duration = 200) {
        let value;
        if(val < 0) {
            value = Math.abs(val);
            if(value > 99 && value < 999) tumblerSign.x = 85;
            else if(value > 999 && value < 9999) tumblerSign.x = 70;
            else if(value > 9999) tumblerSign.x = 52;
            else{
                tumblerSign.x = 105;
            }
            tumblerSign.text = "-";
        }
        else{
            value = val;
            tumblerSign.text = "";
        }

        //let value = Math.max(0, Math.floor(val));  // prevent negatives
        // Rightmost tumbler (20-ft steps)
        let step20Index = Math.floor((value % 100) / 20);
        tumb1.currentIndex = step20Index;

        // Hundreds digit (tumb2)
        if (value >= 100) {
            let hundreds = Math.floor((value % 1000) / 100);
            tumb2.currentIndex = hundreds + 1; // +1 because index 0 = blank
        } else {
            tumb2.currentIndex = 0; // blank
        }

        // Thousands digit (tumb3)
        if (value >= 1000) {
            let thousands = Math.floor((value % 10000) / 1000);
            tumb3.currentIndex = thousands + 1;
        } else {
            tumb3.currentIndex = 0; // blank
        }

        // Ten-thousands digit (tumb4)
        if (value >= 10000) {
            let tenThousands = Math.floor((value % 100000) / 10000);
            tumb4.currentIndex = tenThousands + 1;
        } else {
            tumb4.currentIndex = 0; // blank
        }

    }



    /* ********************** G5Altimeter ************************* */
    //Overlay Opacity
    Rectangle{
        anchors.fill: parent
        color: "black"
        opacity: 0.2
    }

    AltimeterTape{
        id:altTape
        width: parent.width * scaleRatio
        height: parent.height * scaleRatio
        altitude: altROOT.altitude
        duration: altROOT.duration
    }

    /*
    Canvas {
        id: canvas
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * scaleRatio
        height: parent.height * scaleRatio
        scale: 1 / scaleRatio
        transformOrigin: Item.TopLeft

        renderTarget: Canvas.FramebufferObject
        antialiasing: true

        onPaint:{
            var ctx = getContext('2d');
            ctx.reset();
            ctx.scale(scaleRatio,scaleRatio);

            let x = (displayedaltitude * pixelPerAltitude);
            ctx.translate(0, x);

            // White tickmarks
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = altROOT.width * 0.017;

            var lowestIndex = Math.round((displayedaltitude - minimumAltitude) / tickmarkStepSize - visibleTickmarkCount / 2)
            var highestIndex = Math.round(lowestIndex + visibleTickmarkCount)

            if(lowestIndex < 0)lowestIndex = 0

            for (var i = lowestIndex; i <= highestIndex; i++){

                if(!(i%5)){
                    ctx.beginPath()
                    ctx.moveTo(0, 0.5 * height - i * tickmarkStepSize * pixelPerAltitude)
                    ctx.lineTo(mainLineTickMarks_LENGHT, 0.5 * height - i * tickmarkStepSize * pixelPerAltitude)
                    ctx.stroke()
                }
                else{
                    ctx.beginPath()
                    ctx.moveTo(0, 0.5 * height - i * tickmarkStepSize * pixelPerAltitude)
                    ctx.lineTo(subLineTickMarks_LENGHT, 0.5 * height - i * tickmarkStepSize * pixelPerAltitude)
                    ctx.stroke()
                }
            }


            // Labels
            ctx.textAlign    = "right"
            ctx.textBaseline = 'middle'
            ctx.fillStyle    = "#ffffff"

            lowestIndex = Math.round((displayedaltitude - minimumAltitude) / labelStepSize - visibleLabelCount / 2)
            highestIndex = Math.round(lowestIndex + visibleLabelCount)

            if(lowestIndex < 0) lowestIndex = 0

            for (i = lowestIndex; i <= highestIndex; i++) {
                var valueString = i * labelStepSize
                valueString = valueString.toFixed(0)

                if(valueString.length < 4){
                    ctx.font = "bold 38px 'Courier Std'"
                    ctx.fillText(valueString, 110, 0.5 * height - i * labelStepSize * pixelPerAltitude)
                }
                else if (valueString.length === 4){
                    ctx.font = "bold 38px 'Courier Std'"
                    ctx.fillText(valueString, 135, 0.5 * height - i * labelStepSize * pixelPerAltitude)
                }
                else {
                    ctx.font = "bold 38px 'Courier Std'"
                    ctx.fillText(valueString, 135, 0.5 * height - i * labelStepSize * pixelPerAltitude)
                }
            }
        }
    }
    */

    //ALT BUG
    CustomImage{
        id: alt_bug
        anchors.left: parent.left
        y: 0
        height: 28
        source: "qrc:/Resources/G5/Altimeter/alt_bug.svg"
        visible : bugvisible
        z: ddddd.z+100
        transform: Translate {
            y: altitudeBugDeltaY

            Behavior on y{
                NumberAnimation{
                    duration: altROOT.duration
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    //FAIL SIGN
    Image{
        width: parent.width
        height: parent.height - pressureRect.height
        source: "qrc:/Resources/G5/Altimeter/alt_fail.svg"
        visible: altfail
        z:100
    }

    //REFERANCE REC FOR VERTICAL SPEED
    Rectangle{
        id:refRectangle
        width: 6
        height: 2
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color:"blue"
    }

    //VS MASK 1
    Rectangle{
        id: mask1
        width: 6
        height: 25
        anchors.right: parent.right
        anchors.bottom:refRectangle.top
        color: "magenta"
    }

    //VS MASK 2
    Rectangle{
        id: mask2
        width: 6
        height: 25
        anchors.right: parent.right
        anchors.top:refRectangle.bottom
        color : "magenta"
    }

    //VERTICAL SPEED INDICATOR
    Image{
        height: parent.height
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        fillMode: Image.PreserveAspectFit
        cache: false
        smooth: true
        antialiasing: true
        mipmap: true
        source: "qrc:/Resources/G5/Altimeter/alt_scale.svg"
        sourceSize.width: altROOT.width * 0.3
        sourceSize.height: altROOT.height - 100
    }

    //BAROMETRIC CONTAINER
    Rectangle{
        id:pressureRect
        width: altROOT.width
        height: altROOT.width * 0.2
        anchors.bottom: parent.bottom
        color: "black"
        border.width: 2
        border.color: "#00ffff"
        z: ddddd.z+ 200

        //VALUE TEXT
        Text{
            id:pressVal
            text: baroVal
            anchors.centerIn: parent
            font.bold: true
            font.pixelSize: pressureRect.width * 0.17
            color: "#00ffff"
        }

        //PRESSURE UNIT
        Text{
            id:baroUnitLabel
            text: "hpa"
            //width: 20
            anchors.left: pressVal.right
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            font.bold: true
            font.pixelSize: 15
            antialiasing:true
            renderType: Text.QtRendering
            color: "#00ffff"
        }
    }

    //BUG CONTAINER
    Rectangle{
        id:bugRect
        width: altROOT.width
        height: altROOT.width * 0.3
        anchors.top: altROOT.top
        color: "black"
        border.width: pressureRect.border.width * 0.7
        border.color: "gray"
        z: ddddd.z+200

        CImage{
            id:bugImg
            width: 22
            height: parent.height - 10
            source: "qrc:/Resources/G5/Altimeter/alt_bug.svg"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 2
        }

        //BUG VALUE
        Text {
            id:bugVal
            text:bugValue > 0 ? bugValue.toString() : "0" //bugValue.toString()
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: bugImg.right
            anchors.leftMargin: {
                if(bugValue > 9999){
                    return 2
                }
                else{
                    return 4
                }
            }
            font.bold: true
            font.pixelSize: {
                if(bugValue > 9999){
                    return pressureRect.width * 0.20
                }
                else{
                    return pressureRect.width * 0.22
                }
            }
            color: "#00ffff"
        }

        //BUG UNIT
        Text{
            text: "ft"
            width: 6
            anchors.left: bugVal.right
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            font.bold: true
            font.pixelSize: 10
            color: "#00ffff"
        }
    }

    //ALTITUIDE TUMBLER CONTAINER
    Rectangle{
        id:ddddd
        height: parent.height * 0.3
        width: 150
        color: "transparent"
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 6

        //Tumbler container Frame
        CImage {
            id: tumblerFrame
            source: "qrc:/Resources/G5/Altimeter/alt_frame.svg"
            sourceSize.width: ddddd.width - 20
            sourceSize.height: ddddd.height - 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            visible: true
        }

        //Tumbler 1 from Right [9]
        Tumbler {
            id:tumb1
            width: 30
            height:parent.height * 0.68
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            model: [ "00", "20", "40", "60", "80" ]
            visibleItemCount: 3

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString()
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: ddddd.height * 0.22
                y:-12
                rightPadding: 0
                font.bold: true
            }
        }

        //Tumbler 2 from Right [9]
        Tumbler {
            id:tumb2
            width: 18
            height:tumb1.height * 0.65
            anchors.right: tumb1.left
            anchors.rightMargin: -11.5
            anchors.verticalCenter: parent.verticalCenter

            visible: true

            model: [ " ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" ]
            visibleItemCount: 3

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString()
                horizontalAlignment: Text.AlignHCenter
                y:-22
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: ddddd.height * 0.22
                rightPadding: 0
                font.bold: true
            }
        }

        //Tumbler 3 from Right [9]
        Tumbler {
            id:tumb3
            width: 18
            height:tumb2.height
            anchors.right: tumb2.left
            anchors.rightMargin: -12
            anchors.verticalCenter: parent.verticalCenter

            visible: true

            model: [ " ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" ]
            visibleItemCount: 1

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString()
                horizontalAlignment: Text.AlignHCenter
                y:-2
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: ddddd.height * 0.28
                rightPadding: 0
                font.bold: true
            }
        }

        //Tumbler 4 from Right [9]
        Tumbler {
            id:tumb4
            width: 20
            height: tumb2.height
            anchors.right: tumb3.left
            anchors.rightMargin: -12.5
            anchors.verticalCenter: parent.verticalCenter


            visible: true

            model: [ " ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" ]
            visibleItemCount: 1

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString()
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: ddddd.height * 0.28
                y:-2
                font.bold: true
            }
        }

        //Tumbler 5 from Right [9]
        Tumbler {
            id:tumb5
            width: 22
            height:60
            anchors.right: tumb4.left
            anchors.rightMargin: -12.5
            anchors.verticalCenter: parent.verticalCenter


            visible: false

            model: 10
            visibleItemCount: 1

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString()
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: tumb1.height * 0.24
                y:-3
                font.bold: true
            }
        }

        //Tumbler Sign
        Text {
            id: tumblerSign
            text: qsTr("")
            font.pixelSize: 20
            font.bold: true
            color: "white"

            /*
                1st place 105
                2nd place 85
                3rd place 70
                4th place 52
            */
            x: 105

            anchors.verticalCenter: parent.verticalCenter
        }
    }

    /* **********************************************************9 */

}

