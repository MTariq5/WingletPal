#pragma once
#include <QObject>
#include <QSettings>

class LocationProvider : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString city READ getCity NOTIFY cityChanged)
    Q_PROPERTY(double latitude READ getLatitude NOTIFY locationChanged)
    Q_PROPERTY(double longitude READ getLongitude NOTIFY locationChanged)
    Q_PROPERTY(QString error READ getError NOTIFY errorChanged)
public:
    explicit LocationProvider(QObject *parent = nullptr);
    QString getCity() const { return m_city; }
    double getLatitude() const { return m_latitude; }
    double getLongitude() const { return m_longitude; }
    QString getError() const { return m_error; }
    Q_INVOKABLE bool saveManualLocation(const QString &city, double latitude, double longitude);
    Q_INVOKABLE bool useTenthOfRamadan();
signals:
    void cityChanged();
    void locationChanged();
    void errorChanged();
private:
    static bool validLocation(const QString &city, double latitude, double longitude);
    void setError(const QString &message);
    QSettings m_settings;
    QString m_city;
    double m_latitude = 0;
    double m_longitude = 0;
    QString m_error;
};
