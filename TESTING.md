# Testing

All fixtures are synthetic. Tests never read personal PDFs, and generated PDFs
and build products remain ignored by Git.

## Native suite

On a Mac with Swift 6.0 or later, run both configurations:

```bash
bash scripts/test.sh
bash scripts/test.sh -c release
```

The 54 tests cover:

- Exact 75% middle-right Letter placement: 153 pt (2.125 inches) left and
  99 pt (1.375 inches) top/bottom; all nine anchors at 50%, 75%, and 100%.
- Portrait/Landscape output, mixed dimensions, aspect ratios, source page order,
  0/90/180/270-degree rotations, offset crops, and hidden-content clipping.
- Rendered placement and pixel agreement between previews and exported pages.
- Ordinary selectable/searchable multilingual text and invisible OCR layers.
- Per-page overrides, all-page settings, and whole-document orientation.
- Empty, invalid, and password-locked PDFs and invalid layout requests.
- Original-file byte preservation and protection across renames/moves, symlinks,
  hard links, Finder aliases, alternate paths, staged writes, and failed exports.
- Serialized/coalesced previews, cancellation, stale results, queued imports,
  failed-import recovery, and Finder drop providers.
- Adding PDFKit highlights/ink after export and saving/reopening the result.
- The completed Quartz cross-reference normalization, including stable content
  bytes and offsets, idempotence, and unsupported-format no-ops.

To retain 19 PDFs per configuration for independent checks, set
`MARGIN_MAKER_TEST_OUTPUT` to a fresh directory for each run:

```bash
MARGIN_MAKER_TEST_OUTPUT=/private/tmp/mm-debug bash scripts/test.sh
MARGIN_MAKER_TEST_OUTPUT=/private/tmp/mm-release bash scripts/test.sh -c release
```

## Optional Python and independent PDF checks

Python is a behavioral reference and is not bundled with the native app. From
an activated Python environment with the development packages installed:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
python scripts/check-pdf-compatibility.py /private/tmp/mm-compatibility
```

The compatibility script additionally requires local `qpdf` and Poppler
(`pdftotext` and `pdftoppm`), and Swift tools. It generates its own inputs and
checks both orientations with independent readers. Use a new output directory.
Pass `--font /path/to/font.ttf` if the standard Mac Arial Unicode font is absent.
The font must cover Greek, Cyrillic, and CJK.

**Expected exit status: 2.** The script deliberately reports the accepted
`/ActualText` limitation: input `academic text` becomes `XXXXX`. Status 1 means
an unexpected failure; status 0 means ActualText also survived. Inspect
`report.json` to distinguish the known failure from structural and ordinary/OCR
text checks. Passing qpdf alone does not establish semantic preservation.

## Final v0.3.0 verification: November 4, 2026

Test platform: **Apple Silicon, macOS 27.0.1, Apple Swift 6.2.3**, Command Line
Tools without full Xcode. Python reference tests use pypdf 6.10.0.

| Check | Result |
| --- | --- |
| Complete native debug suite | 54 passed in six suites |
| Complete native release suite | 54 passed in six suites |
| Python reference suite | Eight passed |
| Retained native PDFs | 19 debug + 19 release pass qpdf without warnings |
| Independent exports | Six PDFs pass qpdf without warnings in both orientations |
| Independent text extraction | Multilingual and invisible OCR text pass Poppler/pypdf comparisons |
| ActualText semantics | Known loss reproduced in both orientations; expected script exit 2 |

Package verification is recorded in the source repository's RELEASE_CHECKLIST.md.
The application, native engine,
tests, and Python reference are unchanged from completed release preparation
`0e31d56`; no experimental detector was integrated.

Earlier local GUI testing exercised the controls, page settings, both output
orientations, and export/error recovery. The user confirmed physical Finder
dropping, the approved icon, and earlier PDF Expert highlighting. Those are
historical/user results, not new automated tests of the final package. PDFKit
annotation tests do not establish PDF Expert's full handwriting/save/reopen
workflow for this exact build.

macOS 13, Intel hardware, installation on another Mac, and the complete final
PDF Expert workflow remain **unverified**, without blocking the accepted personal
use/source publication scope. The test runner may warn that Testing.framework
requires macOS 14, and provider tests may log sandbox-extension warnings. These
logs do not establish macOS 13 compatibility.

## Optional manual smoke test

Build to a fresh output directory and extract the archive outside synced storage.
Open a synthetic multipage PDF, confirm the default 75% middle-center preview,
try all nine anchors, 50%/100%, both orientations, and a This page override.
Navigate away/back to confirm the override, then adjust All pages. Export and
check dimensions, order, copy/search, and the original's unchanged bytes. Try
invalid/locked input and overwrite rejection on disposable fixtures. In PDF
Expert, highlight and write in a margin, save, and reopen.

`python scripts/make-smoke-fixtures.py` creates disposable inputs under ignored
`tmp/smoke` using the optional development packages.

## Source-protection limits

A cross-volume copy/delete creates a new file identity; reopen the new copy to
protect it as the imported source. A small race remains between the final
filesystem check and replacement if another process changes the destination.
No original is opened for writing. Power-loss durability and coordination with
arbitrary concurrent external filesystem mutations are not guaranteed.
