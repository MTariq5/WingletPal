# Camera face detection

This stage opens a local camera, reports the face count, and greets a detected
visitor on the digital clock/eyes page. The pupils follow the detected face's
position. It maintains a temporary target number, not a recognized identity.
It does not record images.

## Try it

After the startup connectivity check, open the settings drawer on the eyes page
and select **Camera** (or **Diagnostics** for preview). Leave Camera at **0** for
the first device and press **Start camera**.
The page shows the latest detected face count or **No face detected**. If opening
fails, close other camera applications, check operating-system camera permissions,
or select another camera number and retry.

Press **Stop camera** to release the device. After starting it, the camera keeps
running while you visit other pages. Returning shows the same controller's current
state. Closing the application releases the camera.

Enable **Preview** on the camera page for a mirrored live view. Yellow boxes mark
detections, green marks the selected target, a white dot is its current measured
center, and a blue ring is the Kalman estimate. During prediction the blue ring is
dashed and there is no fresh white measurement. The status shows the target number,
Measured/Predicting/Searching, processing milliseconds, and observed frame rate.
The first frame has no FPS estimate. Processing time includes capture, detection,
tracking and the optional preview copy; FPS also includes the between-frame wait.

Preview is off by default. It copies images only while enabled and the camera page
is visible. Hiding the page or disabling Preview clears the UI's image; camera
detection and following continue. No image is saved or uploaded.

**Kalman gaze** switches the eyes between the filtered estimate and the last raw
target measurement for comparison. The filter still runs for association and the
blue diagnostic ring. With this switch off, a brief loss holds the last measured
position rather than extrapolating. This does not change the detection count.

Return to the digital clock/eyes page while the camera is running. After a face
remains detected for 800 ms on that page, the eyes smile, a hand waves, and a bundled
synthetic American English male voice says **Hello, nice to meet you.**. The greeting display lasts 3 seconds.
It waits for any health reminder to finish; reminders cannot start over a greeting.
Focus sessions and the completion celebration suppress greetings and reminders.
Leaving the eyes page stops the greeting audio and animation. Returning does not
repeat an already delivered greeting. Ten seconds without a detected face rearms
it; stopping the camera also resets it. Brief detector misses do not rearm it.
This is one greeting per detected presence, not per recognized person.

`utilities/FaceGreeting.qml` owns the presence timers and audio playback;
`main.qml` connects its inputs to the shared camera, current page and reminder.
`FunnyEyes.greetingActive` controls the greeting expression and waving hand.
If audio fails, the greeting temporarily displays an error and logs the playback
reason. The MP3 is bundled, so greeting playback needs no network or Python.

## Eyes following the face

With the camera running, move your face left/right and up/down while viewing the
eyes page. The largest face starts a new target. Subsequent frames associate the
nearest plausible detection with the predicted target center, rather than always
choosing the largest. Association requires an area ratio of 0.4–2.5 and a distance
within 60% of the previous box diagonal (limited to 0.08–0.25 in normalized image
coordinates). Detection order changes or a distant larger newcomer do not by
themselves change the target. After 600 ms without a matching measurement, the
target expires and the largest available face can start a new target number.

These are geometric associations, not biometric identities: crossing, overlapping,
rapidly moving or very similar nearby faces can still cause incorrect matches.
Target numbers reset when the camera restarts.

`FaceTracker` uses center and velocity in image fractions [0, 1]. The controller
converts the selected raw or estimated center to the eyes' [-1, 1] coordinates:

```text
x = 2 * (face.x + face.width / 2) / frame.width - 1
y = 2 * (face.y + face.height / 2) / frame.height - 1
```

The C++ implementation uses floating-point division. In eye coordinates `(0, 0)`
is the image center; positive camera X is right and positive Y is down.
`CameraController.facePosition` notifies independently of `faceCount`.

The constant-velocity Kalman state is `[x, y, vx, vy]`. Prediction uses actual
elapsed time between frames. Acceleration standard deviation is 0.5 image units/s²;
measurement variance is 0.0004 on each axis. Correction uses Joseph-form covariance
updates. These initial tuning values are in `FaceTracker.cpp`; they are not a
benchmark or an accuracy guarantee. Tests compare stationary measurement jitter,
variable frame timing, target association, prediction expiry and reset behavior.

`main.qml` passes camera/tracking/audio inputs through `RobotBehavior`, and the
controller's `facePosition` into `FunnyEyes`. For an unmirrored camera, `gazeX` negates camera X to
look toward the viewer's screen-side position; `gazeY` keeps camera Y. The values
are clamped to [-1, 1], then animated toward each new target over 180 ms with
ease-out interpolation. This drawing animation remains in addition to the Kalman
filter and also applies when comparing raw-measurement gaze.

Face following takes priority over random looks and the centered speaking pose.
Blinking, greeting expressions and audio continue. Prediction is limited to 600 ms
since the selected target's last measurement, then following ends and random looks
may resume when the behavior state returns to Idle. A controller timer also expires the target if
frames stop arriving; the eyes do not add their older loss-grace interval on top.
Stop/error clears tracking and preview. Greeting presence still uses actual face
detections, so a predicted target alone cannot trigger a greeting.

## Follow the code

1. `main.qml` creates `appCamera` under the main `Window` and passes it to
   `CameraPage.qml` through its required `camera` property. The page calls
   `CameraController::start(cameraIndex)` on that shared instance.
2. The controller queues a request to `FaceDetectionWorker`, which lives on its
   own `QThread`. OpenCV camera and image operations stay on that thread.
3. The worker reads the bundled frontal and profile cascades from Qt resources using `cv::FileStorage`
   and opens `cv::VideoCapture`. Windows uses DirectShow; other platforms use
   OpenCV's automatic backend selection.
