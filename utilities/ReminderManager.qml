import QtQuick
import QtMultimedia

// Modular "developer health" reminder scheduler. Runs on a fixed interval
// relative to app startup (not synced to the clock), randomly picks one
// bundled audio clip (avoiding an immediate repeat), and plays it through
// Qt Multimedia without blocking the UI. Knows nothing about FunnyEyes or
// any other UI — it just emits reminderStarted/reminderFinished so callers
// can react (e.g. main.qml wiring this to funnyEyes.lookAtUser()/
// resumeAutonomy()), the same cross-wiring pattern used for weather/location.
Item {
    id: root

    // Reserved for a future Do-Not-Disturb setting: the timer keeps
    // ticking either way, but no audio plays and no signals fire while
    // this is false.
    property bool remindersEnabled: true

    // TESTING: temporarily 1 minute instead of 60 — revert to
    // `60 * 60 * 1000` after confirming the reminder fires/plays correctly.
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

    function triggerReminder() {
        if (!root.remindersEnabled)
            return
        if (player.playbackState === MediaPlayer.PlayingState)
            return // never overlap two reminders

        lastReminderIndex = pickReminderIndex()
        player.source = reminderSources[lastReminderIndex]
        root.reminderStarted()
        player.play()
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {}

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
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
