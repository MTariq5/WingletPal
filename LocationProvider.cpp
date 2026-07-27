#include "LocationProvider.h"


LocationProvider::LocationProvider(QObject *parent) : QObject(parent) {
    connect(&m_manager, &QNetworkAccessManager::finished,
            this, &LocationProvider::onReplyFinished);

    m_retryTimer.setInterval(5000); // 5 seconds
    m_retryTimer.setSingleShot(false);

    connect(&m_retryTimer, &QTimer::timeout,
            this, &LocationProvider::fetchLocation);
}

QString LocationProvider::getCity()
{
    return m_city;
}

double LocationProvider::getLatitude()
{
    return m_latitude;
}

double LocationProvider::getLongitude()
{
    return m_longitude;
}

QString LocationProvider::getError()
{
    return m_error;
}

void LocationProvider::fetchLocation()
{
    QUrl url("http://ip-api.com/json/");
    QNetworkRequest request(url);
    m_manager.get(request);
}

void LocationProvider::onReplyFinished(QNetworkReply *reply)
{
    //1. Check for network errors
    if (reply->error() != QNetworkReply::NoError) {

        QString newError = reply->errorString();

        if (m_error != newError) {
            m_error = newError;
            emit errorChanged();
        }

        //START retry if not already running
        if (!m_retryTimer.isActive()) {
            qDebug() << "Starting retry timer...";
            m_retryTimer.start();
        }

        reply->deleteLater();
        return; //STOP here
    }


    // success → stop retry
    if (m_retryTimer.isActive()) {
        qDebug() << "Stop retry timer...";
        m_retryTimer.stop();
    }

    //2. Clear error if success
    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }

    //3. Normal flow
    QByteArray data = reply->readAll();

    QJsonDocument doc = QJsonDocument::fromJson(data);

    if (!doc.isObject()) {
        qDebug() << "Invalid JSON!";
        return;
    }

    QJsonObject obj = doc.object();

    QString newCity = obj["city"].toString();
    double  newLat  = obj["lat"].toDouble();
    double  newLon  = obj["lon"].toDouble();

    if (m_city != newCity) {
        m_city = newCity;
        emit cityChanged();
    }

    bool locationUpdated = false;

    if (!qFuzzyCompare(m_latitude + 1.0, newLat + 1.0)) {
        m_latitude = newLat;
        locationUpdated = true;
    }

    if (!qFuzzyCompare(m_longitude + 1.0, newLon + 1.0)) {
        m_longitude = newLon;
        locationUpdated = true;
    }

    if (locationUpdated) {
        emit locationChanged();
    }

    reply->deleteLater();
}
