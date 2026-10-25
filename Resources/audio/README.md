# Greeting and reminder audio

**Publication status (2026-10-24):** the four reminder clips are not the project
owner's recordings and have no established source/license. The generation route
for the greeting and completion clips is recorded below, but redistribution
permission for their Edge-service output has not been established. All six clips
need permission or replacement before public release. These reproduction notes
are not a license grant. See the [asset review](../../docs/ASSET_REVIEW.md).

`hello.mp3` says **Hello, nice to meet you.** using the synthetic American English male voice
`en-US-GuyNeural`. It was generated on 2026-10-24 with
[edge-tts](https://github.com/rany2/edge-tts) 7.3.1 and Microsoft's online voice
service. Only the greeting text was sent for generation, not camera data.
The application plays the bundled MP3 through Qt Multimedia; it does not call
the service or require Python at runtime.

To regenerate with edge-tts installed (internet required):

```sh
edge-tts --voice en-US-GuyNeural --text "Hello, nice to meet you." --write-media Resources/audio/hello.mp3
```

`utilities/FaceGreeting.qml` plays this clip on the eyes page after stable face
detection. See `vision/README.md` for greeting and rearm timing.

Drop Arabic voice-reminder clips here as `reminder1.mp3`, `reminder2.mp3`, `reminder3.mp3`, ...

`CMakeLists.txt` bundles every `*.mp3` in this folder into the Qt resource system automatically
(`file(GLOB AUDIO_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "Resources/audio/*.mp3")`), so adding a new clip is just: drop the file
here, re-run CMake configure.

`utilities/ReminderManager.qml`'s `reminderSources` list currently expects `reminder1.mp3` through
`reminder5.mp3` — add a matching line there when you add a 6th+ clip.

The current folder contains `reminder1.mp3` through `reminder4.mp3`.
`reminder5.mp3` is still absent; selecting it reports a playback error.

## Focus completion

`focus-complete.mp3` says **عاش يا طارق، وقت استراحة صغيرة.** using the
synthetic Egyptian male voice `ar-EG-ShakirNeural`. Generated on 2026-10-24
with edge-tts 7.3.1. Only this sentence was sent to the online voice service.
`FocusCompletion.qml` plays the bundled clip when a focus session completes;
playback works offline and respects the companion mute/volume settings.
