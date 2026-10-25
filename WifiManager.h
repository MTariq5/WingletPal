#ifndef WIFIMANAGER_H
#define WIFIMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantList>

// ============================================================================
// WifiManager
// ----------------------------------------------------------------------------
// Usage: the one Wi-Fi type QML sees — instantiated once in main.qml as
// `wifiManager`, read by WifiSetupPage.qml when ConnectivityChecker reports
// no internet at startup. Scans for nearby networks and joins one by SSID +
// password.
//
// Unlike every other provider in this app, there is no single cross-
// platform implementation possible here: Qt/QML has no built-in API to scan
// or join Wi-Fi networks (unlike the plain HTTP calls LocationProvider/
// WeatherProvider/ConnectivityChecker make, which behave identically on any
// OS). This class is therefore abstract — it owns all the QML-facing state
// (networks/scanning/connecting/status/errorString) and the two public
// entry points below, but defers the actual "how" to startScan()/
// startConnect(), each implemented exactly once by:
//   - WifiManagerLinux   — shells out to `nmcli` (NetworkManager's CLI,
//     present by default on current Raspberry Pi OS — this app's real
//     deployment target).
//   - WifiManagerWindows — shells out to `netsh wlan` (this app's dev/test
//     platform per CLAUDE.md's build notes).
// main.cpp registers whichever one matches the build platform under the
// same QML type name ("WifiManager") via #ifdef Q_OS_WIN — the same
// "swap the concrete class, keep the interface" pattern this codebase
// already uses for FlightDataSource/OpenSkyFlightSource. WifiSetupPage.qml
// never knows or cares which subclass it's actually talking to.
// ============================================================================
class WifiManager : public QObject
{
    Q_OBJECT

    // Each entry: {ssid: string, signal: int (0-100), secured: bool}.
    Q_PROPERTY(QVariantList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool connecting READ connecting NOTIFY connectingChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit WifiManager(QObject *parent = nullptr);

    QVariantList networks() const { return m_networks; }
    bool scanning() const { return m_scanning; }
    bool connecting() const { return m_connecting; }
    QString status() const { return m_status; }
    QString errorString() const { return m_errorString; }

    // Starts an async scan for nearby networks (delegates to startScan()).
    // No-ops if a scan or a connect attempt is already running, so
    // WifiSetupPage's "Rescan" button can be tapped repeatedly without
    // needing to track in-flight state itself.
    Q_INVOKABLE void scanNetworks();

    // Starts an async connection attempt to `ssid` using `password`
    // (delegates to startConnect(); pass an empty password for an open
    // network). Same no-op-if-busy guard as scanNetworks().
    Q_INVOKABLE void connectToNetwork(const QString &ssid, const QString &password);

signals:
    void networksChanged();
    void scanningChanged();
    void connectingChanged();
    void statusChanged();
    void errorStringChanged();

    void scanFinished();
    void connectionResult(bool success, const QString &error);

protected:
    // Called by a platform subclass once its scan/connect attempt actually
    // finishes — the public entry points above only set the busy flags and
    // hand off to startScan()/startConnect(); these two report the outcome
    // back through the shared signals every caller listens to, so neither
    // subclass has to duplicate that bookkeeping.
    void finishScan(const QVariantList &networks);
    void finishConnect(bool success, const QString &error);

private:
    // Implemented once per platform (WifiManagerLinux/WifiManagerWindows).
    // Each must eventually call finishScan()/finishConnect() above,
    // asynchronously, once its QProcess-based scan/connect completes.
    virtual void startScan() = 0;
    virtual void startConnect(const QString &ssid, const QString &password) = 0;

    void setNetworks(const QVariantList &networks);
    void setScanning(bool scanning);
    void setConnecting(bool connecting);
    void setStatus(const QString &status);
    void setErrorString(const QString &error);

    QVariantList m_networks;
    bool m_scanning = false;
    bool m_connecting = false;
    QString m_status = QStringLiteral("Idle");
    QString m_errorString;
};

#endif // WIFIMANAGER_H
