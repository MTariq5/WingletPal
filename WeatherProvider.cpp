#include "WeatherProvider.h"

// ─────────────────────────────────────────────────────────────────────────────
//  Constructor
// ─────────────────────────────────────────────────────────────────────────────
WeatherProvider::WeatherProvider(QObject *parent) : QObject(parent)
{
    connect(&m_manager, &QNetworkAccessManager::finished,
            this,       &WeatherProvider::onReplyFinished);

    m_refreshTimer.setInterval(30 * 60 * 1000);
    m_refreshTimer.setSingleShot(false);
    connect(&m_refreshTimer, &QTimer::timeout,
            this,            &WeatherProvider::updateWeather);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Public API
// ─────────────────────────────────────────────────────────────────────────────
void WeatherProvider::setLocation(double latitude, double longitude)
{
    m_latitude    = latitude;
    m_longitude   = longitude;
    m_hasLocation = true;

    updateWeather();
}

void WeatherProvider::updateWeather()
{
    if (!m_hasLocation) {
        qDebug() << "WeatherProvider: location not yet available, skipping fetch";
        return;
    }

    QUrlQuery query;
    query.addQueryItem("latitude",        QString::number(m_latitude,  'f', 4));
    query.addQueryItem("longitude",       QString::number(m_longitude, 'f', 4));
    query.addQueryItem("hourly",          "temperature_2m,weathercode");
    query.addQueryItem("daily",           "sunrise,sunset");
    query.addQueryItem("current_weather", "true");
    query.addQueryItem("timezone",        "auto");
    query.addQueryItem("forecast_days",   "2");

    QUrl url("https://api.open-meteo.com/v1/forecast");
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    setLoading(true);
    m_manager.get(request);

    qDebug() << "WeatherProvider: GET" << url.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Network reply
// ─────────────────────────────────────────────────────────────────────────────
void WeatherProvider::onReplyFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    setLoading(false);

    if (reply->error() != QNetworkReply::NoError) {
        setError(reply->errorString());
        return;
    }

    clearError();
    parseResponse(reply->readAll());

    if (!m_refreshTimer.isActive()) {
        m_refreshTimer.start();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  JSON parsing
// ─────────────────────────────────────────────────────────────────────────────
void WeatherProvider::parseResponse(const QByteArray &data)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (doc.isNull()) {
        setError("JSON parse error: " + parseError.errorString());
        return;
    }

    QJsonObject root = doc.object();

    // ── 0. Sunrise / sunset (must come before current_weather so the icon is
    //       correct when currentWeatherChanged() fires) ─────────────────────
    m_sunriseSunset.clear();
    if (root.contains("daily")) {
        QJsonObject daily    = root["daily"].toObject();
        QJsonArray  sunrises = daily["sunrise"].toArray();
        QJsonArray  sunsets  = daily["sunset"].toArray();
        int dayCount = qMin(sunrises.size(), sunsets.size());
        for (int i = 0; i < dayCount; ++i) {
            // Open-Meteo daily timestamps: "2024-06-28T05:37"
            QDateTime rise = QDateTime::fromString(sunrises[i].toString(), "yyyy-MM-ddTHH:mm");
            QDateTime set  = QDateTime::fromString(sunsets[i].toString(),  "yyyy-MM-ddTHH:mm");
            if (rise.isValid() && set.isValid()) {
                m_sunriseSunset[rise.date()] = qMakePair(rise, set);
            }
        }
    }

    // ── 1. Current conditions ─────────────────────────────────────────────
    if (root.contains("current_weather")) {
        QJsonObject cw = root["current_weather"].toObject();

        double newTemp = cw["temperature"].toDouble();
        int    newCode = cw["weathercode"].toInt();
        double newWind = cw["windspeed"].toDouble();

        bool changed = false;
        if (!qFuzzyCompare(m_currentTemperature + 1.0, newTemp + 1.0)) {
            m_currentTemperature = newTemp;
            changed = true;
        }
        if (m_currentWeatherCode != newCode) {
            m_currentWeatherCode = newCode;
            changed = true;
        }
        if (!qFuzzyCompare(m_currentWindSpeed + 1.0, newWind + 1.0)) {
            m_currentWindSpeed = newWind;
            changed = true;
        }

        if (changed) {
            emit currentWeatherChanged();
        }
    }

    // ── 2. Hourly forecast — rolling 24-hour window ──────────────────────
    if (root.contains("hourly")) {
        QJsonObject hourly = root["hourly"].toObject();
        QJsonArray  times  = hourly["time"].toArray();
        QJsonArray  temps  = hourly["temperature_2m"].toArray();
        QJsonArray  codes  = hourly["weathercode"].toArray();

        int total = qMin(qMin(times.size(), temps.size()), codes.size());

        QDateTime now         = QDateTime::currentDateTime();
        QDate     today       = now.date();
        int       currentHour = now.time().hour();

        int startIndex = -1;
        for (int i = 0; i < total; ++i) {
            QDateTime dt = QDateTime::fromString(times[i].toString(), "yyyy-MM-ddTHH:mm");
            if (!dt.isValid()) continue;
            if (dt.date() == today && dt.time().hour() == currentHour) {
                startIndex = i;
                break;
            }
        }

        if (startIndex < 0) {
            qDebug() << "WeatherProvider: current hour not found in forecast, falling back to index 0";
            startIndex = 0;
        }

        int count = qMin(total - startIndex, 24);

        QVariantList forecast;
        forecast.reserve(count);

        for (int i = 0; i < count; ++i) {
            int idx = startIndex + i;

            QDateTime dt     = QDateTime::fromString(times[idx].toString(), "yyyy-MM-ddTHH:mm");
            int       hour24 = dt.isValid() ? dt.time().hour() : 0;

            int     h12  = (hour24 % 12 == 0) ? 12 : (hour24 % 12);
            QString ampm = (hour24 < 12) ? "AM" : "PM";

            int code = codes[idx].toInt();

            // Determine day / night using the sunrise and sunset for the
            // forecast entry's own date.  Falls back to day icons if the
            // daily block was missing or could not be parsed.
            bool isNight = false;
            if (dt.isValid() && m_sunriseSunset.contains(dt.date())) {
                const QPair<QDateTime, QDateTime> &sun = m_sunriseSunset[dt.date()];
                isNight = (dt < sun.first || dt >= sun.second);
            }

            QVariantMap item;
            item["hour"]               = QString::number(h12);
            item["ampm"]               = ampm;
            item["temperature"]        = temps[idx].toDouble();
            item["weatherCode"]        = code;
            item["weatherDescription"] = codeToDescription(code);
            item["weatherIcon"]        = codeToIcon(code, isNight);

            forecast.append(item);
        }

        if (m_hourlyForecast != forecast) {
            m_hourlyForecast = forecast;
            emit hourlyForecastChanged();
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WMO weather code → human-readable description
// ─────────────────────────────────────────────────────────────────────────────
QString WeatherProvider::codeToDescription(int code)
{
    if (code == 0)                return "Clear Sky";
    if (code == 1)                return "Mainly Clear";
    if (code == 2)                return "Partly Cloudy";
    if (code == 3)                return "Overcast";
    if (code == 45 || code == 48) return "Fog";
    if (code >= 51 && code <= 55) return "Drizzle";
    if (code >= 56 && code <= 57) return "Freezing Drizzle";
    if (code >= 61 && code <= 65) return "Rain";
    if (code >= 66 && code <= 67) return "Freezing Rain";
    if (code >= 71 && code <= 75) return "Snow";
    if (code == 77)               return "Snow Grains";
    if (code >= 80 && code <= 82) return "Rain Showers";
    if (code >= 85 && code <= 86) return "Snow Showers";
    if (code == 95)               return "Thunderstorm";
    if (code == 96 || code == 99) return "Thunderstorm with Hail";
    return "Unknown";
}

// ─────────────────────────────────────────────────────────────────────────────
//  WMO weather code → icon resource path
//  isNight=true selects the night variant where available.
//  To add more night icons: add the file to Resources/weather/ and add a
//  night branch here (same pattern as code == 0 below).
// ─────────────────────────────────────────────────────────────────────────────
QString WeatherProvider::codeToIcon(int code, bool isNight)
{
    const QString base = "qrc:/AvionicsClock/Resources/weather/";

    if (code == 0) {
        return isNight ? base + "night-moon.png" : base + "clear_sky.png";
    }
    // Future night variants:
    //   if (code == 1) return isNight ? base + "mainly_clear_night.png" : base + "mainly_clear.png";
    //   if (code == 2) return isNight ? base + "cloudy_night.png"        : base + "partaly_cloudy.png";

    if (code == 1)                return base + "mainly_clear.png";
    if (code == 2)                return base + "partaly_cloudy.png";  // preserves filename typo
    if (code == 3)                return base + "Overcast.png";
    if (code == 45 || code == 48) return base + "Overcast.png";
    if (code >= 51 && code <= 67) return base + "rain.png";
    if (code >= 71 && code <= 77) return base + "snow.png";
    if (code >= 80 && code <= 82) return base + "rain.png";
    if (code >= 85 && code <= 86) return base + "snow.png";
    if (code >= 95)               return base + "rain.png";

    return base + "Overcast.png";
}

// ─────────────────────────────────────────────────────────────────────────────
//  Derived getters
// ─────────────────────────────────────────────────────────────────────────────
QString WeatherProvider::currentWeatherDescription() const
{
    return codeToDescription(m_currentWeatherCode);
}

QString WeatherProvider::currentWeatherIcon() const
{
    bool isNight = false;
    QDate today = QDate::currentDate();
    if (m_sunriseSunset.contains(today)) {
        QDateTime now = QDateTime::currentDateTime();
        const QPair<QDateTime, QDateTime> &sun = m_sunriseSunset[today];
        isNight = (now < sun.first || now >= sun.second);
    }
    return codeToIcon(m_currentWeatherCode, isNight);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status helpers
// ─────────────────────────────────────────────────────────────────────────────
void WeatherProvider::setLoading(bool loading)
{
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void WeatherProvider::setError(const QString &error)
{
    qDebug() << "WeatherProvider error:" << error;
    if (m_errorString != error) {
        m_errorString = error;
        emit errorStringChanged();
    }
}

void WeatherProvider::clearError()
{
    if (!m_errorString.isEmpty()) {
        m_errorString.clear();
        emit errorStringChanged();
    }
}
