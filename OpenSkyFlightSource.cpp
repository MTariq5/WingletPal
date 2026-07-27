#include "OpenSkyFlightSource.h"

#include <QNetworkRequest>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

const QString OpenSkyFlightSource::kStatesUrl =
    QStringLiteral("https://opensky-network.org/api/states/all");

// Constructor: connects to the internal OpenSkyTokenManager's tokenReady()/
// tokenError() signals so that whenever a token becomes available (or
// fails to), any pending request left by requestStates() gets resumed (or
// reported as failed). No network activity happens here — only once
// requestStates() is actually called.
OpenSkyFlightSource::OpenSkyFlightSource(QObject *parent) : FlightDataSource(parent)
{
    connect(&m_tokenManager, &OpenSkyTokenManager::tokenReady, this, [this](const QString &) {
        if (m_hasPendingRequest) {
            m_hasPendingRequest = false;
            performRequest(m_pendingBox);
        }
    });

    connect(&m_tokenManager, &OpenSkyTokenManager::tokenError, this, [this](const QString &err) {
        if (m_hasPendingRequest) {
            m_hasPendingRequest = false;
            emit requestFailed(QStringLiteral("OpenSky auth failed: %1").arg(err));
        }
    });
}

// See OpenSkyFlightSource.h for the full contract. In short: skips straight
// to performRequest() if a token is already cached and valid; otherwise
// remembers `box` and asks the token manager for one, letting the
// tokenReady()/tokenError() lambdas above resume (or fail) the request
// once that async call completes.
void OpenSkyFlightSource::requestStates(const GeoBoundingBox &box)
{
    if (m_tokenManager.hasValidToken()) {
        performRequest(box);
        return;
    }

    m_pendingBox = box;
    m_hasPendingRequest = true;
    m_tokenManager.ensureToken();
}

// Builds and fires the actual GET https://opensky-network.org/api/states/all
// request: `box`'s four corners become lamin/lamax/lomin/lomax query
// parameters (QUrl + QUrlQuery handle the URL-encoding), and the token
// manager's currently-cached token is attached as a raw Authorization
// header. The request is fire-and-forget from here — completion is handled
// by onStatesReplyFinished(), connected via a lambda on the reply's own
// finished() signal.
void OpenSkyFlightSource::performRequest(const GeoBoundingBox &box)
{
    QUrl url(kStatesUrl);
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("lamin"), QString::number(box.lamin, 'f', 6));
    query.addQueryItem(QStringLiteral("lamax"), QString::number(box.lamax, 'f', 6));
    query.addQueryItem(QStringLiteral("lomin"), QString::number(box.lomin, 'f', 6));
    query.addQueryItem(QStringLiteral("lomax"), QString::number(box.lomax, 'f', 6));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setRawHeader("Authorization", "Bearer " + m_tokenManager.cachedToken().toUtf8());

    QNetworkReply *reply = m_manager.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onStatesReplyFinished(reply);
    });
}

// Runs once the /states/all HTTP response has fully arrived. Always
// schedules `reply` for cleanup via deleteLater() (not a direct delete,
// since this handler is running as a result of a signal `reply` itself
// emitted). On any transport-level error, emits requestFailed() and stops
// — including a 401, which per OpenSky's own docs just means the cached
// token expired in the gap between hasValidToken() and this response
// coming back (or was invalidated early); the correct recovery is "request
// a new one and retry", which Phase 4's scheduled retry will naturally do
// on its next tick, so no special-case handling is needed here. On
// success, hands the raw bytes to parseStates() and emits statesReady().
void OpenSkyFlightSource::onStatesReplyFinished(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        emit requestFailed(reply->errorString());
        return;
    }

    const QVector<Aircraft> aircraft = parseStates(reply->readAll());
    emit statesReady(aircraft);
}

// Parses the JSON body of an OpenSky /states/all response into a
// QVector<Aircraft>. Expects a top-level object with a "states" array,
// where each element is itself an array (a "state vector") whose field
// order/units are fixed by OpenSky's spec (docs/free/states-response.rst in
// openskynetwork/opensky-api) — the indices below are a direct lookup
// against that spec, not a guess:
//   0 icao24, 1 callsign, 4 last_contact, 5 longitude, 6 latitude,
//   7 baro_altitude, 8 on_ground, 9 velocity, 10 true_track,
//   11 vertical_rate.
// Several of these fields can legitimately be JSON null (e.g. a callsign
// not yet received) — each is guarded with an isNull() check and a sane
// fallback (0 / 0.0) rather than letting toDouble()/toString() on a null
// QJsonValue produce a silently-wrong value. Rows shorter than 11 elements
// (not enough fields to be useful) and rows with an empty icao24 (no
// identity to key on) are skipped rather than included with garbage data.
QVector<Aircraft> OpenSkyFlightSource::parseStates(const QByteArray &json)
{
    QVector<Aircraft> result;

    const QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isObject())
        return result;

    const QJsonArray states = doc.object().value(QStringLiteral("states")).toArray();
    result.reserve(states.size());

    for (const QJsonValue &stateValue : states) {
        const QJsonArray row = stateValue.toArray();
        if (row.size() < 11) // need at least through true_track to be useful
            continue;

        Aircraft a;
        a.icao = row.at(0).toString();
        a.callsign = row.at(1).toString().trimmed();
        a.lastUpdate = row.at(4).isNull() ? 0 : static_cast<qint64>(row.at(4).toDouble());
        a.longitude = row.at(5).toDouble();
        a.latitude = row.at(6).toDouble();
        a.altitude = row.at(7).isNull() ? 0.0 : row.at(7).toDouble();
        a.onGround = row.at(8).toBool();
        a.groundSpeed = row.at(9).isNull() ? 0.0 : row.at(9).toDouble();
        a.heading = row.at(10).isNull() ? 0.0 : row.at(10).toDouble();
        a.verticalSpeed = (row.size() > 11 && !row.at(11).isNull()) ? row.at(11).toDouble() : 0.0;

        if (a.icao.isEmpty())
            continue;

        result.append(a);
    }

    return result;
}
