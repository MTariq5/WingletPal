import QtQuick
import QtMultimedia

Item {
    id: root
    property real volume: 1.0
    property bool muted: false
    readonly property bool active: celebration.running

    function celebrate() {
        celebration.restart()
        voice.play()
    }
    function stop() {
        celebration.stop()
        voice.stop()
    }
    Timer {
        id: celebration
        interval: 6000
        onTriggered: voice.stop()
    }
    MediaPlayer {
        id: voice
        source: "qrc:/AvionicsClock/Resources/audio/focus-complete.mp3"
        audioOutput: AudioOutput { volume: root.volume; muted: root.muted }
        onErrorOccurred: function(error, errorString) {
            console.warn("Focus completion audio:", errorString)
        }
    }
}
