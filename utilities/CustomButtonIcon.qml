import QtQuick 2.15
import QtQuick.Controls.Basic

Button {
    id: control

    width: 70
    height: 35

    property string buttonName: "BUTTON1"
    property string buttonSource: ""
    property int iconSourceWidth: 25
    property int iconSourceHeight: 15

    property color clickColor0: "#48515a"
    property color clickColor1: "#02050c"
    property color hoverColor: "#3498DB"

    signal buttonClicked()

    onClicked: buttonClicked()

    //-----------------------------------
    // BACKGROUND (Button styling)
    //-----------------------------------
    background: Rectangle {
        radius: 6

        gradient: Gradient {
            GradientStop { position: 0.0; color: control.clickColor0 }
            GradientStop { position: 1.0; color: control.clickColor1 }
        }

        border.color: control.hovered ? control.hoverColor : "transparent"
        border.width: 2
    }

    //-----------------------------------
    // CONTENT
    //-----------------------------------
    contentItem: Column {
        anchors.centerIn: parent
        spacing: 4

        Image {
            source: control.buttonSource
            width: control.iconSourceWidth
            height: control.iconSourceHeight
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            text: control.buttonName
            color: "white"
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }
    }
}
