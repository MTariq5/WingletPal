#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QTimer>
#include <chrono>

class FocusSession : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)
public:
    explicit FocusSession(QObject *parent = nullptr);
    explicit FocusSession(std::chrono::milliseconds duration, QObject *parent = nullptr);
    bool active() const { return m_timer.isActive(); }
    int remainingSeconds() const { return m_remainingSeconds; }
    Q_INVOKABLE void start();
    Q_INVOKABLE void cancel();
signals:
    void activeChanged();
    void remainingSecondsChanged();
    void completed();
private:
    void updateRemaining();
    QTimer m_timer;
    QElapsedTimer m_elapsed;
    qint64 m_durationMs;
    int m_remainingSeconds = 0;
};
