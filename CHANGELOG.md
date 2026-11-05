# Changelog

## 0.4.0 - unreleased development

- Add numeric horizontal/vertical edge offsets in inches, defaulting to zero,
  with symmetric insets and the existing nine anchors and page scopes.
- Preserve the selected scale; warn and block export when offsets cannot fit.
  Validate all pages, clear invalid previews, and reject invalid numeric input.
- Display version/build/channel from the app bundle in the footer. Keep metadata
  in Packaging/Info.plist and give development packages a separate name/identity.
- Development build 2: select the existing numeric value on initial focus, allow
  normal cursor editing afterward, restore blank fields on blur, and show dynamic
  inch ranges with specific validation limits. Keep PDF placement unchanged.
- Development build 3: format completed offsets, ranges, and validation limits to
  two decimals; round maxima down to valid hundredths and reject excess input
  precision. Remove range hover tooltips while retaining visible ranges,
  keyboard navigation, and VoiceOver guidance. Keep full PDF geometry precision.
- Add geometry, rendered PDF, text, preview/export, input, scope, and version tests.

No release or tag has been created. v0.2.0 and v0.3.0 remain unchanged.

## 0.3.0 - 2026-11-04

Changes since the accepted v0.2.0 baseline:

- Replace four-state document rotation with whole-document Portrait/Landscape
  Letter canvases. Imported readings keep their existing orientation; nine
  anchors, scaling, and individual-page overrides remain available.
- Protect the imported original by retained file identity across same-filesystem
  renames and moves, symlinks, hard links, Finder aliases and alternate paths.
  Stage exports beside the destination and validate immediately before replacement.
- Serialize expensive preview conversion, coalesce pending settings, check
  cancellation after drawing/finalization, and retain stale-result guards.
- Queue the latest picker/Finder/drop open request while busy. Failed imports
  preserve the current reading, settings, and preview.
- Accept one PDF dropped across the main application area, with subtle feedback.
- Integrate the approved Concept C icon, including all standard macOS sizes and
  transparent corners, through the native build pipeline before signing.
- Repair Quartz's unused zero-offset xref entries without rewriting page content.
- Expand native regressions to 54 tests, including multilingual text and an
  invisible OCR layer, and add an independent compatibility reproduction tool.
- Package version 0.3.0, build 4, with separate normal and QA identities and
  documentation. Existing apps and ZIPs are refused rather than overwritten.

**Known limitation accepted for this version:** Certain PDFs using `/ActualText`
lose replacement-text information, affecting copying, searching, and accessibility
even when visually correct. The app does not guarantee lossless preservation of
all PDF structures. Existing annotations are not guaranteed to survive conversion;
prepare margins before annotation. Original source documents are protected from
replacement. See [COMPATIBILITY.md](COMPATIBILITY.md).

Finalized for personal use and MIT-licensed source publication. The detailed
ActualText investigation is retained without its unfinished detector. No public
binary distribution, Developer ID signing, or notarization is included.

## 0.2.0 - accepted local baseline

Centered 75% default, nine positions, 50-100% scale, per-page settings,
four-state document rotation, vector export with crop/rotation handling, and
local SwiftUI/PDFKit workflow. The original `v0.2.0` tag and accepted builds remain
preserved.
