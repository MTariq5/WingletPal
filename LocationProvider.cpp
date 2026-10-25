#include "LocationProvider.h"
#include <cmath>

LocationProvider::LocationProvider(QObject *parent)
    : QObject(parent), m_settings(QSettings::IniFormat, QSettings::UserScope,
                                  "AvionicsClock", "Location")
{
    m_city = m_settings.value("city").toString();
    m_latitude = m_settings.value("latitude").toDouble();
    m_longitude = m_settings.value("longitude").toDouble();
    if (!m_settings.contains("latitude") || !m_settings.contains("longitude")
        || !validLocation(m_city, m_latitude, m_longitude))
        useTenthOfRamadan();
    else if (m_city == QString::fromUtf8("العاشر من رمضان"))
        saveManualLocation(QStringLiteral("10th of Ramadan City"), m_latitude, m_longitude);
}

bool LocationProvider::validLocation(const QString &city, double latitude, double longitude)
{
    return !city.trimmed().isEmpty() && std::isfinite(latitude) && std::isfinite(longitude)
           && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
}

void LocationProvider::setError(const QString &message)
{
    if (m_error == message)
        return;
    m_error = message;
    emit errorChanged();
}

bool LocationProvider::saveManualLocation(const QString &city, double latitude, double longitude)
{
    if (!validLocation(city, latitude, longitude)) {
        setError(tr("Enter a city, latitude (-90 to 90), and longitude (-180 to 180)."));
        return false;
    }
    m_settings.setValue("city", city.trimmed());
    m_settings.setValue("latitude", latitude);
    m_settings.setValue("longitude", longitude);
    m_settings.sync();
    if (m_settings.status() != QSettings::NoError) {
        setError(tr("Could not save the location settings."));
        return false;
    }
    m_city = city.trimmed();
    m_latitude = latitude;
    m_longitude = longitude;
    setError({});
    emit cityChanged();
    emit locationChanged();
    return true;
}

bool LocationProvider::useTenthOfRamadan()
{
    return saveManualLocation(QStringLiteral("10th of Ramadan City"), 30.306503, 31.741455);
}
