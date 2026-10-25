#ifndef WIFIMANAGERLINUX_H
#define WIFIMANAGERLINUX_H

#include "WifiManager.h"
#include <QProcess>

// ============================================================================
// WifiManagerLinux
// ----------------------------------------------------------------------------
// Usage: the Linux/Raspberry Pi implementation of WifiManager, registered
// under the QML type "WifiManager" by main.cpp only when NOT building for
// Windows (see CMakeLists.txt's if(WIN32) block, which picks between this
// and WifiManagerWindows). Shells out to `nmcli` — NetworkManager's CLI,
// present by default on current Raspberry Pi OS images — via QProcess for
// both scanning and connecting, so neither ever blocks the UI thread;
// QProcess reports back through its own finished() signal.
// ============================================================================
class WifiManagerLinux : public WifiManager
{
    Q_OBJECT

public:
    explicit WifiManagerLinux(QObject *parent = nullptr);

protected:
    void startScan() override;
    void startConnect(const QString &ssid, const QString &password) override;

private:
    // Parses `nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list` output (one
    // network per line, colon-separated fields, escaped colons within a
    // field spelled "\:") into the {ssid, signal, secured} list
    // WifiManager::finishScan() expects. Static/side-effect-free so it can
    // be reasoned about independent of QProcess.
    static QVariantList parseScanOutput(const QByteArray &output);

    QProcess *m_scanProcess = nullptr;
    QProcess *m_connectProcess = nullptr;
};

#endif // WIFIMANAGERLINUX_H
