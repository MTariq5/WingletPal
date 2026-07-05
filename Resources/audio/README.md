# Health reminder audio

Drop Arabic voice-reminder clips here as `reminder1.mp3`, `reminder2.mp3`, `reminder3.mp3`, ...

`CMakeLists.txt` bundles every `*.mp3` in this folder into the Qt resource system automatically
(`file(GLOB AUDIO_FILES "Resources/audio/*.mp3")`), so adding a new clip is just: drop the file
here, re-run CMake configure.

`utilities/ReminderManager.qml`'s `reminderSources` list currently expects `reminder1.mp3` through
`reminder5.mp3` — add a matching line there when you add a 6th+ clip.

No audio files are checked in yet; `ReminderManager` will simply fail to play (harmless, logged by
Qt Multimedia) until real recordings are added here.
