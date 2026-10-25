import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import TimeDateProvider 1.0
import LocationProvider 1.0
import WeatherProvider 1.0
import ConnectivityChecker 1.0
import WifiManager 1.0
import CameraController 1.0
import FocusSession 1.0

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

    property real companionVolume: 1.0
    property bool companionMuted: false

    property real fontSize: 20
    property string fontStyle: "Eurostile" //"Roboto Mono"


    TimeDateProvider{
        id:timeDate
    }

    LocationProvider{
        id:location
    }

    WeatherProvider {
        id: weather
        Component.onCompleted: setLocation(location.latitude, location.longitude)
    }

    CameraController {
        id: appCamera
    }

    ReminderManager {
        id: healthReminder
        remindersEnabled: !faceGreeting.active && !focusSession.active && !focusCompletion.active
        volume: root.companionVolume
        muted: root.companionMuted
    }

    FaceGreeting {
        id: faceGreeting
        cameraRunning: appCamera.running
        facePresent: appCamera.facePresent
        enabledForPage: digitalPage.SwipeView.isCurrentItem && root.appState === "ready"
                        && !focusSession.active && !focusCompletion.active
        audioBusy: healthReminder.active
        volume: root.companionVolume
        muted: root.companionMuted
    }

    FocusSession {
        id: focusSession
        onCompleted: focusCompletion.celebrate()
    }

    FocusCompletion {
        id: focusCompletion
        volume: root.companionVolume
        muted: root.companionMuted
    }

    RobotBehavior {
        id: robotBehavior
        cameraRunning: appCamera.running
        trackingValid: appCamera.trackingValid
        predicting: appCamera.predicting
        greetingActive: faceGreeting.active
        reminderActive: healthReminder.active
        focusActive: focusSession.active
        completionActive: focusCompletion.active
    }

    ConnectivityChecker {
        id: connectivityChecker
        Component.onCompleted: {
            checkNow()
        }
    }

    WifiManager {
        id: wifiManager
    }

    // ── Startup gating state machine ────────────────────────────────────
    // "splash" -> "wifiSetup" | "ready". SplashScreen/WifiSetupPage below
    // never unmount mainRec (the whole existing SwipeView UI) — they're
    // painted on top of it, as Window-level siblings declared after it, so
    // they cover *everything* mainRec contains (every page, the settings
    // drawer, the drag handle) without needing to reach inside it. mainRec
    // and every provider above keep running underneath the whole time —
    // WeatherProvider starts fetching using the saved location on its own
    // Component.onCompleted regardless of appState. Gating their startup
    // too would add real complexity for a window that's normally only
    // gated for ~2s plus one HTTP round trip.
    property bool splashMinTimeElapsed: false
    property string appState: "splash" // "splash" | "wifiSetup" | "ready"

    function evaluateAppState() {
        if (!root.splashMinTimeElapsed || connectivityChecker.checking) {
            root.appState = "splash"
        } else if (connectivityChecker.online) {
            root.appState = "ready"
        } else {
            root.appState = "wifiSetup"
        }
    }

    // Guarantees the splash is visible for at least this long even if the
    // very first connectivity check resolves almost instantly — matches
    // the "~2 seconds" requirement this whole feature was built for.
    Timer {
        id: splashMinTimer
        interval: 2000
        running: true
        onTriggered: {
            root.splashMinTimeElapsed = true
            root.evaluateAppState()
        }
    }

    Connections {
        target: connectivityChecker
        function onCheckFinished() {
            root.evaluateAppState()
        }
    }

    // Inside LocationProvider (or as a sibling Connections element)
    Connections {
        target: location
        function onLocationChanged() {
            weather.setLocation(location.latitude, location.longitude)
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
            currentIndex: 0

            //DESK COMPANION — first swipe page
            Item {
                id: digitalPage
                Basic.Button {
                    id: settingsToggle
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 8
                    width: 56
                    height: 26
                    z: 1
                    text: "⌄"
                    font.pixelSize: 30
                    font.bold: true
                    background: Item {}
                    contentItem: Text {
                        text: settingsToggle.text
                        font: settingsToggle.font
                        color: "#D9A441"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Accessible.name: qsTr("Open companion settings")
                    onClicked: companionSettings.open()
                }

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
                            greetingActive: robotBehavior.waving
                            followingFace: robotBehavior.followingFace
                            attentionActive: robotBehavior.attentionActive
                            autonomousLookEnabled: robotBehavior.autonomousLookEnabled
                            facePosition: appCamera.facePosition
                            Layout.alignment: Qt.AlignHCenter
                        }

                        //DATE
                        Text {
                            id: currentDate
                            text: focusCompletion.active ? qsTr("وقت استراحة صغيرة!")
                                  : focusSession.active ? qsTr("Focus  %1:%2")
                                      .arg(Math.floor(focusSession.remainingSeconds / 60).toString().padStart(2, "0"))
                                      .arg((focusSession.remainingSeconds % 60).toString().padStart(2, "0"))
                                  : robotBehavior.waving
                                  ? (faceGreeting.audioError ? qsTr("تعذّر تشغيل الصوت") : qsTr("أهلًا!"))
                                  : timeDate.date
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



                    }
                }
            }

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
                            width: gaugeSize * 0.44
                            height: width
                            radius: width/2
                            clip: true

                            Image {
                                id:pitchLadder
                                source: "qrc:/AvionicsClock/Resources/eaid/eadi_adi_ladd.svg"
                                fillMode: Image.PreserveAspectFit
                                width: pitchLadderCont.width
                                opacity: 0.6
                                height: width * (sourceSize.height / sourceSize.width)
                                x: pitchLadderCont.width / 2 - width / 2
                                y: pitchLadderCont.height / 2 - height / 2 - pfdBackground.effectivePitch * pixelsPerDegree

                                readonly property real pixelsPerDegree: pfdBackground.pixelsPerDegree

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
                        // Supersample the SVG before filtering its rotated edges.
                        sourceSize: Qt.size(gaugeSize * Screen.devicePixelRatio * 3,
                                            gaugeSize * Screen.devicePixelRatio * 3)
                        smooth: true
                        mipmap: true
                        transformOrigin: Item.Center
                        rotation: (timeDate.hours % 12) * 30 + timeDate.minutes * 0.5
                    }

                    //Minute hand
                    Image {
                        anchors.fill: parent
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AvionicsClock/Resources/eaid/minuitesArrow.svg"
                        // Supersample the SVG before filtering its rotated edges.
                        sourceSize: Qt.size(gaugeSize * Screen.devicePixelRatio * 3,
                                            gaugeSize * Screen.devicePixelRatio * 3)
                        smooth: true
                        mipmap: true
                        transformOrigin: Item.Center
                        rotation: timeDate.minutes * 6 + timeDate.seconds * 0.1
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 6 * uiScale
                        width: Math.min(cityLabel.implicitWidth + 14 * uiScale, root.screenWidth * 0.35)
                        height: 24 * uiScale
                        radius: 5 * uiScale
                        color: "#B3121820"
                        border.color: "#30FFFFFF"

                        Text {
                            id: cityLabel
                            anchors.fill: parent
                            anchors.leftMargin: 7 * uiScale
                            anchors.rightMargin: 7 * uiScale
                            verticalAlignment: Text.AlignVCenter
                            text: location.city !== "" ? location.city
                                  : location.error !== "" ? "No location" : "Locating…"
                            elide: Text.ElideRight
                            font.bold: true
                            font.pixelSize: fontSmall
                            color: "#F4F6F8"
                            font.family: fontStyle
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6 * uiScale
                        width: temperatureLabel.implicitWidth + 14 * uiScale
                        height: 24 * uiScale
                        radius: 5 * uiScale
                        color: "#B3121820"
                        border.color: "#30FFFFFF"

                        Text {
                            id: temperatureLabel
                            anchors.centerIn: parent
                            text: weather.hourlyForecast.length > 0
                                  ? Math.round(weather.currentTemperature) + "°C" : "—°C"
                            font.bold: true
                            font.pixelSize: fontSmall
                            color: "#F4F6F8"
                            font.family: fontStyle
                        }
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

            CameraPage {
                id: cameraPage
                behaviorState: robotBehavior.stateName
                camera: appCamera
                onBackRequested: swipeView.setCurrentIndex(digitalPage.SwipeView.index)
                visible: SwipeView.isCurrentItem
            }

            AboutPage {
                id: aboutPage
            }
        }

        LocationSettings {
            id: locationSettings
            width: parent.width
            height: parent.height
            locationProvider: location
        }

        CompanionSettings {
            id: companionSettings
            width: parent.width
            height: parent.height
            volume: root.companionVolume
            muted: root.companionMuted
            focusActive: focusSession.active
            onFocusRequested: {
                if (focusSession.active) {
                    focusSession.cancel()
                } else {
                    faceGreeting.stopGreeting()
                    healthReminder.stopReminder()
                    focusCompletion.stop()
                    focusSession.start()
                }
                swipeView.setCurrentIndex(digitalPage.SwipeView.index)
                close()
            }
            onLocationRequested: {
                close()
                locationSettings.open()
            }
            onVolumeEdited: function(level) { root.companionVolume = level }
            onMutedEdited: function(silent) { root.companionMuted = silent }
            onCameraRequested: function(showDiagnostics) {
                cameraPage.diagnosticsVisible = showDiagnostics
                swipeView.setCurrentIndex(cameraPage.SwipeView.index)
                close()
            }
        }

        //Drag Rec
        Rectangle {
            id: dragArea
            width: parent.width
            height: cameraPage.SwipeView.isCurrentItem || digitalPage.SwipeView.isCurrentItem ? 8 : 40
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

    // Startup gate overlays — declared after mainRec so they paint on top
    // of it (every page, the settings drawer, and the drag handle all
    // live inside mainRec). Each is a full-window MouseArea-backed opaque
    // screen while visible, so nothing underneath is reachable until
    // appState reaches "ready".
    SplashScreen {
        anchors.fill: parent
        visible: root.appState === "splash"
        checking: connectivityChecker.checking

        MouseArea {
            anchors.fill: parent
        }
    }

    WifiSetupPage {
        anchors.fill: parent
        visible: root.appState === "wifiSetup"
        wifiManager: wifiManager
        connectivityChecker: connectivityChecker
    }
}
