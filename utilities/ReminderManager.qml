import QtQuick
import QtMultimedia

// Modular "developer health" reminder scheduler. Runs on a fixed interval
// relative to app startup (not synced to the clock), randomly picks one
// bundled audio clip (avoiding an immediate repeat), and plays it through
// Qt Multimedia without blocking the UI. Knows nothing about FunnyEyes or
// any other UI — it just emits reminderStarted/reminderFinished so callers
// can react. Its active property also reserves audio while a clip loads.
Item {
    id: root

    property real volume: 1.0
    property bool muted: false

    // main.qml disables reminders while the face greeting is active.
    property bool remindersEnabled: true
    property bool active: false

    property int reminderIntervalMs: 60 * 60 * 1000

    // Add more reminder categories/clips by appending entries here (and
    // dropping the matching .mp3 into Resources/audio/, which CMake
    // bundles automatically) — no other logic needs to change.
    readonly property var reminderSources: [
        "qrc:/AvionicsClock/Resources/audio/reminder1.mp3",
        "qrc:/AvionicsClock/Resources/audio/reminder2.mp3",
        "qrc:/AvionicsClock/Resources/audio/reminder3.mp3",
        "qrc:/AvionicsClock/Resources/audio/reminder4.mp3",
        "qrc:/AvionicsClock/Resources/audio/reminder5.mp3"
    ]

    property int lastReminderIndex: -1

    // Fired right before playback starts / right after it stops, so a
    // companion (FunnyEyes) can look at the user for the duration.
    signal reminderStarted()
    signal reminderFinished()

    function pickReminderIndex() {
        if (reminderSources.length <= 1)
            return 0

        var index
        do {
            index = Math.floor(Math.random() * reminderSources.length)
        } while (index === lastReminderIndex)
        return index
    }

    function stopReminder() {
        player.stop()
        root.active = false
    }

    function triggerReminder() {
        if (!root.remindersEnabled)
            return
        if (root.active)
            return // never overlap two reminders

        lastReminderIndex = pickReminderIndex()
        player.source = reminderSources[lastReminderIndex]
        root.active = true
        root.reminderStarted()
        player.play()
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput { volume: root.volume; muted: root.muted }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState) {
                root.active = false
                root.reminderFinished()
            }
        }
        onErrorOccurred: function(error, errorString) {
            console.warn("Reminder audio:", errorString)
            root.active = false
            root.reminderFinished()
        }
    }

    // Idle until it fires — no polling, no per-frame work between ticks.
    Timer {
        interval: root.reminderIntervalMs
        running: true
        repeat: true
        onTriggered: root.triggerReminder()
    }
}
