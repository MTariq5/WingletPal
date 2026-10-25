import QtQml

QtObject {
    id: root

    enum Mode { Idle, Attentive, Searching, Greeting, Reminder, Focus, Break }

    property bool focusActive: false
    property bool completionActive: false

    required property bool cameraRunning
    required property bool trackingValid
    required property bool predicting
    required property bool greetingActive
    required property bool reminderActive

    // Audio states own the expression; tracking remains independent so the
    // companion can keep looking toward someone while speaking.
    readonly property int currentState: {
        if (completionActive) return RobotBehavior.Break
        if (focusActive) return RobotBehavior.Focus
        if (reminderActive) return RobotBehavior.Reminder
        if (greetingActive && cameraRunning) return RobotBehavior.Greeting
        if (!followingFace) return RobotBehavior.Idle
        return predicting ? RobotBehavior.Searching : RobotBehavior.Attentive
    }
    readonly property string stateName: ["Idle", "Attentive", "Searching", "Greeting", "Reminder", "Focus", "Break"][currentState]
    readonly property bool followingFace: cameraRunning && trackingValid
    readonly property bool attentionActive: currentState === RobotBehavior.Greeting
                                            || currentState === RobotBehavior.Reminder
                                            || currentState === RobotBehavior.Break
    readonly property bool waving: currentState === RobotBehavior.Greeting || currentState === RobotBehavior.Break
    readonly property bool autonomousLookEnabled: currentState === RobotBehavior.Idle
}
