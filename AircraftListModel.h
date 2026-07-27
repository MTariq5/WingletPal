#ifndef AIRCRAFTLISTMODEL_H
#define AIRCRAFTLISTMODEL_H

#include <QAbstractListModel>
#include <QVector>

#include "Aircraft.h"

// ============================================================================
// AircraftListModel
// ----------------------------------------------------------------------------
// Usage: the single, shared list of currently-tracked aircraft. Owned by
// FlightTrackerProvider (exposed to QML via its `model` property) and
// bound directly to a MapItemView in TrafficMap.qml, which instantiates one
// AircraftMarker (via a MapQuickItem) per row.
//
// The whole reason this is a real QAbstractListModel instead of a
// QVariantList is upsert(): every ~30s refresh calls it with a fresh batch
// from OpenSky, and it updates existing rows *in place* (emitting a
// targeted dataChanged for just that row) rather than clearing and
// rebuilding the entire list. A full rebuild would destroy and recreate
// every on-screen marker every refresh, which is both wasteful and would
// make Phase 5's "animate the marker smoothly to its new position" work
// impossible — you can't animate a delegate that was just destroyed and
// replaced with a new one.
//
// Rows are matched between refreshes by `icao` (see Aircraft.h) — never by
// row position, which has no persistent meaning here.
// ============================================================================
class AircraftListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    // Role identifiers exposed to QML delegates as e.g. `model.heading`.
    // Values start at Qt::UserRole + 1 per Qt's own convention for custom
    // model roles (values below that are reserved by Qt itself).
    enum Roles {
        IcaoRole = Qt::UserRole + 1,
        CallsignRole,
        LatitudeRole,
        LongitudeRole,
        HeadingRole,
        AltitudeRole,
        GroundSpeedRole,
        VerticalSpeedRole,
        LastUpdateRole,
        OnGroundRole
    };
    Q_ENUM(Roles)

    explicit AircraftListModel(QObject *parent = nullptr);

    // Standard QAbstractListModel overrides — see the .cpp for each.
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Merges a freshly-fetched batch of aircraft into the model. For each
    // aircraft already present (matched by icao): updates its row in place
    // and emits a per-row dataChanged. For each existing row whose icao is
    // NOT present in `incoming`: removes that row (the aircraft is no
    // longer being reported — out of range, out of the query radius, or
    // simply gone quiet). For each aircraft in `incoming` not already
    // present: appends a new row. Called by FlightTrackerProvider whenever
    // a FlightDataSource::statesReady signal arrives; never called with a
    // partial/failed batch (see FlightTrackerProvider::onRequestFailed,
    // which deliberately never touches this model at all).
    void upsert(const QVector<Aircraft> &incoming);

private:
    QVector<Aircraft> m_aircraft;
};

#endif // AIRCRAFTLISTMODEL_H
