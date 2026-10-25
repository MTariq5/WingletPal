#include "WifiManager.h"

WifiManager::WifiManager(QObject *parent) : QObject(parent)
{
}

void WifiManager::scanNetworks()
{
    if (m_scanning || m_connecting)
        return;

    setScanning(true);
    setStatus(QStringLiteral("Scanning"));
    setErrorString(QString());
    startScan();
}

void WifiManager::connectToNetwork(const QString &ssid, const QString &password)
{
    if (m_scanning || m_connecting)
        return;

    setConnecting(true);
    setStatus(QStringLiteral("Connecting"));
    setErrorString(QString());
    startConnect(ssid, password);
}

void WifiManager::finishScan(const QVariantList &networks)
{
    setNetworks(networks);
    setScanning(false);
    setStatus(QStringLiteral("Idle"));
    emit scanFinished();
}

void WifiManager::finishConnect(bool success, const QString &error)
{
    setConnecting(false);
    setStatus(success ? QStringLiteral("Connected") : QStringLiteral("Failed"));
    setErrorString(error);
    emit connectionResult(success, error);
}

void WifiManager::setNetworks(const QVariantList &networks)
{
    m_networks = networks;
    emit networksChanged();
}

void WifiManager::setScanning(bool scanning)
{
    if (m_scanning != scanning) {
        m_scanning = scanning;
        emit scanningChanged();
    }
}

void WifiManager::setConnecting(bool connecting)
{
    if (m_connecting != connecting) {
        m_connecting = connecting;
        emit connectingChanged();
    }
}

void WifiManager::setStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        emit statusChanged();
    }
}

void WifiManager::setErrorString(const QString &error)
{
    if (m_errorString != error) {
        m_errorString = error;
        emit errorStringChanged();
    }
}
