---
paths:
  - G5/**
  - utilities/G5Altimeter.qml
  - utilities/G5AirspeedIndicator.qml
---

### G5 test page — `utilities/G5Altimeter.qml` / `utilities/G5AirspeedIndicator.qml` (⚠️ duplicated files, read this before touching either)

A Garmin-G5-style airspeed/altimeter component pair was imported from another project onto the unnumbered test page (SwipeView index 0, see the root CLAUDE.md's page list). **The files live in two places and only one of them is real:**

- `G5/PFD/G5Altimeter.qml`, `G5/PFD/G5AirspeedIndicator.qml`, `G5/PFD/AirSpeedTape.qml`, `G5/PFD/AltimeterTape.qml`, `G5/PFD/G5Battery.qml`, `G5/PFD/G5Heading.qml`, and everything under `G5/Utilities/` **except** `CImage.qml`/`CustomImage.qml` — none of this is referenced by `qt_add_qml_module` in `CMakeLists.txt`. It is dead code as far as the build is concerned; editing it changes nothing at runtime.
- `utilities/G5Altimeter.qml` and `utilities/G5AirspeedIndicator.qml` are separate, manually-duplicated copies of the two files above — **these are the ones actually compiled and instantiated** in `main.qml`'s test page. Any behavior change belongs here.

Both were originally written against Qt Quick Controls **1** (`import QtQuick.Extras 1.4`, `import QtQuick.Controls.Styles 1.4`, `Tumbler`/`TumblerStyle`/`TumblerColumn` for the scrolling digit-wheel readouts) — that whole API was deleted in Qt6 and both imports fail with "module not found". They've been ported to native Qt Quick Controls **2** `Tumbler`: each old `Tumbler > TumblerStyle > TumblerColumn` triple (always exactly one column per Tumbler in this code) collapsed into a single `Tumbler` with `model`/`visibleItemCount`/`background`/`delegate` set directly; delegate `styleData.value` → `modelData`, `styleData.displacement` → the `Tumbler.displacement` attached property; and `tumbN.setCurrentIndexAt(0, index, duration)` → `tumbN.currentIndex = index` (Controls 2's `Tumbler` animates the roll itself, no duration argument needed). Apply the same pattern to `G5Battery.qml`/`G5Heading.qml` if they're ever wired up — they still have the Controls-1 imports.

`import "../G5/Utilities"` in both `utilities/` copies resolves to `G5/Utilities/`, but only `CImage.qml` and `CustomImage.qml` are registered as `QML_FILES` there (the only two types either file actually instantiates) — adding a call to another component from that folder means adding its own `QML_FILES G5/Utilities/X.qml` line too. Don't add `CButtonIndicator.qml` as-is: it still has `import QtGraphicalEffects 1.0`, the pre-Qt6 module name (should be `Qt5Compat.GraphicalEffects`, same fix already applied to `main.qml`).

Known open issues on this page (non-fatal, app runs fine without fixing these):
- Every `Image`/`CustomImage` `source:` in both files points at `qrc:/Resources/Airspeed/...` or `qrc:/Resources/Altimeter/...`, missing the `AvionicsClock` prefix every other qrc reference in this project uses (should be `qrc:/AvionicsClock/Resources/Airspeed/...` etc.) — images silently fail to load ("Cannot open" warnings), nothing crashes.
- The test page's root `Item` sets `anchors.fill: parent`, which conflicts with `SwipeView`'s own child layout ("conflicting anchors" warning at runtime) — every other page correctly leaves its root `Item` unanchored and lets `SwipeView` size it.
