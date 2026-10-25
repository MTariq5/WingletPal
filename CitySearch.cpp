#include "CitySearch.h"
#include <QNetworkReply>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <cmath>
#include <algorithm>

namespace {
bool containsArabic(const QString &text)
{
    return std::any_of(text.cbegin(), text.cend(), [](QChar ch) {
        return ch.script() == QChar::Script_Arabic;
    });
}
}

CitySearch::CitySearch(QObject *parent)
    : CitySearch(QUrl("https://geocoding-api.open-meteo.com/v1/search"), parent) {}

CitySearch::CitySearch(const QUrl &endpoint, QObject *parent)
    : QObject(parent), m_endpoint(endpoint) {}

void CitySearch::clear()
{
    ++m_revision;
    if (m_pending)
        m_pending->abort();
    m_pending.clear();
    m_results.clear();
    m_cityIds.clear();
    m_englishCities = {};
    m_error.clear();
    m_searching = false;
    m_searched = false;
    emit changed();
}

void CitySearch::search(const QString &name)
{
    clear();
    if (name.trimmed().size() < 2) {
        m_error = tr("Enter at least two characters.");
        emit changed();
        return;
    }
    m_arabicQuery = containsArabic(name);
    QUrl url(m_endpoint);
    QUrlQuery query;
    query.addQueryItem("name", name.trimmed());
    query.addQueryItem("count", "10");
    query.addQueryItem("language", m_arabicQuery ? "ar" : "en");
    url.setQuery(query);
    m_searching = m_searched = true;
    request(url, ReplyKind::Search);
    emit changed();
}

void CitySearch::request(const QUrl &url, ReplyKind kind)
{
    QNetworkRequest request(url);
    request.setTransferTimeout(15000);
    auto *reply = m_network.get(request);
    m_pending = reply;
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, revision = m_revision, kind] { finish(reply, revision, kind); });
}

void CitySearch::finish(QNetworkReply *reply, int revision, ReplyKind kind)
{
    reply->deleteLater();
    if (revision != m_revision)
        return;
    m_pending.clear();
    if (reply->error() != QNetworkReply::NoError)
        m_error = tr("City search failed. Check your connection and try again.");
    else if (kind == ReplyKind::EnglishCity)
        collectEnglishCity(reply->readAll());
    else if (m_arabicQuery)
        collectCityIds(reply->readAll());
    else
        parseResults(reply->readAll());
    m_searching = !m_pending.isNull();
    emit changed();
}

void CitySearch::collectCityIds(const QByteArray &json)
{
    const auto document = QJsonDocument::fromJson(json);
    const auto response = document.object();
    if (!document.isObject() || response.value("error").toBool()
        || (response.contains("results") && !response.value("results").isArray())) {
        m_error = tr("The city search service returned an invalid response.");
        return;
    }
    for (const auto &entry : response.value("results").toArray()) {
        const int id = entry.toObject().value("id").toInt();
        if (id > 0 && !m_cityIds.contains(QString::number(id)))
            m_cityIds.append(QString::number(id));
    }
    requestNextEnglishCity();
}

void CitySearch::requestNextEnglishCity()
{
    if (m_cityIds.isEmpty()) {
        parseResults(QJsonDocument(QJsonObject{{"results", m_englishCities}}).toJson());
        return;
    }
    QUrl url = m_endpoint.resolved(QUrl("get"));
    QUrlQuery query;
    query.addQueryItem("id", m_cityIds.takeFirst());
    query.addQueryItem("language", "en");
    url.setQuery(query);
    request(url, ReplyKind::EnglishCity);
}

void CitySearch::collectEnglishCity(const QByteArray &json)
{
    const auto document = QJsonDocument::fromJson(json);
    if (!document.isObject() || document.object().value("error").toBool()) {
        m_error = tr("Could not retrieve English city names. Please try again.");
        return;
    }
    m_englishCities.append(document.object());
    requestNextEnglishCity();
}

void CitySearch::parseResults(const QByteArray &json)
{
    const auto document = QJsonDocument::fromJson(json);
    const auto response = document.object();
    if (!document.isObject() || response.value("error").toBool()
        || (response.contains("results") && !response.value("results").isArray())) {
        m_error = tr("The city search service returned an invalid response.");
        return;
    }
    for (const auto &entry : response.value("results").toArray()) {
        const auto city = entry.toObject();
        if (containsArabic(city.value("name").toString())
            || containsArabic(city.value("admin1").toString())
            || containsArabic(city.value("country").toString())) {
            m_error = tr("English names are unavailable for this result. Try another spelling.");
            continue;
        }
        const double latitude = city.value("latitude").toDouble(qQNaN());
        const double longitude = city.value("longitude").toDouble(qQNaN());
        if (city.value("name").toString().trimmed().isEmpty()
            || !std::isfinite(latitude) || !std::isfinite(longitude)
            || std::abs(latitude) > 90 || std::abs(longitude) > 180)
            continue;
        m_results.append(QVariantMap{{"name", city.value("name").toString()},
                                     {"region", city.value("admin1").toString()},
                                     {"country", city.value("country").toString()},
                                     {"latitude", latitude}, {"longitude", longitude}});
    }
}
