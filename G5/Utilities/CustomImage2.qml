import QtQuick 2.15

Image {
    id:img

    property real currentAngle: 0
    property real targetAngle: 0

    onTargetAngleChanged: {
        animation.stop();
        animation.from = currentAngle;
        animation.to = targetAngle;
        animation.start();
        currentAngle = targetAngle;
    }

    sourceSize.width: 1024
    sourceSize.height: 1024
    fillMode: Image.PreserveAspectFit
    cache: false
    smooth: true
    antialiasing: true
    mipmap: true

    RotationAnimation {
        id: animation
        target: img
        property: "rotation"
        from: currentAngle
        to: targetAngle
        duration: 200
        direction: RotationAnimation.Shortest
    }

    Behavior on x{
        NumberAnimation{
            duration: 200
        }
    }

    Behavior on y{
        NumberAnimation{
            duration: 200
        }
    }
}
