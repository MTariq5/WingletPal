#ifndef FLIGHTTRACKERPROVIDER_H
#define FLIGHTTRACKERPROVIDER_H

#include <QObject>
#include <QTimer>
#include <QAbstractItemModel>

#include "AircraftListModel.h"
#include "FlightDataSource.h"

// ============================================================================
// FlightTrackerProvider
// ----------------------------------------------------------------------------
// Usage: the one type QML sees for the "aircraft nearby" feature — this is
// what gets qmlRegisterType'd and instantiated in AirTrafficPage.qml, e.g.:
//
//   FlightTrackerProvider {
//       id: flightTracker
//       currentLatitude: location.latitude   // reuse LocationProvider, no new logic
//       currentLongitude: location.longitude
//       active: SwipeView.isCurrentItem      // pause polling when off-screen
//   }
//   ... TrafficMap { aircraftModel: flightTracker.model } ...
//
// It performs no networking or JSON parsing itself — that's
// OpenSkyFlightSource's job, reached only through the abstract
// FlightDataSource interface (see FlightDataSource.h) so swapping providers
// later never touches this class. Its own job is purely orchestration:
//   - own a 30s repeating QTimer that (when `active`) asks the data source
//     for a fresh read;
//   - convert currentLatitude/currentLongitude + searchRadiusKm into a
//     GeoBoundingBox for each request;
//   - feed successful results into its AircraftListModel via upsert();
//   - track status/errorString so a future UI overlay (Phase 6/7) can show
//     "Traffic Unavailable" without ever having to clear the map — on
//     failure this class deliberately leaves the model untouched, so the
//     last known aircraft positions simply stay on screen.
// ============================================================================
class FlightTrackerProvider : public QObject
{
    Q_OBJECT

    // The aircraft list, exposed as a plain QAbstractItemModel* so QML can
    // bind it straight into a MapItemView/ListView's `model` property.
    // CONSTANT: the model *instance* never changes for this object's
    // lifetime (only its rows do, via upsert()), so there's no need for a
    // change signal here.
    Q_PROPERTY(QAbstractItemModel *model READ model CONSTANT)

    Q_PROPERTY(int aircraftCount READ aircraftCount NOTIFY aircraftCountChanged)
    Q_PROPERTY(double searchRadiusKm READ searchRadiusKm WRITE setSearchRadiusKm NOTIFY searchRadiusKmChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)
    Q_PROPERTY(double currentLatitude READ currentLatitude WRITE setCurrentLatitude NOTIFY currentLatitudeChanged)
    Q_PROPERTY(double currentLongitude READ currentLongitude WRITE setCurrentLongitude NOTIFY currentLongitudeChanged)

public:
    explicit FlightTrackerProvider(QObject *parent = nullptr);

    // Returns the AircraftListModel instance for QML to bind against.
    // Declared const (matching the READ property convention) even though
    // the model's *rows* are mutated elsewhere via upsert() — the pointer
    // identity itself never changes, which is the only thing "const" is
    // promising here.
    QAbstractItemModel *model() const;

    // Convenience read of model()->rowCount() — how many aircraft are
    // currently being displayed. Kept as its own property (rather than
    // making QML call model.rowCount() itself) so a future overlay can
    // bind straight to `flightTracker.aircraftCount` without touching the
    // model API at all.
    int aircraftCount() const;

    double searchRadiusKm() const { return m_searchRadiusKm; }
    void setSearchRadiusKm(double km);

    // Gates all polling. Set to true when this page becomes visible
    // (typically bound to SwipeView.isCurrentItem) to start the refresh
    // timer and fetch immediately; set to false to stop the timer
    // entirely. This is the single biggest lever for both API-credit
    // budget and CPU/battery use — there is no reason to poll OpenSky (or
    // run a 30s timer at all) while the user is looking at a different
    // page.
    bool active() const { return m_active; }
    void setActive(bool active);

    // "Ok" after the most recent request succeeded, "Unavailable" after it
    // failed. Starts as "Ok" (not "Unavailable") so the UI doesn't flash an
    // error before the very first request has even been attempted.
    QString status() const { return m_status; }

    // Human-readable detail for the most recent failure; empty when
    // status() is "Ok".
    QString errorString() const { return m_errorString; }

    double currentLatitude() const { return m_currentLatitude; }
    void setCurrentLatitude(double lat);

    double currentLongitude() const { return m_currentLongitude; }
    void setCurrentLongitude(double lon);

signals:
    void aircraftCountChanged();
    void searchRadiusKmChanged();
    void activeChanged();
    void statusChanged();
    void errorStringChanged();
    void currentLatitudeChanged();
    void currentLongitudeChanged();

private:
    // True once currentLatitude/currentLongitude hold a real fix rather
    // than the (0, 0) default LocationProvider reports before its first
    // successful lookup — mirrors the same guard AirTrafficPage.qml uses
    // for the map center, so we never query a bounding box around the
    // Gulf of Guinea on startup.
    bool hasLocationFix() const;

    void setStatus(const QString &status);
    void setErrorString(const QString &error);

    // Builds the bounding box from current state and asks m_dataSource for
    // a fresh read. No-ops (silently) if not active or no location fix yet
    // — called both from the timer's timeout() and immediately whenever
    // `active` or the current position changes, so the first fetch after
    // becoming visible (or after a location fix finally arrives) doesn't
    // have to wait up to 30s for the next timer tick.
    void refresh();

    // Connected to m_dataSource's statesReady(): merges the new batch into
    // m_model via upsert(), updates aircraftCount, and marks status "Ok".
    void onStatesReady(const QVector<Aircraft> &aircraft);

    // Connected to m_dataSource's requestFailed(): updates status/
    // errorString only. Deliberately never touches m_model — see the class
    // comment above.
    void onRequestFailed(const QString &error);

    AircraftListModel m_model;

    // Held as the abstract interface, not OpenSkyFlightSource*, even
    // though only OpenSkyFlightSource exists today — this is the one line
    // in the whole feature that would change to point at a different
    // provider. Owned via QObject parenting (constructed with `this` as
    // parent), not a smart pointer.
    FlightDataSource *m_dataSource;

    QTimer m_refreshTimer;

    double m_searchRadiusKm = 1000;
    bool m_active = false;
    QString m_status = QStringLiteral("Ok");
    QString m_errorString;

    double m_currentLatitude = 0.0;
    double m_currentLongitude = 0.0;
};

#endif // FLIGHTTRACKERPROVIDER_H
