#include "OpenSkyTokenManager.h"

#include <QSettings>
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

// Per OpenSky's docs (docs/free/rest.rst): the auth server is a *separate*
// host from the API itself (auth.opensky-network.org vs. opensky-network.org
// /api) — easy to get wrong by assuming one domain for everything.
const QString OpenSkyTokenManager::kTokenUrl = QStringLiteral(
    "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token");

// Constructor: loads credentials synchronously (a local file read, not a
// network call) and does nothing else. No token is fetched here — that
// only happens on the first ensureToken() call, so a manager can exist
// (e.g. as a member of OpenSkyFlightSource) without immediately hitting
// the network at app startup.
OpenSkyTokenManager::OpenSkyTokenManager(QObject *parent) : QObject(parent)
{
    loadCredentialsFromConfig();
}

// Reads [opensky]/client_id and [opensky]/client_secret from
// <repo-root>/opensky.ini. The path is fixed via the AVIONICSCLOCK_SOURCE_DIR
// compile definition (see CMakeLists.txt) rather than resolved next to the
// built .exe — so the same opensky.ini works regardless of which of the
// project's build directories/kits you're using, with nothing to copy
// per-build. Trims whitespace from both values defensively (a stray space
// after "=" in the ini file is a common copy/paste mistake). Sets
// m_hasCredentials to false (and logs a clear, actionable qWarning) if
// either value ends up empty, so every other method can rely on
// m_hasCredentials rather than re-checking the strings themselves.
void OpenSkyTokenManager::loadCredentialsFromConfig()
{
    const QString path = QStringLiteral(AVIONICSCLOCK_SOURCE_DIR) + QStringLiteral("/opensky.ini");
    QSettings settings(path, QSettings::IniFormat);

    m_clientId = settings.value(QStringLiteral("opensky/client_id")).toString().trimmed();
    m_clientSecret = settings.value(QStringLiteral("opensky/client_secret")).toString().trimmed();
    m_hasCredentials = !m_clientId.isEmpty() && !m_clientSecret.isEmpty();

    if (!m_hasCredentials) {
        qWarning() << "OpenSkyTokenManager: no credentials found at" << path
                   << "- copy opensky.ini.example to opensky.ini and fill in client_id/client_secret"
                   << "from https://opensky-network.org/my-opensky/account";
    }
}

// Synchronous, side-effect-free check: is m_token non-empty and still
// before its (early-margined) expiry? Used both by external callers
// deciding whether to expect an instant vs. asynchronous ensureToken(),
// and internally by ensureToken() itself to short-circuit a fetch.
bool OpenSkyTokenManager::hasValidToken() const
{
    return !m_token.isEmpty() && QDateTime::currentDateTimeUtc() < m_expiresAt;
}

// Returns the cached token if it's still valid, otherwise an empty string.
// Never triggers a fetch — purely a read of current state.
QString OpenSkyTokenManager::cachedToken() const
{
    return hasValidToken() ? m_token : QString();
}

// The main entry point. Three possible outcomes, in order:
//   1. No credentials configured -> emit tokenError() immediately, no
//      network activity attempted (there would be no point).
//   2. A cached token is still valid -> emit tokenReady() immediately with
//      it (no network activity).
//   3. Otherwise -> if a fetch isn't already running, POST a client-
//      credentials grant to OpenSky's auth server (form-urlencoded body:
//      grant_type/client_id/client_secret) and wire the reply's finished()
//      signal to onTokenReplyFinished(). If a fetch IS already running,
//      this call does nothing further — that in-flight request's own
//      completion will still emit tokenReady()/tokenError() for whichever
//      caller(s) are waiting on it.
void OpenSkyTokenManager::ensureToken()
{
    if (!m_hasCredentials) {
        emit tokenError(QStringLiteral("OpenSky credentials not configured (see opensky.ini.example)"));
        return;
    }

    if (hasValidToken()) {
        emit tokenReady(m_token);
        return;
    }

    if (m_fetchInFlight)
        return;

    m_fetchInFlight = true;

    QUrlQuery body;
    body.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("client_credentials"));
    body.addQueryItem(QStringLiteral("client_id"), m_clientId);
    body.addQueryItem(QStringLiteral("client_secret"), m_clientSecret);

    QNetworkRequest request{QUrl(kTokenUrl)};
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                       QStringLiteral("application/x-www-form-urlencoded"));

    QNetworkReply *reply = m_manager.post(request, body.query(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onTokenReplyFinished(reply);
    });
}

// Runs once the auth server's HTTP response has fully arrived (connected
// as a lambda on QNetworkReply::finished in ensureToken()). Always clears
// m_fetchInFlight and schedules `reply` for cleanup via deleteLater() —
// not a direct delete, since this handler is itself running as a result of
// a signal `reply` emitted; deleting it immediately here would destroy the
// object while code it triggered is still executing. On a transport-level
// error (timeout, DNS failure, ...) or a response that isn't valid JSON or
// is missing access_token, emits tokenError() with a descriptive message
// and stops. On success, stores the token and computes m_expiresAt as
// (now + expires_in - kRefreshMarginSecs), then emits tokenReady().
void OpenSkyTokenManager::onTokenReplyFinished(QNetworkReply *reply)
{
    m_fetchInFlight = false;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        const QString err = reply->errorString();
        qWarning() << "OpenSkyTokenManager: token request failed -" << err;
        emit tokenError(err);
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        emit tokenError(QStringLiteral("OpenSky token response was not valid JSON"));
        return;
    }

    const QJsonObject obj = doc.object();
    const QString accessToken = obj.value(QStringLiteral("access_token")).toString();
    if (accessToken.isEmpty()) {
        emit tokenError(QStringLiteral("OpenSky token response had no access_token"));
        return;
    }

    // Refresh a bit early (kRefreshMarginSecs) rather than exactly at the
    // documented 1800s expiry, so a request already in flight can't
    // straddle the boundary and come back with a 401.
    const int expiresIn = obj.value(QStringLiteral("expires_in")).toInt(1800);
    m_token = accessToken;
    m_expiresAt = QDateTime::currentDateTimeUtc().addSecs(qMax(0, expiresIn - kRefreshMarginSecs));

    emit tokenReady(m_token);
}
