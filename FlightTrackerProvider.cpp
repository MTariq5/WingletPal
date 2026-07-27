#include "FlightTrackerProvider.h"

#include "OpenSkyFlightSource.h"
#include "GeoBoundingBox.h"

// Constructs the one concrete data source this feature uses today
// (OpenSkyFlightSource), parented to `this` for ownership, but stores it
// behind the abstract FlightDataSource* — everything else in this class
// only ever calls through that interface. Wires up the 30s refresh timer
// (not started yet; see setActive()) and the data source's two signals.
// No network activity happens in this constructor.
FlightTrackerProvider::FlightTrackerProvider(QObject *parent)
    : QObject(parent)
    , m_dataSource(new OpenSkyFlightSource(this))
{
    connect(m_dataSource, &FlightDataSource::statesReady,
            this, &FlightTrackerProvider::onStatesReady);
    connect(m_dataSource, &FlightDataSource::requestFailed,
            this, &FlightTrackerProvider::onRequestFailed);

    m_refreshTimer.setInterval(30000);
    connect(&m_refreshTimer, &QTimer::timeout, this, &FlightTrackerProvider::refresh);
}

QAbstractItemModel *FlightTrackerProvider::model() const
{
    return const_cast<AircraftListModel *>(&m_model);
}

int FlightTrackerProvider::aircraftCount() const
{
    return m_model.rowCount();
}

void FlightTrackerProvider::setSearchRadiusKm(double km)
{
    if (qFuzzyCompare(m_searchRadiusKm + 1.0, km + 1.0))
        return;
    m_searchRadiusKm = km;
    emit searchRadiusKmChanged();
}

// Mirrors AirTrafficPage.qml's own hasLocationFix guard: LocationProvider
// defaults both latitude and longitude to exactly 0.0 until its first
// successful ip-api.com lookup, so "both are still 0" is treated as "no
// fix yet" rather than a real position at (0, 0).
bool FlightTrackerProvider::hasLocationFix() const
{
    return m_currentLatitude != 0.0 || m_currentLongitude != 0.0;
}

void FlightTrackerProvider::setActive(bool active)
{
    if (m_active == active)
        return;

    m_active = active;
    emit activeChanged();

    if (m_active) {
        m_refreshTimer.start();
        refresh(); // fetch immediately rather than waiting up to 30s for the first tick
    } else {
        m_refreshTimer.stop();
    }
}

void FlightTrackerProvider::setCurrentLatitude(double lat)
{
    if (qFuzzyCompare(m_currentLatitude + 1.0, lat + 1.0))
        return;
    m_currentLatitude = lat;
    emit currentLatitudeChanged();

    // A location fix arriving (or changing) while this page is already
    // active shouldn't have to wait for the next timer tick either.
    if (m_active)
        refresh();
}

void FlightTrackerProvider::setCurrentLongitude(double lon)
{
    if (qFuzzyCompare(m_currentLongitude + 1.0, lon + 1.0))
        return;
    m_currentLongitude = lon;
    emit currentLongitudeChanged();

    if (m_active)
        refresh();
}

void FlightTrackerProvider::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}

void FlightTrackerProvider::setErrorString(const QString &error)
{
    if (m_errorString == error)
        return;
    m_errorString = error;
    emit errorStringChanged();
}

// The only place a request actually gets fired. Silently does nothing if
// polling is paused (`!m_active`) or there's no location fix yet — both
// are expected, ordinary states (not errors), so no status/errorString
// change happens here either; the last real status stands until an actual
// request succeeds or fails.
void FlightTrackerProvider::refresh()
{
    if (!m_active || !hasLocationFix())
        return;

    const GeoBoundingBox box =
        GeoBoundingBox::fromCenterRadius(m_currentLatitude, m_currentLongitude, m_searchRadiusKm);
    m_dataSource->requestStates(box);
}

void FlightTrackerProvider::onStatesReady(const QVector<Aircraft> &aircraft)
{
    m_model.upsert(aircraft);
    emit aircraftCountChanged();
    setStatus(QStringLiteral("Ok"));
    setErrorString(QString());
}

// Deliberately does NOT touch m_model — the last successfully-fetched
// aircraft positions stay exactly as they are, satisfying the "keep
// displaying the map and last known traffic on failure" requirement for
// free, simply by never calling anything that would clear or replace rows.
void FlightTrackerProvider::onRequestFailed(const QString &error)
{
    setStatus(QStringLiteral("Unavailable"));
    setErrorString(error);
}
