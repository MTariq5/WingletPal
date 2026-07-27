#include "GeoBoundingBox.h"

#include <QtMath>

// Converts a center point + radius into a lat/lon bounding box.
//
// The math: latitude degrees are a constant ~111.32 km apart everywhere on
// Earth, so the latitude half-extent is just radiusKm / 111.32. Longitude
// degrees are NOT constant distance apart — they shrink toward the poles by
// a factor of cos(latitude) (at the equator, 1 degree of longitude is also
// ~111.32 km; at 60° latitude it's about half that; at the poles it's 0).
// So the longitude half-extent has to divide by that shrunk distance
// instead, or the box would be far too narrow (east/west) away from the
// equator. cos() is clamped to a small positive minimum so a center point
// very close to a pole can't produce a division by (near-)zero and blow up
// the box.
GeoBoundingBox GeoBoundingBox::fromCenterRadius(double centerLat, double centerLon, double radiusKm = 500)
{
    // 1 degree of latitude is ~111.32 km everywhere.
    const double kmPerDegreeLat = 111.32;
    const double latDelta = radiusKm / kmPerDegreeLat;

    // 1 degree of longitude shrinks with cos(latitude) — ~111.32 km/degree
    // at the equator, shrinking toward 0 at the poles. Clamp cos() away
    // from 0 so extreme latitudes can't divide by (near-)zero.
    const double cosLat = qMax(0.01, qCos(qDegreesToRadians(centerLat)));
    const double kmPerDegreeLon = kmPerDegreeLat * cosLat;
    const double lonDelta = radiusKm / kmPerDegreeLon;

    GeoBoundingBox box;
    box.lamin = centerLat - latDelta;
    box.lamax = centerLat + latDelta;
    box.lomin = centerLon - lonDelta;
    box.lomax = centerLon + lonDelta;
    return box;
}
