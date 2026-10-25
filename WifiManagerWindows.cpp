#include "WifiManagerWindows.h"

#include <QDir>
#include <QRegularExpression>
#include <QTemporaryFile>

WifiManagerWindows::WifiManagerWindows(QObject *parent) : WifiManager(parent)
{
}

void WifiManagerWindows::startScan()
{
    if (m_scanProcess) {
        m_scanProcess->deleteLater();
        m_scanProcess = nullptr;
    }

    m_scanProcess = new QProcess(this);

    connect(m_scanProcess, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus) {
        const QString output = QString::fromLocal8Bit(m_scanProcess->readAllStandardOutput());
        m_scanProcess->deleteLater();
        m_scanProcess = nullptr;

        finishScan(exitCode == 0 ? parseScanOutput(output) : QVariantList());
    });

    m_scanProcess->start(QStringLiteral("netsh"),
                          {QStringLiteral("wlan"), QStringLiteral("show"),
                           QStringLiteral("networks"), QStringLiteral("mode=bssid")});
}

void WifiManagerWindows::startConnect(const QString &ssid, const QString &password)
{
    if (m_connectProcess) {
        m_connectProcess->deleteLater();
        m_connectProcess = nullptr;
    }

    // netsh has no direct "connect with this SSID/password" command for a
    // brand-new network — it only connects to a *profile* Windows already
    // knows about. So: write a temporary profile XML for this SSID/
    // password, register it (`netsh wlan add profile`), then connect by
    // name as a second step once that succeeds. autoRemove defaults to
    // true on QTemporaryFile, so the file is deleted from disk as soon as
    // this object is — it only needs to survive long enough for
    // `add profile` to read it; the profile itself, once added, is stored
    // by Windows independently of this file.
    auto *profileFile = new QTemporaryFile(
        QDir::tempPath() + QStringLiteral("/avionicsclock-wifi-XXXXXX.xml"), this);

    if (!profileFile->open()) {
        profileFile->deleteLater();
        finishConnect(false, QStringLiteral("Could not create Wi-Fi profile file"));
        return;
    }
    profileFile->write(buildProfileXml(ssid, password).toUtf8());
    profileFile->close();

    const QString profilePath = profileFile->fileName();

    m_connectProcess = new QProcess(this);

    connect(m_connectProcess, &QProcess::finished, this,
            [this, ssid, profileFile](int exitCode, QProcess::ExitStatus) {
        const QByteArray addProfileStderr = m_connectProcess->readAllStandardError();
        m_connectProcess->deleteLater();
        m_connectProcess = nullptr;
        profileFile->deleteLater(); // Done with the temp file either way.

        if (exitCode != 0) {
            finishConnect(false, QString::fromLocal8Bit(addProfileStderr).trimmed());
            return;
        }

        // Second step: the profile is registered, now actually connect. A
        // fresh QProcess rather than reusing m_connectProcess, since that
        // one just finished — QProcess instances aren't meant to be
        // restarted with new arguments mid-callback.
        auto *connectStep = new QProcess(this);
        connect(connectStep, &QProcess::finished, this,
                [this, connectStep](int connectExitCode, QProcess::ExitStatus) {
            const QByteArray connectStderr = connectStep->readAllStandardError();
            connectStep->deleteLater();

            const bool success = (connectExitCode == 0);
            finishConnect(success, success ? QString() : QString::fromLocal8Bit(connectStderr).trimmed());
        });
        connectStep->start(QStringLiteral("netsh"),
                            {QStringLiteral("wlan"), QStringLiteral("connect"),
                             QStringLiteral("name=") + ssid});
    });

    m_connectProcess->start(QStringLiteral("netsh"),
                            {QStringLiteral("wlan"), QStringLiteral("add"), QStringLiteral("profile"),
                             QStringLiteral("filename=") + profilePath});
}

