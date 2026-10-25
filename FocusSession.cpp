#include "FocusSession.h"
#include <algorithm>

FocusSession::FocusSession(QObject *parent)
    : FocusSession(std::chrono::minutes(25), parent) {}

FocusSession::FocusSession(std::chrono::milliseconds duration, QObject *parent)
    : QObject(parent), m_durationMs(duration.count())
{
    Q_ASSERT(m_durationMs > 0);
    m_timer.setInterval(200);
    connect(&m_timer, &QTimer::timeout, this, &FocusSession::updateRemaining);
}

void FocusSession::start()
{
    if (active())
        return;
    m_elapsed.start();
    m_timer.start();
    updateRemaining();
    emit activeChanged();
}

void FocusSession::cancel()
{
    if (!active())
        return;
    m_timer.stop();
    m_remainingSeconds = 0;
    emit remainingSecondsChanged();
    emit activeChanged();
}

void FocusSession::updateRemaining()
{
    // Derive time from elapsed duration so delayed GUI ticks do not extend a session.
    const auto remainingMs = std::max<qint64>(0, m_durationMs - m_elapsed.elapsed());
    const int seconds = static_cast<int>((remainingMs + 999) / 1000);
    if (seconds != m_remainingSeconds) {
        m_remainingSeconds = seconds;
        emit remainingSecondsChanged();
    }
    if (remainingMs == 0) {
        m_timer.stop();
        emit completed();
        emit activeChanged();
    }
}