4. A single-shot timer calls `processNextFrame()`: read a frame, resize if wider
   than 640 pixels, convert BGR to grayscale, and run frontal detection plus
   profile detection on both the original and horizontally mirrored image.
   Mirrored boxes return to original coordinates with `x = frameWidth - x - width`.
   `FaceDetections::merge` keeps the frontal box when detections overlap by more
   than 50% of the smaller box's area; non-overlapping faces remain separate.
5. The worker updates `FaceTracker` and emits `frameProcessed(FaceFrame)` across
   the thread boundary. The frame contains normalized boxes, the selected index,
   raw/estimated centers, target validity, timing, and optionally an owned `QImage`.
   The controller updates count, gaze, and diagnostics together. `CameraPreview`
   paints the GUI-thread copy, preserving aspect ratio and mirroring boxes and
   centers with the image.
6. The worker schedules the next frame 100 ms after processing finishes. This is
   not a guaranteed 10 FPS. Stop requests run between camera operations.

`running` means the camera opened, not that a frame has already been processed.
The controller also exposes `state` (`Stopped`, `Starting`, `Running`, `Stopping`,
`Error`) and `errorString`. Start is accepted only in Stopped or Error; Stop also
works during Starting. On an error, the worker releases the device and the
controller clears the previous face count.

Shutdown waits for the worker to release the camera before ending its thread.
A camera driver blocked inside OpenCV's `open()` or `read()` can delay Stop and
application shutdown; these calls are not forcibly terminated.

## Build dependency

The application now requires an OpenCV 4 C++ development build containing `core`,
`imgproc`, `objdetect`, and `videoio`, including a backend for local cameras.
Python's `opencv-python` package does not supply this project's C++ dependency.

Set the CMake cache variable `OpenCV_DIR` to the directory containing the matching
`OpenCVConfig.cmake`, then configure and build the application again. In Qt Creator,
add this variable under Projects > Build > CMake. OpenCV must match the Qt kit's
architecture and compiler; an MSVC build cannot be linked into a MinGW application.
For shared OpenCV builds, make its runtime libraries available to the executable
as well. A static OpenCV build avoids the OpenCV DLL deployment step.

See [OpenCV's build instructions](https://docs.opencv.org/4.x/d7/d9f/tutorial_linux_install.html)
for building from source. Existing Qt module requirements still apply.

## Detection limits and model

The bundled Haar cascades are from OpenCV 4.12.0:
[frontal face](https://github.com/opencv/opencv/blob/4.12.0/data/haarcascades/haarcascade_frontalface_default.xml)
and [profile face](https://github.com/opencv/opencv/blob/4.12.0/data/haarcascades/haarcascade_profileface.xml).
Their original licenses and attribution remain in the XML headers.

The profile model is applied in both directions to cover left/right head turns.
All three detection passes run on the worker thread each frame, including when
a frontal face is present, so frontal and profile faces can coexist. This costs
more processing time than frontal-only detection; frame rate is not fixed.
Partial turns, occlusion, and poor lighting can still cause misses. Nearby faces
with strongly overlapping boxes may be merged. Prediction is bounded to 600 ms;
the 10 s greeting rearm interval remains unchanged.

## Tracker tests

The deterministic tests need Qt Core/Test and OpenCV core, without camera access:

```sh
cmake -S tests/vision -B build-tracker-tests -DCMAKE_PREFIX_PATH="<Qt-kit-prefix>" -DOpenCV_DIR="<OpenCV-config-directory>"
cmake --build build-tracker-tests
ctest --test-dir build-tracker-tests --output-on-failure
```

Use the same compiler/architecture as the application and ensure Qt runtime
libraries are on the executable search path. The tests use synthetic detections;
live accuracy and latency should also be checked with Preview on the target device.

Detection results are per frame, with no temporal smoothing. Lighting, head angle, small
faces, or false detections can change the count. Zero detections does not prove
that nobody is present. This is a face detector, not a full-body person detector.

## Companion behavior states

`utilities/RobotBehavior.qml` is a reactive finite-state selector. It reads current
camera, tracker and audio activity and always resolves one state in this order:

| State | Entry condition | Exit |
| --- | --- | --- |
| Break | Focus completion celebration is active | When it ends, re-evaluate all inputs |
| Focus | A focus session is active | Completion or cancellation |
| Reminder | Reminder is active | When it ends, re-evaluate all inputs |
| Greeting | Greeting is active and camera is running | When greeting ends/stops, re-evaluate |
| Searching | Running camera, valid target, prediction without a fresh match | Measured target → Attentive; expiry → Idle |
| Attentive | Running camera, valid measured target | Missing match → Searching; stopped/error camera → Idle |
| Idle | None of the above | New tracked face or an audio event |

Break and Focus take precedence over reminders and greetings. Reminder wins if
both reminder and greeting flags are set, although the audio components prevent
overlap. These states take priority for expression; gaze still follows a
valid target while speaking. Only Idle allows autonomous random looks. The tracker
owns the 600 ms loss limit, and FaceGreeting still owns its stability/cooldown and
page-exit rules. The behavior selector adds no timers and starts no audio itself.
Stopping the camera ends following, but an already-playing reminder can continue.

Enable Preview on the camera page to see the current robot state, including
`Idle`, `Attentive`, `Searching`, `Greeting`, `Reminder`, `Focus`, and `Break`.
The eyes receive behavior outputs rather than direct camera/audio mode commands.

Behavior and eye-interaction tests (no camera required):

```sh
cmake -S tests/behavior -B build-behavior-tests -DCMAKE_PREFIX_PATH="<Qt-kit-prefix>"
cmake --build build-behavior-tests
ctest --test-dir build-behavior-tests --output-on-failure
```

Use the application's compiler and Qt runtime path, as for the tracker tests.
