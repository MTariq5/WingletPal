import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import TimeDateProvider 1.0
import LocationProvider 1.0
import WeatherProvider 1.0

import "./utilities"
import "./Brightness-Control"



Window {
    id: root
    width: 400
    height: 400
    visible: true
    title: qsTr("Avioncs Clock V1.0")

    flags: Qt.FramelessWindowHint
    color: "transparent"

    InputPanel {
        id: inputPanel
        z: 99
        x: 0
        y: root.height
        width: root.width

        states: State {
            name: "visible"
            when: inputPanel.active
            PropertyChanges {
                target: inputPanel
                y: root.height - inputPanel.height
            }
        }
        transitions: Transition {
            from: ""
            to: "visible"
            reversible: true
            ParallelAnimation {
                NumberAnimation {
                    properties: "y"
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }


    property real fontSize: 20
    property string fontStyle: "Eurostile" //"Roboto Mono"


    TimeDateProvider{
        id:timeDate
    }

    LocationProvider{
        id:location
        Component.onCompleted: {
            fetchLocation();
        }
    }

    WeatherProvider {
        id: weather
        Component.onCompleted: {

        }
    }

    ReminderManager {
        id: healthReminder
    }

    // Inside LocationProvider (or as a sibling Connections element)
    Connections {
        target: location
        function onLocationChanged() {
            weather.setLocation(location.latitude, location.longitude)
        }
    }

    // Cross-wires the reminder scheduler to the Page 2 companion eyes —
    // ReminderManager has no knowledge of FunnyEyes itself.
    Connections {
        target: healthReminder
        function onReminderStarted() {
            funnyEyes.lookAtUser()
        }
        function onReminderFinished() {
            funnyEyes.resumeAutonomy()
        }
    }


    //MAIN UI CONTAINER
    Rectangle {
        id:mainRec
        anchors.fill: parent
        radius: width / 2
        color: "transparent"

        layer.enabled: true
        layer.smooth: true

        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: mainRec.width
                height: mainRec.height
                radius: width / 2
            }
        }

        SwipeView {
            id: swipeView
            anchors.fill: parent

            //PAGE1 ANALOUGE CLOCK
            Item {
                //HSI CLOCK SHAPE
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"

                    //CLOCK BASE IMAGE
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/ehsi_hdg_scale.svg"
                    }

                    //CASE ACFT UI ONLY
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/hi_case.svg"
                    }

                    //Needle Hours
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/hi_loc2-needle.svg"
                        transformOrigin: Item.Center
                        rotation: (timeDate.hours % 12) * 30 + timeDate.minutes * 0.5
                    }

                    //Needle minuites
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/hi_loc2-needle-Minuites.svg"
                        transformOrigin: Item.Center
                        rotation: timeDate.minutes * 6 + timeDate.seconds * 0.1
                    }

                    //Bug Seconds
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/ehsi_hdg_bug.svg"
                        transformOrigin: Item.Center
                        rotation: timeDate.seconds * 6
                    }
                }
            }

            //PAGE2 DIGITAL CLOCK
            Item {
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#121212"

                    // PREMIUM COCKPIT BACKGROUND — subtle dark radial gradient
                    RadialGradient {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#2B2B2B" }
                            GradientStop { position: 0.6; color: "#1E1E1E" }
                            GradientStop { position: 1.0; color: "#121212" }
                        }
                    }

                    ColumnLayout{
                        width: parent.width
                        spacing: 15
                        anchors.centerIn: parent


                        RowLayout{
                            id: digitalClockRow
                            spacing: 6
                            Layout.alignment: Qt.AlignHCenter

                            layer.enabled: true
                            layer.effect: DropShadow {
                                transparentBorder: true
                                horizontalOffset: 0
                                verticalOffset: 2
                                radius: 8
                                samples: 17
                                color: "#66000000"
                            }

                            Text {
                                id: digitalHoursLabel
                                text: timeDate.hours12 < 10 ? "0" + timeDate.hours12 : timeDate.hours12
                                font.bold: true
                                font.pixelSize: fontSize * 1.6
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: spoeration
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontSize * 1.6
                                color: "#D9A441"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: digitalMinuitesLabel
                                text: timeDate.minutes < 10 ? "0" + timeDate.minutes : timeDate.minutes
                                font.bold: true
                                font.pixelSize: fontSize * 1.6
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: spoeration2
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontSize * 1.6
                                color: "#D9A441"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: digitalSecondsLabel
                                text: timeDate.seconds < 10 ? "0" + timeDate.seconds : timeDate.seconds
                                font.bold: true
                                font.pixelSize: fontSize * 1.6
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: pmAmLabel
                                text: timeDate.amPm
                                font.bold: true
                                font.pixelSize: fontSize * 1.6
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }
                        }

                        //DESKTOP COMPANION EYES
                        FunnyEyes {
                            id: funnyEyes
                            Layout.alignment: Qt.AlignHCenter
                        }

                        //DATE
                        Text {
                            id: currentDate
                            text: timeDate.date
                            font.bold: true
                            font.pixelSize: fontSize
                            color: "white"
                            font.family: fontStyle
                            Layout.alignment: Qt.AlignHCenter
                        }

                        //TEMPERATURE
                        Text {
                            id: currentTemp
                            text: Math.round(weather.currentTemperature) + "°C"
                            font.bold: true
                            font.pixelSize: fontSize
                            color: "white"
                            font.family: fontStyle
                            Layout.alignment: Qt.AlignHCenter
                        }

                        //CITY
                        Text {
                            id: currentCity
                            text: location.city == "" ? "NO INTERNET CONN." : location.city
                            font.bold: true
                            font.pixelSize: fontSize
                            color: "white"
                            font.family: fontStyle
                            Layout.alignment: Qt.AlignHCenter
                        }


                        //CARBIT BUTTON ADDED
                        CustomButtonIcon{
                            id:settingBtn
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 35
                            buttonName: " "
                            buttonSource: "qrc:/AvionicsClock/Resources/settings-outline.svg" //"Resources/settings-outline.svg"
                            Layout.alignment: Qt.AlignHCenter
                            visible: false

                            onButtonClicked: {
                                settingsCarbet.y = 0
                            }
                        }
                    }
                }
            }

            //PAGE3 TEMPERATURE STATUS
            Item{
                //anchors.fill: parent
                Rectangle{
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"

                    layer.enabled: true
                    layer.smooth: true

                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: mainRec.width
                            height: mainRec.height
                            radius: width / 2
                        }
                    }

                    // Background (for demo)
                    Image {
                        id: bg
                        anchors.fill: parent
                        source: "qrc:/AvionicsClock/Resources/closeup-shot-plane-wing.jpg"
                        fillMode: Image.PreserveAspectCrop
                    }

                    // Glass container
                    Rectangle {
                        id: glassRect
                        width: parent.width //* 0.8
                        height: parent.height * 0.4
                        anchors.centerIn: parent
                        radius: 20
                        color: "#80ffffff"
                        border.color: "#40ffffff"
                        border.width: 1
                        clip: true
                    }

                    // Blur effect
                    FastBlur {
                        anchors.fill: glassRect
                        source: bg
                        radius: 20
                        transparentBorder: true
                    }

                    //Optional overlay for better glass look
                    Rectangle {
                        anchors.fill: glassRect
                        radius: glassRect.radius
                        color: "#40ffffff"
                    }

                    ColumnLayout{
                        width: parent.width
                        //height: parent.height * 0.3
                        spacing: 2
                        anchors.bottom: listView.top
                        anchors.bottomMargin: 5

                        RowLayout{
                            height: parent.height * 0.4
                            Layout.alignment: Qt.AlignHCenter

                            Image {
                                source: "qrc:/AvionicsClock/Resources/weather/" + "location.svg"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: location.city == "" ? "NO INTERNET CONN." : location.city
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                font.family: fontStyle
                                Layout.alignment: Qt.AlignBottom
                            }
                        }

                        //DIGITAL TIME
                        RowLayout{
                            spacing: 6
                            Layout.alignment: Qt.AlignHCenter

                            Text {
                                text: timeDate.hours12 < 10 ? "0" + timeDate.hours12 : timeDate.hours12
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: timeDate.minutes < 10 ? "0" + timeDate.minutes : timeDate.minutes
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: timeDate.seconds < 10 ? "0" + timeDate.seconds : timeDate.seconds
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: timeDate.amPm
                                font.bold: true
                                font.pixelSize: fontSize
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }
                        }

                        //DATE
                        Text {
                            text: timeDate.date
                            font.bold: true
                            font.pixelSize: fontSize
                            color: "white"
                            font.family: fontStyle
                            Layout.alignment: Qt.AlignHCenter
                        }

                    }

                    ListView{
                        id:listView
                        width: parent.width * 0.8
                        height: parent.height * 0.4
                        anchors.centerIn: parent
                        clip: true
                        orientation: ListView.Horizontal

                        model: weather.hourlyForecast

                        delegate: CustomTempContainer{
                            width: 50
                            height: ListView.view.height
                            hour: modelData.hour
                            ampm: modelData.ampm
                            icon: modelData.weatherIcon
                            temp: Math.round(modelData.temperature)
                        }
                    }
                }
            }
        }

        //SETTINGS CARBET
        Rectangle{
            id:settingsCarbet
            width: parent.width
            height: parent.height
            color: "black"
            opacity: 0.9

            y: -height

            Behavior on y {
                NumberAnimation{
                    duration: 400
                }
            }

            MouseArea{
                anchors.fill: parent
            }

            ColumnLayout{
                anchors.fill: parent

                //Brightness Slider
                BritnessControl{
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignHCenter
                    setVal : 127
                }

                //CRABIT BUTTON REMOVER
                CustomButtonIcon{
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 35
                    Layout.alignment: Qt.AlignHCenter
                    buttonName: " "
                    buttonSource: "qrc:/AvionicsClock/Resources/up-arrow.svg" //"Resources/up-arrow.svg"

                    onButtonClicked: {
                        settingsCarbet.y = -settingsCarbet.height
                    }
                }
            }
        }

        //Drag Rec
        Rectangle {
            id: dragArea
            width: parent.width
            height: 40
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                property point clickPos

                onPressed: (mouse) => {
                    clickPos = Qt.point(mouse.x, mouse.y)
                }

                onPositionChanged: (mouse) => {
                    root.x += mouse.x - clickPos.x
                    root.y += mouse.y - clickPos.y
                }
            }
        }
    }


}
