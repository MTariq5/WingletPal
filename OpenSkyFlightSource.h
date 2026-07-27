#ifndef OPENSKYFLIGHTSOURCE_H
#define OPENSKYFLIGHTSOURCE_H

#include "FlightDataSource.h"
#include "OpenSkyTokenManager.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>

// ============================================================================
// OpenSkyFlightSource
// ----------------------------------------------------------------------------
// Usage: the concrete FlightDataSource implementation that talks to
// OpenSky's /states/all and nothing else — no timers, no caching, no UI.
// To use it: construct one (optionally with a parent for ownership), connect
// to the inherited statesReady()/requestFailed() signals, then call
// requestStates(box) whenever you want a fresh read. It owns its own
// OpenSkyTokenManager internally, so callers never touch auth directly.
//
//   auto *source = new OpenSkyFlightSource(this);
//   connect(source, &FlightDataSource::statesReady, this, &MyClass::onAircraft);
//   connect(source, &FlightDataSource::requestFailed, this, &MyClass::onError);
//   source->requestStates(GeoBoundingBox::fromCenterRadius(lat, lon, radiusKm));
//
// FlightTrackerProvider (Phase 4) is the only thing meant to construct this
// class and call requestStates() on it, on a repeating schedule. For now
// (Phase 3) it's driven directly by a one-shot call from main.cpp to verify
// auth + query + parsing end to end, with no model/UI involved yet.
// ============================================================================
class OpenSkyFlightSource : public FlightDataSource
{
    Q_OBJECT

public:
    // Sets up the internal OpenSkyTokenManager and wires its tokenReady()/
    // tokenError() signals to resume whatever request is pending (see
    // requestStates()). Performs no network activity by itself.
    explicit OpenSkyFlightSource(QObject *parent = nullptr);

    // Entry point (implements FlightDataSource::requestStates). If a valid
    // token is already cached, goes straight to performRequest(box). If
    // not, stashes `box` in m_pendingBox/m_hasPendingRequest and calls
    // OpenSkyTokenManager::ensureToken() — the actual query happens later,
    // resumed from the tokenReady()/tokenError() lambda connections set up
    // in the constructor once a token is (or isn't) obtained. This
    // "stash-and-resume" shape is necessary because token acquisition is
    // asynchronous: this function cannot simply wait for it.
    void requestStates(const GeoBoundingBox &box) override;

private:
    // Builds the actual GET request: encodes `box` as lamin/lamax/lomin/
    // lomax query parameters via QUrlQuery, attaches the current token as
    // an "Authorization: Bearer ..." header, fires the request via
    // m_manager, and wires the reply's finished() signal to
    // onStatesReplyFinished(). Only ever called once a valid token is
    // known to be available (from requestStates() or the tokenReady()
    // lambda).
    void performRequest(const GeoBoundingBox &box);

    // Runs once the /states/all HTTP response has fully arrived. Schedules
    // `reply` for cleanup via deleteLater(). On a transport-level error
    // (including an expired-token 401 — see the .cpp for why that's not
    // treated specially here), emits requestFailed(). On success, hands
    // the raw response body to parseStates() and emits statesReady() with
    // the result.
    void onStatesReplyFinished(QNetworkReply *reply);

    // Pure function: takes the raw JSON bytes of an OpenSky /states/all
    // response and returns one Aircraft per valid state-vector row. Static
    // and touches no member state, which is what makes it straightforward
    // to trust/reason about (and eventually unit-test) in isolation from
    // all the networking/auth machinery around it.
    static QVector<Aircraft> parseStates(const QByteArray &json);

    static const QString kStatesUrl;

    OpenSkyTokenManager m_tokenManager;
    QNetworkAccessManager m_manager;

    // A request can arrive before we have a valid token; the box is
    // stashed here so the queued tokenReady()/tokenError() handlers know
    // what to actually query once (if) a token comes back.
    GeoBoundingBox m_pendingBox;
    bool m_hasPendingRequest = false;
};

#endif // OPENSKYFLIGHTSOURCE_H
