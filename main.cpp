#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <TimeDateProvider.h>
#include <LocationProvider.h>
#include <WeatherProvider.h>
#include <FlightTrackerProvider.h>


int main(int argc, char *argv[])
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QGuiApplication app(argc, argv);

    qmlRegisterType<TimeDateProvider>("TimeDateProvider", 1, 0, "TimeDateProvider");
    qmlRegisterType<LocationProvider>("LocationProvider", 1, 0, "LocationProvider");
    qmlRegisterType<WeatherProvider> ("WeatherProvider",  1, 0, "WeatherProvider");

    // ATD Phase 4: orchestrates OpenSkyFlightSource + AircraftListModel on a
    // schedule. Instantiated in AirTrafficPage.qml, not here — see
    // FlightTrackerProvider.h for how it's used from QML. This supersedes
    // the Phase 3 one-shot probe that used to live in this function.
    qmlRegisterType<FlightTrackerProvider>("FlightTracker", 1, 0, "FlightTrackerProvider");

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
