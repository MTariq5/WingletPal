# Asset provenance and publication review

Reviewed on **2026-10-24**. Scope: all **49** image, audio and detector-model files under `Resources/` (31 SVG, 8 PNG, 2 JPEG, 6 MP3, 2 XML). Updated after the approved replacement of 27 icons/drawings and the active weather background. Resource paths and file formats were retained.

The decisions below concern publishing the actual resource files in a public Git repository and distributing them with the app. A license for showing an image in a finished design does not automatically grant permission to distribute its editable/source file. A search result, filename, export-tool signature, or Git author is not a license.

## Decision summary

| Status | Files | Publication decision |
| --- | ---: | --- |
| Verified upstream match with explicit terms | 3 | Keep with the relevant notices: one QFlightInstruments SVG and two OpenCV models |
| Strong evidence of modified QFlightInstruments artwork | 9 | Retain provisionally with QFlightInstruments attribution; confirm the provenance of modifications before clearing the current versions, or use the verified upstream versions as replacement inputs |
| Approved MIT replacement artwork | 27 | Publish current versions with their asset-specific notices; see [replacement sources](ICON_SOURCES.md) |
| Approved AI-generated background | 1 | See [provenance and asset-only notice](BACKGROUND_SOURCE.md) |
| Unresolved provenance or output rights | 9 | Hold from public release until documented, replaced, or removed from the publishable version |

These are evidence-based release decisions, not a claim that every unresolved file infringes copyright. The original project-code license remains undecided at the owner's request.

## 1. Artwork with an identified open-source origin

