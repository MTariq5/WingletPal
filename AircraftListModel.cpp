#include "AircraftListModel.h"

#include <QHash>
#include <QSet>

AircraftListModel::AircraftListModel(QObject *parent) : QAbstractListModel(parent)
{
}

int AircraftListModel::rowCount(const QModelIndex &parent) const
{
    // Per QAbstractListModel convention: a valid parent means someone asked
    // for the row count of a child of one of our rows, which doesn't apply
    // to a flat list model — always 0 in that case.
    if (parent.isValid())
        return 0;
    return m_aircraft.size();
}

QVariant AircraftListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_aircraft.size())
        return QVariant();

    const Aircraft &a = m_aircraft.at(index.row());
    switch (role) {
    case IcaoRole:          return a.icao;
    case CallsignRole:      return a.callsign;
    case LatitudeRole:      return a.latitude;
    case LongitudeRole:     return a.longitude;
    case HeadingRole:       return a.heading;
    case AltitudeRole:      return a.altitude;
    case GroundSpeedRole:   return a.groundSpeed;
    case VerticalSpeedRole: return a.verticalSpeed;
    case LastUpdateRole:    return a.lastUpdate;
    case OnGroundRole:      return a.onGround;
    default:                return QVariant();
    }
}

QHash<int, QByteArray> AircraftListModel::roleNames() const
{
    return {
        { IcaoRole,          "icao" },
        { CallsignRole,      "callsign" },
        { LatitudeRole,      "latitude" },
        { LongitudeRole,     "longitude" },
        { HeadingRole,       "heading" },
        { AltitudeRole,      "altitude" },
        { GroundSpeedRole,   "groundSpeed" },
        { VerticalSpeedRole, "verticalSpeed" },
        { LastUpdateRole,    "lastUpdate" },
        { OnGroundRole,      "onGround" }
    };
}

// See AircraftListModel.h for the full contract. Implementation is three
// straightforward passes rather than one clever one, favoring "obviously
// correct" over "obviously fast" — at the scale this model actually runs
// at (tens, occasionally low hundreds of aircraft, refreshed every ~30s),
// none of this is remotely performance-sensitive; a bug in the row
// bookkeeping (e.g. an off-by-one in which row gets removed) would be far
// more costly than a few extra QHash/QSet builds.
void AircraftListModel::upsert(const QVector<Aircraft> &incoming)
{
    // Index the incoming batch by icao once, up front, so every lookup
    // below is O(1) instead of an O(n) scan through `incoming`.
    QHash<QString, Aircraft> incomingByIcao;
    incomingByIcao.reserve(incoming.size());
    for (const Aircraft &a : incoming)
        incomingByIcao.insert(a.icao, a);

    // Pass 1 — update rows that are still present in this batch. Emits a
    // dataChanged for just that one row, not the whole model, which is
    // what lets a delegate's Behavior/animation (Phase 5) transition only
    // the aircraft that actually changed rather than re-triggering for
    // everything on screen.
    for (int row = 0; row < m_aircraft.size(); ++row) {
        const auto it = incomingByIcao.constFind(m_aircraft.at(row).icao);
        if (it != incomingByIcao.constEnd()) {
            m_aircraft[row] = it.value();
            const QModelIndex idx = index(row);
            emit dataChanged(idx, idx);
        }
    }

    // Pass 2 — remove rows whose aircraft did not appear in this batch at
    // all. Walked from the last row back to the first: removing row N
    // never changes the row numbers of rows before it, so this is safe
    // without having to recompute indices mid-loop.
    for (int row = m_aircraft.size() - 1; row >= 0; --row) {
        if (!incomingByIcao.contains(m_aircraft.at(row).icao)) {
            beginRemoveRows(QModelIndex(), row, row);
            m_aircraft.remove(row);
            endRemoveRows();
        }
    }

    // Pass 3 — collect aircraft from this batch that weren't already in
    // the model (i.e. newly-seen icao24s), then append them as a single
    // contiguous range. Collecting first and inserting once means this is
    // one beginInsertRows/endInsertRows no matter how many new aircraft
    // showed up, instead of one per aircraft.
    QSet<QString> existingIcaos;
    existingIcaos.reserve(m_aircraft.size());
    for (const Aircraft &a : m_aircraft)
        existingIcaos.insert(a.icao);

    QVector<Aircraft> newcomers;
    for (const Aircraft &a : incoming) {
        if (!existingIcaos.contains(a.icao))
            newcomers.append(a);
    }

    if (!newcomers.isEmpty()) {
        const int first = m_aircraft.size();
        const int last = first + newcomers.size() - 1;
        beginInsertRows(QModelIndex(), first, last);
        m_aircraft += newcomers;
        endInsertRows();
    }
}
