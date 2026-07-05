#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <TimeDateProvider.h>
#include <LocationProvider.h>
#include <WeatherProvider.h>


int main(int argc, char *argv[])
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QGuiApplication app(argc, argv);

    qmlRegisterType<TimeDateProvider>("TimeDateProvider", 1, 0, "TimeDateProvider");
    qmlRegisterType<LocationProvider>("LocationProvider", 1, 0, "LocationProvider");
    qmlRegisterType<WeatherProvider> ("WeatherProvider",  1, 0, "WeatherProvider");

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
