#include "FocusSession.h"
#include <QtTest>
#include <chrono>
using namespace std::chrono_literals;

class FocusSessionTests : public QObject
{
    Q_OBJECT
private slots:
    void delayedTicksCompleteOnce();
    void cancelDoesNotCelebrateAndAllowsRestart();
    void startWhileActiveDoesNotResetDeadline();
};

void FocusSessionTests::delayedTicksCompleteOnce()
{
    FocusSession session(250ms);
    QSignalSpy completed(&session, &FocusSession::completed);
    session.start();
    QVERIFY(session.active());
    QCOMPARE(session.remainingSeconds(), 1);
    QTest::qSleep(400); // Simulate a busy GUI thread missing timer ticks.
    QTRY_COMPARE_WITH_TIMEOUT(completed.count(), 1, 1000);
    QVERIFY(!session.active());
    QCOMPARE(session.remainingSeconds(), 0);
    QTest::qWait(250);
    QCOMPARE(completed.count(), 1);
}

void FocusSessionTests::cancelDoesNotCelebrateAndAllowsRestart()
{
    FocusSession session(250ms);
    QSignalSpy completed(&session, &FocusSession::completed);
    session.start();
    session.cancel();
    session.cancel();
    QVERIFY(!session.active());
    QCOMPARE(session.remainingSeconds(), 0);
    QTest::qWait(400);
    QCOMPARE(completed.count(), 0);
    session.start();
    QTRY_COMPARE_WITH_TIMEOUT(completed.count(), 1, 1500);
}

void FocusSessionTests::startWhileActiveDoesNotResetDeadline()
{
    FocusSession session(250ms);
    QSignalSpy completed(&session, &FocusSession::completed);
    session.start();
    QTest::qSleep(400);
    session.start();
    QCoreApplication::processEvents();
    QCOMPARE(completed.count(), 1);
}

QTEST_GUILESS_MAIN(FocusSessionTests)
#include "FocusSessionTests.moc"
