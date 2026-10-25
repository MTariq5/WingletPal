#ifndef WIFIMANAGERWINDOWS_H
#define WIFIMANAGERWINDOWS_H

#include "WifiManager.h"
#include <QProcess>

// ============================================================================
// WifiManagerWindows
// ----------------------------------------------------------------------------
// Usage: the Windows implementation of WifiManager, registered under the
// QML type "WifiManager" by main.cpp only when building for Windows (this
// app's dev/test platform per CLAUDE.md's build notes — the real deployment
// target is the Linux/Raspberry Pi side, WifiManagerLinux). Shells out to
// `netsh wlan` via QProcess for both scanning and connecting.
//
// Two known limitations, both inherent to this approach rather than bugs to
// fix later:
//   - `netsh wlan show networks`'s output is human-readable, tabular text,
//     *localized* to the Windows display language — parseScanOutput()'s
//     regexes are written against the English-language field names ("SSID",
//     "Signal", "Authentication") and will need adjusting (or a locale-
//     aware rewrite) on a non-English Windows install. nmcli's `-t` terse
//     mode on the Linux side has no equivalent stability problem.
//   - Joining a *new* secured network always builds its profile as
//     WPA2-Personal (PSK/AES) — the overwhelmingly common case for home/
//     small-office Wi-Fi, but not WPA3-only or enterprise (802.1X)
//     networks, which this does not support.
// ============================================================================
class WifiManagerWindows : public WifiManager
{
    Q_OBJECT

public:
    explicit WifiManagerWindows(QObject *parent = nullptr);

protected:
    void startScan() override;
    void startConnect(const QString &ssid, const QString &password) override;

private:
    static QVariantList parseScanOutput(const QString &output);
    static QString buildProfileXml(const QString &ssid, const QString &password);

    QProcess *m_scanProcess = nullptr;
    QProcess *m_connectProcess = nullptr;
};

#endif // WIFIMANAGERWINDOWS_H
