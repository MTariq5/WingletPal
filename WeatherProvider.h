#ifndef WEATHERPROVIDER_H
#define WEATHERPROVIDER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QUrlQuery>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>
#include <QMap>
#include <QDebug>


class WeatherProvider : public QObject
{
    Q_OBJECT

    // ── Current conditions ────────────────────────────────────────────────
    Q_PROPERTY(double  currentTemperature       READ currentTemperature       NOTIFY currentWeatherChanged)
    Q_PROPERTY(int     currentWeatherCode       READ currentWeatherCode       NOTIFY currentWeatherChanged)
    Q_PROPERTY(QString currentWeatherDescription READ currentWeatherDescription NOTIFY currentWeatherChanged)
    Q_PROPERTY(QString currentWeatherIcon       READ currentWeatherIcon       NOTIFY currentWeatherChanged)
    Q_PROPERTY(double  currentWindSpeed         READ currentWindSpeed         NOTIFY currentWeatherChanged)

    // ── Hourly forecast ───────────────────────────────────────────────────
    // QVariantList of QVariantMaps.  Each map contains:
    //   "hour"               – "HH:MM" string
    //   "temperature"        – double
    //   "weatherCode"        – int
    //   "weatherDescription" – QString
    //   "weatherIcon"        – QString (qrc:// path)
    Q_PROPERTY(QVariantList hourlyForecast READ hourlyForecast NOTIFY hourlyForecastChanged)

    // ── Status ────────────────────────────────────────────────────────────
    Q_PROPERTY(bool    loading     READ isLoading   NOTIFY loadingChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit WeatherProvider(QObject *parent = nullptr);

    // ── Getters ───────────────────────────────────────────────────────────
    double       currentTemperature()        const { return m_currentTemperature; }
    int          currentWeatherCode()        const { return m_currentWeatherCode; }
    QString      currentWeatherDescription() const;   // derived from m_currentWeatherCode
    QString      currentWeatherIcon()        const;   // derived from m_currentWeatherCode + current time
    double       currentWindSpeed()          const { return m_currentWindSpeed; }
    QVariantList hourlyForecast()            const { return m_hourlyForecast; }
    bool         isLoading()                 const { return m_loading; }
    QString      errorString()               const { return m_errorString; }

    // ── Public API ────────────────────────────────────────────────────────
    Q_INVOKABLE void setLocation(double latitude, double longitude);
    Q_INVOKABLE void updateWeather();

signals:
    void currentWeatherChanged();
    void hourlyForecastChanged();
    void loadingChanged();
    void errorStringChanged();

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    static QString codeToDescription(int code);

    // isNight=true selects the night variant of the icon where available.
    // Extend night branches here as new night icons are added to Resources/weather/.
    static QString codeToIcon(int code, bool isNight = false);

    void parseResponse(const QByteArray &data);
    void setLoading(bool loading);
    void setError(const QString &error);
    void clearError();

    // ── Members ───────────────────────────────────────────────────────────
    QNetworkAccessManager m_manager;
    QTimer                m_refreshTimer;

    double m_latitude    = 0.0;
    double m_longitude   = 0.0;
    bool   m_hasLocation = false;
    int m_locationRevision = 0;

    // Current weather
    double m_currentTemperature = 0.0;
    int    m_currentWeatherCode = 0;
    double m_currentWindSpeed   = 0.0;

    // Hourly forecast (next 24 h)
    QVariantList m_hourlyForecast;

    // Sunrise/sunset per calendar date (populated from daily API block).
    // Key = date, Value = {sunrise, sunset} as local QDateTimes.
    QMap<QDate, QPair<QDateTime, QDateTime>> m_sunriseSunset;

    // Status
    bool    m_loading = false;
    QString m_errorString;
};

#endif // WEATHERPROVIDER_H
