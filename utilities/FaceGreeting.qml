import QtQuick
import QtMultimedia

Item {
    id: root

    property real volume: 1.0
    property bool muted: false

    required property bool cameraRunning
    required property bool facePresent
    required property bool enabledForPage
    required property bool audioBusy
    readonly property bool active: greetingDuration.running
    property string audioError: ""
    property bool greeted: false

    // Brief detector misses must not repeatedly greet the same visitor.
    Timer {
        interval: 800
        running: root.cameraRunning && root.facePresent && root.enabledForPage
                 && !root.audioBusy && !root.greeted && !root.active
        onTriggered: {
            root.greeted = true
            root.audioError = ""
            greetingDuration.start()
            voice.play()
        }
    }

    Timer {
        interval: 10000
        running: root.cameraRunning && !root.facePresent
        onTriggered: root.greeted = false
    }

    Timer {
        id: greetingDuration
        interval: 3000
        onTriggered: voice.stop()
    }

    function stopGreeting() {
        voice.stop()
        greetingDuration.stop()
    }

    onCameraRunningChanged: {
        if (!cameraRunning) {
            stopGreeting()
            greeted = false
        }
    }
    onEnabledForPageChanged: {
        if (!enabledForPage)
            stopGreeting()
    }

    MediaPlayer {
        id: voice
        source: "qrc:/AvionicsClock/Resources/audio/hello.mp3"
        audioOutput: AudioOutput { volume: root.volume; muted: root.muted }
        onErrorOccurred: function(error, errorString) {
            root.audioError = errorString
            console.warn("Face greeting audio:", errorString)
        }
    }
}
