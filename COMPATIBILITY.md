# PDF compatibility: v0.4.0

The v0.4.0 candidate retains the known ActualText and annotation limitations
described below. New edge offsets change page placement, not the PDF drawing or
text-preservation pipeline. Ordinary multilingual vector text and conventional
invisible OCR layers are verified with independent readers; ActualText loss is
an expected disclosed failure, not a claim of lossless PDF conversion.

The candidate uses production identity (0.4.0, build 5, Release channel) and is
prepared for final public-release approval. It is ad-hoc signed, arm64 only, and
not Apple-notarized. macOS 13, Intel compatibility, another-Mac installation, and
the full PDF Expert handwriting/save/reopen workflow remain unverified.

## Historical v0.3.0 investigation

The investigation below is retained as recorded. Its references to source-only
publication and the then-current engine describe v0.3.0, not the new package's
release status. Current candidate verification is recorded in TESTING.md and
RELEASE_0.4.0.md in the source repository.

Investigated November 4, 2026 on Apple Silicon, macOS 27.0.1, Swift 6.2.3.
The completed release preparation (`0e31d56`) and documentation-only safeguard
investigation (`774f7c6`) are incorporated into main. No detector prototype is
included. The engine remains unchanged from the completed release preparation.

## Disposition

| Issue | Result | Release disposition |
| --- | --- | --- |
| `/ActualText` replacement semantics | Confirmed lost in both orientations; not fixed | Accepted, documented limitation for v0.3.0 personal use and source publication. |
| Offset-zero in-use xref entry | Confirmed in bare Quartz and both engine orientations; narrowly repaired | Fixed for the observed Quartz output format, with native regression and independent validation. |

The application does not guarantee lossless preservation of all PDF structures.
No automatic detector or in-app warning for `/ActualText` has been added; a
visually correct preview is not evidence that replacement text survived.
Existing annotations are not guaranteed to survive conversion. Prepare margins
before highlighting or handwriting. Original source documents are protected
from replacement. Source publication does not include a public binary release.

## A. `/ActualText`

A synthetic input paints `XXXXX` inside a marked-content span whose `/ActualText`
contains UTF-16 `academic text`. Poppler extracts `academic text` from the input.
Current Portrait and Landscape exports extract `XXXXX`. Inspecting the decoded
content confirms that the replacement property was discarded.

The same result occurs with a bare `CGContext.drawPDFPage`, without Margin Maker's
scaling, positioning, crop clipping, cancellation, or xref normalization. PDFKit
page drawing also loses the replacement in the tested case. A PDFKit save of
the unchanged document preserves it, demonstrating that a lossless *save* is
possible; it does not perform Margin Maker's canvas/scale/position conversion.
A development experiment wrapping page drawing in a manually authored ActualText
tag did not restore the original marked-content semantics for Poppler.

