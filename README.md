# Margin Maker

A small, free macOS utility that adds room for notes around PDF readings.
Position each reading on a white US Letter page, then export a new PDF before
highlighting or handwriting in PDF Expert or another annotation app.

Academic readings rarely leave enough space for handwritten notes. Margin Maker
does one job: make that space, without becoming a PDF editor.

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

## Build from source

Use a Mac with **Swift 6.0 or later**, supplied by Xcode or Apple's Command Line
Tools. From the repository directory:

```bash
bash scripts/build-app.sh release build/personal-0.3.0
```

This creates **Margin Maker.app** and **Margin Maker.zip** in that directory.
Choose a fresh output directory: the script refuses to overwrite an app or ZIP.
Use `debug` instead of `release` for a development build. Extract the ZIP outside
iCloud or other synced storage before opening the app. See [INSTALL.md](INSTALL.md).

The native build uses Apple frameworks and downloads no third-party packages.
It builds for the current Mac's architecture, generates the approved icon with
`sips`/`iconutil`, and signs locally with an ad-hoc signature. No Apple developer
account is needed. This project publishes source; Developer ID signing,
notarization, installers, and public binary distribution are outside this release.

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

## Known limitations

- **PDF text semantics:** Certain PDFs using `/ActualText` may lose replacement-text
  information during conversion. Copying, searching, and accessibility can be
  affected even when the pages look correct. Ordinary vector text and conventional
  invisible OCR layers pass the tested fixtures, but the application **does not
  guarantee lossless preservation of all PDF structures**. Original source
  documents are protected from replacement. There is no automatic `/ActualText`
  detector. See [the compatibility report](COMPATIBILITY.md) and the detailed
  [investigation for contributors](ACTUALTEXT_SAFEGUARD.md).
- **Annotations:** Prepare margins **before** highlighting or handwriting.
  Existing annotations are not guaranteed to survive conversion. Links, forms,
  outlines, signatures, and accessible document structure are not migrated.
- Password-locked PDFs need an unlocked copy from another PDF application.
  Scans without OCR remain images; Margin Maker does not add OCR or trim content.
- A cross-volume copy creates a new file identity; reopen that copy to protect it
  as the imported source. Concurrent external changes to export destinations and
  power-loss durability have limits described in [TESTING.md](TESTING.md).
- An individual Core Graphics page draw cannot be interrupted midway. Large
  pages can delay the next preview or queued import.

The `/ActualText` limitation is accepted for **v0.3.0 personal use and source
publication**. It remains a known issue, not a claim of complete text preservation.

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
