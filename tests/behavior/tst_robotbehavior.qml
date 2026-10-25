import QtQuick
import QtTest
import "../../utilities"

TestCase {
    id: testCase
    name: "RobotBehavior"
    when: windowShown
    Component {
        id: behaviorComponent
        RobotBehavior {
            cameraRunning: false
            trackingValid: false
            predicting: false
            greetingActive: false
            reminderActive: false
        }
    }
    Component {
        id: eyesComponent
        FunnyEyes {
            followingFace: testCase.robot.followingFace
            attentionActive: testCase.robot.attentionActive
            autonomousLookEnabled: testCase.robot.autonomousLookEnabled
            greetingActive: testCase.robot.waving
            facePosition: Qt.point(-0.7, 0.2)
        }
    }
    property var robot
    property var eyes
    function init() {
        robot = behaviorComponent.createObject(testCase)
        eyes = eyesComponent.createObject(testCase)
    }
    function cleanup() {
        eyes.destroy()
        wait(1)
        robot.destroy()
        wait(1)
    }
    function trackFace() {
        robot.cameraRunning = true
        robot.trackingValid = true
    }
    function test_focusPreservesGazeAndCompletionHasPriority() {
        trackFace()
        robot.focusActive = true
        robot.greetingActive = true
        robot.reminderActive = true
        compare(robot.currentState, RobotBehavior.Focus)
        verify(robot.followingFace)
        verify(!robot.waving)
        verify(!robot.autonomousLookEnabled)
        robot.completionActive = true
        compare(robot.currentState, RobotBehavior.Break)
        verify(robot.waving)
        robot.focusActive = false
        robot.greetingActive = false
        robot.reminderActive = false
        robot.completionActive = false
        compare(robot.currentState, RobotBehavior.Attentive)
    }
    function test_trackingLossAndRecovery() {
        compare(robot.currentState, RobotBehavior.Idle)
        trackFace()
        compare(robot.currentState, RobotBehavior.Attentive)
        verify(!robot.autonomousLookEnabled)
        robot.predicting = true
        compare(robot.currentState, RobotBehavior.Searching)
        verify(robot.followingFace)
        robot.predicting = false
        compare(robot.currentState, RobotBehavior.Attentive)
        robot.trackingValid = false
        compare(robot.currentState, RobotBehavior.Idle)
        verify(robot.autonomousLookEnabled)
    }
    function test_greetingTracksAndReturnsToCurrentPresence() {
        trackFace()
        robot.greetingActive = true
        compare(robot.currentState, RobotBehavior.Greeting)
        verify(eyes.greetingActive)
        tryCompare(eyes, "gazeX", 0.7, 600)
        robot.predicting = true
        compare(robot.currentState, RobotBehavior.Greeting)
        robot.greetingActive = false
        compare(robot.currentState, RobotBehavior.Searching)
        verify(!eyes.autonomousLookEnabled)
        robot.trackingValid = false
        compare(robot.currentState, RobotBehavior.Idle)
        tryCompare(eyes, "gazeX", 0, 600)
    }
    function test_reminderPriorityAndCameraStop() {
        trackFace()
        robot.greetingActive = true
        robot.reminderActive = true
        compare(robot.currentState, RobotBehavior.Reminder)
        verify(!eyes.greetingActive)
        verify(robot.followingFace)
        robot.cameraRunning = false
        compare(robot.currentState, RobotBehavior.Reminder)
        verify(!robot.followingFace)
        verify(!eyes.autonomousLookEnabled)
        robot.reminderActive = false
        compare(robot.currentState, RobotBehavior.Idle)
        verify(!robot.waving)
        verify(eyes.autonomousLookEnabled)
    }
    function test_attentionEntryCancelsRandomMovement() {
        eyes.lookAround()
        wait(150)
        robot.reminderActive = true
        compare(robot.currentState, RobotBehavior.Reminder)
        tryCompare(eyes, "gazeX", 0, 600)
        tryCompare(eyes, "gazeY", 0, 600)
        robot.reminderActive = false
        compare(robot.currentState, RobotBehavior.Idle)
        verify(eyes.autonomousLookEnabled)
        verify(!eyes.attentionActive)
    }
}
