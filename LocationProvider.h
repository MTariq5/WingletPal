#ifndef LOCATIONPROVIDER_H
#define LOCATIONPROVIDER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QNetworkRequest>
#include <QTimer>
#include <QDebug>

class LocationProvider : public QObject
{
    Q_OBJECT

public:
    explicit LocationProvider(QObject *parent = nullptr);

    Q_PROPERTY(QString city READ getCity NOTIFY cityChanged)

    Q_PROPERTY(double latitude READ getLatitude NOTIFY locationChanged)
    Q_PROPERTY(double longitude READ getLongitude NOTIFY locationChanged)

    Q_PROPERTY(QString error READ getError NOTIFY errorChanged)

    QString getCity();
    double getLatitude();
    double getLongitude();
    QString getError();

    Q_INVOKABLE void fetchLocation();


signals:
    void cityChanged();
    void locationChanged();
    void errorChanged();

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager m_manager; //sending recieving requestes
    QString m_city;
    double m_latitude = 0.0;
    double m_longitude = 0.0;
    QString m_error;
    QTimer m_retryTimer;
    bool m_loading = false;

};

#endif // LOCATIONPROVIDER_H
