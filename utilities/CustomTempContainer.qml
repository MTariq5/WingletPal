import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    width: parent.width
    height: parent.height

    property real fontSize: 16
    property color fontcolor: "white"
    property int hour: 4
    property string ampm: "PM"
    property url icon: ""
    property int icon_width: 35
    property int icon_Height: 35
    property int temp: 20

    ColumnLayout{
        width: parent.width
        anchors.centerIn: parent
        spacing: 20

        Text{
            text: hour + ampm
            font.bold: true
            font.pixelSize: fontSize
            color: fontcolor
            Layout.alignment: Qt.AlignHCenter
        }

        Image{
            source: icon
            Layout.preferredWidth: icon_width
            Layout.preferredHeight: icon_Height
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignHCenter
        }

        Text{
            text: temp + "°C"
            font.bold: true
            font.pixelSize: fontSize
            color: fontcolor
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
