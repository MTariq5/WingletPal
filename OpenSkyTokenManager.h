#ifndef OPENSKYTOKENMANAGER_H
#define OPENSKYTOKENMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QDateTime>

// ============================================================================
// OpenSkyTokenManager
// ----------------------------------------------------------------------------
// Usage: owns the OAuth2 client-credentials lifecycle against OpenSky's
// auth server — nothing else. It does not know about /states/all, bounding
// boxes, or aircraft. A caller (currently only OpenSkyFlightSource) that
// needs an Authorization header:
//
//   1. Calls ensureToken().
//   2. Listens for tokenReady(token) (use it as the Bearer token) or
//      tokenError(errorString) (the fetch/config failed — surface it,
//      don't retry in a tight loop).
//   3. Can check hasValidToken()/cachedToken() synchronously at any time,
//      e.g. to skip calling ensureToken() entirely when a cached token is
//      still good.
//
// This class fetches/refreshes as needed; callers never see the difference
// between "reused a cached token" and "did a fresh network round-trip" —
// both surface via the same tokenReady() signal.
//
// Credentials are loaded once at construction from a local, gitignored
// config file (<repo-root>/opensky.ini — see opensky.ini.example) via
// QSettings, never hardcoded and never passed through QML. If the file is
// missing or the keys are empty, this manager stays in a permanent
// "no credentials" state and reports a clear error instead of attempting
// requests with blank credentials.
// ============================================================================
class OpenSkyTokenManager : public QObject
{
    Q_OBJECT

public:
    // Constructs the manager and immediately attempts to load client_id/
    // client_secret from opensky.ini (see loadCredentialsFromConfig()).
    // Does not perform any network activity yet — that only happens once
    // ensureToken() is called.
    explicit OpenSkyTokenManager(QObject *parent = nullptr);

    // True once client_id/client_secret were found (non-empty) in the
    // config file. Does NOT mean a token has been successfully fetched yet —
    // use hasValidToken() for that. Mainly useful for an early, synchronous
    // "is this even configured?" check before bothering to call ensureToken().
    bool hasCredentials() const { return m_hasCredentials; }

    // True if a previously-fetched token exists and is not yet within
    // kRefreshMarginSecs of expiring. Callers can use this to decide
    // whether calling ensureToken() will resolve instantly (cached) or
    // trigger a real network request.
    bool hasValidToken() const;

    // Returns the current token if hasValidToken() is true, otherwise an
    // empty string. This is a synchronous, no-side-effects read — it never
    // triggers a fetch. Use ensureToken() to actually obtain/refresh one.
    QString cachedToken() const;

    // Kicks off a token fetch (or reuses a still-valid cached one) and
    // reports the result via tokenReady()/tokenError() — never returns the
    // token directly, since a fetch may need to happen first. Safe to call
    // repeatedly: if a fetch is already in flight, this is a no-op (the
    // in-flight fetch's result will still reach every caller via the
    // signal); if credentials are missing, it fails fast with tokenError()
    // instead of attempting a request that could only ever fail.
    void ensureToken();

signals:
    // Emitted once a valid token is available — either because one was
    // already cached, or because a fetch just completed successfully.
    void tokenReady(const QString &token);

    // Emitted when a token could not be obtained: missing/empty
    // credentials, a network-level failure, or a malformed/incomplete
    // response from the auth server. `errorString` is human-readable.
    void tokenError(const QString &errorString);

private:
    // Reads client_id/client_secret from <repo-root>/opensky.ini via
    // QSettings and sets m_hasCredentials accordingly. Called once, from
    // the constructor. Logs a qWarning() (with a pointer to
    // opensky.ini.example) if the file is missing or the keys are empty,
    // rather than failing silently.
    void loadCredentialsFromConfig();

    // Slot-like handler (invoked from a lambda connected to the reply's
    // finished() signal in ensureToken()) that parses the auth server's
    // JSON response, extracts access_token/expires_in, updates m_token/
    // m_expiresAt on success, and emits tokenReady() or tokenError()
    // accordingly. Always takes ownership of cleaning up `reply` via
    // deleteLater().
    void onTokenReplyFinished(QNetworkReply *reply);

    static const QString kTokenUrl;
    // Refresh this many seconds before the token's actual expiry, so a
    // request already in flight can never straddle the boundary and hit a
    // just-expired token.
    static const int kRefreshMarginSecs = 60;

    QNetworkAccessManager m_manager;

    QString m_clientId;
    QString m_clientSecret;
    bool m_hasCredentials = false;

    QString m_token;
    QDateTime m_expiresAt;
    bool m_fetchInFlight = false;
};

#endif // OPENSKYTOKENMANAGER_H