Source: [Marek M. Cel's QFlightInstruments](https://github.com/marek-cel/QFlightinstruments/tree/b1401ba9f96cc954d44d59559efebad2ea36e3f9), inspected at commit `b1401ba9f96cc954d44d59559efebad2ea36e3f9`. Its [MIT license](https://github.com/marek-cel/QFlightinstruments/blob/b1401ba9f96cc954d44d59559efebad2ea36e3f9/LICENSE) names Copyright (c) 2021 Marek M. Cel. A copy is retained in [licenses/QFlightInstruments-MIT.txt](../licenses/QFlightInstruments-MIT.txt).

MIT permits reuse and modification subject to retaining its copyright and permission notice. That identifies the upstream terms; it does not establish who made every later local modification.

All local paths in the next table are relative to `Resources/`; upstream paths are relative to `qfi/images/` at the pinned commit.

| Local file | Upstream file | Evidence | Decision |
| --- | --- | --- | --- |
| `Altimeter/alt_ground.svg` | `eadi/eadi_alt_ground.svg` | Full text matches after line-ending normalization and outer whitespace trimming | Keep with MIT notice |
| `Airspeed/airSpeed_bug.svg` | `eadi/eadi_asi_bug.svg` | Shared `g4183` and `rect1258` IDs; related speed-bug geometry, modified export | Confirm modifications or replace from upstream |
| `eaid/eadi_adi_ladd.svg` | `eadi/eadi_adi_ladd.svg` | All 135 non-generic local IDs are present upstream; both have 97 path/rect/polygon elements, with transformed geometry | Strong derivative evidence; confirm modifications or replace from upstream |
| `ehsi/ehsi_dev_scale.svg` | `ehsi/ehsi_dev_scale.svg` | All 8 non-generic IDs match; the same four circle-path structure is transformed/re-exported | Strong derivative evidence; confirm modifications or replace from upstream |
| `ehsi/ehsi_hdg_scale.svg` | `ehsi/ehsi_hdg_scale.svg` | All 107 non-generic IDs match; local geometry is re-exported and differs | Strong derivative evidence; confirm modifications or replace from upstream |
| `ehsi/hi_case.svg` | `hi/hi_case.svg` | 359 of 360 non-generic IDs match; bezel/aircraft structures remain, with local changes | Strong derivative evidence; confirm modifications or replace from upstream |
| `ehsi/hi_loc2-dev.svg` | `ehsi/ehsi_dev_bar.svg` | Same `g1293` / `rect966-9` structure; changed dimensions/color | Confirm modifications or replace from upstream |
| `ehsi/hi_loc2-dev-Minuites.svg` | `ehsi/ehsi_dev_bar.svg` | Same IDs and bar structure; renamed variant | Confirm modifications or replace from upstream |
| `ehsi/hi_loc2-needle.svg` | `ehsi/ehsi_crs_arrow.svg` | Same `rect966-3` / `rect966-3-6` IDs and shaft/arrow arrangement; modified geometry | Confirm modifications or replace from upstream |
| `ehsi/hi_loc2-needle-Minuites.svg` | `ehsi/ehsi_crs_arrow.svg` | Same IDs and shaft/arrow arrangement; renamed variant | Confirm modifications or replace from upstream |

The nine derivative findings are inferences from the file contents, not byte-for-byte matches. Merely sharing a filename was not treated as proof. In particular, `ehsi_hdg_bug.svg` has a different current shape and lacks enough matching structural evidence, so its previous version was unresolved; it has now been replaced with original geometric artwork. This review does not clear the imported G5 QML code as a whole.

## 2. Detector models: verified and retainable

Both files are byte-for-byte matches to the OpenCV 4.12.0 files at these URLs:

- [`haarcascade_frontalface_default.xml`](https://raw.githubusercontent.com/opencv/opencv/4.12.0/data/haarcascades/haarcascade_frontalface_default.xml)
- [`haarcascade_profileface.xml`](https://raw.githubusercontent.com/opencv/opencv/4.12.0/data/haarcascades/haarcascade_profileface.xml)

Each file includes the Intel License Agreement and Copyright (C) 2000 Intel Corporation. Keep the source headers; include the notice with binary distributions as required by those headers. A copy is in [licenses/OpenCV-Haar-Intel.txt](../licenses/OpenCV-Haar-Intel.txt). This model-specific license should not be replaced with the license of the current OpenCV library.

## 3. Audio: replace or establish explicit permission

| Files under `Resources/audio/` | What is known | Action before publication |
| --- | --- | --- |
| `reminder1.mp3`, `reminder2.mp3`, `reminder3.mp3`, `reminder4.mp3` | Owner confirmed these are not their own recordings. Git history contains no source/license. MP3 tags only identify the encoder (`Lavf58.76.100`), not the voice owner or a license | Obtain the original provider/recordist's redistribution permission, or replace all four |
| `hello.mp3` | Project notes identify edge-tts 7.3.1 and Microsoft's `en-US-GuyNeural` voice | Regenerate through a service with documented output rights, or obtain explicit permission for the current output |
| `focus-complete.mp3` | Project notes identify edge-tts 7.3.1 and Microsoft's `ar-EG-ShakirNeural` voice; the text is personalized with Tarek's name | Same permission issue; also use a generic completion message when replacing |

The [edge-tts project](https://github.com/rany2/edge-tts) describes a client for Microsoft Edge's online speech service. Its software license does not itself establish a right to distribute recordings from that service. The generation route is documented for the last two clips; it could not be reconstructed from their MP3 metadata alone.

I did not find a binding grant covering public redistribution of these particular Edge-generated recordings. A [Microsoft-hosted Q&A response](https://learn.microsoft.com/en-us/answers/questions/5925556/commercial-use-of-edge-read-aloud-voices-via-edge) also describes the lack of explicit public documentation, but it expressly states it is not a legally binding interpretation. This is an **unresolved-rights** result, not a finding that Microsoft has expressly prohibited these files.

For replacement, the clearest route is original recordings with the speaker's permission to distribute them with the repository. Another route is generating new clips under an applicable paid TTS agreement: the inspected [Microsoft Azure Product Terms](https://www.microsoft.com/licensing/terms/en-US/productoffering/MicrosoftAzure/OVOVS) expressly grant paid-tier customers use of prebuilt-neural-voice output, including commercial use. Those are Azure terms, not a retroactive license for Edge output; confirm the applicable agreement and permission for your intended repository distribution before choosing that route.

`reminder5.mp3` is referenced in code but does not exist. It is not part of the six-file count; fix that reference when replacing the reminder set.

## 4. Photos and raster artwork: original findings

The seven weather icons below have now been replaced with licensed Tabler adaptations. The active weather background has also been replaced with approved AI-generated artwork; the other three files remain unresolved. The table preserves the findings about their previous versions.

| Files under `Resources/` | Evidence | Suggested disposition |
| --- | --- | --- |
| `closeup-shot-plane-wing.jpg` | IPTC caption describes a plane wing in a pinkish sky; no identified photographer/license. Title searches returned stock-photo listings, but did not establish an exact licensed download | Replace the active weather background with an original photo or an original drawn background unless a suitable license is supplied |
| `cloudscape-with-plane-flying.jpg` | Camera/Lightroom metadata and a descriptive caption; no author/license was established | Candidate for removal: bundled, but no direct code reference found |
| `eaid/Clock-removebg-preview.png` | No attribution metadata; Git describes it as source/reference clock artwork | Candidate for removal if no longer needed; confirm the source of the related dial artwork too |
| `eaid/background.svg` | SVG contains a base64-embedded raster image, not solely vector shapes; no source/license was established | Candidate for removal: bundled, but no direct code reference found |
| `weather/clear_sky.png`, `weather/mainly_clear.png`, `weather/night-moon.png`, `weather/Overcast.png`, `weather/partaly_cloudy.png`, `weather/rain.png`, `weather/snow.png` | No author/license metadata. One file identifies Inkscape, which is an editor, not an asset license | Replace the seven icons with original drawings or a verified permissively licensed icon set |

No photo was attributed to Freepik, Shutterstock or another provider solely on its filename or a search-result description. No reverse-image upload was performed. A “free download” label alone would not establish permission to publish the source files in this repository.

## 5. Vector artwork: original findings, now replaced

All 20 SVGs below have now been replaced; see [current sources and notices](ICON_SOURCES.md). This table records the previous versions, including copies still in Git history.

The previous versions of these **20** SVG files had no sufficient verified source/license in the repository or the upstream comparison. Some are small hand-written shapes, but simplicity and clean XML are not proof of original authorship.

| Group | Exact paths relative to `Resources/` | Action |
| --- | --- | --- |
| Main dial | `eaid/clock-pfd.svg` | Confirm original design/provenance. Git says a previous embedded raster was replaced with vector dial art; vector conversion alone does not establish new rights. Otherwise redraw independently |
| Hand and clock needles | `waving-hand.svg`, `eaid/hourArrow.svg`, `eaid/minuitesArrow.svg` | Keep if confirmed to have been created for this project without an external copied asset; otherwise redraw these simple shapes |
| Aircraft marker | `traffic/aircraft.svg` | Confirm original path or replace with an original aircraft silhouette |
| UI icons | `settings-outline.svg`, `up-arrow.svg`, `Brightness-Slider/brightnessicon.svg`, `Brightness-Slider/brightnessicon-orange.svg`, `Brightness-Slider/crescent-moon.svg`, `weather/location.svg` | Establish source or replace with a documented icon set/original drawings |
| Remaining airspeed art | `Airspeed/airSpeed_fail.svg`, `Airspeed/airSpeed_Tumbler_Frame.svg`, `Airspeed/GS_fail.svg` | Confirm source or recreate the labels/frame |
| Remaining altimeter art | `Altimeter/alt_back.svg`, `Altimeter/alt_bug.svg`, `Altimeter/alt_fail.svg`, `Altimeter/alt_frame.svg`, `Altimeter/alt_scale.svg` | Confirm source or recreate |
| Heading bug | `ehsi/ehsi_hdg_bug.svg` | Same filename exists upstream, but the current shape differs and source was not established; redraw or replace from a verified upstream asset |

## 6. Recommended next change

1. Preserve the identified upstream notices. Use verified upstream artwork or confirm the origin of the local modifications for the nine derivative candidates.
2. Replace the six audio clips with recordings/output whose redistribution rights are recorded alongside the files.
3. The active weather background and seven weather icons have been replaced; preserve their documented provenance and notices.
4. The 20 unresolved vectors have been replaced with approved Tabler adaptations or original geometric drawings; preserve their notices.
5. Remove unnecessary reference assets from both the resource list and publishable files after verifying runtime references. The three candidates are `cloudscape-with-plane-flying.jpg`, `eaid/background.svg`, and `eaid/Clock-removebg-preview.png`.
6. Decide how to handle history before pushing: replacing/deleting a tracked asset today does **not** remove its earlier copies from Git. If permission remains missing, publish a reviewed clean export as a new repository or deliberately clean the affected history. No history rewrite has been performed here.

28 assets have been replaced in the working tree. No QML animation/layout changes, commit, push or history rewrite were made for this replacement. The per-file inventory, SHA-256 fingerprints, decisions and detected code references are in [asset-manifest.json](asset-manifest.json).
