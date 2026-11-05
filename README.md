# Margin Maker

A small, free macOS utility that adds room for notes around PDF readings.
Position each reading on a white US Letter page, then export a new PDF before
highlighting or handwriting in PDF Expert or another annotation app.

Academic readings rarely leave enough space for handwritten notes. Margin Maker
does one job: make that space, without becoming a PDF editor.

## Known limitations

- **PDF text semantics:** Certain PDFs using `/ActualText` may lose replacement-text
  information during conversion. Copying, searching, and accessibility can be
  affected even when the pages look correct. Ordinary vector text and conventional
  invisible OCR layers pass the tested fixtures, but the application **does not
  guarantee lossless preservation of all PDF structures**. Original source
  documents are protected from replacement. There is no automatic `/ActualText`
  detector. See [the compatibility report](COMPATIBILITY.md) and the detailed
  [investigation for contributors](ACTUALTEXT_SAFEGUARD.md).
- **Annotations:** Keep your original PDFs and prepare margins **before**
  highlighting or handwriting. Existing annotations are not guaranteed to survive
  conversion. Links, forms, outlines, signatures, and accessible document structure
  are not migrated.
- **Mac compatibility:** The public ZIP contains only Apple Silicon (arm64) code.
  **macOS 13 and Intel compatibility remain unverified**, as does clean installation
  on another Mac. Local testing covers Apple Silicon on macOS 27.0.1.