QVariantList WifiManagerWindows::parseScanOutput(const QString &output)
{
    // netsh groups its output by SSID block, e.g.:
    //   SSID 1 : MyNetwork
    //        Network type            : Infrastructure
    //        Authentication          : WPA2-Personal
    //        Encryption              : CCMP
    //        BSSID 1                 : xx:xx:xx:xx:xx:xx
    //             Signal             : 87%
    // Parsed line-by-line rather than with one big regex, since a network
    // can list multiple BSSIDs (one per radio/band), each with its own
    // Signal line — only the SSID/Authentication lines and the *first*
    // Signal line per SSID block are kept, so one entry comes out per SSID
    // rather than one per BSSID.
    QVariantList result;
    QString currentSsid;
    QString currentAuth;
    bool haveSignalForCurrent = false;

    static const QRegularExpression ssidLine(QStringLiteral("^SSID \\d+ : (.*)$"));
    static const QRegularExpression authLine(QStringLiteral("^Authentication\\s*: (.*)$"));
    static const QRegularExpression signalLine(QStringLiteral("^Signal\\s*: (\\d+)%$"));

    const QStringList lines = output.split(QStringLiteral("\n"));
    for (const QString &rawLine : lines) {
        const QString line = rawLine.trimmed();

        const auto ssidMatch = ssidLine.match(line);
        if (ssidMatch.hasMatch()) {
            currentSsid = ssidMatch.captured(1).trimmed();
            currentAuth.clear();
            haveSignalForCurrent = false;
            continue;
        }

        const auto authMatch = authLine.match(line);
        if (authMatch.hasMatch() && !currentSsid.isEmpty()) {
            currentAuth = authMatch.captured(1).trimmed();
            continue;
        }

        const auto signalMatch = signalLine.match(line);
        if (signalMatch.hasMatch() && !currentSsid.isEmpty() && !haveSignalForCurrent) {
            haveSignalForCurrent = true;

            QVariantMap entry;
            entry[QStringLiteral("ssid")] = currentSsid;
            entry[QStringLiteral("signal")] = signalMatch.captured(1).toInt();
            entry[QStringLiteral("secured")] =
                currentAuth.compare(QStringLiteral("Open"), Qt::CaseInsensitive) != 0;
            result << entry;
        }
    }

    return result;
}

QString WifiManagerWindows::buildProfileXml(const QString &ssid, const QString &password)
{
    // XML-escaping the SSID/password: names or passphrases containing '&',
    // '<', '>', '"' would otherwise produce invalid XML. Qt has no built-in
    // "escape for XML text content" helper, so this is spelled out
    // explicitly rather than pulling in a full XML library for two
    // attributes.
    auto escape = [](QString s) {
        s.replace(QLatin1Char('&'), QStringLiteral("&amp;"));
        s.replace(QLatin1Char('<'), QStringLiteral("&lt;"));
        s.replace(QLatin1Char('>'), QStringLiteral("&gt;"));
        s.replace(QLatin1Char('"'), QStringLiteral("&quot;"));
        return s;
    };

    const QString escapedSsid = escape(ssid);

    QString security;
    if (password.isEmpty()) {
        security = QStringLiteral(
            "<authEncryption>"
            "<authentication>open</authentication>"
            "<encryption>none</encryption>"
            "<useOneX>false</useOneX>"
            "</authEncryption>");
    } else {
        // WPA2-Personal (PSK/AES) — see this class's header comment for
        // why this is the one security type supported for new profiles.
        security = QStringLiteral(
            "<authEncryption>"
            "<authentication>WPA2PSK</authentication>"
            "<encryption>AES</encryption>"
            "<useOneX>false</useOneX>"
            "</authEncryption>"
            "<sharedKey>"
            "<keyType>passPhrase</keyType>"
            "<protected>false</protected>"
            "<keyMaterial>%1</keyMaterial>"
            "</sharedKey>").arg(escape(password));
    }

    return QStringLiteral(
        "<?xml version=\"1.0\"?>"
        "<WLANProfile xmlns=\"http://www.microsoft.com/networking/WLAN/profile/v1\">"
        "<name>%1</name>"
        "<SSIDConfig><SSID><name>%1</name></SSID></SSIDConfig>"
        "<connectionType>ESS</connectionType>"
        "<connectionMode>manual</connectionMode>"
        "<MSM><security>%2</security></MSM>"
        "</WLANProfile>").arg(escapedSsid, security);
}
