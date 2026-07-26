import QtQuick 2.0
import QtQuick.Controls 2.0
import QtGraphicalEffects 1.0


Rectangle {
    id: button

    property bool checked: false

    signal clicked();

    property alias text: btnText.text

    height: parent.height
    radius: 2
    border.color:"gray"
    gradient: off

    Gradient {
        id:off
        GradientStop { position: 0.08; color: "#48515a" }
        GradientStop { position: 0.15; color: "#02050c" }

    }

    Gradient {
        id:onn
        GradientStop { position: 0.0; color: "green"}
        GradientStop { position: 0.8; color: "green" }
    }


    Column{
        id:col1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height *0.6
        spacing: height - col1.children[0].height - col1.children[1].height

        //Button Text
        Text {
            id:btnText
            anchors.horizontalCenter: parent.horizontalCenter
            color:"white"
            text: "text"
            font.bold: true
            font.pointSize: parent.width * 0.25
            font.family: "Dubai"
        }

        //Idicator Rectangle
        Rectangle{
            width: button.width * 0.6
            height: button.height * 0.1
            color: checked ? "#46f72b" : "gray"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked:  {
            button.checked = !button.checked; // Toggle the button's checked state
            button.clicked();
        }
    }

//*****************************************************************************
//     // Change the button's appearance when it is checked
//     states: [
//         State {
//             name: "checked"
//             when: checked
// //            PropertyChanges {
// //                target: button
// //                gradient: onn
// //            }
//         },
//         State {
//             name: "unchecked"
//             when: !checked
// //            PropertyChanges {
// //                target: button
// //                //gradient: off //feki
// //                gradient: off //tarek
// //            }
//         }
//     ]

//*******************************************************************************

}


