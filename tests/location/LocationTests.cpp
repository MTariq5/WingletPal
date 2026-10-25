#include "LocationProvider.h"
#include <QtTest>
#include <QTemporaryDir>
#include <limits>

class LocationTests : public QObject {
    Q_OBJECT
private slots:
    void savedLocationSurvivesRecreation();
    void previousArabicPresetKeepsCoordinatesWhenRenamed();
    void invalidCoordinatesPreserveSavedLocation();
};

void LocationTests::savedLocationSurvivesRecreation()
{
    QTemporaryDir folder;
    QVERIFY(folder.isValid());
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, folder.path());
    {
        LocationProvider location;
        QCOMPARE(location.getLatitude(), 30.306503);
        QSignalSpy updated(&location, &LocationProvider::locationChanged);
        QVERIFY(location.saveManualLocation("  Test city  ", 30.31, 31.74));
        QCOMPARE(updated.count(), 1);
    }
    LocationProvider restored;
    QCOMPARE(restored.getCity(), QString("Test city"));
    QCOMPARE(restored.getLatitude(), 30.31);
    QCOMPARE(restored.getLongitude(), 31.74);
    QVERIFY(restored.useTenthOfRamadan());
    LocationProvider preset;
    QCOMPARE(preset.getLongitude(), 31.741455);
}

void LocationTests::previousArabicPresetKeepsCoordinatesWhenRenamed()
{
    QTemporaryDir folder;
    QVERIFY(folder.isValid());
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, folder.path());
    QSettings settings(QSettings::IniFormat, QSettings::UserScope, "AvionicsClock", "Location");
    settings.setValue("city", QString::fromUtf8("العاشر من رمضان"));
    settings.setValue("latitude", 30.3);
    settings.setValue("longitude", 31.75);
    settings.sync();
    LocationProvider migrated;
    QCOMPARE(migrated.getCity(), QString("10th of Ramadan City"));
    QCOMPARE(migrated.getLatitude(), 30.3);
    QCOMPARE(migrated.getLongitude(), 31.75);
    LocationProvider restored;
    QCOMPARE(restored.getCity(), migrated.getCity());
}

void LocationTests::invalidCoordinatesPreserveSavedLocation()
{
    QTemporaryDir folder;
    QVERIFY(folder.isValid());
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, folder.path());
    LocationProvider location;
    QVERIFY(!location.saveManualLocation(" ", 30, 31));
    QVERIFY(!location.saveManualLocation("Invalid", 91, 31));
    QVERIFY(!location.saveManualLocation("Invalid", 30, -181));
    QVERIFY(!location.saveManualLocation("Invalid", std::numeric_limits<double>::quiet_NaN(), 31));
    QVERIFY(!location.getError().isEmpty());
    LocationProvider restored;
    QCOMPARE(restored.getLatitude(), 30.306503);
    QCOMPARE(restored.getLongitude(), 31.741455);
}
QTEST_GUILESS_MAIN(LocationTests)
#include "LocationTests.moc"
