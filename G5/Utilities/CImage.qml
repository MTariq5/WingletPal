import QtQuick 2.15

Image {
    id:img

    property real currentAngle: 0

    property real rotate: 0
    property real pitch: 0
    property real pixelPerDegree: 0

    property int duration: 200

    property real maxPitch: -1

    property real _pitchX: 0
    property real _pitchY: 0

    onRotateChanged: {
        update();
        animation.stop();
        animation.from = currentAngle;
        animation.to = rotate;
        animation.start();
        currentAngle = rotate;
    }

    onPitchChanged: {
        update();
    }


    function update(){
        if(maxPitch >= 0){
            let __PitchY = pixelPerDegree * pitch * Math.cos(Math.PI * (-rotate) / 180.0)

            if(__PitchY > maxPitch && __PitchY > 0){
                //console.log("A PITCH ANGLE IS GREATER THAN LIMIT")
                _pitchY = maxPitch;
                _pitchX = pixelPerDegree * pitch * Math.sin(Math.PI * (-rotate) / 180.0)
            }
            else if(__PitchY < (-maxPitch) && __PitchY < 0){
                //console.log("B PITCH ANGLE IS LESS THAN LIMIT")
                _pitchY = -maxPitch
                _pitchX = pixelPerDegree * pitch * Math.sin(Math.PI * (-rotate) / 180.0)
            }
            else{
                _pitchX = pixelPerDegree * pitch * Math.sin(Math.PI * (-rotate) / 180.0)
                _pitchY = pixelPerDegree * pitch * Math.cos(Math.PI * (-rotate) / 180.0)
            }
        }
        else{
            _pitchX = pixelPerDegree * pitch * Math.sin(Math.PI * (-rotate) / 180.0)
            _pitchY = pixelPerDegree * pitch * Math.cos(Math.PI * (-rotate) / 180.0)
        }
    }

    sourceSize.width: 1024
    sourceSize.height: 1024
    fillMode: Image.PreserveAspectFit
    cache: false
    smooth: true
    antialiasing: true
    mipmap: true
    asynchronous: true //this dont freeze ui when set

    transform: [
        Translate {
            x : _pitchX
            y : _pitchY

            Behavior on x{
                NumberAnimation{
                    duration: img.duration
                }
            }
            Behavior on y{
                NumberAnimation{
                    duration: img.duration
                }
            }
        }
    ]

    RotationAnimation {
        id: animation
        target: img
        property: "rotation"
        from: currentAngle
        to: rotate
        duration: img.duration
        direction: RotationAnimation.Shortest
    }
}
