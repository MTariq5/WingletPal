#include "TimeDateProvider.h"

TimeDateProvider::TimeDateProvider(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &TimeDateProvider::timeUpdated);
    m_timer.start(1000); // update every second
}

void TimeDateProvider::timeUpdated(){
    /*
    qDebug() << "TIME" << QTime::currentTime().hour()
             << ":" << QTime::currentTime().minute()
             << ":" << QTime::currentTime().second();
    */

    /*
    QDate date = QDate::currentDate();
    QString formatted = date.toString("dddd, MMMM d, yyyy");
    qDebug() << "DATE" << formatted;
    */

    QTime now = QTime::currentTime();
    QDate today = QDate::currentDate();

    // HOURS
    if (m_hours != now.hour()) {
        m_hours = now.hour();
        emit hoursChanged();
    }

    // MINUTES
    if (m_minuites != now.minute()) {
        m_minuites = now.minute();
        emit minuitesChanged();
    }

    // SECONDS
    m_seconds = now.second();
    emit secondsChanged();

    //AM PM
    QTime time = QTime::currentTime();
    QString ampm = time.toString("AP");
    if(m_ampm != ampm){
        m_ampm = ampm;
        emit amPmChanged();
    }

    // TIME STRING (optional: every second)
    emit timeStringChanged();

    // DATE (changes once per day)
    QString newDate = today.toString("dddd, MMMM d, yyyy");
    if (m_date != newDate) {
        m_date = newDate;
        emit dateChanged();
    }
}

int TimeDateProvider::getHours() const {
    return m_hours;
}

int TimeDateProvider::getMinutes() const {
    return m_minuites;
}

int TimeDateProvider::getSeconds() const {
    return m_seconds;
}

QString TimeDateProvider::getTimeString() const {
    return QString("%1:%2:%3")
    .arg(m_hours, 2, 10, QChar('0'))
        .arg(m_minuites, 2, 10, QChar('0'))
        .arg(m_seconds, 2, 10, QChar('0'));
}

QString TimeDateProvider::getAmPm() const
{
    return m_ampm;
}

QString TimeDateProvider::getDate() const {
    return m_date;
}
