cmake_minimum_required(VERSION 3.16)

project(AvionicsClock VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 COMPONENTS Quick REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(Qt6 REQUIRED COMPONENTS Network)
find_package(Qt6 REQUIRED COMPONENTS Multimedia)
# Air Traffic Display page: QtLocation/QtPositioning QML modules (osm map
# plugin, coordinate types). Not installed by default on every kit — if this
# find_package fails at configure time, add "Qt Location" to that kit's Qt
# install via the Qt Maintenance Tool (same situation Multimedia was in).
find_package(Qt6 REQUIRED COMPONENTS Location Positioning)
find_package(OpenCV 4 REQUIRED COMPONENTS core imgproc objdetect videoio)

qt_add_executable(appAvionicsClock
    main.cpp
)

# Debug builds use the developer's source-root configuration; distributed
# builds read opensky.ini next to the executable instead.
target_compile_definitions(appAvionicsClock PRIVATE
    "$<$<CONFIG:Debug>:AVIONICSCLOCK_SOURCE_DIR=\"${CMAKE_CURRENT_SOURCE_DIR}\">"
)

# Bundles greeting and reminder clips; see Resources/audio/README.md.
# RELATIVE is required: qt_add_qml_module's resource system rejects absolute
# paths (which file(GLOB) returns by default) with a QT_RESOURCE_ALIAS error.
file(GLOB AUDIO_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "Resources/audio/*.mp3")

qt_add_qml_module(appAvionicsClock
    URI AvionicsClock
    VERSION 1.0
    QML_FILES main.qml
    RESOURCES Resources/ehsi/ehsi_dev_scale.svg
    RESOURCES Resources/ehsi/ehsi_hdg_scale.svg
    RESOURCES Resources/ehsi/hi_case.svg
    RESOURCES Resources/ehsi/hi_loc2-needle.svg
    RESOURCES Resources/ehsi/hi_loc2-dev.svg
    RESOURCES Resources/ehsi/ehsi_hdg_bug.svg
    QML_FILES utilities/CloseButton.qml utilities/CustomButtonIcon.qml
    RESOURCES Resources/settings-outline.svg
    RESOURCES Resources/up-arrow.svg
    RESOURCES Resources/Brightness-Slider/brightnessicon-orange.svg Resources/Brightness-Slider/brightnessicon.svg Resources/Brightness-Slider/crescent-moon.svg
    QML_FILES Brightness-Control/BritnessControl.qml
    SOURCES
    SOURCES FocusSession.h FocusSession.cpp
    QML_FILES utilities/FocusCompletion.qml
    SOURCES TimeDateProvider.h TimeDateProvider.cpp
    SOURCES LocationProvider.h LocationProvider.cpp CitySearch.h CitySearch.cpp
    SOURCES WeatherProvider.h WeatherProvider.cpp
    RESOURCES Resources/closeup-shot-plane-wing.jpg Resources/cloudscape-with-plane-flying.jpg
    QML_FILES utilities/CustomTempContainer.qml
    QML_FILES utilities/FunnyEyes.qml
    RESOURCES Resources/weather/clear_sky.png Resources/weather/mainly_clear.png Resources/weather/Overcast.png Resources/weather/partaly_cloudy.png Resources/weather/rain.png Resources/weather/snow.png
    RESOURCES Resources/weather/location.svg
    RESOURCES Resources/ehsi/hi_loc2-dev-Minuites.svg Resources/ehsi/hi_loc2-needle-Minuites.svg
    RESOURCES Resources/weather/night-moon.png
    QML_FILES utilities/ReminderManager.qml
    QML_FILES utilities/FaceGreeting.qml
    QML_FILES utilities/RobotBehavior.qml
    QML_FILES utilities/CompanionSettings.qml
    QML_FILES utilities/LocationSettings.qml
    RESOURCES Resources/waving-hand.svg
    RESOURCES ${AUDIO_FILES}
    RESOURCES Resources/eaid/clock-pfd.svg Resources/eaid/hourArrow.svg Resources/eaid/minuitesArrow.svg
    RESOURCES Resources/eaid/background.svg
    RESOURCES Resources/eaid/Clock-removebg-preview.png
    QML_FILES utilities/SkyGradient.qml utilities/GroundGradient.qml utilities/HorizonLine.qml utilities/PfdBackground.qml
    RESOURCES Resources/eaid/eadi_adi_ladd.svg

    # Air Traffic Display (ATD) page — map/UI (Phases 0-2).
    QML_FILES utilities/AirTrafficPage.qml utilities/TrafficMap.qml utilities/CenterCrosshair.qml utilities/ZoomButton.qml utilities/MapStyleMenu.qml

    # ATD overlay bars — DMS position readout (top) + city/temperature/date/
    # time (bottom-left floating panel), part of Phase 6, added ahead of the
    # rest of that phase by explicit request.
    QML_FILES utilities/CoordinateBar.qml utilities/StatusBar.qml

    # ATD marker selection — tap an aircraft to highlight it orange and open
    # a left floating detail card; tap again (or its close button) to
    # deselect. AircraftMarker.qml's ColorOverlay needs Qt5Compat.
    # GraphicalEffects, already a required module (see main.qml's DropShadow/
    # FastBlur/RadialGradient usage).
    QML_FILES utilities/AircraftDetailPanel.qml

    # ATD backend, Phase 3 — OAuth2 token manager + OpenSky /states/all data
    # source.
    SOURCES GeoBoundingBox.h GeoBoundingBox.cpp
    SOURCES Aircraft.h
    SOURCES FlightDataSource.h
    SOURCES OpenSkyTokenManager.h OpenSkyTokenManager.cpp
    SOURCES OpenSkyFlightSource.h OpenSkyFlightSource.cpp

    # ATD backend, Phase 4 — AircraftListModel (upsert-by-icao QAbstractListModel)
    # + FlightTrackerProvider (the QML-facing orchestrator: 30s polling schedule,
    # bounding box from lat/lon + searchRadiusKm, status/errorString). Plus the
    # on-map marker: a heading-rotated glyph, not a dot, rendered via a
    # MapItemView added to TrafficMap.qml in this same phase.
    SOURCES AircraftListModel.h AircraftListModel.cpp
    SOURCES FlightTrackerProvider.h FlightTrackerProvider.cpp
    QML_FILES utilities/AircraftMarker.qml
    RESOURCES Resources/traffic/aircraft.svg

    # Startup connectivity gating + Wi-Fi setup — a splash screen blocks the
    # app until real internet is confirmed (not just a network interface
    # being up); ConnectivityChecker probes it, WifiManager scans/joins a
    # network if it's missing. See .claude/rules/startup-connectivity.md.
    SOURCES ConnectivityChecker.h ConnectivityChecker.cpp
    SOURCES WifiManager.h WifiManager.cpp
    QML_FILES utilities/SplashScreen.qml utilities/WifiSetupPage.qml

    # Page 6 — About: project summary + developer contact, mirroring the
    # name/email already shown briefly on SplashScreen.qml.
    QML_FILES utilities/AboutPage.qml
    SOURCES vision/CameraController.h vision/CameraController.cpp
    SOURCES vision/FaceDetectionWorker.h vision/FaceDetectionWorker.cpp
    QML_FILES utilities/CameraPage.qml
    RESOURCES Resources/models/haarcascade_frontalface_default.xml
    RESOURCES Resources/models/haarcascade_profileface.xml
    SOURCES vision/FaceDetections.h
    SOURCES vision/FaceTracker.h vision/FaceTracker.cpp vision/FaceFrame.h
    SOURCES vision/CameraPreview.h vision/CameraPreview.cpp
)

# Wi-Fi scan/connect backend — exactly one of these two is compiled in,
# matching whichever platform this is actually being built for. Both
# implement the same abstract WifiManager interface (see WifiManager.h);
# main.cpp registers whichever one was compiled under the same QML type
# name ("WifiManager"), so WifiSetupPage.qml never has to know which is in
# use. Kept as a plain target_sources() call rather than folded into
# qt_add_qml_module's SOURCES above, since that call's SOURCES list isn't
# meant to carry per-platform generator logic.
if(WIN32)
    target_sources(appAvionicsClock PRIVATE WifiManagerWindows.h WifiManagerWindows.cpp)
else()
    target_sources(appAvionicsClock PRIVATE WifiManagerLinux.h WifiManagerLinux.cpp)
endif()

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appAvionicsClock PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appAvionicsClock
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appAvionicsClock
    PRIVATE Qt6::Quick Qt6::Core Qt6::Network Qt6::Multimedia Qt6::Location Qt6::Positioning
    ${OpenCV_LIBS})
target_include_directories(appAvionicsClock PRIVATE ${OpenCV_INCLUDE_DIRS})


include(GNUInstallDirs)
install(TARGETS appAvionicsClock
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
