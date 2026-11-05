# Review the next Margin Maker version

**Historical development record.** The final v0.4.0 candidate now uses production
identity, Release channel, build 5, and footer v0.4.0 (5). The Dev identities and
builds described below are historical review packages, not the production ZIP.
This record is retained in source and is not bundled with the release candidate.
See RELEASE_0.4.0.md, RELEASE_NOTES_0.4.0.md, and NEXT_STEPS.md for current status.

Work is isolated on `codex/margin-maker-v2`, based on main `45417d1`. The checkout
was clean before branching. Main and the existing tags have not moved. Local
development commits on this branch are authorized. Pushing, merging, creating a
release/tag, installing over an existing app, and website changes remain outside
the scope of this review.

## Preserved baseline

Before development, GitHub and local tag objects agreed:

| Ref | Tag object | Target commit |
| --- | --- | --- |
| v0.2.0 | f17dc4bf2303b79e4b5002bc914e1eb025e91994 | e707124 |
| v0.3.0 | da62c55938c0c512d1401773caf0a13109540edb | b96d985 |

GitHub has one published release, v0.3.0, including its existing Apple Silicon ZIP.
v0.2.0 is preserved as a tag; it does not have a separate GitHub release record.
The v0.3.0 ZIP's recorded SHA-256 is
`43c50baec087bd47f04ad401ee3a9bf1edfda4f2d61d1b6ada3463d41fa14bbc`.
Historical release records in RELEASE_CHECKLIST.md are retained as written.

## Offset behavior

Offsets are nonnegative decimal inches. Horizontal reserves the same inset at
left and right; vertical reserves the same inset at top and bottom. The selected
anchor places the reading within that rectangle. Center remains center, including
when only one axis is centered. For a 75% portrait Letter source with 0.5-inch
offsets, upper-left starts 36 pt from the left and top; upper-right ends 36 pt
from the right and top. A centered page keeps its original placement.

The fitted source size and scale calculation are unchanged. Available width is
canvas width minus twice the horizontal offset; height follows the same rule.
If either is smaller than the scaled reading, the setting is invalid for every
anchor, including center. No automatic shrink, clamp, or clipped export occurs.
The inline warning identifies the first invalid page, including offscreen
overrides. Invalid current settings clear the preview; valid current pages can
still preview while another page blocks export. Correct the offsets or scale to
resume. Crop and rotation handling and vector drawing use the existing engine.

## Version authority

Packaging/Info.plist holds CFBundleShortVersionString (proposed 0.4.0),
CFBundleVersion (development build 3), and MarginMakerBuildChannel (Development).
The footer reads Bundle.main at runtime: `v0.4.0 · Development (3)`. Compiler
configuration does not imply publication: both debug and optimized builds show
Development. Direct `swift run` executions without bundle metadata show
`Unbundled development build` rather than inventing a version.

The same plist supplies the build script's default name and bundle identifier:
Margin Maker Dev / local.marginmaker.development. Existing paired QA overrides
still work. Packaged apps are ad-hoc signed and the script refuses existing app
or ZIP paths. Keep using fresh output directories. Version/build values are not
duplicated in application source or substituted by the build script. Increment
the build in the plist for subsequent distributed review builds.

## Local review

```bash
git status --short --branch
git diff --stat
git diff
bash scripts/test.sh
bash scripts/test.sh -c release
bash scripts/build-app.sh release build/v2-review
```

Use a new directory if that output already exists. Extract **Margin Maker Dev.zip**
outside iCloud/synced storage, and launch **Margin Maker Dev.app** from there.
Keep the released app in its existing location. The separate app name and bundle
identifier allow both versions to coexist without installing over either one.

The initial review package (build 1) remains in the ignored directory
`build/v0.4.0-development-review-final/`. The build 2 input usability update remains
in `build/v0.4.0-development-inputs/`. Build 3, with two-decimal precision and
tooltip removal, is in `build/v0.4.0-development-hundredths/`. Quit the older Dev
app yourself before opening the new Dev app, and check the footer for build 3.
No existing release or review package is replaced.

1. Confirm the footer version before and after opening a PDF. Check the smallest
   window size; the controls scroll if needed.
2. Open a disposable mixed-size multipage PDF. Confirm All pages, 75%, centered,
   and both offsets zero. Compare zero-offset export with v0.3.0.
3. Try 0.25, 0.5, and 0.75 inches, all nine anchors, 50%/75%/100%, and both output
   orientations. At 100% on a matching Letter page, positive offsets must warn.
