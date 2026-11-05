# Margin Maker v0.4.0

Final public release candidate: **0.4.0, build 5**, Apple Silicon (arm64).
Production identity: **Margin Maker.app**, `local.marginmaker.app`, Release channel.
This package awaits final approval; no v0.4.0 tag or public release has been published.

Margin Maker is a free, offline macOS utility that creates annotation space
around PDF readings before you mark them up in PDF Expert or another PDF app.

## New in v0.4.0

- Adjustable horizontal and vertical edge offsets, in inches, alongside the
  existing nine-position grid, 50-100% scale, and Portrait/Landscape Letter output.
- Two-decimal inputs and dynamic allowable ranges. Maxima round down to valid
  hundredths; PDF geometry keeps full precision. Zero offsets preserve earlier positioning.
- Initial click/Tab selects the existing value; later clicks support normal
  cursor editing. Blank drafts restore the last valid value on blur, or 0.00.
- Clear range/precision warnings block invalid exports without changing scale
  or clipping content. Apply changes to all pages or customize individual pages.
- A small footer version indicator: **v0.4.0 (5)**, read from the application bundle.
- Visible ranges beneath fields, keyboard navigation, and VoiceOver labels/range
  guidance. Range hover tooltips are removed.

Imported originals remain protected. Exported pages retain original order and
ordinary selectable vector text in the verified synthetic fixtures. Processing
stays offline, with no uploads, accounts, analytics, subscriptions, or networking.

## Compatibility and limitations

Tested locally on **Apple Silicon, macOS 27.0.1**, Apple Swift 6.2.3 with Command
Line Tools. The ZIP is arm64 only. The declared minimum is macOS 13, but macOS 13,
Intel compatibility, and installation on another Mac remain unverified.

The app is **ad-hoc signed and not Apple-notarized**, without Developer ID signing.
Follow INSTALL.md and Apple's application-specific opening guidance if macOS blocks it.

**Retain originals and prepare margins before annotation.** Existing annotations
are not guaranteed to survive. Some PDFs using **/ActualText** lose replacement-text
information, affecting copy/search/accessibility even when visually correct.
The app does not guarantee lossless PDF structure preservation and has no automatic
ActualText detector. Links, forms, outlines, signatures, and accessible structure
are not migrated. See COMPATIBILITY.md and ACTUALTEXT_SAFEGUARD.md.

The full PDF Expert highlighting, handwriting, save, close, and reopen workflow
on this exact candidate remains a final manual approval check.

## Installation and verification

Extract the ZIP into a fresh folder outside synced storage. Keep existing apps
and release archives untouched. Quit an older running production copy yourself,
open the extracted Margin Maker.app, and confirm v0.4.0 (5) in the footer.

The final ZIP byte count and SHA-256 are supplied alongside the archive and in
the proposed GitHub release notes. The existing v0.3.0 release, assets, and direct
download link remain available; neither historical tag is replaced.
