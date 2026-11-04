# Margin Maker development handoff

## Start here

Read `AGENTS.md`, `README.md`, `NEXT_STEPS.md`, and `TESTING.md` before making
changes. Version **0.2.0** is the user-approved working baseline as of
November 3, 2026. The immediate implementation and UI refinement work is
complete. Future work should preserve that workflow.

## Current application

Main is at `8dc8769`, with source protection, Portrait/Landscape, serialized
previews, queued imports, and PDF drag-and-drop reviewed and fast-forward merged.
The current branch is `feature/app-icon`, integrating only the approved Concept C
artwork and packaging. It must remain unmerged pending user QA. The installed
v0.2.0 app, existing ZIPs, and baseline tag remain protected.

The native Mac app already exists. It uses SwiftUI, PDFKit, and Core Graphics,
has no third-party runtime dependencies, and runs entirely offline.

- Default layout: **75%, middle-center** on portrait US Letter.
- Nine positioning buttons, scale slider, page navigation, and All pages /
  This page scope. Existing individual settings survive a scope change until
  another adjustment is made.
- Page Orientation selects Portrait (612 × 792 pt, default) or Landscape
  (792 × 612 pt) for the whole document, independent of layout scope. It changes
  the canvas and keeps the imported reading's existing orientation. Individual
  page positions and scales survive switching orientations.
- Preview and export share the vector PDF engine. The source file is never
  edited, and exports cannot replace it through path aliases.
- Long toolbar filenames truncate inside their capsule. The scope heading is
  displayed once, above the segmented control.
- Preview work is serialized; pending settings coalesce, and revision checks
  suppress obsolete results/errors. The renderer checks cancellation after
  page drawing and finalization.
- The latest open request is retained during import/export or a native file
  panel. Request ordering is reserved before asynchronous drop URL resolution.
  Failed imports retain the current source, settings, and preview.
- The full application area accepts one Finder PDF with subtle hover feedback.
  PDFKit's separate native file-drop path is disabled so drops use AppModel's
  protected importer. Open PDF remains available during background work.

## Code and commands

- `Sources/MarginMaker`: UI, application state, native file panels, PDF preview.
- `Sources/MarginMakerCore`: layout state and vector conversion engine.
- `tests/MarginMakerCoreTests`: PDF engine, file protection, application-state,
  cancellation, and drop-provider Swift Testing regressions.
- `Packaging/Info.plist` and `scripts/build-app.sh`: local app packaging.
- `Packaging/AppIcon` and `scripts/build-icon.sh`: unchanged approved transparent
  artwork and native macOS icon generation before app signing.
- `margin_maker/core.py` and `tests/test_core.py`: Python reference only;
  they are not bundled with the Mac app.

```bash
bash scripts/test.sh
bash scripts/test.sh -c release
bash scripts/build-app.sh release /private/tmp/margin-maker-local-build
```

The build produces `Margin Maker.app` and `Margin Maker.zip` in the chosen
output directory, signed ad-hoc for local use. The default directory is `build`;
existing apps/ZIPs are refused. Use a fresh output directory. Extract the ZIP
outside iCloud before installing.
The build stages signing outside synced folders to avoid Finder metadata
invalidating the bundle. `README.md` has full run instructions.

## Recorded validation and remaining gaps

The reliability/drag-drop branch passes 48 native tests in debug and release.
Controlled workers test serialization, coalescing, stale-result/error suppression,
latest-open queuing during import/export, failure recovery, and slow drop-provider
ordering. Portrait/Landscape, crops/rotations, source protection, searchable text,
and PDFKit highlight/ink annotation reopening pass. The separate QA app's Open
PDF and both save-panel export paths were checked. The Python reference is
unchanged. See `TESTING.md` for evidence and the QA archive path.

Physical Finder drag/drop remains a manual QA item: automation did not initiate
a native file drag even in a Finder-to-Finder control test. Provider-level drop
handling and hover state are covered automatically; do not present that as an
end-to-end physical drag verification.

PDF Expert's own open/highlight/write/save/reopen workflow remains unverified.
Physical testing covers this Apple Silicon Mac on macOS 27.0.1; the declared
macOS 13 minimum and Intel support require compatibility testing before being
advertised. Developer ID signing, notarization, clean installation on another
Mac, and public distribution are still future work.

## Recommended next task

When asked to resume development without a different priority:

1. Let the user inspect the separately named Icon QA app, particularly the Dock
   icon at normal and magnified sizes. Finder list/icon views and QA launch were
   verified; direct Dock inspection timed out. See the icon run in `TESTING.md`.
2. Review `feature/app-icon` against main. Merge only after explicit approval;
   preserve all existing ZIPs, installed apps, and the v0.2.0 tag.
3. Complete the real PDF Expert workflow and promised macOS/hardware checks.
4. For further changes, use generated PDFs and a new QA output path so the
   accepted app and reading session stay intact. Record concrete failures and
   add focused regressions; avoid unrelated feature expansion.

Keep the accepted interface and defaults stable during this audit. Optional
features and release milestones are recorded in `NEXT_STEPS.md`; the roadmap
does not mean those features have already been implemented. Publishing source
or release downloads is a separate future task.
