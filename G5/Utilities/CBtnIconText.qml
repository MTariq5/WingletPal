import QtQuick 2.15
import QtQuick.Controls 2.5

Item {
    id:cBtnROOT

    property string btnName: "TEXT"

    property int btnTextFont: Math.min(cBtnROOT.width,cBtnROOT.height) * 0.25
    property color btnTextColor: "black"

    property string btnIconSource: ""

    property color borderColor: "gray"

    property bool btnIcon_text: false //false -> text , True -> icon

    property string btn_SubText: "----"
    property string signText: "-"

    property string color0: "#363636" //"gray" //"#48515a" //"lightsteelblue"
    property string color1: "#02050c" //"#121212"

    signal buttonClicked() //signal onclicked

    //Main Rect
    Rectangle{
        id:mainRec
        width: cBtnROOT.width
        height: cBtnROOT.height
        radius:4
        border.color:borderColor
        border.width:2
        clip:true

        gradient: Gradient {
                    GradientStop {
                        position: 0.5;
                        color: color0
                    }
                    GradientStop {
                        position: 0.9;
                        color: color1
                    }
        }


//        // Animate the border color change
//        Behavior on border.color {
//            ColorAnimation {
//                duration: 350 // Animation duration in milliseconds
//            }
//        }


        Column{
            id:col
            anchors.fill: parent
            anchors.topMargin: 2
            visible: btnIcon_text
            spacing: 2

            //Button Text
            Text {
                text: btnName
                font.bold: true
                font.pixelSize: btnTextFont
                color: btnTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            //Icon Image
            Image {
                source: btnIconSource
                height: cBtnROOT.width * 0.5
                width: height
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                mipmap: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }



        Column{
            id:col2
            anchors.fill: parent
            anchors.topMargin: 2
            visible: !btnIcon_text
            spacing: 4

            //Button Text
            Text {
                text: btnName
                font.bold: true
                font.pixelSize: btnTextFont
                color: btnTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            //Text
            Text {
                text: btn_SubText
                font.bold: true
                font.pixelSize: btnTextFont + 8
                color: "cyan"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: signText
                    font.bold: true
                    width: 2
                    font.pixelSize: btnTextFont * 0.8
                    color: "cyan"
                    wrapMode: Text.WordWrap
                    anchors.left: parent.right
                }
            }
        }





        MouseArea {
            anchors.fill: parent
            hoverEnabled: false

//            onPressed: {
//                borderColor = "cyan"
//            }

//            onPositionChanged: {
//                borderColor = "gray"
//            }

            onClicked: {
                buttonClicked();
            }
        }
    }
}
