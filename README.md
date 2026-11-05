# Margin Maker

A free, offline macOS utility that adds room for notes around PDF readings.
Position each reading on a white US Letter page, then export a new PDF before
highlighting or handwriting in PDF Expert or another annotation app.

## v0.4.0 release candidate

The final candidate is **Margin Maker 0.4.0, build 5**, using the production
bundle identifier `local.marginmaker.app` and the Release channel. Its footer
shows **v0.4.0 (5)**. This is the production application prepared for approval;
publication is pending. It has no Development label.

The currently published [v0.3.0 release](https://github.com/deanlefor/margin-maker/releases/tag/v0.3.0)
and its [Apple Silicon ZIP](https://github.com/deanlefor/margin-maker/releases/download/v0.3.0/Margin.Maker.0.3.0.macOS.Apple.Silicon.zip)
remain available and unchanged. The v0.2.0 and v0.3.0 tags are preserved.
See [installation instructions](INSTALL.md), [changes](CHANGELOG.md), and the
[approval/publication steps](NEXT_STEPS.md). No public website change is included.

## Use

1. Click **Open PDF**, press Command-O, or drop one PDF from Finder onto the window.
   The original is never modified or replaced.
2. Choose **Portrait** (8.5 x 11 inches, default) or **Landscape** (11 x 8.5 inches).
   Orientation applies to the output document; the source keeps its imported orientation.
3. Choose one of nine positions and **50% to 100%** scale. Defaults are **75%,
   middle-center**. At 100%, the visible source page fits proportionally inside
   Letter. Smaller percentages scale that fitted size; content is never stretched.
4. Set **Horizontal** and **Vertical** edge offsets in inches, in **0.01-inch**
   increments. Both default to **0.00**. Offsets inset opposite edges equally;
   edge/corner anchors move inward and centered axes remain centered.
5. Keep **All pages** selected, or choose **This page** to customize a page. Use
   the arrows or Command-[ / Command-] to navigate.
6. Click **Export PDF** or press Shift-Command-E to save a separate PDF, then annotate it.

The export has one Letter page per source page, in original order. Ordinary
vector text remains selectable/searchable in the tested fixtures. Read the
compatibility limitations below before converting important readings.

### Offset controls and validation

Click or Tab into a field to select its value; later clicks allow ordinary cursor
editing. Valid inputs normalize to two decimal places when you leave the field
(for example, .5 becomes 0.50). A temporary blank restores the last valid value
on blur, or 0.00 if that value no longer fits. Extra decimal places and nonnumeric
entries are rejected with a clear message, rather than silently rounded.

Each field displays its dynamic range beneath it. Maxima round down to the
nearest valid hundredth: 1.0625 becomes 1.06. Limits depend on source dimensions,
crops/rotation, output orientation, scale, and page scope. All pages uses the
smallest allowance across the document at the selected scale. Keyboard editing
and VoiceOver labels/range guidance remain available; there are no range hover tooltips.

Offsets never change the selected scale. A setting that cannot fit shows the
actual limit and affected page and disables export. Invalid current settings
clear the preview; a valid current page can still preview when another page
blocks the document export. Zero offsets preserve the earlier placement behavior.
PDF geometry retains full precision despite the two-decimal input controls.

## Compatibility and known limitations

- **PDF text semantics:** Some PDFs using `/ActualText` lose replacement-text
  information during conversion. Copying, searching, and accessibility may be
  affected even when pages look correct. Ordinary multilingual vector text and
  conventional invisible OCR layers pass the tested fixtures. The app does not
  guarantee lossless preservation of all PDF structures and has no automatic
  ActualText detector. Retain originals. See [COMPATIBILITY.md](COMPATIBILITY.md)
  and [ACTUALTEXT_SAFEGUARD.md](ACTUALTEXT_SAFEGUARD.md).
- **Annotations:** Prepare margins before highlighting or handwriting. Existing
  annotations are not guaranteed to survive. Links, forms, outlines, signatures,
  and accessible document structure are not migrated.
- **Macs:** The candidate ZIP contains **Apple Silicon (arm64)** code only.
  Tested locally on **macOS 27.0.1**, Apple Swift 6.2.3 with Command Line Tools.
  The declared minimum is macOS 13; **macOS 13, Intel compatibility, and clean
  installation on another Mac remain unverified**. Intel code is not in this ZIP.
- **Signing:** Ad-hoc signed, without Developer ID signing or Apple notarization.
  macOS may display security warnings; see [INSTALL.md](INSTALL.md).
- Locked PDFs require an unlocked copy. Scans without OCR remain images. The app
  adds no OCR and does not trim content. The full PDF Expert highlight/handwriting/
  save/reopen workflow on this exact candidate remains a final manual check.
- Cross-volume copies create new file identities; reopen the copy to protect it
  as the source. Concurrent external changes and power-loss durability have limits
  described in [TESTING.md](TESTING.md). Individual Core Graphics draws cannot be
  interrupted midway, so large pages may delay queued work.

## Build from source

Use a Mac with **Swift 6.0 or later**, supplied by Xcode or Apple's Command Line Tools:

```bash
bash scripts/build-app.sh release build/v0.4.0-local
```

A fresh directory receives **Margin Maker.app** and **Margin Maker.zip**. The
script refuses to overwrite either. Use debug instead of release for compiler
configuration; bundle version/channel still come from Packaging/Info.plist.
Extract ZIPs outside synced storage before opening. Do not replace an existing
application during candidate review. Historical builds remain available from
separate checkouts of their tags.

The native app uses Apple frameworks, downloads no third-party packages, builds
for the current Mac's architecture, generates the approved icon with sips/iconutil,
and signs locally with an ad-hoc signature. There is no installer, Developer ID
signing, or notarization pipeline. Python is an optional behavioral reference.

## Privacy

PDF processing stays on your Mac and works offline. There are no uploads,
accounts, analytics, telemetry, subscriptions, automatic updates, or application
networking. Saving into iCloud or another synced folder follows that service's settings.

## Tests and contributions

```bash
bash scripts/test.sh
bash scripts/test.sh -c release
```

[TESTING.md](TESTING.md) describes synthetic fixtures, independent qpdf/Poppler/
pypdf checks, evidence, and manual checks. The app is in Sources/MarginMaker and
Sources/MarginMakerCore. margin_maker/core.py is not an application dependency.
See [CONTRIBUTING.md](CONTRIBUTING.md) and the [MIT license](LICENSE).
