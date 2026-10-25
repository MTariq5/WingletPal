#include "ConnectivityChecker.h"

#include <QNetworkRequest>
#include <QUrl>

namespace {
// A small, fast, highly-available endpoint used purely as an internet-
// reachability probe — not a real API dependency the way ip-api.com/
// open-meteo.com are for LocationProvider/WeatherProvider. This is the same
// "generate_204" trick Android/ChromeOS use internally for the identical
// purpose: it answers instantly with an empty 204 response, so there's no
// body to download and nothing meaningful in the payload to parse — only
// "did this request succeed at all" matters here. Firefox's equivalent
// (http://detectportal.firefox.com/success.txt) is a documented alternative
// if this one is ever blocked on a given network.
const char *kProbeUrl = "https://clients3.google.com/generate_204";
constexpr int kTimeoutMs = 4000;
}

ConnectivityChecker::ConnectivityChecker(QObject *parent) : QObject(parent)
{
    m_timeoutTimer.setSingleShot(true);
    m_timeoutTimer.setInterval(kTimeoutMs);
    connect(&m_timeoutTimer, &QTimer::timeout, this, &ConnectivityChecker::onTimeout);

    connect(&m_manager, &QNetworkAccessManager::finished,
            this, &ConnectivityChecker::onReplyFinished);
}

void ConnectivityChecker::checkNow()
{
    if (m_checking)
        return;

    setChecking(true);
    m_pendingReply = m_manager.get(QNetworkRequest(QUrl(QString::fromLatin1(kProbeUrl))));
    m_timeoutTimer.start();
}

void ConnectivityChecker::onTimeout()
{
    if (!m_pendingReply)
        return;

    // Aborting triggers onReplyFinished with an OperationCanceledError,
    // which finish(false) below treats the same as any other failure — one
    // path handles both "the server never responded" and "the server said
    // no".
    m_pendingReply->abort();
}

void ConnectivityChecker::onReplyFinished(QNetworkReply *reply)
{
    if (reply != m_pendingReply) {
        // Shouldn't happen (only one request is ever in flight at a time),
        // but a stray/unexpected reply is cleaned up rather than touched.
        reply->deleteLater();
        return;
    }

    m_timeoutTimer.stop();
    const bool succeeded = (reply->error() == QNetworkReply::NoError);
    reply->deleteLater();
    m_pendingReply = nullptr;

    finish(succeeded);
}

void ConnectivityChecker::finish(bool online)
{
    setOnline(online);
    setChecking(false);
    emit checkFinished(online);
}

void ConnectivityChecker::setOnline(bool online)
{
    if (m_online != online) {
        m_online = online;
        emit onlineChanged();
    }
}

void ConnectivityChecker::setChecking(bool checking)
{
    if (m_checking != checking) {
        m_checking = checking;
        emit checkingChanged();
    }
}
