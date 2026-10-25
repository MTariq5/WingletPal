# Third-party notices

This inventory records identifiable dependencies and resources. It does not grant a license to the original project code or replace upstream terms.

The [asset publication review](docs/ASSET_REVIEW.md), dated 2026-10-24,
records decisions for all 49 bundled image/audio/model files. The repository is
not yet cleared for public asset redistribution: 9 files remain unresolved and
9 modified upstream candidates still need their modifications' provenance confirmed.

## Approved replacement icons and drawings

27 resources were replaced on 2026-10-24: 15 Tabler-derived icons under [Tabler MIT](licenses/Tabler-MIT.txt), and 12 original geometric drawings under [the artwork-only MIT notice](licenses/AvionicsClock-Artwork-MIT.txt). The owner approved the designs and adding their licenses. This does not select a license for the application code.

[Per-file sources and modifications](docs/ICON_SOURCES.md) identify the exact scope of each notice and pinned upstream URLs. Preserve these notices with source and binary distributions containing the corresponding artwork.

## Generated weather background

The selected blue sky/cloudscape replaces the active weather background. See [generation provenance and asset-only license](docs/BACKGROUND_SOURCE.md). Its legacy resource filename remains unchanged.

## QFlightInstruments artwork

`Resources/Altimeter/alt_ground.svg` matches `qfi/images/eadi/eadi_alt_ground.svg`
from [QFlightInstruments by Marek M. Cel](https://github.com/marek-cel/QFlightinstruments/tree/b1401ba9f96cc954d44d59559efebad2ea36e3f9)
after line-ending normalization. Its MIT copyright and permission notice is
retained in [licenses/QFlightInstruments-MIT.txt](licenses/QFlightInstruments-MIT.txt).

Nine additional SVGs have structural evidence of derivation from that project;
their exact paths, upstream mappings and confidence are in the review. Preserve
the upstream notice for those portions, but do not treat it as proof that any
unidentified additions, other G5 resources, or all project code are MIT-licensed.

## Libraries

- **Qt 6**: Core, Quick/QML, Network, Multimedia, Location, Positioning, Qt5Compat and the QML modules used by the application. Qt is an external build/runtime dependency. Check the terms for the exact Qt distribution and modules you use before distributing binaries: https://www.qt.io/licensing/
- **OpenCV 4**: core, imgproc, objdetect and videoio. OpenCV is an external build/runtime dependency. Preserve the notices supplied with your selected build: https://opencv.org/license/

## Bundled face-detection models

`Resources/models/haarcascade_frontalface_default.xml` and `Resources/models/haarcascade_profileface.xml` contain their own Intel License Agreement notices. Those headers are retained in the files and must remain with source redistributions; the headers also specify notice requirements for binary redistributions.

The frontal detector credits Rainer Lienhart. The profile detector credits David Bradley. The model headers state Copyright (C) 2000, Intel Corporation.

Both local model files were verified byte-for-byte against the linked OpenCV
4.12.0 files. A separate copy of their notice is retained in
[licenses/OpenCV-Haar-Intel.txt](licenses/OpenCV-Haar-Intel.txt) for inclusion with distributions.

Upstream files identified by the camera documentation:

- https://github.com/opencv/opencv/blob/4.12.0/data/haarcascades/haarcascade_frontalface_default.xml
- https://github.com/opencv/opencv/blob/4.12.0/data/haarcascades/haarcascade_profileface.xml

## Online data services

- Open-Meteo supplies weather and city-search results: https://open-meteo.com/
- GeoNames supplies location data used by Open-Meteo geocoding: https://www.geonames.org/
- OpenSky supplies aircraft data: https://opensky-network.org/
- OpenStreetMap and providers selected by the Qt Location OSM plugin supply maps: https://www.openstreetmap.org/copyright

Keep the map's provider/copyright display visible. Service data and access are governed by their providers' terms, separately from the application's code.

## Audio and graphics: publication review outstanding

The generation details for `hello.mp3` and `focus-complete.mp3` are recorded in [Resources/audio/README.md](Resources/audio/README.md). They were generated using edge-tts and Microsoft's online voice service. That provenance alone does not establish redistribution permission; review the applicable service terms before publication.

The owner confirmed that the four reminder clips are not their own recordings;
no source or redistribution license has been established for them. The two
edge-tts clips have documented generation details, but no verified grant for
redistributing these Edge-service outputs. Replace or obtain permission for all
six audio files before release. This is unresolved permission, not a finding
that their use has expressly been prohibited.

The remaining unresolved photos and graphics are listed individually in the
review and [asset manifest](docs/asset-manifest.json). Confirm their authorship or
obtain the original licenses before public distribution. Do not describe all
bundled assets as MIT-licensed. Replacing a file in the working tree does not
remove its earlier versions from Git history.
