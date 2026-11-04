# Local verification

Run `bash scripts/test.sh` for the native engine and document settings tests.
The tests create their own PDFs in memory; they never read personal documents.
The optional Python prototype tests use `requirements-dev.txt`.

The native suite verifies:

- Exact 75% middle-right Letter margins: 153 pt left and 99 pt top/bottom.
- All nine anchors, with pixel bounds checked in rendered exported PDFs.
- Portrait and Landscape Letter output with all nine anchors at 50%, 75%, and 100%.
- Letter, A4, landscape, oversized, and small source pages fitted without distortion.
- 0/90/180/270-degree rotation with independently positioned corner marks.
- Both output orientations respect all four existing source rotations, including crops.
- Small pages and crops enlarged to the correct Letter fit at each scale.
- Single-page previews render identically to their full export pages in both orientations.
- Offset crop boxes at all four rotations, including clipping hidden content.
- Letter dimensions, selectable/searchable text, and source page order.
- Single-page preview, per-page overrides, and all-page adjustments.
- Empty/invalid/password-locked input and invalid settings/page indices.
- Source byte preservation and protection of paths, symlinks, hard links,
  and case aliases on case-insensitive volumes.
- Import-time identity protection after source/file-directory renames and moves,
  retargeted import symlinks, unlinked hard links, and Finder aliases.
- Destination changes after staging, pinned destination-directory replacement,
  cleanup after rejected/failed replacement, and failed staging without data loss.
- Serialized/coalesced previews, cancellation before and during single-page
  drawing, revision/error guards, queued imports during import/export, and
  recovery without losing the current document or a failed-export message.
- Finder file-URL representations, PDF candidate hover/exit state, drop ordering,
  protected import after drops, invalid providers, unsupported files, and aliases.
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
11. Confirm Page Orientation defaults to Portrait (8.5 × 11 in). Switch to
    Landscape (11 × 8.5 in) and confirm the white canvas becomes wider while
    the reading stays upright. Navigate to another page and verify Landscape
    applies there too, even with This page selected. Switch back to Portrait
    and confirm individual settings survive. Export in both orientations and
    verify page dimensions, crop clipping, text selection, and preview agreement.

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

### Focused source-file protection fix

Validation on this Apple Silicon Mac: **28 native tests passed in debug and
28 passed in release**, including 10 new tests with 13 filesystem scenarios.
The non-root permission-failure test executed and passed in both configurations.
The existing Command Line Tools warning about Testing.framework's macOS 14
minimum remains limited to the test executable; app deployment remains macOS 13.

The `fix/source-file-protection` branch starts at the accepted `v0.2.0` tag.
Import now reads PDF bytes and captures device/inode identity through the same
file handle. That read handle remains open with the source snapshot, preventing
inode reuse while the imported file is protected. Both the imported path and its
resolved path remain reserved as an additional conservative check.

Exports use an exclusively created temporary sibling in a pinned directory.
After writing, synchronizing, and closing the staged PDF, the writer rechecks
the destination and immediately calls directory-relative `renameat`. Errors
remove the staging file and leave existing destination/source data intact.

Regression coverage includes renamed/moved source files and source directories;
case, relative-path, directory-symlink, hard-link, and Finder aliases; import
symlink retargeting; hard-link unlink/path reuse; independent copies and new
destinations; and source/alias substitutions after staging. Directory-rename
and failure tests check that writes cannot be redirected to a different parent
and that temporary files are cleaned up. Permission tests require a non-root
test process.

Limits: a cross-volume copy/delete creates a new identity and must be reopened
to become the protected source. A small final `fstatat`-to-`renameat` race remains
if another process changes the final directory entry in that interval; validation
and replacement are not one conditional filesystem operation. No original is
opened for writing. Power-loss durability and coordination with arbitrary
concurrent external filesystem mutations are not guaranteed.

Build/test products for this fix are isolated under
`/private/tmp/margin-maker-source-protection`. The accepted app/ZIP are not
rebuilt, installed, or replaced; interface, defaults, and PDF rendering are
unchanged. Other audit findings are outside this fix.
The accepted app executable and working ZIP SHA-256 hashes were unchanged after
both full test runs. The debug and release logs are retained in the isolated
test directory as `debug-tests.log` and `release-tests.log`.

### Page Orientation feature QA

Branch `feature/page-orientation` starts from clean main at `78e19c8`, retaining
the source-file protection fix. Portrait (612 × 792 pt, default) and Landscape
(792 × 612 pt) replace the four-state document rotation. The canvas orientation
applies to every page; the source's existing PDF rotation is honored without
adding rotation. Each page keeps its anchor and scale settings.

- Complete native suite: **28 passed in debug and 28 passed in release** on
  this Apple Silicon Mac. Existing file-protection regressions also pass.
- Rendered regression coverage checks all nine anchors at 50%, 75%, and 100%
  in both orientations, mixed source dimensions, all four source rotations,
  hidden crop content, small/cropped-page enlargement, searchable/selectable
  text, and highlight annotations that survive reopening.
- Single-page previews and the corresponding full-export pages match pixels
  in both orientations, including mixed sizes/rotations/crops and page overrides.
  Raster edge checks allow one pixel per edge for antialiasing; layout geometry
  and page dimensions are checked independently.
- Separate optimized QA app: verified default Portrait, Landscape canvas with
  upright reading content, a 63% top-left This page override, switching back
  to Portrait, navigation to a different 75% middle-center page, and return to
  the preserved override. Landscape applies to both pages despite This page scope.
