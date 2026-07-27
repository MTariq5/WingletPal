import QtQuick 2.15
import QtQuick.Controls 2.5

Item {
    id:cRectROOT

    property string title_Name: "TEXT"

    property int title_TextFont: Math.min(cRectROOT.width,cRectROOT.height) * 0.25

    property color borderColor: "gray"

    property double val: 0
    property bool decimalePoint: false
    property string sing_val: "°"

    property string color0: "#363636" //"gray" //"#48515a" //"lightsteelblue"
    property string color1: "#02050c" //"#121212"

    signal buttonClicked() //signal onclicked

    //Main Rect
    Rectangle{
        id:mainRec
        width: cRectROOT.width
        height: cRectROOT.height
        radius:8
        border.color:borderColor
        border.width:3.5
        clip:true

        gradient: Gradient {
                    GradientStop {
                        position: 0.1;
                        color: color0
                    }
                    GradientStop {
                        position: 0.7;
                        color: color1
                    }
        }



        Column{
            id:col
            anchors.fill: parent
            anchors.topMargin: 2
            spacing: (col.height - (col.children[0].height + col.children[1].height)) / 2

            //Titel Label
            Text {
                text: title_Name
                font.bold: true
                font.pixelSize: title_TextFont
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row{
                anchors.horizontalCenter: parent.horizontalCenter


                //utility text
                Text {
                    text: decimalePoint ? val.toFixed(1) : val
                    font.bold: true
                    font.pixelSize: title_TextFont * 1.35
                    color: "cyan"
                    anchors.verticalCenter: parent.verticalCenter
                }

                //utility text sign
                Text {
                    text: sing_val
                    font.bold: true
                    font.pixelSize: title_TextFont * 1.35
                    color: "cyan"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
