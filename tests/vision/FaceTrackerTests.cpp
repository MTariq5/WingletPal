#include "FaceTracker.h"
#include <QTest>
#include <cmath>

class FaceTrackerTests : public QObject
{
    Q_OBJECT
private slots:
    void largerNewcomerDoesNotStealTarget()
    {
        FaceTracker tracker;
        const cv::Rect2d original(0.1, 0.2, 0.2, 0.2);
        const cv::Rect2d newcomer(0.6, 0.1, 0.35, 0.35);
        const auto first = tracker.update({original}, 0);
        const auto next = tracker.update({newcomer, original}, 0.15);
        QCOMPARE(next.selectedIndex, 1);
        QCOMPARE(next.targetId, first.targetId);
        QVERIFY(cv::norm(next.measured - cv::Point2d(0.2, 0.3)) < 1e-9);
    }

    void lostTargetIsHeldThenReplacedAfterTimeout()
    {
        FaceTracker tracker;
        const cv::Rect2d original(0.1, 0.2, 0.2, 0.2);
        const cv::Rect2d newcomer(0.65, 0.2, 0.3, 0.3);
        const auto first = tracker.update({original}, 0);
        const auto missing = tracker.update({newcomer}, 0.3);
        QVERIFY(missing.valid);
        QCOMPARE(missing.selectedIndex, -1);
        QCOMPARE(missing.targetId, first.targetId);
        const auto replaced = tracker.update({newcomer}, 0.61);
        QCOMPARE(replaced.selectedIndex, 0);
        QVERIFY(replaced.targetId != first.targetId);
        QVERIFY(cv::norm(replaced.estimated - cv::Point2d(0.8, 0.35)) < 1e-9);
    }

    void shortOcclusionKeepsIdButLongOcclusionExpires()
    {
        FaceTracker tracker;
        const cv::Rect2d face(0.3, 0.3, 0.2, 0.2);
        const auto first = tracker.update({face}, 0);
        QVERIFY(tracker.update({}, 0.25).valid);
        QCOMPARE(tracker.update({face}, 0.45).targetId, first.targetId);
        QVERIFY(!tracker.update({}, 1.06).valid);
        const auto returned = tracker.update({face}, 1.2);
        QVERIFY(returned.targetId != first.targetId);
        tracker.reset();
        QVERIFY(!tracker.update({}, 0).valid);
        const auto restarted = tracker.update({face}, 0.1);
        QCOMPARE(restarted.targetId, 1);
        QVERIFY(cv::norm(restarted.estimated - restarted.measured) < 1e-9);
    }

    void kalmanReducesStationaryMeasurementJitter()
    {
        FaceTracker tracker;
        double measuredError = 0;
        double estimatedError = 0;
        for (int i = 0; i < 60; ++i) {
            const double jitter = i % 2 == 0 ? 0.012 : -0.012;
            const auto target = tracker.update({{0.4 + jitter, 0.4, 0.2, 0.2}}, i * 0.12);
            QVERIFY(target.valid);
            if (i >= 10) {
                measuredError += std::pow(target.measured.x - 0.5, 2);
                estimatedError += std::pow(target.estimated.x - 0.5, 2);
            }
        }
        QVERIFY(estimatedError < measuredError * 0.6);
    }

    void predictionUsesElapsedTimeAndExpires()
    {
        FaceTracker tracker;
        double seconds = 0;
        for (int i = 0; i < 16; ++i) {
            seconds += i % 2 == 0 ? 0.1 : 0.18;
            const auto target = tracker.update({{0.1 + 0.1 * seconds, 0.3, 0.2, 0.2}}, seconds);
            QCOMPARE(target.selectedIndex, 0);
        }
        const auto predicted = tracker.update({}, seconds + 0.3);
        QVERIFY(predicted.valid);
        QCOMPARE(predicted.selectedIndex, -1);
        QVERIFY(std::abs(predicted.predictionRemainingSeconds - 0.3) < 1e-9);
        QVERIFY(std::abs(predicted.estimated.x - (0.2 + 0.1 * (seconds + 0.3))) < 0.025);
        QVERIFY(!tracker.update({}, seconds + 0.61).valid);
    }
};

QTEST_GUILESS_MAIN(FaceTrackerTests)
#include "FaceTrackerTests.moc"