- Saved four-page Portrait and Landscape PDFs through the native save panel.
  All eight exported pages match engine-generated expected settings pixel for
  pixel. Independent `pypdf` checks confirm dimensions, page order, text, no
  residual rotation, and no raster images; `qpdf --check` passes for both files.
- The QA bundle and a fresh ZIP extraction pass `codesign --verify --strict`.
  Its display name is **Margin Maker Orientation QA** and its bundle identifier
  is `local.marginmaker.orientationqa`, separate from the running accepted app.

The QA archive is `build/qa-page-orientation/Margin Maker Orientation QA.zip`.
Extract it outside iCloud before launching. The tested local app is at
`/private/tmp/margin-maker-page-orientation/qa-build/Margin Maker Orientation QA.app`.
Test logs, generated fixtures, and GUI exports are under
`/private/tmp/margin-maker-page-orientation`. The archive is ad-hoc signed for
local testing; it is not a notarized distribution build.

Main and the existing `v0.2.0` tag are unchanged. The original app executable
and working ZIP retain their prior SHA-256 hashes; the installed/running app was
not replaced or closed. PDF Expert, macOS 13, and Intel hardware remain
unverified. Existing source annotations/links/forms are still not migrated,
and this change does not auto-correct readings that are already sideways.

### Reliability and drag-and-drop QA

Stage 1 reviewed `30fdedf` against main without significant findings and
fast-forward merged it. Main therefore contains both source protection
(`78e19c8`) and Portrait/Landscape output. Stage 2 is isolated on
`feature/reliability-and-drag-drop` and must remain unmerged pending user QA.

- Complete native suite: **48 passed in debug and 48 passed in release** on
  this Apple Silicon Mac. All 28 prior tests still pass, alongside 20 new
  application-state, drop-provider, and cancellation tests.
- Controlled detached workers prove maximum preview concurrency of one,
  replacement of intermediate pending settings by the latest request, continued
  main-actor control changes, and suppression of stale results and errors even
  when an old worker ignores cancellation.
- A complex single-page PDF tests in-flight cancellation after drawing. Already
  cancelled work also fails without returning a PDF. The PDF context is closed
  on cancellation/errors, and cancellation is checked after finalization too.
- Controlled imports/exports verify latest pending URL wins, intermediate opens
  are skipped, superseded imports cannot replace the current document, failed
  new imports preserve source/settings/preview, and queued imports do not hide
  an export failure. Queued and dropped imports retain original-file identity
  protection after renames.
- Drop tests exercise actual NSItemProvider URL, data, and string representations;
  a single PDF candidate's hover/exit state; late hover/provider completions;
  drops queued during export; invalid/remote providers; corrupt PDFs; multiple
  files; folders; unsupported types; symlinks; and Finder aliases. PDF bytes are
  loaded from the original URL by the shared protected importer, not copied
  from a temporary provider representation.
- Headless AppModel benchmark on the 300,000-rectangle audit fixture: one update
  settled in about **0.71 seconds**. Eight changes over **0.67 seconds** settled
  in **1.40 seconds**, using **1.22 CPU seconds**. Main-actor update gaps stayed
  at or below **0.086 seconds**. This measures conversion/state responsiveness,
  not full PDFView display latency or a guarantee for arbitrary PDFs.
- The separately named optimized QA app launches, opens the synthetic reading
  through the native picker, responds to a native slider drag, and saves both
  Portrait and Landscape documents through the save panel at 75% middle-right.
  Independent pypdf/qpdf checks confirm four pages, correct Letter dimensions,
  source order, searchable vector text, no residual output rotation, and no
  added raster images. Rendered pages were inspected for upright placement.
- PDFKit adds a highlight to selected text and an ink stroke in the margin,
  then saves/reopens both output orientations with both annotations and text
  intact. This supports the post-export annotation workflow but does not
  substitute for testing PDF Expert itself.

The QA candidate is named **Margin Maker Reliability QA**, with bundle ID
`local.marginmaker.reliabilityqa`. Its archive is
`build/qa-reliability-and-drag-drop/Margin Maker Reliability QA.zip`.
The local QA app is under `/private/tmp/margin-maker-reliability-drag-drop/qa-final`.
Builds, test logs, benchmark output, generated fixtures, and GUI exports are
under `/private/tmp/margin-maker-reliability-drag-drop`. It is ad-hoc signed for
local testing; extract outside iCloud before launching or installing alongside
the accepted application.

Remaining manual checks:

- **Physical Finder drag/drop and its visible hover border remain unverified.**
  The automation did not initiate a file drag, including in a Finder-to-Finder
  control test with disposable files. The provider/queue tests above pass,
  but do not establish end-to-end physical dragging. Test one PDF over the
  empty workspace, sidebar, and existing PDF preview; also try an unsupported
  file and a multiple-file drop.
- PDF Expert's highlight/write/save/reopen workflow, macOS 13, and Intel hardware
  remain unverified. The old annotation/link/form migration limitations and
  the source-identity cross-volume/final-rename race limits remain unchanged.
- An in-progress Core Graphics page draw cannot be interrupted midway. The
  pending preview waits for that worker to finish before starting the latest
  request. A large import/export similarly completes before a pending open.

The v0.2.0 tag is preserved. Existing working app executables and ZIPs were
hashed before Stage 1 and verified unchanged. The installed/running app was
not modified or closed. Stage 2 is not merged, pushed, published, or distributed.
