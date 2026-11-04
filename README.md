# Margin Maker

A small, free macOS utility that makes room for handwritten notes around PDF
readings. Open a PDF, position it on a US Letter canvas, and export a new copy
before annotating it in PDF Expert or another PDF reader.

Margin Maker works entirely on your Mac. It has no accounts, telemetry,
networking, automatic updates, subscriptions, or third-party runtime dependencies.

## 0.3.0 release candidate

This is a **local release candidate for final user acceptance testing**, not a
published release. The current packaged builds target Apple Silicon. The source
project targets macOS 13+, but physical testing covers macOS 27.0.1 on Apple
Silicon; macOS 13 and Intel Macs remain unverified.

**Unresolved text-preservation limitation:** conversion does not preserve PDF
`/ActualText` replacements. A document may look correct while copying, searching,
or accessibility tools receive different text. This can affect ligatures,
mathematics, and specially encoded or accessible PDFs. Do not use this candidate
when those replacement semantics must be retained. Unrestricted public release
requires an explicit decision on this limitation. See [COMPATIBILITY.md](COMPATIBILITY.md).

## Install the local QA build

1. Extract **Margin Maker 0.3.0 RC QA.zip** outside iCloud or other synced folders.
2. Open **Margin Maker 0.3.0 RC QA.app**, or copy that separately named app into
   Applications alongside your working version.
3. Open a disposable reading first, then inspect its exported copy in your PDF reader.

The QA bundle identifier is `local.marginmaker.rc030qa`, separate from the normal
`local.marginmaker.app`. The supplied normal app is named **Margin Maker.app**;
use the QA app during acceptance testing to preserve your installed copy.
These are ad-hoc-signed local builds, not Developer ID signed or notarized public
downloads. No installer or background service is included.

## Use

1. Click **Open PDF**, press Command-O, or drop one PDF from Finder onto the window.
2. Choose **Portrait** (8.5 × 11 inches, default) or **Landscape** (11 × 8.5 inches).
   This changes the canvas for the whole document; the reading stays upright,
   respecting its existing PDF orientation.
3. Choose one of nine positions and set the scale from **50% to 100%**. Defaults
   are **75%, middle-center**. At 100%, the visible source page is proportionally
   fitted inside the chosen canvas, including small and cropped pages.
4. Keep **All pages** selected, or choose **This page** to adjust individual pages.
   Changing scope alone preserves existing settings. Orientation always applies
   to the whole document, while individual positions and scales survive.
5. Export with Shift-Command-E. The suggested filename is `Reading-margins.pdf`.
6. Annotate the exported copy in PDF Expert or another reader.

Preview and export share the same vector engine. Ordinary selectable text and
conventional invisible OCR text layers are retained in the tested fixtures;
scans without OCR remain images. Content is never stretched or automatically
trimmed. Command-[ and Command-] navigate pages.

The exporter protects the imported original, including renamed files and aliases
on the same filesystem, and stages a new PDF before atomic replacement. A failed
new import retains the current reading and its settings. While an import/export
is busy, the latest open request is queued and displayed as **Next**. Rapid
adjustments coalesce into one preview worker.

## Known limitations

- `/ActualText` and accessible document structure are not preserved; see the
  release decision and reproduction evidence in [COMPATIBILITY.md](COMPATIBILITY.md).
- Existing annotations, links, forms, outlines, and signatures are not migrated.
  Prepare margins **before** annotating. This is not an accessibility or archival
  conversion tool and does not add OCR.
- Password-locked PDFs require an unlocked copy from another PDF application.
- A cross-volume copy/delete creates a new file identity; reopen that copy to
  protect it as the imported source. A small race with another process changing
  the destination immediately before replacement remains; see [TESTING.md](TESTING.md).
- Core Graphics cannot interrupt an individual page draw midway. The latest
  preview waits for the old drawing to finish; pending opens wait for import/export.
- macOS 13, Intel hardware, clean installation on another Mac, and the exact
  release-candidate/PDF Expert interaction need further testing. The user has
  verified Finder dropping, the icon, and earlier PDF Expert highlighting.

## Build from source

Use a Mac with Swift 6.0+ from Xcode or Apple's Command Line Tools. No packages
are downloaded by the native app build. It produces the current Mac architecture.

```bash
bash scripts/build-app.sh release /private/tmp/margin-maker-030-local
```

The output directory contains **Margin Maker.app** and **Margin Maker.zip**.
Use `debug` instead of `release` for a development build. Existing apps and ZIPs
are refused; choose a fresh output directory. Signing happens in a temporary
local folder before the bundle is copied or archived, avoiding iCloud metadata
in the ZIP. Extract the archive outside synced storage.

To reproduce the separate QA package:

```bash
MARGIN_MAKER_APP_NAME="Margin Maker 0.3.0 RC QA" \
MARGIN_MAKER_BUNDLE_ID="local.marginmaker.rc030qa" \
bash scripts/build-app.sh release /private/tmp/margin-maker-030-qa
```

Both overrides are required together. Native `sips` and `iconutil` generate the
approved Concept C icon from the unchanged master under `Packaging/AppIcon` and
embed it before signing. See [the artwork record](Packaging/AppIcon/README.md).
The build does not install, notarize, publish, or change signing certificates.

## Verify

```bash
bash scripts/test.sh
bash scripts/test.sh -c release
```

The native suite covers page geometry, both orientations, rotations/crops,
preview/export agreement, text and OCR layers, annotations, file protection,
cancellation, queued imports, dropped-file providers, and the Quartz xref repair.
Recorded results and remaining manual checks are in [TESTING.md](TESTING.md).

Optional Python reference and independent PDF checks use the development-only
packages from `requirements-dev.txt`, plus qpdf and Poppler for compatibility checks:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
python scripts/check-pdf-compatibility.py /private/tmp/margin-maker-compatibility
```

The independent check requires a new output directory. It intentionally exits
**2** while the known `/ActualText` loss remains; its JSON report distinguishes
that limitation from structural checks and successful ordinary/OCR extraction.
Use `--font /path/to/font.ttf` if Arial Unicode is unavailable on your Mac.
No test reads personal PDFs. Python and the validation tools are not bundled
with the application.

## Project and license

- `Sources/MarginMaker`: SwiftUI interface, file panels, drop handling, PDFKit preview.
- `Sources/MarginMakerCore`: layout, source protection, vector export, xref normalization.
- `tests/MarginMakerCoreTests`: native regression tests.
- `Packaging` and `scripts`: approved artwork, metadata, build and verification tools.
- `margin_maker/core.py`: optional Python behavioral reference, not an app dependency.

The project uses the existing [MIT license](LICENSE). Apple system frameworks
supply the native runtime; no AGPL dependency has been introduced. The optional
Python reference uses BSD-3-Clause licensed pypdf. See [CHANGELOG.md](CHANGELOG.md)
for changes since v0.2.0 and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for the
remaining approval and distribution work.
