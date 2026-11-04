# Margin Maker development handoff

## Start here

Read `AGENTS.md`, `README.md`, `NEXT_STEPS.md`, and `TESTING.md` before making
changes. Version **0.2.0** is the user-approved working baseline as of
November 3, 2026. The immediate implementation and UI refinement work is
complete. Future work should preserve that workflow.

## Current application

The current feature branch is `feature/page-orientation`, starting from main's
source-protection fix (`78e19c8`). It replaces the rotation control with two
output canvas orientations. The installed `v0.2.0` app remains the accepted
baseline; this branch is a separate QA candidate.

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

## Code and commands

- `Sources/MarginMaker`: UI, application state, native file panels, PDF preview.
- `Sources/MarginMakerCore`: layout state and vector conversion engine.
- `tests/MarginMakerCoreTests`: Swift Testing regression tests.
- `Packaging/Info.plist` and `scripts/build-app.sh`: local app packaging.
- `margin_maker/core.py` and `tests/test_core.py`: Python reference only;
  they are not bundled with the Mac app.

```bash
bash scripts/test.sh
bash scripts/test.sh -c release
bash scripts/build-app.sh
```

The build produces `build/Margin Maker.app` and `build/Margin Maker.zip`,
signed ad-hoc for local use. Extract the ZIP outside iCloud before installing.
The build stages signing outside synced folders to avoid Finder metadata
invalidating the bundle. `README.md` has full run instructions.

## Recorded validation and remaining gaps

The Page Orientation feature run passed 28 native tests in debug and release.
The separate QA app was checked locally in Portrait and Landscape, including
per-page overrides, save-panel exports, source rotations/crops, selectable text,
and preview/export agreement. The Python reference is unchanged; its previous
eight-test result belongs to the baseline. See `TESTING.md` for the evidence.

PDF Expert's own open/highlight/write/save/reopen workflow remains unverified.
Physical testing covers this Apple Silicon Mac on macOS 27.0.1; the declared
macOS 13 minimum and Intel support require compatibility testing before being
advertised. Developer ID signing, notarization, clean installation on another
Mac, and public distribution are still future work.

## Recommended next task

When asked to resume development without a different priority:

1. Preserve the baseline in local version control. At this handoff, the
   project folder has no Git repository. Retain the accepted build separately
   from future generated artifacts.
2. Audit the native conversion engine, original-file protection, asynchronous
   UI behavior, and large-document performance using `NEXT_STEPS.md`.
3. Report findings with severity, file/line references, reproduction steps,
   and focused fixes. Make small, verified correctness fixes where warranted
   and add regression tests for actual failures.
4. Run applicable tests, render affected export fixtures, and smoke-test the
   Mac UI. Use generated PDFs and a separate QA app copy so an open reading
   session is not discarded.
5. Update the test record and remaining roadmap. Keep any incomplete PDF
   Expert, OS compatibility, or distribution checks explicit.

Keep the accepted interface and defaults stable during this audit. Optional
features and release milestones are recorded in `NEXT_STEPS.md`; the roadmap
does not mean those features have already been implemented. Publishing source
or release downloads is a separate future task.
