cmake_minimum_required(VERSION 3.16)

project(AvionicsClock VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 COMPONENTS Quick REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(Qt6 REQUIRED COMPONENTS Network)
find_package(Qt6 REQUIRED COMPONENTS Multimedia)

qt_add_executable(appAvionicsClock
    main.cpp
)

# Bundles whatever reminder clips have been dropped into Resources/audio/ —
# see Resources/audio/README.md. Empty on a fresh checkout; harmless if so.
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
    SOURCES TimeDateProvider.h TimeDateProvider.cpp
    SOURCES LocationProvider.h LocationProvider.cpp
    SOURCES WeatherProvider.h WeatherProvider.cpp
    RESOURCES Resources/closeup-shot-plane-wing.jpg Resources/cloudscape-with-plane-flying.jpg
    QML_FILES utilities/CustomTempContainer.qml
    QML_FILES utilities/FunnyEyes.qml
    RESOURCES Resources/weather/clear_sky.png Resources/weather/mainly_clear.png Resources/weather/Overcast.png Resources/weather/partaly_cloudy.png Resources/weather/rain.png Resources/weather/snow.png
    RESOURCES Resources/weather/location.svg
    RESOURCES Resources/ehsi/hi_loc2-dev-Minuites.svg Resources/ehsi/hi_loc2-needle-Minuites.svg
    RESOURCES Resources/weather/night-moon.png
    QML_FILES utilities/ReminderManager.qml
    RESOURCES ${AUDIO_FILES}
    RESOURCES Resources/eaid/clock-pfd.svg Resources/eaid/hourArrow.svg Resources/eaid/minuitesArrow.svg
    RESOURCES Resources/eaid/background.svg
    RESOURCES Resources/eaid/Clock-removebg-preview.png
    QML_FILES utilities/SkyGradient.qml utilities/GroundGradient.qml utilities/HorizonLine.qml utilities/PfdBackground.qml
    QML_FILES utilities/AirSpeedTape.qml utilities/AltimeterTape.qml utilities/G5AirspeedIndicator.qml utilities/G5Altimeter.qml
    QML_FILES G5/Utilities/CImage.qml G5/Utilities/CustomImage.qml
    RESOURCES Resources/Airspeed/airSpeed_bug.svg Resources/Airspeed/airSpeed_fail.svg Resources/Airspeed/airSpeed_Tumbler_Frame.svg Resources/Airspeed/GS_fail.svg Resources/Altimeter/alt_back.svg Resources/Altimeter/alt_bug.svg Resources/Altimeter/alt_fail.svg Resources/Altimeter/alt_frame.svg Resources/Altimeter/alt_ground.svg Resources/Altimeter/alt_scale.svg
    RESOURCES Resources/eaid/eadi_adi_ladd.svg
)

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
    PRIVATE Qt6::Quick Qt6::Core Qt6::Network Qt6::Multimedia)


include(GNUInstallDirs)
install(TARGETS appAvionicsClock
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
