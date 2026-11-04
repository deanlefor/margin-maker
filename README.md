# Margin Maker

Small, local macOS PDF utility to make room for handwritten margin notes in
academic readings **before** annotating them in PDF Expert.

The native application uses SwiftUI, PDFKit, and Core Graphics. It has no
third-party runtime dependencies and needs no Python installation.

**Status:** Version **0.2.0** is the accepted working local Mac app. The next
milestones are a code audit, real PDF Expert and compatibility checks, and
release packaging. See [NEXT_STEPS.md](NEXT_STEPS.md) for the prioritized
roadmap and [CODEX_TASK.md](CODEX_TASK.md) for the development handoff.

Main includes original-file protection, Portrait/Landscape output, serialized
previews, queued file opens, and PDF drag-and-drop (`8dc8769`).
**Feature branch:** `feature/app-icon` integrates the approved Concept C icon.
The accepted installed app, existing ZIPs, and `v0.2.0` tag remain unchanged.

## The interaction

1. Open a reading (PDF), or drag one PDF from Finder onto the application area.
2. See its page on a white US Letter canvas; choose Portrait or Landscape.
3. Set its size with a **50–100% slider** (75% by default).
4. Position the reading with **nine buttons** (top/middle/bottom × left/center/right).
5. Apply settings to all pages or adjust individual pages.
6. Export a new PDF and open it in PDF Expert for annotations.

Optional additions such as saved layouts and content trimming are recorded
in the roadmap; the accepted interface remains the baseline.

## Build and run on a Mac

Requires **macOS 13+** and **Swift 6.0+** from Xcode or Apple's Command Line
Tools. Build for the architecture of your current Mac:

```bash
bash scripts/build-app.sh
open "build/Margin Maker.app"
```

For a development build: `bash scripts/build-app.sh debug`. Alternatively,
open `Package.swift` in Xcode and run the MarginMaker scheme, or use
`swift run MarginMaker`.

The script creates and verifies an **ad-hoc signed local app**. Developer ID
signing, notarization, universal builds, and public distribution are separate
work. The package has no remote dependencies. A `build/Margin Maker.zip`
archive is also created without Finder metadata. For an iCloud checkout,
extract that archive outside iCloud before moving the app to Applications;
iCloud can reattach metadata that invalidates bundle signature checks.
You can instead choose a local output directory:

```bash
bash scripts/build-app.sh release /private/tmp/margin-maker-build
```

Builds refuse to replace an existing app or ZIP; choose a fresh output directory.
The approved transparent icon master is retained under `Packaging/AppIcon`.
macOS `sips` and `iconutil` generate the icon before bundle signing; see that
directory's README for provenance and reproducibility details.

To create the separately named icon QA app without changing regular app metadata:

```bash
MARGIN_MAKER_APP_NAME="Margin Maker Icon QA" \
MARGIN_MAKER_BUNDLE_ID="local.marginmaker.iconqa" \
bash scripts/build-app.sh release /private/tmp/margin-maker-icon-qa
```

Both overrides are required together. The output is `Margin Maker Icon QA.app`
and `Margin Maker Icon QA.zip`; this does not install or replace an application.

## Using the app

Open a PDF with Command-O. The default layout is 75%, middle-center. The
preview uses the same vector PDF engine as export. At 100%, the visible crop
box, respecting the PDF's existing orientation, is proportionally fitted inside
the chosen Letter canvas. Lower percentages
scale that fitted size; pages are never stretched or automatically trimmed.

You can also drop one PDF anywhere in the main application area, including
the preview and controls. A subtle border marks a PDF candidate under the
pointer. Folders, multiple files, and unsupported file types are rejected with
feedback; the importer checks PDF validity and password protection on opening.

If another import or export is running, the latest open request is retained
and processed when safe. Its filename appears as **Next** during the busy
operation. Picker, Finder, and drop requests share the protected importer.
An unsuccessful new import keeps the current reading and its page settings.

Keep **All pages** selected to adjust the whole reading, or choose **This
page** and use the arrows (Command-[ / Command-]) for individual settings.
Changing scope alone preserves existing settings. The next adjustment in All
pages applies the displayed settings to every page.

**Page Orientation** offers **Portrait (8.5 × 11 inches)**, the default, and
**Landscape (11 × 8.5 inches)**. It changes the output canvas for every page,
including when This page is selected for positioning and scale. Each reading
keeps its imported orientation, and individual position/scale settings survive
orientation changes. Preview and export use the same canvas and layout.

Export with Shift-Command-E. The suggested name is `OriginalName-margins.pdf`;
the app refuses to replace the source, including symlinks and hard links.
Source identity is captured at import, so protection follows renames and moves
within the same filesystem, including Finder aliases and alternate paths.
Exports are staged beside the destination and checked again immediately before
atomic replacement. A cross-volume copy/delete creates a different file identity;
reopen that copy if it should become the protected source.
The **PDF exported** menu opens the result or reveals it in Finder.

## Native tests

```bash
bash scripts/test.sh
```

The tests verify actual exported PDFs, rendered anchor positions, crop
clipping, all four source rotations, both canvas orientations, page order,
search/selection, per-page settings,
highlight annotations, input errors, and original-file protection. See
[TESTING.md](TESTING.md) for the local UI checklist and verification results.

## Implementation and Python reference

`Sources/MarginMaker` contains the native UI, file panels, and PDFKit preview.
Loading, preview generation, and export run off the UI thread. Preview
requests are debounced and coalesced to the latest settings. Only one preview
conversion runs at a time; a cancelled drawing finishes before its replacement
starts, and revision checks prevent stale results from appearing.
`Sources/MarginMakerCore` contains the independent, tested layout and vector
PDF engine. Source bytes are held in an immutable snapshot.

`margin_maker/core.py` is the original `pypdf` behavioral reference. It is
retained with its tests and is not used or bundled by the Mac application.

Text stays selectable/searchable when supported by the source PDF. Scans stay
images. Original annotations, links, interactive forms, outlines, and document
signatures are not migrated: annotate the exported PDF afterward.
Password-locked inputs need an unlocked copy from another PDF viewer first.

### Run the core tests

With Python 3.10 or newer:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
```

## Sharing the application later

The project code is available under the MIT license (`LICENSE`). The Mac app
uses only Apple system frameworks and bundles no AGPL dependencies. The
optional Python reference uses BSD-3-Clause licensed `pypdf`.

The intended result is a free Mac app distributed through a normal download,
without subscriptions, accounts, or PDF uploads. Publication to GitHub and
code signing/notarization are separate future steps, not part of this handoff.