4. Click or Tab into each field and type without manually selecting text: the
   existing value should be replaced. Click again to position the cursor, then
   edit normally. Clear and leave each field: its last valid value should return
   without an error. Try decimals, negative/nonnumeric/over-limit values, and
   verify the displayed ranges and specific validation limits. Test a per-page override and
   navigate away/back. Check that a warning on another page blocks whole export.
5. Export a valid mixed document. Check order, dimensions, copy/search, and source
   bytes. In PDF Expert, add highlights and handwriting, save, and reopen.

The existing ActualText/annotation limitations remain documented in
COMPATIBILITY.md; this feature does not change PDF semantic preservation.

## Changed files

| Files | Purpose |
| --- | --- |
| Sources/MarginMakerCore/PageLayout.swift, PDFEngine.swift | Offset geometry, validation, actionable errors |
| Sources/MarginMaker/AppModel.swift, ContentView.swift | Numeric controls, page validation, preview/export behavior, footer |
| Sources/MarginMaker/AppVersion.swift | Runtime bundle version/build/channel label |
| Sources/MarginMaker/OffsetTextField.swift | Native initial-focus selection, normal editing, and blur callbacks |
| Packaging/Info.plist, scripts/build-app.sh | Development metadata/identity and packaging defaults |
| tests/MarginMakerCoreTests/PDFEngineTests.swift, OffsetControlsTests.swift | Geometry, offset validation, range and blank recovery regressions |
| tests/MarginMakerCoreTests/OffsetTextFieldTests.swift | Field-editor timing, cursor protection, and native delegate regressions |
| README.md, CHANGELOG.md, TESTING.md, DEVELOPMENT.md | Usage, development record, verification and review instructions |

## Build 3 hundredth-inch input verification on November 4, 2026

Completed fields, range endpoints, and numeric validation limits use exactly two
decimal places. The maximum is the largest hundredth no greater than the actual
full-precision allowance: for example, 1.0625 displays as 1.06 and 1.375 as 1.37.
Binary rounding at exact cent boundaries is handled without advertising a value
above the actual maximum. The underlying PDF engine and geometry files are
unchanged; only interface input precision/formatting and validation are limited.

Typing supports temporary blanks and partial decimals, then normalizes valid
numbers on blur (1 becomes 1.00; .5 becomes 0.50). More than two decimal places,
scientific notation, and nonnumeric entries remain editable with an explicit
range/precision error; they are not silently rounded or exported. Blank recovery
still restores the last valid hundredth or 0.00. Merely focusing/leaving a valid
field does not apply All pages or erase per-page overrides.

The native field's toolTip is nil. Allowed ranges remain visible below each
field and in VoiceOver accessibility help, along with the axis, inch units, and
0.01-inch precision guidance. Tab/Shift-Tab and initial click selection are
unchanged. Full VoiceOver speech output is not automated by the test suite.

All 78 native tests pass in debug and release. New and updated regressions cover
two-decimal formatting, rejection of extra decimal places, strict downward
maxima, acceptance of displayed boundaries in both orientations at 50/75/100%,
and full-precision core geometry. Live macOS QA verifies both default fields at
0.00, .5/.75 entry normalized to 0.50/0.75 on Tab/Shift-Tab, 1.07 rejected against
the 1.06 maximum, excess precision rejected with the specific two-decimal range,
and simultaneous acceptance of advertised 1.06/1.37 maxima. Accessible labels,
range help, and the visible range text remain present; no hover tooltip appeared.
The separately identified Precision QA app leaves existing Dev windows intact.
New packages use fresh output paths; existing
releases, tags, apps, archives, and the running Dev app remain untouched.

## Build 2 input usability verification on November 4, 2026

The PDF engine and placement calculations are unchanged from build 1. The UI
derives the maximum on each axis from the existing zero-offset placement:
`(canvas size - scaled source size) / 144` gives inches, reserving both edges.
For All pages, the displayed range is the smallest allowance across the source
pages at the current scale, since the next adjustment applies that scale to all
pages. For This page, it uses only the current source page. Existing overrides
are still validated individually for whole-document export. Ranges update with
scope, scale, orientation, source dimensions, crops, rotation, and page selection.
Displayed limits round down to six decimals with floating-point noise removed;
typing the advertised maximum is accepted by the unchanged fit tolerance.

