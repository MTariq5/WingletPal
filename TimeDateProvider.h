#ifndef TIMEDATEPROVIDER_H
#define TIMEDATEPROVIDER_H

#include <QObject>
#include <QTime>
#include <QDate>
#include <QTimer>
#include <QDebug>

class TimeDateProvider : public QObject
{
    Q_OBJECT
public:
    explicit TimeDateProvider(QObject *parent = nullptr);

    QTime currentTime() const;

    void timeUpdated();

    Q_PROPERTY(int hours READ getHours NOTIFY hoursChanged)
    Q_PROPERTY(int hours12 READ getHours12 NOTIFY hours12Changed)
    Q_PROPERTY(int minutes READ getMinutes NOTIFY minuitesChanged)
    Q_PROPERTY(int seconds READ getSeconds NOTIFY secondsChanged)
    Q_PROPERTY(QString timeString READ getTimeString NOTIFY timeStringChanged)
    Q_PROPERTY(QString amPm READ getAmPm NOTIFY amPmChanged)
    Q_PROPERTY(QString date READ getDate NOTIFY dateChanged)

    int getHours() const;
    int getHours12() const;
    int getMinutes() const;
    int getSeconds() const;
    QString getTimeString() const;
    QString getAmPm() const;
    QString getDate() const;

signals:
    void timeChanged();
    void hoursChanged();
    void hours12Changed();
    void minuitesChanged();
    void secondsChanged();
    void timeStringChanged();
    void amPmChanged();
    void dateChanged();

private:
    QTimer m_timer;

    int m_hours;
    int m_hours12;
    int m_minuites;
    int m_seconds;
    QString m_ampm;

    QString m_date;
};

#endif // TIMEDATEPROVIDER_H
