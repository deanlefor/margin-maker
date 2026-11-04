# Margin Maker next steps

## Accepted working baseline

Version **0.2.0** was approved for the current reading workflow on
**November 3, 2026**. Preserve its small, single-purpose interface while
preparing a dependable release. The recommended order is a source checkpoint,
code audit, compatibility testing, and distribution preparation. Consider
additional features after using the app on real readings.

Margin Maker is already a native Mac program: SwiftUI controls, a PDFKit
preview, a Core Graphics conversion engine, and a built `.app` bundle. It
does not need a rewrite to become a Mac application. The remaining packaging
work concerns installation, signing, distribution, and support.

The accepted behavior is:

- PDF import with the original file protected from replacement.
- White portrait US Letter output, with selectable/searchable source text.
- Nine positions and a 50-100% slider, defaulting to **75%, middle-center**.
- All-page layout changes by default, with individual-page overrides.
- Document rotation in 90-degree clockwise steps, composed with each source
  page's existing orientation. Four clicks return to the original orientation.
- Matching preview and export, with crop clipping and proportional fitting.
- Fully local processing, without accounts, analytics, or runtime dependencies
  beyond Apple system frameworks.

The latest recorded validation is **18 native tests passing in both debug and
release**, eight Python reference tests passing, local Mac UI testing, and
independent inspection of exported PDFs. Details are in [TESTING.md](TESTING.md).
The current archive is `build/Margin Maker.zip`; it is ad-hoc signed for local
use, not a Developer ID signed or notarized public release.

## First preserve the baseline

- [ ] Initialize local Git history and commit the accepted source and project
  documentation. This folder is not currently a Git repository.
- [ ] Tag the baseline as `v0.2.0` and retain a versioned copy of the working
  ZIP with its checksum. Keep generated caches and personal PDFs out of Git.
- [ ] Choose whether and where to host the source later. Public hosting is a
  separate decision from making a local checkpoint.

**Complete when:** the source can be restored to the accepted version and its
working build can be identified independently of future builds.

## Then audit correctness and reliability

Start with the native implementation in `Sources/MarginMakerCore` and
`Sources/MarginMaker`. The Python prototype is a behavioral reference, not
the app's runtime. These are audit topics, not confirmed defects:

- [ ] Review crop/media box intersections, nonzero page origins, small-page
  enlargement, unusual dimensions, all anchors, and composed rotation.
- [ ] Review source-file protection, destination aliases, atomic writes,
  permissions failures, and interrupted or failed exports.
- [ ] Review asynchronous loading, stale preview cancellation, rapid slider
  and rotation changes, and opening another document during ongoing work.
- [ ] Measure responsiveness and peak memory with a long reading and a large
  scanned PDF. Add progress/cancellation controls only if that testing shows
  a practical need.
- [ ] Review keyboard access, VoiceOver labels, minimum window size, long
  filenames, and light/dark appearance.
- [ ] Confirm that source-annotation, link, form, outline, and signature
  limitations are accurately described to users. Preserve the workflow of
  preparing margins before annotation.
- [ ] Confirm the app has no networking or telemetry code and bundles only
  the intended executable, metadata, and license resources.

Record findings with severity, file/line references, a reproducible example,
and a focused fix. Add meaningful regression tests for confirmed failures.
Keep the approved controls and defaults intact.

**Complete when:** findings are documented, issues that threaten source files
or exported content are resolved, and applicable tests and UI checks pass.

## Verify real reading and installation workflows

- [ ] In **PDF Expert**, open an exported reading, search/select text,
  highlight it, write in a margin, save, and reopen. Repeat with rotation and
  a cropped or mixed-size reading. This check remains outstanding.
- [ ] Try representative single-column and two-column papers, scans, A4
  readings, rotated pages, and longer documents. Record concrete failures
  before expanding the interface.
- [ ] Decide the supported macOS versions and Mac architectures. The package
  declares macOS 13+, but physical testing so far covers macOS 27.0.1 on
  Apple Silicon. Test the oldest promised system; add Intel testing if Intel
  support will be advertised.
- [ ] Test on another Mac or a clean user account: extract the archive outside
  iCloud, move the app to Applications, launch it, import, preview, and export.
- [ ] Check replacement of an older installed version and opening a PDF from
  Finder. Ensure the installed version is easy to identify.

**Complete when:** the actual PDF Expert workflow passes, the compatibility
claims match tested systems, and a clean installation works without developer
tools or Python.

## Prepare a normal Mac release

Use a direct-download ZIP as the initial distribution candidate. A DMG can
follow if it improves installation. The Mac App Store can be evaluated later;
it is not necessary to keep using the native app locally. Apple documents
both distribution paths in its [macOS distribution guide](https://developer.apple.com/macos/distribution/).

- [ ] Choose a stable bundle identifier and the initial supported hardware.
- [ ] Add a finished app icon, useful About/Help content, and release notes.
- [ ] Set up Developer ID signing and the required release configuration,
  notarization, and ticket stapling using Apple's
  [notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
- [ ] Extend the existing build script to produce versioned release artifacts
  and checksums while keeping signing credentials out of the repository.
- [ ] Follow Apple's [packaging guidance](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
  and verify the final downloaded archive on a clean Mac with normal
  Gatekeeper settings. Keep the existing staging outside iCloud so synced
  Finder metadata does not contaminate the app bundle.
- [ ] Choose the download location and a lightweight way to report bugs.
  Manual downloads are sufficient initially; automatic updates can wait.

Notarization is a release-time step for the compiled app. Reading PDFs still
remain on the user's Mac during normal use.

**Complete when:** the audited build is signed, notarized, installable from
its actual download, and accompanied by accurate compatibility information,
license information, and instructions. Call that the first public release
only after the preceding audit and workflow checks are complete.

## Optional features after the release work

These are candidates, not commitments. Relative effort is an initial estimate
and may change after the audit. Choose one at a time based on actual use.

| Candidate | Benefit | Relative effort | Scope to preserve |
| --- | --- | --- | --- |
| Drag and drop a PDF | Quicker import | Small | Keep Open PDF and the existing workflow. |
| A small set of saved layouts | Reuse a favorite scale and position | Small to moderate | Keep 75% middle-center as the default unless the user explicitly chooses another layout. |
| Rotate an individual page | Fix a reading with one sideways page | Moderate | Define how page rotation composes with document rotation and the scope control first. |
| Apply a layout to a page range | Configure sections of longer readings | Moderate | Preserve All pages and This page as the main interaction. |
| Landscape Letter or A4 output | Support another annotation workflow | Moderate | Add explicit output-size tests; retain portrait Letter as the default. |
| Optional automatic content trimming | Reclaim excessive whitespace | Larger | Keep it opt-in and previewable; preserve text and avoid clipping reading content. |

Annotation editing, OCR, AI, batch processing, syncing, accounts, subscriptions,
and telemetry remain outside the first-version scope in [AGENTS.md](AGENTS.md).

## Next work session

The recommended next engineering task is **a focused code audit with small,
tested correctness fixes where warranted**. Use [CODEX_TASK.md](CODEX_TASK.md)
as the handoff. Keep feature expansion separate from preparing the accepted
workflow for release.
