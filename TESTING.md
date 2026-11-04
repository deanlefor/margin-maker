# Local verification

Run `bash scripts/test.sh` for the native engine and document settings tests.
The tests create their own PDFs in memory; they never read personal documents.
The optional Python prototype tests use `requirements-dev.txt`.

The native suite verifies:

- Exact 75% middle-right Letter margins: 153 pt left and 99 pt top/bottom.
- All nine anchors, with pixel bounds checked in rendered exported PDFs.
- Letter, A4, landscape, oversized, and small pages at 50%, 75%, and 100%.
- 0/90/180/270-degree rotation with independently positioned corner marks.
- Document rotation composed with all four source rotations, including crops.
- Small pages and crops enlarged to the correct Letter fit at each scale.
- Rotated single-page previews render identically to their full export pages.
- Offset crop boxes at all four rotations, including clipping hidden content.
- Letter dimensions, selectable/searchable text, and source page order.
- Single-page preview, per-page overrides, and all-page adjustments.
- Empty/invalid/password-locked input and invalid settings/page indices.
- Source byte preservation and protection of paths, symlinks, hard links,
  and case aliases on case-insensitive volumes.
- Adding a highlight annotation and reopening the exported PDF with PDFKit.

## Manual Mac smoke test

1. Run `bash scripts/build-app.sh` and open `build/Margin Maker.app`.
2. Confirm the empty state, disabled export, and Open PDF button.
3. Open a multipage reading. Confirm the default 75% middle-center preview on
   a white Letter page and the initial All pages scope.
4. Click all nine position buttons. Move the slider to 50% and 100%.
5. Navigate pages with the arrows and with Command-[ / Command-].
6. Select This page, change position/scale, navigate away and back, and confirm
   the override persists. Select All pages and adjust again to unify settings.
7. Export with the `OriginalName-margins.pdf` suggestion. Verify page count,
   order, Letter dimensions, placement, search, and text selection.
8. Attempt to export to the source filename and confirm the app refuses.
9. Open empty, malformed, and password-locked PDFs and confirm actionable
   errors. The previously loaded document should stay available.
10. Open the export in PDF Expert, highlight text, write in a margin, save,
    and reopen. This requires PDF Expert to be installed and must be reported
    separately from PDFKit verification.
11. Click Rotate document four times. Confirm successive 90° clockwise turns
    and a return to the original orientation. Navigate to another page and
    verify rotation applies there too, even with This page selected. Export
    while rotated and verify orientation, crop clipping, and text selection.

Generate synthetic readings with the optional Python development dependencies:

```bash
python3 scripts/make-smoke-fixtures.py
```

Files are written only under ignored `tmp/smoke`. Never use an important
reading to test overwrite rejection.

## Recorded run: November 3, 2026

Tested on this Apple Silicon Mac with macOS 27.0.1 and Apple Swift 6.2.3,
using Command Line Tools without a full Xcode installation.

- Native Swift Testing suite: **13 passed in debug and 13 passed in release**.
- Original Python reference suite: **8 passed** (`pypdf` 6.10.0).
- Native UI: launched the built app and used a separate QA copy to preserve
  the user's open reading. Imported the four-page synthetic reading, checked
  the default preview, selected all nine anchors, exercised 50% and 100%,
  navigated with keyboard shortcuts, verified a 63% per-page override survived
  navigation, and applied 75% middle-right to all pages again.
- Export: accepted the suggested filename through the native save panel.
  Independent `pypdf` checks found four 612 x 792 pt pages in the original
  order, expected text on every page, no residual page rotation, and no image
  objects. `qpdf --check` reported no syntax or stream encoding errors.
- Visual review: rendered the exported pages with Poppler and inspected the
  Letter, rotated, and cropped results; the reading stayed within the canvas.
- Safety/error recovery: the UI refused an attempted overwrite of the
  disposable source. Its SHA-256 stayed unchanged. Empty, invalid, and locked
  PDFs showed actionable errors, and the prior reading remained available.
- Packaging: built the optimized app, ad-hoc signed it, and verified both
  the local bundle outside iCloud and a fresh extraction of its ZIP archive
  with `codesign --verify --strict`. The checkout is in iCloud Drive, which
  reattaches Finder metadata to `.app` folders; the metadata-free ZIP avoids
  carrying that into a local extraction.
- Optimized UI smoke test: launched the signed release build outside iCloud,
  imported the mixed-page sample, verified its preview, and saved a fresh
  four-page export through the native save panel.

PDF Expert is not installed here, so its specific open/highlight/save/reopen
check is **not verified**. PDFKit text search and adding/reopening highlight
annotations passed automatically. This is a tested local development build,
not a Developer ID signed or notarized public release. macOS 13 compatibility
and Intel hardware have not been exercised on physical machines.

### Layout correction: version 0.1.1

Rebuilt and visually checked the optimized app with a generated sample named
`12. Dahl (1947) Science of Public Administration.pdf`. The toolbar filename
stays inside its capsule with middle truncation and horizontal padding. The
scope section displays one heading above the segmented control, with no
squeezed label beside it. Switching to This page still updates the scope and
helper text correctly. The original running app session was left intact.

### Centered default and document rotation: version 0.2.0

- Native suite: **18 passed in debug and 18 passed in release**; Python
  reference suite: **8 passed**. The default is now 75%, middle-center.
- Rotation tests cover all 16 combinations of existing page rotation and
  added document rotation, including offset crops and hidden corner marks.
  Tests also compare rendered single-page previews against full exports,
  verify all four button states, preserve per-page overrides, and check
  that small source pages scale up correctly at 50%, 75%, and 100%.
- Fixed fitting small/cropped pages: Core Graphics only scales down in its
  page drawing transform, so the exporter now applies the proportional fit
  explicitly after normalizing the visible, rotated page.
- Mac UI: launched the optimized build in a separate QA copy. Verified
  middle-center at 75%, then created a 63% top-left page override. Rotated
  with This page selected, navigated to another page, and confirmed the
  document rotation applied there while page layouts stayed independent.
  Cycled through 90/180/270/0 degrees and confirmed the override survived.
- Saved a 90-degree rotated four-page mixed-size reading through the native
  save panel. Independent `pypdf` checks confirmed Letter dimensions, source
  order, searchable text, and no raster images. `qpdf --check` passed. Poppler
  renders of Letter, pre-rotated, and cropped pages were inspected visually.
  The source's SHA-256 was unchanged. PDF Expert remains unverified here.
