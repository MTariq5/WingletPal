#ifndef AIRCRAFT_H
#define AIRCRAFT_H

#include <QObject>
#include <QString>
#include <QMetaType>

// ============================================================================
// Aircraft
// ----------------------------------------------------------------------------
// Usage: this is the one and only "aircraft" data type in the ATD feature.
// It is a plain value — create one, fill in its fields, copy it around,
// throw it away. It has no methods and no behavior; it is not responsible
// for fetching, parsing, caching, or displaying itself.
//
//   - Created by: OpenSkyFlightSource::parseStates(), one per state-vector
//     row returned by OpenSky's /states/all endpoint.
//   - Carried by: QVector<Aircraft>, passed as the payload of
//     FlightDataSource::statesReady(const QVector<Aircraft> &).
//   - Consumed by: (Phase 4) AircraftListModel, which will read these fields
//     to populate QAbstractListModel roles, matching/updating existing rows
//     by `icao` rather than replacing the whole list on every refresh — this
//     is the whole reason the ATD feature exposes a QVector<Aircraft> here
//     instead of a QVariantList of maps (which would force a full rebuild of
//     every on-screen marker on every update).
//
// Field names/units match OpenSky's REST API docs directly
// (docs/free/states-response.rst in the openskynetwork/opensky-api repo),
// so mapping a field here back to the spec is a straight lookup, not a
// translation.
//
// Q_GADGET (not QObject): these are values copied around in a QVector, not
// identity-bearing objects that live for a while and get pointed at. Q_GADGET
// gives Qt's meta-object system (and QML, later) reflective access to the
// fields below via Q_PROPERTY, without paying for QObject's parent/child
// ownership tree or signal machinery on every single instance.
// ============================================================================
class Aircraft
{
    Q_GADGET

    Q_PROPERTY(QString icao MEMBER icao)
    Q_PROPERTY(QString callsign MEMBER callsign)
    Q_PROPERTY(double latitude MEMBER latitude)
    Q_PROPERTY(double longitude MEMBER longitude)
    Q_PROPERTY(double heading MEMBER heading)
    Q_PROPERTY(double altitude MEMBER altitude)
    Q_PROPERTY(double groundSpeed MEMBER groundSpeed)
    Q_PROPERTY(double verticalSpeed MEMBER verticalSpeed)
    Q_PROPERTY(qint64 lastUpdate MEMBER lastUpdate)
    Q_PROPERTY(bool onGround MEMBER onGround)

public:
    // icao24 hex transponder address. This is the *identity* of an aircraft
    // for our purposes — Phase 4's AircraftListModel will use this (not
    // callsign, which can repeat or be blank) to decide whether an incoming
    // state vector is an update to an existing on-screen marker or a new one.
    QString icao;

    // Callsign of the flight (e.g. "BAW71LK"), trimmed. OpenSky pads this to
    // 8 characters with spaces on the wire, and it can be an empty string if
    // no callsign has been received yet for this aircraft — callers (UI)
    // should have a fallback label (e.g. show `icao` instead) for that case.
    QString callsign;

    double  latitude = 0.0;
    double  longitude = 0.0;

    // True track: compass heading in degrees clockwise from north (0 = due
    // north). This is what a marker's rotation should bind to.
    double  heading = 0.0;

    // Barometric altitude in meters.
    double  altitude = 0.0;

    // Ground speed in meters per second.
    double  groundSpeed = 0.0;

    // Vertical rate in meters per second. Positive = climbing,
    // negative = descending.
    double  verticalSpeed = 0.0;

    // Unix timestamp (seconds) of the last update for this state vector.
    // Useful later for deciding an aircraft is "stale" and should be faded
    // out / removed from the model.
    qint64  lastUpdate = 0;

    // True if this aircraft's position was reported as a surface position
    // (i.e. it's on the ground, not airborne).
    bool    onGround = false;
};

Q_DECLARE_METATYPE(Aircraft)

#endif // AIRCRAFT_H
