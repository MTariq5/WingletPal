#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QVariantList>
#include <QJsonArray>

class QNetworkReply;

class CitySearch : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList results READ results NOTIFY changed)
    Q_PROPERTY(bool searching READ searching NOTIFY changed)
    Q_PROPERTY(bool searched READ searched NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit CitySearch(QObject *parent = nullptr);
    explicit CitySearch(const QUrl &endpoint, QObject *parent = nullptr);
    QVariantList results() const { return m_results; }
    bool searching() const { return m_searching; }
    bool searched() const { return m_searched; }
    QString error() const { return m_error; }
    Q_INVOKABLE void search(const QString &name);
    Q_INVOKABLE void clear();
signals:
    void changed();
private:
    enum class ReplyKind { Search, EnglishCity };
    void request(const QUrl &url, ReplyKind kind);
    void finish(QNetworkReply *reply, int revision, ReplyKind kind);
    void collectCityIds(const QByteArray &json);
    void requestNextEnglishCity();
    void collectEnglishCity(const QByteArray &json);
    void parseResults(const QByteArray &json);
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_pending;
    QUrl m_endpoint;
    QVariantList m_results;
    QString m_error;
    QStringList m_cityIds;
    QJsonArray m_englishCities;
    bool m_arabicQuery = false;
    int m_revision = 0;
    bool m_searching = false;
    bool m_searched = false;
};
