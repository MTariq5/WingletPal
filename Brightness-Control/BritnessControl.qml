import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import QtQuick.Controls.Basic
import Qt5Compat.GraphicalEffects

Rectangle{
    id: brihtnessControlRoot
    // anchors.verticalCenter: parent.verticalCenter
    width:  300
    height: 40
    x: ( parent.width / 2 ) - ( width / 2 )
    color : "transparent"
    layer.enabled: true

    property alias setVal: myslider.value
    property alias getVal: myslider.position
    property int   fvale : 0

    onGetValChanged: {
        fvale = myslider.position * 254
    }

    //Close Brightness Control
    // Timer{
    //     id:timer
    //     interval: 500
    //     running: false
    //     repeat: false
    //     onTriggered: {
    //         brihtnessControlRoot.visible = true
    //         //console.log("Timer Triggered")
    //     }
    // }

    Slider {
        id: myslider

        property color checkedColor: "white" //"#3498DB"

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        leftPadding: 0
        rightPadding: 0
        width: brihtnessControlRoot.width * 0.9
        height: brihtnessControlRoot.height * 0.9
        value:25.4
        from: 0
        to:254

        background: Rectangle {
            id: rec1
            width: myslider.width
            height: myslider.height
            radius: height / 2
            color: "#D0D0D0"        // important – do not paint behind the parts

            //clipping
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: rec1.width
                    height: rec1.height
                    radius: rec1.radius
                }
            }

            // WHITE
            Rectangle {
                id: filledPart
                height: parent.height
                width: myslider.handle.x + myslider.handle.width / 2
                color: "white"
                radius: 0
            }

            // DARK GRAY
            Rectangle {
                id: rightPart
                height: parent.height
                width: parent.width - filledPart.width
                x: filledPart.width
                color: "#808080"
                radius: 0
            }
        }


        handle:Rectangle {
            x: myslider.visualPosition * (myslider.availableWidth - width)
            y:  (rec1.height/2) - height/2
            implicitWidth: rec1.height
            implicitHeight: implicitWidth
            radius: implicitWidth / 2
            color: myslider.pressed ? Qt.darker(myslider.checkedColor, 1.2) : myslider.checkedColor
            layer.enabled: myslider.hovered | myslider.pressed
            layer.effect: DropShadow {
                transparentBorder: true
                color: myslider.checkedColor
                samples: 20
            }
        }

        //SUN ICON
        Image {
            id: icon2
            source: myslider.value > 190 ? "qrc:/AvionicsClock/Resources/Brightness-Slider/brightnessicon-orange.svg"
                                         : "qrc:/AvionicsClock/Resources/Brightness-Slider/brightnessicon.svg"
            width: parent.height * 0.5
            height: width
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: (rec1.height - height) / 2
            z:1000
        }

        // onValueChanged: {
        //     timer.restart()
        // }

        // onMoved: {
        //     timer.restart()
        // }
    }
}