The native text field handles both AppKit attaching its shared editor late and
attaching it before the initial mouseDown. Only the focus click selects all;
later clicks and keyboard editing retain normal cursor behavior. No field-editor
selection is reset merely because the SwiftUI model updates. Tab/Shift-Tab use
AppKit's standard key navigation.

A blank draft keeps the last accepted placement visible, without an input error,
and waits for editing to finish before export. On blur it restores that axis's
last valid value; if a changed setting makes that value impossible, it uses zero.
Invalid nonblank input remains editable with an explicit allowed range. Values
above the fitting limit report the affected axis/page, maximum, scale, and output
orientation. No automatic scale change, clipping, or offset clamp was added.

- All 75 native tests pass in debug and release, including nine additional
  regressions since build 1 and the original geometry/zero-offset/export tests.
- Live QA checks pass for both fields: click/select, 0 replaced with 1, later
  cursor edits, 0.5/0.75 entry, blank/blur recovery, Tab/Shift-Tab, and invalid
  values showing the actual limit. Ranges change at 50/75/100%, Portrait/Landscape,
  and when navigating Letter/A4/rotated pages with This page selected.
- The normal review package retains the Dev identity and shows development build
  2. UI testing used a separate Input QA identity so the user's running build 1
  app, open reading, and settings could remain intact.
- New apps/archives use fresh paths. All pre-existing release and review outputs
  are retained. No commit, push, merge, tag, release, or website edit occurred.

The full PDF Expert workflow and the historical platform/installation limits
below remain unverified. The native AppKit hidden-window focus test could not
obtain a field editor in the CLI environment; event/selection/delegate regression
tests and the real macOS UI checks cover this behavior instead.

## Initial build 1 verification on November 4, 2026

Apple Silicon, macOS 27.0.1, Apple Swift 6.2.3 with Command Line Tools:

| Check | Result |
| --- | --- |
| Baseline native suite before edits | 54 passed |
| Complete updated native suite | 66 debug + 66 release passed, eight suites each |
| Existing Python reference suite | Eight passed; Python prototype unchanged |
| Retained native exports | 21 debug + 21 release PDFs pass qpdf without warnings |
| New offset exports | Portrait/Landscape multipage dimensions, order and text pass pypdf and Poppler; representative renders inspected |
| Existing independent compatibility tool | Six exports structurally clean; ordinary multilingual and invisible OCR text pass; expected exit 2 for known ActualText loss |
| Release build and packaging | Compiled; new ad-hoc signed development app and ZIP generated; fresh extraction passes strict signature verification |
| Bundle metadata | Proposed 0.4.0, build 1, Development; separate name and identifier |
| Live extracted app | Footer before/after import, zero defaults, 0.5/0.75 offsets, upper anchors, live preview, Portrait/Landscape, This page navigation, 100% fit warning, negative input, export blocking/recovery checked |
| Save-panel export | Four landscape Letter pages, original order and selectable text; qpdf clean |
| Preservation | Main and both tag object IDs unchanged; all 14 pre-existing app executables/ZIPs retain SHA-256; public v0.3.0 asset digest unchanged |
| Existing-output guard | Build script refuses to replace the newly generated app/ZIP |
| Source hygiene | git diff --check and bash syntax checks pass; outputs/caches remain ignored |

Packaging initially hit the previously documented iconutil failure inside the
tool sandbox; the unchanged icon pipeline succeeded with local build permissions.
The known Testing.framework deployment and PDFKit/provider test log warnings
remain. No new dependency or network processing was added.

The UI smoke test used the default window size. Minimum-window scrolling,
macOS 13, Intel, installation on another Mac, and full PDF Expert
highlight/handwriting/save/reopen testing remain manual review items. Native
tests verify adding/saving PDFKit annotations, but do not establish PDF Expert
compatibility. This is a development build, not a release-ready declaration.

## Proposed release process — requires separate authorization

After local review and PDF Expert testing, review the development-branch commit.
Only after explicit authorization, push the branch and open a review,
then merge into main. For an approved release, set the channel to Release,
choose the final build number and normal app name/identifier in the same plist,
rerun tests and package into a fresh directory, and verify the extracted bundle.
Create a new v0.4.0 tag at the approved commit and a separate GitHub release/asset.
Never move v0.2.0 or v0.3.0, replace old assets, or delete earlier releases. Keep
the existing direct v0.3.0 download link usable. Any website or landing-page
change requires its own authorization and work in its own repository.