- **Signing:** The app is ad-hoc signed, without Developer ID signing or Apple
  notarization. macOS may display security warnings. See [installation instructions](INSTALL.md)
  and [Apple's official opening guidance](https://support.apple.com/en-us/102445).
- Password-locked PDFs need an unlocked copy from another PDF application.
  Scans without OCR remain images; Margin Maker does not add OCR or trim content.
- A cross-volume copy creates a new file identity; reopen that copy to protect it
  as the imported source. Concurrent external changes to export destinations and
  power-loss durability have limits described in [TESTING.md](TESTING.md).
- An individual Core Graphics page draw cannot be interrupted midway. Large
  pages can delay the next preview or queued import.

The `/ActualText` limitation is accepted and disclosed for **v0.3.0**. It remains
a known issue, not a claim of complete text preservation.

## Download and install

1. [Download Margin Maker v0.3.0 for Apple Silicon (ZIP)](https://github.com/deanlefor/margin-maker/releases/download/v0.3.0/Margin.Maker.0.3.0.macOS.Apple.Silicon.zip).
   The [public release](https://github.com/deanlefor/margin-maker/releases/tag/v0.3.0)
   also includes release notes; its source-code archives are for building from source.
2. Double-click the ZIP in Finder to extract it outside iCloud or other synced storage.
3. Open **Margin Maker.app** from the extracted folder. Keep it separate from older
   copies so you launch this version. If macOS blocks it, follow the application-specific
   steps in [INSTALL.md](INSTALL.md).

The download is **v0.3.0, build 4**, and requires no build tools. [INSTALL.md](INSTALL.md)
includes the SHA-256 checksum, security-warning guidance, and details about the
unchanged archive's historical documentation.

## Use

1. Click **Open PDF**, press Command-O, or drop one PDF from Finder onto the window.
2. Choose **Portrait** (8.5 × 11 inches, default) or **Landscape** (11 × 8.5 inches).
   Orientation applies to the whole document; the source reading stays upright.
3. Choose one of nine positions and a scale from **50% to 100%**. Defaults are
   **75%, middle-center**. At 100%, the visible source page fits proportionally
   inside Letter; smaller percentages scale that fitted size. Content is never stretched.
4. Keep **All pages** selected, or choose **This page** to customize individual pages.
   Use the arrows or Command-[ / Command-] to navigate.
5. Click **Export PDF** or press Shift-Command-E to save a new copy, then annotate it.

The exported PDF has one Letter page per original page, in the original order.
The imported source is protected from replacement. Keep it for reference.

### Development version: edge offsets and version display

On `codex/margin-maker-v2`, **Horizontal** and **Vertical** edge offsets accept
numeric inches in 0.01-inch increments (for example, 0.25, 0.50, or 0.75).
Both default to 0.00. They inset
opposite edges equally: left/right and top/bottom anchors move inward by the
chosen amount, while centered axes remain centered. Offsets follow **All pages**
or **This page**, just like scale and position, and update the preview as you type.
Click or Tab into a field to select its current value; subsequent clicks allow
ordinary cursor editing. A blank draft is allowed while editing and restores the
last valid value when you leave the field (or zero if that value no longer fits).
Each field shows its allowed range for the selected scope and scale. Limits
update with source dimensions, crops/rotation, output orientation, and scale.
Completed inputs and ranges use two decimal places. Maximum values round down
to the nearest hundredth; extra decimal places are rejected with a clear message
instead of silently rounded. Input formatting occurs on blur so decimal typing
stays straightforward. The ranges stay visible beneath the fields; there are no
hover tooltips. Keyboard navigation and VoiceOver labels/range guidance remain
available. PDF placement calculations retain full precision.

Scale always means the same proportional fit to the full Letter page. If the
scaled reading cannot fit inside the inset area, a warning identifies the first
affected page and export is disabled. Reduce an offset or explicitly choose a
smaller scale. Invalid numeric input also blocks export and reports the allowed
range. An unfinished blank draft keeps the last valid preview and waits for blur
to restore the value before export. The current preview is
cleared when its settings are invalid, so it cannot show an obsolete placement.

The footer shows the packaged version, build, and development channel. This
branch builds a separate **Margin Maker Dev.app**, with its own bundle identity,
for the proposed 0.4.0 version. It is unreleased. The published v0.3.0 download
above and all historical tags remain available. See [development review](DEVELOPMENT.md).

## Build from source

Use a Mac with **Swift 6.0 or later**, supplied by Xcode or Apple's Command Line
Tools. From the repository directory:

```bash
bash scripts/build-app.sh release build/v2-review
```

This development branch creates **Margin Maker Dev.app** and **Margin Maker Dev.zip**
in that directory. To build the historical release, use a separate checkout of
`v0.3.0` and its original build instructions.
Choose a fresh output directory: the script refuses to overwrite an app or ZIP.
Use `debug` instead of `release` for a development build. Extract the ZIP outside
iCloud or other synced storage before opening the app. See [INSTALL.md](INSTALL.md).

The native build uses Apple frameworks and downloads no third-party packages.
It builds for the current Mac's architecture, generates the approved icon with
`sips`/`iconutil`, and signs locally with an ad-hoc signature. No Apple developer
account is needed. The public v0.3.0 download is the verified Apple Silicon build.
Developer ID signing, Apple notarization, and installers are not included.

## macOS compatibility

**Tested:** Apple Silicon, macOS 27.0.1, Apple Swift 6.2.3 with Command Line Tools.
The package declares a macOS 13 deployment target, but **macOS 13 and Intel Macs
are unverified**. Building on the current machine does not establish compatibility
with those configurations. Clean installation on another Mac is also unverified.

## Privacy

PDF processing happens locally on your Mac and works fully offline. Margin Maker
has no uploads, accounts, analytics, telemetry, subscriptions, automatic updates,
or application networking. You choose where to save the exported copy; a folder
managed by iCloud or another sync service follows that service's settings.

## Tests and contributions

```bash
bash scripts/test.sh
bash scripts/test.sh -c release
```

[TESTING.md](TESTING.md) includes optional Python reference tests, independent PDF
checks, and current results. Tests generate synthetic documents; no personal
readings are included. Python, qpdf, and Poppler are development tools only.

The application lives in `Sources/MarginMaker` and `Sources/MarginMakerCore`.
`margin_maker/core.py` is an optional Python behavioral reference, not an app
dependency. See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md),
and the [MIT license](LICENSE).