Apple documents `drawPDFPage` as drawing page content into a graphics context,
not copying the original PDF object graph. The SDK's `CGPDFContext.h` documents
`CGPDFContextBeginTag` as tagging drawing commands that the caller authors; it
provides no transparent forwarding of each input span while `drawPDFPage` runs.
[Apple drawing API](https://developer.apple.com/documentation/coregraphics/cgcontext/drawpdfpage(_:)).

### Consequences and limits of the evidence

- Affected spans can copy or search as their painted glyph text instead of the
  intended replacement. Accessibility consumers can also lose the intended text.
- Academic PDFs can use replacement text for ligatures, mathematics, and special
  encodings. Their prevalence in the user's readings was not measured. This is
  not a claim that all academic PDFs are affected.
- Some extractors already ignore ActualText. Matching pypdf's input/output text
  therefore does not prove semantic preservation. Poppler supplies the decisive
  independent comparison here; the replacement's structural absence corroborates it.
- Ordinary Latin, Greek, Cyrillic, CJK, accented text and conventional invisible
  OCR text layers pass the independent fixtures. OCR implementations that depend
  on ActualText remain subject to this limitation. Scans without OCR stay images.
- Input files remain untouched. This is a semantic loss in the exported copy,
  not corruption of the imported original or a visual page-layout failure.

### Decision and possible future approaches

1. **Accept and prominently disclose the restricted scope.** Keep the small native
   tool for visual pre-annotation layout of ordinary PDFs. Retain the original
   for semantic copying/search/accessibility, and do not use the conversion when
   replacement semantics are required. The user explicitly selected this option
   for finalizing v0.3.0 and preparing its source for publication.
2. **Reject affected inputs.** A reliable detector would need to scan marked
   content, named property resources, and nested forms, not merely grep bytes.
   This would change which readings the application accepts and merits a separate
   product decision. It would prevent loss, not preserve the information.
3. **Adopt object-preserving composition.** Copy original streams/resources and
   apply wrapper transforms and clipping, preserving the marked content. This
   needs a PDF serializer/composition layer or another engine, with new licensing,
   packaging, memory, crop/rotation and compatibility work. It is a substantial
   architectural change, so it was not attempted in this release-preparation task.

Blindly overlaying replacement text, assigning a whole page one replacement, or
matching glyph strings after redrawing is not a reliable fix for multiple spans,
nested content, reading order, clipping, or search geometry. Options 2 and 3 are
future contributor topics, not remaining work or blockers for v0.3.0.

## B. Cross-reference entry

The multilingual fixture uses a subsetted TrueType font and contains Latin,
ligatures, Greek, Cyrillic, Chinese and Japanese. The valid source passes qpdf.
Before repair, both engine orientations emit an unused object number with the
classic xref entry `0000000000 00000 n`. qpdf reports object 6 at offset zero.
A bare Quartz copy emits the same problem (object 5), establishing a framework
writer issue independent of the orientation/layout implementation. In this
reproduction the placeholder is unreferenced, not a missing used font program.

qpdf's own reader explicitly handles this Quartz behavior as a missing/null
object. Its [primary source](https://github.com/qpdf/qpdf/blob/main/libqpdf/QPDF_objects.cc)
describes the historical writer defect. Tolerant readers render/extract these
files correctly, but stricter validators can reject the invalid entry; it was
therefore inappropriate to dismiss the warning without repair and verification.

`PDFCrossReference` now normalizes only this known case in **newly generated**
Quartz output. It recognizes a contiguous classic xref table, marks unused
zero-offset entries permanently free, and rebuilds the free-object chain with
fixed-width entries. It preserves all object/content/font bytes, table positions,
file length and `startxref`. Existing free-entry generations are retained. Valid
files are unchanged. Unknown formats, malformed tables, xref streams and
incremental/hybrid updates are left untouched rather than guessed at. Imported
source bytes are never repaired or rewritten.

Tests cover the exact offset-zero case, multiple unused/free entries, stable
bytes/offsets, idempotence, CRLF entries, no-op valid output, unsupported formats,
multilingual extraction and conventional invisible OCR layers. After repair:

- qpdf 12.3.2 reports no warnings for both multilingual exports.
- Poppler 26.08.0 and pypdf preserve ordinary multilingual and OCR fixture text.
- Independent Poppler before/after repair renders are pixel-identical.
- All 38 retained debug/release native PDFs and six independent engine exports
  pass qpdf without warnings. This is not a general PDF/A, PDF/UA or archival
  certification; qpdf cannot prove every font or accessibility property correct.

## Reproduce from source

Install the optional `requirements-dev.txt` packages and local qpdf/Poppler tools,
then run on a Mac with Swift tools, using a new disposable output directory:

```bash
python scripts/check-pdf-compatibility.py /private/tmp/margin-maker-compatibility
pdftotext /private/tmp/margin-maker-compatibility/actualtext.pdf -
pdftotext /private/tmp/margin-maker-compatibility/actualtext-Portrait.pdf -
```

`--font` accepts a local Unicode TrueType font if the standard Mac Arial Unicode
font is absent. The script generates its own inputs, compiles the current engine,
compares Poppler/pypdf extraction, checks both page orientations, and writes a
JSON report plus bare-Quartz controls. It exits **2** for the known ActualText
loss, **1** for unexpected failures, and **0** only if all checks including
ActualText preservation pass. No PDF/font data or validation tool is bundled
in the app. The first command intentionally returns 2 for the accepted limitation;
the following commands show input `academic text` becoming output `XXXXX`.
Choose another output directory if it already exists. `report.json` records the
results. Raw framework controls intentionally retain the known defects; the
clean-export counts exclude those controls. Test instructions and current
verification results are in [TESTING.md](TESTING.md).

## Subsequent safeguard feasibility investigation

The follow-up on `codex/actualtext-safeguard` did not establish a dependable small
native rejection check. Parsed object/stream probes detected the obvious cases,
but resource-context and decoder-completeness counterexamples prevented treating
negative scans as proof of safety. No partial detector was integrated and no
safeguard QA package was created. The application remains identical to the
`0e31d56b` engine, with the same accepted ActualText limitation.
See [ACTUALTEXT_SAFEGUARD.md](ACTUALTEXT_SAFEGUARD.md) for evidence, qualifications
and alternatives; this conclusion does not assert that a fuller detector is
impossible.
