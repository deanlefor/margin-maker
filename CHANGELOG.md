# Changelog

## 0.3.0 - release candidate, unreleased

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

**Unresolved:** ActualText replacement semantics/accessibility structure are not
preserved by the drawing engine. This is a significant pre-existing limitation,
now reproduced and prominently disclosed. Unrestricted public distribution is
on hold pending an explicit scope decision; see `COMPATIBILITY.md`.

## 0.2.0 - accepted local baseline

Centered 75% default, nine positions, 50-100% scale, per-page settings,
four-state document rotation, vector export with crop/rotation handling, and
local SwiftUI/PDFKit workflow. The original `v0.2.0` tag and accepted builds remain
preserved. This changelog does not designate or tag a final 0.3.0 release.
