#ifndef CONNECTIVITYCHECKER_H
#define CONNECTIVITYCHECKER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>

// ============================================================================
// ConnectivityChecker
// ----------------------------------------------------------------------------
// Usage: instantiated once in main.qml (id: connectivityChecker), alongside
// the app's other independent single-purpose providers (TimeDateProvider,
// LocationProvider, WeatherProvider). Its one job is answering "is there
// actually internet access right now" — not "is a network interface up",
// which a device can report while sitting behind a router with no WAN. It
// answers that the same way most OS-level captive-portal checks do: fire one
// small HTTP request at a fast, reliable endpoint and see whether it
// succeeds within a short timeout, rather than trusting any link/interface
// status flag.
//
// main.qml calls checkNow() explicitly from Component.onCompleted, matching
// LocationProvider's own onCompleted-triggered fetchLocation() — this class
// never auto-starts a check from its constructor, so it stays passive/
// testable, and the caller controls exactly when checks happen: once at
// startup, and again after a Wi-Fi connection attempt from WifiSetupPage.qml
// (or a manual "Retry" tap there).
// ============================================================================
class ConnectivityChecker : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)

public:
    explicit ConnectivityChecker(QObject *parent = nullptr);

    // True once a check has completed successfully. Starts false — main.qml
    // treats "false" as "not confirmed online yet", not "confirmed offline",
    // which is why appState gating also waits on checking() rather than
    // ever trusting online()'s startup default on its own.
    bool online() const { return m_online; }

    // True for the duration of one checkNow() call, from the moment it
    // fires the request until the reply (or timeout) resolves it.
    bool checking() const { return m_checking; }

    // Fires one connectivity probe. No-ops (silently) if a check is already
    // in flight, so a caller can call this defensively — e.g. once at
    // startup and again after a Wi-Fi connect attempt — without tracking
    // in-flight state itself.
    Q_INVOKABLE void checkNow();

signals:
    void onlineChanged();
    void checkingChanged();

    // Emitted once per checkNow() call, when it resolves one way or the
    // other (HTTP success, HTTP/network error, or timeout). online() and
    // checking() have already been updated by the time this fires.
    void checkFinished(bool online);

private slots:
    void onReplyFinished(QNetworkReply *reply);
    void onTimeout();

private:
    void setOnline(bool online);
    void setChecking(bool checking);
    void finish(bool online);

    QNetworkAccessManager m_manager;
    QTimer m_timeoutTimer;
    QNetworkReply *m_pendingReply = nullptr;

    bool m_online = false;
    bool m_checking = false;
};

#endif // CONNECTIVITYCHECKER_H
