#ifndef FLIGHTDATASOURCE_H
#define FLIGHTDATASOURCE_H

#include <QObject>
#include <QVector>

#include "Aircraft.h"
#include "GeoBoundingBox.h"

// ============================================================================
// FlightDataSource
// ----------------------------------------------------------------------------
// Usage: this is an abstract interface, not something you instantiate
// directly. It is the *only* thing FlightTrackerProvider (Phase 4) knows
// about "where aircraft data comes from" — it holds a FlightDataSource
// pointer, calls requestStates() on it, and listens for statesReady()/
// requestFailed(). It has no idea the concrete implementation is OpenSky.
//
// To add a second provider later (e.g. a different flight-tracking API),
// write a new class that inherits FlightDataSource and implements
// requestStates() to emit the same two signals. Nothing above this
// interface — the model, the map, the UI — needs to change. This is the
// "program to an interface, not an implementation" pattern (a.k.a.
// dependency inversion): high-level code depends on this abstract contract,
// and concrete networking details (OpenSkyFlightSource) depend on it too,
// rather than the high-level code depending directly on OpenSky.
//
// Currently implemented by: OpenSkyFlightSource (see OpenSkyFlightSource.h).
// ============================================================================
class FlightDataSource : public QObject
{
    Q_OBJECT

public:
    // Trivial pass-through constructor — this class carries no state of its
    // own, only the contract below. `parent` follows normal QObject
    // ownership rules (if non-null, `parent` will delete this instance when
    // it itself is destroyed).
    explicit FlightDataSource(QObject *parent = nullptr) : QObject(parent) {}

    // Nothing to clean up here — subclasses own whatever resources
    // (network managers, token managers) they need to release.
    ~FlightDataSource() override = default;

    // Ask the data source to fetch aircraft currently within `box`.
    // Pure virtual: every subclass MUST implement this. Contract for
    // implementers: this call may return before the data is available
    // (implementations are expected to be asynchronous, e.g. over the
    // network) — the result must be reported later via statesReady() on
    // success or requestFailed() on failure, never returned directly.
    virtual void requestStates(const GeoBoundingBox &box) = 0;

signals:
    // Emitted by a subclass once a requestStates() call completes
    // successfully. `aircraft` is the full set of aircraft found within the
    // most recently requested bounding box (not just ones that changed).
    void statesReady(const QVector<Aircraft> &aircraft);

    // Emitted by a subclass when a requestStates() call could not be
    // completed (network error, authentication failure, malformed
    // response, ...). `errorString` is a human-readable description
    // suitable for logging or a "Traffic Unavailable" style UI message.
    void requestFailed(const QString &errorString);
};

#endif // FLIGHTDATASOURCE_H
