import QtQuick 2.15

Item {

    width: 50
    height: 50

    property string clickColor0: "#48515a" //"lightsteelblue"
    property string clickColor1: "#02050c" //"#151C24" //"#121212"
    property string hoverColor: "#3498DB"

    signal buttonclicked() //signal onclicked

    //Main Rec
    Rectangle{
        id:rec
        anchors.fill: parent
        radius: 2
        border.color: "gray"
        border.width: 2
        gradient: Gradient {
                    GradientStop {
                        position: 0.08;
                        color: clickColor0
                    }
                    GradientStop {
                        position: 0.15;
                        color: clickColor1
                    }
        }


        //SVG Icon X of Close Button
        Image {
            source: "/Resources/flpn/closeIcon.svg"
            width: parent.width - 20
            height: parent.height - 20
            anchors.centerIn: parent
        }

        MouseArea{
            anchors.fill: parent
            hoverEnabled: false
            //onEntered: clickColor1 = hoverColor
            //onExited:  clickColor1 = "#02050c" //"#151C24" //"#121212"

            onClicked: buttonclicked()
        }
    }

}
