#include <QGuiApplication>
#include "FocusSession.h"
#include "CitySearch.h"
#include <QQmlApplicationEngine>
#include <TimeDateProvider.h>
#include <LocationProvider.h>
#include <WeatherProvider.h>
#include <FlightTrackerProvider.h>
#include <ConnectivityChecker.h>
#include <WifiManager.h>
#include "vision/CameraController.h"
#include "vision/CameraPreview.h"
#ifdef Q_OS_WIN
#include <WifiManagerWindows.h>
#else
#include <WifiManagerLinux.h>
#endif


int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<TimeDateProvider>("TimeDateProvider", 1, 0, "TimeDateProvider");
    qmlRegisterType<LocationProvider>("LocationProvider", 1, 0, "LocationProvider");
    qmlRegisterType<WeatherProvider> ("WeatherProvider",  1, 0, "WeatherProvider");
    qmlRegisterType<CameraController>("CameraController", 1, 0, "CameraController");
    qmlRegisterType<CameraPreview>("CameraController", 1, 0, "CameraPreview");

    // ATD Phase 4: orchestrates OpenSkyFlightSource + AircraftListModel on a
    // schedule. Instantiated in AirTrafficPage.qml, not here — see
    // FlightTrackerProvider.h for how it's used from QML. This supersedes
    // the Phase 3 one-shot probe that used to live in this function.
    qmlRegisterType<FlightTrackerProvider>("FlightTracker", 1, 0, "FlightTrackerProvider");

    // Startup gating: main.qml's SplashScreen/WifiSetupPage use these to
    // decide whether the main SwipeView UI is allowed to become visible at
    // all — see ConnectivityChecker.h and WifiManager.h for why each exists.
    qmlRegisterType<ConnectivityChecker>("ConnectivityChecker", 1, 0, "ConnectivityChecker");

    // Exactly one of WifiManagerLinux/WifiManagerWindows is compiled in
    // (see CMakeLists.txt's if(WIN32) block) — whichever it is, it's
    // registered under the same QML type name so WifiSetupPage.qml never
    // has to know which platform backend it's actually talking to.
#ifdef Q_OS_WIN
    qmlRegisterType<WifiManagerWindows>("WifiManager", 1, 0, "WifiManager");
#else
    qmlRegisterType<WifiManagerLinux>("WifiManager", 1, 0, "WifiManager");
#endif

    qmlRegisterType<FocusSession>("FocusSession", 1, 0, "FocusSession");

    qmlRegisterType<CitySearch>("CitySearch", 1, 0, "CitySearch");

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/AvionicsClock/main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
