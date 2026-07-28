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

    // ── Display sizing constants ────────────────────────────────────────
    // Single source of truth for the target display. Porting to another
    // panel (e.g. 480x320, 800x480) means changing these two numbers —
    // every font size and gauge below is derived from them.
    property int screenWidth: 320
    property int screenHeight: 240
    readonly property real uiScale: screenHeight / 240
    property real gaugeSize: Math.min(screenWidth, screenHeight) //* 0.85
    property real fontLarge: 26 * uiScale
    property real fontMedium: 16 * uiScale
    property real fontSmall: 11 * uiScale

    width: screenWidth
    height: screenHeight
    minimumWidth: screenWidth
    maximumWidth: screenWidth
    minimumHeight: screenHeight
    maximumHeight: screenHeight
    visible: true
    title: qsTr("Avioncs Clock V1.0")

    flags: Qt.FramelessWindowHint
    color: "#121212"

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

    // Cross-wires the reminder scheduler to the Page 3 companion eyes —
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
        color: "#121212"

        SwipeView {
            id: swipeView
            anchors.fill: parent

            /*
            //TEST PAGE
            Item{
                anchors.fill: parent

                Rectangle{
                    anchors.fill: parent
                    color: "green"

                    G5Altimeter{
                        id:alt
                        width: parent.width * 0.272
                        height: parent.height
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        bugValue: 0
                        bugvisible: true
                    }

                    //AIRSPEED
                    G5AirspeedIndicator {
                        id:ias
                        width: parent.width * 0.2035 //65
                        height: parent.height
                        anchors.left: parent.left
                    }
                }
            }
            */

            //PAGE 1 PFD CLOCK
            Item {
                id: pfdPage

                //PFD CLOCK SHAPE
                Rectangle {
                    anchors.fill: parent
                    color: "#121212"

                    //PFD SKY GROUND
                    PfdBackground {
                        id: pfdBackground
                        anchors.fill: parent
                        horizonLineWidth: 2 * uiScale
                    }

                    //CLOCK IMAGE
                    Image {
                        id:clockSVG
                        anchors.fill: parent
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/eaid/clock-pfd.svg"
                        clip: true

                        Rectangle{
                            id:pitchLadderCont
                            anchors.centerIn: parent
                            color: "transparent"
                            width: clockSVG.width * 0.4
                            height: width
                            radius: width/2
                            clip: true

                            Image {
                                id:pitchLadder
                                source: "qrc:/AvionicsClock/Resources/eaid/eadi_adi_ladd.svg"
                                fillMode: Image.PreserveAspectFit
                                width: pitchLadderCont.width
                                height: width * (sourceSize.height / sourceSize.width)
                                x: pitchLadderCont.width / 2 - width / 2
                                y: pitchLadderCont.height / 2 - height / 2 - pfdBackground.effectivePitch * pixelsPerDegree

                                property real pixelsPerDegree: pitchLadderCont.height / 3

                                // Roll must pivot around the gauge's fixed center, not the
                                // image's own center — the image's own center already moved
                                // vertically by the pitch offset above, so rotating around it
                                // (the default transformOrigin) would drag the ladder off-center
                                // whenever pitch and roll are non-zero at the same time.
                                transform: Rotation {
                                    origin.x: pitchLadder.width / 2
                                    origin.y: pitchLadder.height / 2 + pfdBackground.effectivePitch * pitchLadder.pixelsPerDegree
                                    angle: pfdBackground.effectiveRoll
                                }
                            }
                        }
                    }

                    //Hour hand
                    Image {
                        anchors.fill: parent
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/eaid/hourArrow.svg"
                        transformOrigin: Item.Center
                        rotation: (timeDate.hours % 12) * 30 + timeDate.minutes * 0.5
                    }

                    //Minute hand
                    Image {
                        anchors.fill: parent
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/eaid/minuitesArrow.svg"
                        transformOrigin: Item.Center
                        rotation: timeDate.minutes * 6 + timeDate.seconds * 0.1
                    }

                    //CITY (upper-left, in the side margin outside the round gauge)
                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 6 * uiScale
                        text: location.city == "" ? "NO INTERNET CONN." : location.city
                        font.bold: true
                        font.pixelSize: fontMedium
                        color: "white"
                        font.family: fontStyle

                        width: 50
                        wrapMode: Text.WrapAnywhere
                    }

                    //TEMPERATURE (upper-right, in the side margin outside the round gauge)
                    Text {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6 * uiScale
                        text: Math.round(weather.currentTemperature) + "°C"
                        font.bold: true
                        font.pixelSize: fontMedium
                        color: "white"
                        horizontalAlignment: Text.AlignRight
                        font.family: fontStyle
                    }
                }
            }

            //PAGE2 ANALOUGE CLOCK
            Item {
                //HSI CLOCK SHAPE
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"

                    //CLOCK BASE IMAGE
                    Image {
                        width: gaugeSize
                        height: gaugeSize
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/ehsi_hdg_scale.svg"
                    }

                    //CASE ACFT UI ONLY
                    Image {
                        width: gaugeSize
                        height: gaugeSize
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/hi_case.svg"
                    }

                    //Needle Hours
                    Image {
                        width: gaugeSize
                        height: gaugeSize
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/hi_loc2-needle.svg"
                        transformOrigin: Item.Center
                        rotation: (timeDate.hours % 12) * 30 + timeDate.minutes * 0.5
                    }

                    //Needle minuites
                    Image {
                        width: gaugeSize
                        height: gaugeSize
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/hi_loc2-needle-Minuites.svg"
                        transformOrigin: Item.Center
                        rotation: timeDate.minutes * 6 + timeDate.seconds * 0.1
                    }

                    //Bug Seconds
                    Image {
                        width: gaugeSize
                        height: gaugeSize
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/ehsi/ehsi_hdg_bug.svg"
                        transformOrigin: Item.Center
                        rotation: timeDate.seconds * 6
                    }
                }
            }

            //PAGE3 DIGITAL CLOCK
            Item {
                Rectangle {
                    anchors.fill: parent
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
                        spacing: 8
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
                                font.pixelSize: fontLarge
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: spoeration
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontLarge
                                color: "#D9A441"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: digitalMinuitesLabel
                                text: timeDate.minutes < 10 ? "0" + timeDate.minutes : timeDate.minutes
                                font.bold: true
                                font.pixelSize: fontLarge
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: spoeration2
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontLarge
                                color: "#D9A441"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: digitalSecondsLabel
                                text: timeDate.seconds < 10 ? "0" + timeDate.seconds : timeDate.seconds
                                font.bold: true
                                font.pixelSize: fontLarge
                                color: "#D9A441"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                id: pmAmLabel
                                text: timeDate.amPm
                                font.bold: true
                                font.pixelSize: fontLarge
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
                            font.pixelSize: fontMedium
                            color: "white"
                            font.family: fontStyle
                            Layout.alignment: Qt.AlignHCenter
                        }

                        //TEMPERATURE
                        Text {
                            id: currentTemp
                            text: Math.round(weather.currentTemperature) + "°C"
                            font.bold: true
                            font.pixelSize: fontMedium
                            color: "white"
                            font.family: fontStyle
                            Layout.alignment: Qt.AlignHCenter
                        }

                        //CITY
                        Text {
                            id: currentCity
                            text: location.city == "" ? "NO INTERNET CONN." : location.city
                            font.bold: true
                            font.pixelSize: fontMedium
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

            //PAGE4 TEMPERATURE STATUS
            Item{
                //anchors.fill: parent
                Rectangle{
                    anchors.fill: parent
                    color: "black"

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
                                sourceSize.width: fontMedium
                                sourceSize.height: fontMedium
                                fillMode: Image.PreserveAspectFit
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: location.city == "" ? "NO INTERNET CONN." : location.city
                                font.bold: true
                                font.pixelSize: fontMedium
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
                                font.pixelSize: fontMedium
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontMedium
                                color: "white"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: timeDate.minutes < 10 ? "0" + timeDate.minutes : timeDate.minutes
                                font.bold: true
                                font.pixelSize: fontMedium
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: qsTr(":")
                                font.bold: true
                                font.pixelSize: fontMedium
                                color: "white"
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: timeDate.seconds < 10 ? "0" + timeDate.seconds : timeDate.seconds
                                font.bold: true
                                font.pixelSize: fontMedium
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }

                            Text {
                                text: timeDate.amPm
                                font.bold: true
                                font.pixelSize: fontMedium
                                color: "white"
                                font.family: fontStyle
                                verticalAlignment: Qt.AlignVCenter
                            }
                        }

                        //DATE
                        Text {
                            text: timeDate.date
                            font.bold: true
                            font.pixelSize: fontMedium
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
                            width: 46
                            height: ListView.view.height
                            fontSize: fontSmall
                            icon_width: 24
                            icon_Height: 24
                            hour: modelData.hour
                            ampm: modelData.ampm
                            icon: modelData.weatherIcon
                            temp: Math.round(modelData.temperature)
                        }
                    }
                }
            }

            //PAGE5 AIR TRAFFIC DISPLAY (ATD) — map + crosshair + zoom + DMS/
            //status overlay bars; see utilities/AirTrafficPage.qml for phase
            //notes. currentCity/currentTemperature/timeProvider reuse the
            //same location/weather/timeDate instances every other page
            //already binds to directly — no new provider, no new fetch.
            AirTrafficPage {
                id: airTrafficPage
                currentLatitude: location.latitude
                currentLongitude: location.longitude
                currentCity: location.city
                currentTemperature: weather.currentTemperature
                timeProvider: timeDate
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
                anchors.centerIn: parent
                spacing: 12

                //Brightness Slider
                BritnessControl{
                    Layout.preferredWidth: screenWidth - 20
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
