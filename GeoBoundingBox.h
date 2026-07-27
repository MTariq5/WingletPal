#ifndef GEOBOUNDINGBOX_H
#define GEOBOUNDINGBOX_H

// ============================================================================
// GeoBoundingBox
// ----------------------------------------------------------------------------
// Usage: pure coordinate math, nothing else. Call
// GeoBoundingBox::fromCenterRadius(...) with a center point and a radius to
// get back the lamin/lamax/lomin/lomax box that OpenSky's /states/all
// endpoint expects as query parameters (see OpenSkyFlightSource::
// performRequest). No networking, no Qt Location types, no knowledge of
// aircraft or providers — just doubles in, doubles out. Kept as its own
// tiny type (rather than inline arithmetic inside FlightTrackerProvider or
// OpenSkyFlightSource) so this math has exactly one place to live and one
// place to get right.
// ============================================================================
struct GeoBoundingBox
{
    double lamin = 0.0; // minimum latitude (south edge)
    double lamax = 0.0; // maximum latitude (north edge)
    double lomin = 0.0; // minimum longitude (west edge)
    double lomax = 0.0; // maximum longitude (east edge)

    // Builds a bounding box centered on (centerLat, centerLon) that extends
    // `radiusKm` in every direction (north/south/east/west).
    //
    // Params:
    //   centerLat  - center latitude, decimal degrees (e.g. from
    //                LocationProvider::latitude)
    //   centerLon  - center longitude, decimal degrees
    //   radiusKm   - how far the box should extend from the center, in
    //                kilometers (e.g. FlightTrackerProvider's
    //                searchRadiusKm, default 50)
    //
    // Returns: a GeoBoundingBox with lamin/lamax/lomin/lomax filled in.
    //
    // Note: this is a flat-earth approximation (not great-circle-exact) —
    // fine for a ~50km "nearby traffic" query, not for precision navigation.
    static GeoBoundingBox fromCenterRadius(double centerLat, double centerLon, double radiusKm);
};

#endif // GEOBOUNDINGBOX_H
