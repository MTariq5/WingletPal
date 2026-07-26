import QtQuick 2.9
import QtQuick.Controls 2.15

import "../G5/Utilities"

Item  {
    id:aisROOT
    clip  : false

    property double scaleRatio: 2.6

    property double airspeed: 0
    property double tas: 0
    property double gs: 0
    property double oat: 0

    property double bugY_Value: 0
    property double bugA_Value: 60
    property double bugG_Value: 30

    property double maximumAirspeed: 999
    property double minimumAirspeed: 0
    property double tickmarkStepSize: 5
    property double labelStepSize: 10

    readonly property double pixelPerSpeed: 8
    readonly property double highAirspeed: 170
    readonly property double lowAirspeed: 50

    readonly property int tickmarkCount: (maximumAirspeed - minimumAirspeed) / tickmarkStepSize
    readonly property int visibleTickmarkCount: parent.height / (tickmarkStepSize * pixelPerSpeed) //375

    readonly property int labelCount: (maximumAirspeed - minimumAirspeed) / labelStepSize
    readonly property int visibleLabelCount: parent.height / (labelStepSize * pixelPerSpeed)

    readonly property double redTickmarkStepSize: 5
    readonly property double redTickmarksCount: (maximumAirspeed - minimumAirspeed) / redTickmarkStepSize
    readonly property double visibleRedTickmarkCount: parent.height / (redTickmarkStepSize * pixelPerSpeed)

    property double bugY: 0
    property double bugA: 0
    property double bugG: 0

    property bool  bugvisable: false
    property bool  iasfail: false
    property bool  gsFail: false


    property real duration : 250


    property real displayedAirSpeed: 0
    Behavior on displayedAirSpeed {
        NumberAnimation{
            duration: aisROOT.duration
        }
    }

    onDisplayedAirSpeedChanged: update()

    onAirspeedChanged: displayedAirSpeed = airspeed

    onBugY_ValueChanged: update()
    onBugA_ValueChanged: update()
    onBugG_ValueChanged: update()

    function update() {
        var tempBugY = pixelPerSpeed * (airspeed - bugY_Value) ///+42.5;  // 42.5 is  correction value
        var tempBugA = pixelPerSpeed * (airspeed - bugA_Value)
        var tempBugG = pixelPerSpeed * (airspeed - bugG_Value)

        if      ( tempBugY < -120 ) tempBugY = -120;
        else if ( tempBugY >  120.0 ) tempBugY =  120.0;


        bugY = tempBugY
        bugA = tempBugA
        bugG = tempBugG

        canvas.requestPaint()
        airSpeed_tumblerupdate();
    }


    function airSpeed_tumblerupdate(){
        let value = displayedAirSpeed.toFixed(0)
        //let value = airspeed.toFixed(0) //263

        let airSpeedStr = value.toString();

//        console.log("----------------------------------------------------------")
//        console.log("Airspeed         " , value)
//        console.log("Airspeed String  " , airSpeedStr)

        // Split into desired parts: 3, 6, and 2
        let firstPart = airSpeedStr.slice(-1);       // last two digits: "3"
        let secondPart = airSpeedStr.slice(-2, -1);  // single digit: "6"
        let thirdPart = airSpeedStr.slice(-3, -2);   // remaining digits: "2"

        // Convert parts to numbers and replace NaN with 0
        let airspeedArray = [
            isNaN(parseInt(firstPart))  ? 0 : parseInt(firstPart),
            isNaN(parseInt(secondPart)) ? 0 : parseInt(secondPart),
            isNaN(parseInt(thirdPart))  ? 0 : parseInt(thirdPart)
        ];

//        console.log("airspeedArray[0] ", airspeedArray[0]);
//        console.log("airspeedArray[1] ", airspeedArray[1]);
//        console.log("airspeedArray[2] ", airspeedArray[2]);
//        console.log("----------------------------------------------------------")

        tumb1.currentIndex = airspeedArray[0]
        tumb2.currentIndex = airspeedArray[1]
        tumb3.currentIndex = airspeedArray[2]

    }


    //Overlay Opacity
    Rectangle{
        anchors.fill: parent
        color: "black"
        opacity: 0.2
    }

    //AirSpeed Canvas
    Canvas {
        id: canvas
        x: 0
        y: 0
        width: parent.width * scaleRatio
        height: parent.height * scaleRatio  //285 a7a kolo hena Done Yasta
        antialiasing: true
        scale: 1 / scaleRatio
        transformOrigin: Item.TopLeft

        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext('2d');
            ctx.reset();
            ctx.scale(scaleRatio, scaleRatio);
            ctx.translate(0, displayedAirSpeed * pixelPerSpeed);

            var height = parent.height;


            //Green Normall airspeed marker line X,Y
            {
                ctx.lineWidth = 10
                ctx.beginPath()
                ctx.moveTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - (lowAirspeed * 0.8) * pixelPerSpeed )  //From
                ctx.lineTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - highAirspeed * pixelPerSpeed)  // To
                ctx.strokeStyle = "#36FF0F"
                ctx.stroke()
            }


            // White Low airspeed marker line X,Y
            {
                ctx.lineWidth = 5;
                ctx.beginPath();
                ctx.moveTo((aisROOT.width - (ctx.lineWidth*0.6)), 0.5 * height);
                ctx.lineTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - lowAirspeed * pixelPerSpeed);
                ctx.strokeStyle = "#ffffff";
                ctx.stroke();
            }


            //Yellow Caution Speed
            {
                ctx.lineWidth = 10
                ctx.beginPath()
                ctx.moveTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - highAirspeed * pixelPerSpeed)  //From
                ctx.lineTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - 220 * pixelPerSpeed )  // To
                ctx.strokeStyle = "yellow"
                ctx.stroke()
            }


            // Red tickmarks
            {
                ctx.lineWidth = 10
                ctx.beginPath()
                ctx.moveTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - 220 * pixelPerSpeed)  //From
                ctx.lineTo((aisROOT.width - (ctx.lineWidth*0.6)) , 0.5 * height - (displayedAirSpeed + 80) * pixelPerSpeed )  // To
                ctx.strokeStyle = "red"
                ctx.stroke()
            }


            // White degrees tickmarks
            {
                ctx.strokeStyle = "#ffffff"
                ctx.lineWidth = 3

                let lowestIndex = Math.round((displayedAirSpeed - minimumAirspeed) / tickmarkStepSize - visibleTickmarkCount / 2)
                let highestIndex = Math.round(lowestIndex + visibleTickmarkCount)

                if(lowestIndex < 0)lowestIndex = 0

                for (var i = lowestIndex; i <= highestIndex; i++) {

                    if(!(i%2)){
                        ctx.beginPath()
                        ctx.moveTo((aisROOT.width - ctx.lineWidth), 0.5 * height - i * tickmarkStepSize * pixelPerSpeed)   /// 47 c position
                        ctx.lineTo((aisROOT.width - ctx.lineWidth -15), 0.5 * height - i * tickmarkStepSize * pixelPerSpeed)   /// length of dash
                        ctx.stroke()
                    }
                    else{
                        ctx.beginPath()
                        ctx.moveTo((aisROOT.width - ctx.lineWidth), 0.5 * height - i * tickmarkStepSize * pixelPerSpeed)   /// 47 c position
                        ctx.lineTo((aisROOT.width - ctx.lineWidth -10), 0.5 * height - i * tickmarkStepSize * pixelPerSpeed)   /// length of dash
                        ctx.stroke()
                    }
                }
            }

            // Labels
            {
                //ctx.font = "bold 20px 'Courier Std'"
                ctx.font = "bold " + (45 / scaleRatio) + "px monospace"
                ctx.textAlign = "right"
                ctx.textBaseline = 'middle'
                ctx.fillStyle = "#ffffff"

                let lowestIndex = Math.round((displayedAirSpeed - minimumAirspeed) / labelStepSize - visibleLabelCount / 2)
                let highestIndex = Math.round(lowestIndex + visibleLabelCount)

                if(lowestIndex < 0) lowestIndex = 0

                for (let i = lowestIndex; i <= highestIndex; i++) {
                    var valueString = i * labelStepSize

                    var x =  45 //60  //text x pos 40
                    let y = (0.5 * height - i * labelStepSize * pixelPerSpeed) //- 45
                    ctx.fillText(valueString.toFixed(0), x, y)
                }
            }
        }
    }

    /*
    //AirSpeedTape
    AirSpeedTape{
        height: parent.height
        airspeed: aisROOT.airspeed
        duration: aisROOT.duration
    }
    */

    //TAS Rec
    Rectangle{
        id:tasREC
        width: parent.width
        height: width * 0.3
        anchors.top: parent.top
        anchors.topMargin: width * 0.35
        color: "black"
        border.width: 1
        border.color: "gray"

        Row{
            spacing: 5
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter

            //tas Label
            Text {
                text: qsTr("TAS")
                font.bold: true
                font.pixelSize: parent.width * 0.15
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }

            //tas Val
            Text {
                text: tas.toFixed(0)
                font.bold: true
                font.pixelSize: parent.width * 0.22
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }


    //airspeed Unit Sign (KT)
    Text {
        text: qsTr("KT")
        font.bold: true
        color: "gray"
        font.pixelSize: aisROOT.width * 0.25
        width: 4
        wrapMode: Text.Wrap
        anchors.bottom: gsREC.top
        anchors.bottomMargin: 6
        anchors.leftMargin: 2
    }

    //GS Rec
    Rectangle{
        id:gsREC
        width: parent.width
        height: width * 0.3
        anchors.bottom: oatREC.top
        color: "black"
        border.width: 1
        border.color: "gray"

        Row{
            spacing: 5
            width: parent.width
            height: parent.height
            leftPadding:2

            //GS Label
            Text {
                text: qsTr("GS")
                font.bold: true
                font.pixelSize: parent.width * 0.15
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }

            //GS Val
            Text {
                text: gs.toFixed(0)
                font.bold: true
                font.pixelSize: parent.width * 0.22
                color: "magenta"
                anchors.verticalCenter: parent.verticalCenter
            }

            //GS UNIT sign
            Text {
                text: "KT"
                width: 5
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.Wrap
                font.bold: true
                font.pixelSize: parent.width * 0.1
                color: "white"
            }
        }


        //FAIL SIGN GS
        Image {
            width: parent.width - gsREC.border.width * 2
            height: parent.height - gsREC.border.width * 2
            anchors.centerIn: parent
            source: "qrc:/Resources/Airspeed/GS_fail.svg"
            visible: gsFail
            z:100
        }
    }


    //OAT Rec
    Rectangle{
        id:oatREC
        width: parent.width
        height: width * 0.26
        anchors.bottom: parent.bottom
        color: "black"
        border.width: 1
        border.color: "gray"

        Row{
            spacing: 5
            width: parent.width
            height: parent.height

            //oat Label
            Text {
                text: qsTr("OAT")
                font.bold: true
                font.pixelSize: parent.width * 0.15
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }

            //oat Val
            Text {
                text: oat.toFixed(0) + "°C"
                font.bold: true
                font.pixelSize: parent.width * 0.22
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }



    //BUG Y
    CustomImage {
        id: bug_Y
        x: parent.width
        y:115
        width: 35
        height: 27
        source: "qrc:/Resources/Airspeed/airSpeed_bug.svg"
        visible: bugvisable
        transform: Translate {
            y: bugY
        }

        Text {
            text: qsTr("Y")
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
            font.pixelSize: 20
            color: "#00ffff"
        }
    }

    //BUG A
    CustomImage {
        id: bug_A
        x: parent.width
        y:115
        width: 35
        height: 27
        source: "qrc:/Resources/Airspeed/airSpeed_bug.svg"
        visible: bugvisable
        transform: Translate {
            y: bugA
        }

        Text {
            text: qsTr("A")
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
            font.pixelSize: 20
            color: "#00ffff"
        }
    }

    //BUG G
    CustomImage {
        id: bug_G
        x: parent.width
        y:115
        width: 35
        height: 27
        source: "qrc:/Resources/Airspeed/airSpeed_bug.svg"
        visible: bugvisable
        transform: Translate {
            y: bugG
        }

        Text {
            text: qsTr("G")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
            font.pixelSize: 20
            color: "#00ffff"
        }
    }


    //FAIL SIGN
    Image {
        width: parent.width
        height: parent.height - gsREC.height
        source: "qrc:/Resources/Airspeed/airSpeed_fail.svg"
        visible: iasfail
        z:100
    }


    //AIRSPEED TUMBLER CONTAINER
    Rectangle{
        height: parent.height * 0.3
        width: parent.width * 0.7
        color: "transparent"
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 15

        //Tumbler container Frame
        Image{
            id: tumblerFrame
            source: "qrc:/Resources/Airspeed/airSpeed_Tumbler_Frame.svg"
            width: 66
            height: parent.height
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: -10
            cache: false
            smooth: true
            antialiasing: true
            mipmap: true
        }

        //Tumbler 1 from Right [9]
        Tumbler {
            id:tumb1
            width: 22
            height: parent.height
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: -7

            model: 10
            visibleItemCount: 3

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString().padStart(1, '0')
                horizontalAlignment: Text.AlignHCenter
                y:-2
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: tumb1.height * 0.24
                font.bold: true
            }
        }

        //Tumbler 2 from Right [9]
        Tumbler {
            id:tumb2
            width: 20
            height: tumb1.height * 0.5
            anchors.right: tumb1.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: -12

            model: 10
            visibleItemCount: 1

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString().padStart(1, '0')
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: tumb1.height * 0.28
                padding: 0.5
                rightPadding: 0
                font.bold: true
            }
        }

        //Tumbler 3 from Right [9]
        Tumbler{
            id:tumb3
            width: 20
            height:tumb1.height * 0.5
            anchors.right: tumb2.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: -12

            model: 10
            visibleItemCount: 1

            background: Rectangle {
                color: "black"
            }

            delegate: Text {
                text: modelData.toString().padStart(1, '0')
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                color: "white"
                font.pixelSize: tumb1.height * 0.28
                rightPadding: 0
                font.bold: true
            }
        }
    }
}
