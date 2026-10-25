#include "WifiManagerLinux.h"

#include <QSet>
#include <QStringList>
#include <QVariantMap>

WifiManagerLinux::WifiManagerLinux(QObject *parent) : WifiManager(parent)
{
}

void WifiManagerLinux::startScan()
{
    if (m_scanProcess) {
        m_scanProcess->deleteLater();
        m_scanProcess = nullptr;
    }

    m_scanProcess = new QProcess(this);

    // -t (terse, colon-separated, script-friendly) with an explicit field
    // list keeps the output format stable across nmcli versions, unlike its
    // human-readable table layout. --rescan yes forces a fresh over-the-air
    // scan rather than nmcli's cached list, which can be stale by the time
    // a user actually opens this page.
    const QStringList args = {
        QStringLiteral("-t"),
        QStringLiteral("-f"), QStringLiteral("SSID,SIGNAL,SECURITY"),
        QStringLiteral("dev"), QStringLiteral("wifi"), QStringLiteral("list"),
        QStringLiteral("--rescan"), QStringLiteral("yes")
    };

    connect(m_scanProcess, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus) {
        const QByteArray output = m_scanProcess->readAllStandardOutput();
        m_scanProcess->deleteLater();
        m_scanProcess = nullptr;

        // A failed scan still resolves finishScan(), just with an empty
        // list, rather than leaving `scanning` stuck true — WifiSetupPage
        // can tell "no networks found" apart from "still scanning" via the
        // scanning property either way.
        finishScan(exitCode == 0 ? parseScanOutput(output) : QVariantList());
    });

    m_scanProcess->start(QStringLiteral("nmcli"), args);
}

void WifiManagerLinux::startConnect(const QString &ssid, const QString &password)
{
    if (m_connectProcess) {
        m_connectProcess->deleteLater();
        m_connectProcess = nullptr;
    }

    m_connectProcess = new QProcess(this);

    QStringList args = {
        QStringLiteral("dev"), QStringLiteral("wifi"), QStringLiteral("connect"), ssid
    };
    if (!password.isEmpty()) {
        args << QStringLiteral("password") << password;
    }

    connect(m_connectProcess, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus) {
        const QByteArray stderrOutput = m_connectProcess->readAllStandardError();
        m_connectProcess->deleteLater();
        m_connectProcess = nullptr;

        const bool success = (exitCode == 0);
        finishConnect(success, success ? QString() : QString::fromUtf8(stderrOutput).trimmed());
    });

    m_connectProcess->start(QStringLiteral("nmcli"), args);
}

QVariantList WifiManagerLinux::parseScanOutput(const QByteArray &output)
{
    QVariantList result;
    QSet<QString> seenSsids;

    const QList<QByteArray> lines = output.split('\n');
    for (const QByteArray &lineBytes : lines) {
        const QString line = QString::fromUtf8(lineBytes).trimmed();
        if (line.isEmpty())
            continue;

        // nmcli -t escapes a literal colon within a field as "\:", so a
        // naive split(':') would break on any SSID that happens to contain
        // one — uncommon but real. Splitting only on colons *not* preceded
        // by a backslash keeps those intact, un-escaping "\:" back to ":"
        // per field as it goes.
        QStringList fields;
        QString current;
        for (int i = 0; i < line.length(); ++i) {
            if (line[i] == QLatin1Char('\\') && i + 1 < line.length() && line[i + 1] == QLatin1Char(':')) {
                current += QLatin1Char(':');
                ++i;
            } else if (line[i] == QLatin1Char(':')) {
                fields << current;
                current.clear();
            } else {
                current += line[i];
            }
        }
        fields << current;

        if (fields.size() < 3)
            continue;

        const QString ssid = fields.at(0);
        if (ssid.isEmpty() || seenSsids.contains(ssid))
            continue; // Same AP can appear once per band/channel — first hit wins.
        seenSsids.insert(ssid);

        const int signalStrength = fields.at(1).toInt();
        const bool secured = !fields.at(2).isEmpty() && fields.at(2) != QStringLiteral("--");

        QVariantMap entry;
        entry[QStringLiteral("ssid")] = ssid;
        entry[QStringLiteral("signal")] = signalStrength;
        entry[QStringLiteral("secured")] = secured;
        result << entry;
    }

    return result;
}
