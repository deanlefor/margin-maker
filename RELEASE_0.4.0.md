# Margin Maker v0.4.0 final package approval record

Prepared November 4, 2026 on codex/margin-maker-v2, following feature commit
832272afe28af3670e11708efc8f9699c1631476. This task changes only production
identity, the packaging-metadata test, packaged documentation, and release records.
Application runtime and PDF engine source files remain byte-identical to 832272a.
No feature, PDF drawing, or positioning change is included in release preparation.

## Production package

- Application: Margin Maker.app; CFBundleName/DisplayName: Margin Maker.
- Bundle identifier: local.marginmaker.app.
- Version: 0.4.0; build: 5 (following production v0.3.0 build 4); channel: Release.
- Footer verified in the extracted app: v0.4.0 (5), without Development.
- Architecture: arm64 only. Declared/binary minimum macOS: 13.0.
- Signature: ad-hoc, no Developer ID or Apple notarization. The signed staging
  bundle and clean ZIP extraction pass strict codesign verification, including
  after the extracted app was launched and used to export a PDF.
- Candidate ZIP: build/v0.4.0-production-final/Margin.Maker.0.4.0.macOS.Apple.Silicon.zip
- Size: **2,237,740 bytes**.
- SHA-256:

```text
eba72759c2fd9767cf67d8c3dec8684d9ab44e5ed33a7f671ee8c755cd641853
```

SHA256SUMS.txt is beside the ZIP. The archive includes the production app, current
README/install instructions, changelog, v0.4.0 release notes, approval/publication
steps, contributor notes, compatibility/ActualText reports, testing notes, and MIT
license. Historical Dev instructions are excluded. Checksum/approval records stay
outside their own ZIP to avoid a self-referential checksum.

The app copy in the iCloud checkout acquired Finder metadata after copying,
causing strict verification to fail there. This does not alter the metadata-free
ZIP or its clean extracted bundle. Extract outside synced storage and launch
that copy, as INSTALL.md explains. No existing package/application was replaced.

## Verification

Tested on Apple Silicon, macOS 27.0.1, Apple Swift 6.2.3 with Command Line Tools.

| Check | Result |
| --- | --- |
| Native debug and release suites | 78 + 78 tests passed, nine suites each |
| Python reference suite | Eight passed; pypdf 6.10.0/reportlab 4.4.9 |
| Retained native PDFs | 42 pass qpdf without warnings |
| Independent compatibility exports | Six structurally clean; ordinary multilingual/invisible OCR text preserved |
| Known ActualText semantics | Reproduced in both orientations; expected tool exit 2, no unexpected failure |
| Independent offset export checks | Both orientations/configurations pass pypdf/Poppler dimensions/order/text |
| Visual output | Representative offset Portrait/Landscape renders inspected |
| Production identity | Bundle metadata, arm64 binary, minimum OS, signature, and footer verified |
| Extracted app smoke test | Defaults, nonzero top-left offsets, numeric/range/precision validation, blank/Tab recovery, 100% warning, both orientations, save-panel export passed |
| GUI export | Four Portrait Letter pages in order; text verified by pypdf/Poppler; qpdf clean |
| Source preservation | GUI source SHA-256 unchanged after export; automated protection regressions pass |
| History/artifacts | Existing runtime source, v0.3.0 records, applications, ZIPs and historical tags preserved |

Verification logs, native fixtures, compatibility report, artifact metadata and
GUI evidence are under /private/tmp/mm-040-release-20261104. Generated artifacts
and personal PDFs are not committed. INSTALL_0.3.0.md preserves the pre-existing
published v0.3.0 installation record byte-for-byte; RELEASE_CHECKLIST.md and
PUBLICATION_AUDIT.md remain unchanged.

## Final manual checks and approval

1. Use this exact ZIP. Extract outside synced storage without replacing an
   existing app, open the extracted app, and confirm v0.4.0 (5).
2. Complete PDF Expert highlighting, handwriting in a margin, save, close, and
   reopen. Confirm text/annotations remain usable and the original stays unchanged.
   PDFKit annotation tests do not establish this application-specific workflow.
3. Accept the disclosed ActualText/annotation and ad-hoc-signing limitations.
   macOS 13, Intel, another-Mac installation, full VoiceOver speech, and minimum
   window behavior remain unverified; this ZIP does not include Intel code.
4. Approve this package and separately authorize merge, the new v0.4.0 tag, and
   publication. No public website change is included.

## Proposed publication

The release-preparation commit is pushed only to codex/margin-maker-v2. A draft
PR targets main, without merging. An unpublished GitHub release draft may hold
this exact ZIP and checksum; the proposed tag name is v0.4.0, but the Git tag must
not exist until final authorization. Draft notes identify outstanding checks.
The current public v0.3.0 release remains current and unchanged during approval.

After approval, follow NEXT_STEPS.md: merge the reviewed PR, verify the approved
application tree, create the new annotated v0.4.0 tag at the approved main commit,
verify the existing draft asset/checksum, and publish that release. Do not rebuild
or replace this approved ZIP, move old tags, delete old assets, or modify the
website as part of those steps without separate authorization.
