# Margin Maker v0.3.0 release record

Finalized November 4, 2026 for personal use and MIT-licensed source publication.
The known `/ActualText` loss is accepted and disclosed. No additional detector
or PDF-engine development was undertaken.

## Consolidation and publication review

- Completed release work `0e31d56` was reviewed against main `6c811fd` and
  fast-forwarded into main, followed by documentation-only investigation `774f7c6`.
- The app, engine, tests, and Python reference remain byte-identical to `0e31d56`.
  The final packaging change includes the investigation and test notes in the ZIP.
- Full existing history and the annotated v0.2.0 baseline remain intact. No force
  merge, rewritten commit, prototype integration, or tag replacement occurred.
- README, build/use/test instructions, MIT license, changelog, known limitations,
  technical investigation, contribution notes, and ignore rules are included.
- [PUBLICATION_AUDIT.md](PUBLICATION_AUDIT.md) records tracked-file/history review.
  No sensitive-file or history blocker was identified. Existing Git attribution
  and public icon-provenance metadata remain visible by design.

## Verification

Tested on Apple Silicon, macOS 27.0.1, Apple Swift 6.2.3 with Command Line Tools.

| Check | Result |
| --- | --- |
| Complete native suite | 54 debug + 54 release passed, six suites each |
| Python reference tests | Eight passed with pypdf 6.10.0 |
| Native PDF fixtures | 38 pass qpdf without warnings |
| Independent generated exports | Six pass qpdf; multilingual/OCR text matches with Poppler and pypdf |
| Known ActualText issue | Reproduced in both orientations; expected compatibility-script status 2 |
| Layout/regression coverage | Anchors, scales, both orientations, crops/rotations, page order, preview/export agreement, source protection, asynchronous state, and drop handling pass |
| Visual review | Representative Portrait/Landscape renders and the final app preview inspected |
| Final extracted app smoke test | Launched, imported four-page synthetic PDF, confirmed 75% middle-center/All pages defaults, selected middle-right, switched Landscape/Portrait, exported through save panel |
| GUI export validation | Four 612 × 792 pt pages, original order, extracted text, qpdf clean |
| Bundle metadata | 0.3.0, build 4, local.marginmaker.app, arm64, declared minimum macOS 13.0 |
| Icon | Approved master checksum unchanged; all ten bundled icon representations have correct dimensions and transparent outer corners |
| Local signatures | Ad-hoc; bundle and fresh ZIP extraction pass strict verification; no Developer ID or notarization |
| Preservation | All 12 pre-existing app executables/ZIPs retain recorded checksums; v0.2.0 tag object unchanged |

The restricted build compiled but macOS iconutil rejected its iconset inside the
tool sandbox. Running the unchanged build pipeline outside that sandbox completed
successfully. Native tests may emit the documented Testing.framework deployment
and provider sandbox-extension warnings; all tests pass.

Historical user confirmation covers Finder dropping, icon approval, and earlier
PDF Expert highlighting. The full final-build PDF Expert handwriting/save/reopen
workflow, macOS 13, Intel, and another-Mac installation remain unverified. These
are disclosed limits, not blockers for the accepted release scope.

## Personal-use archive

The final archive is stored locally in the ignored build directory:

`build/v0.3.0-personal-final/Margin Maker 0.3.0 Personal.zip`

SHA-256:

```text
43c50baec087bd47f04ad401ee3a9bf1edfda4f2d61d1b6ada3463d41fa14bbc
```

It contains Margin Maker.app, installation notes, changelog, compatibility and
ActualText reports, testing notes, and the MIT license. Extract outside synced
storage. Existing apps and ZIPs were not replaced, and the app was not installed.
Logs and JSON verification records are beside the ZIP in `verification/`.

## Local release identity and source publication

The local annotated `v0.3.0` tag identifies final main. Verify with:

```bash
git status --short
git show --no-patch v0.3.0
git rev-parse main 'v0.3.0^{commit}'
git show --no-patch v0.2.0
```

Source is ready for GitHub publication with the documented limitations. No remote
is configured and nothing was pushed, published, or made public. Follow
[NEXT_STEPS.md](NEXT_STEPS.md) when separately choosing to publish source.
Public binary distribution, notarization, Developer ID signing, and an installer
are outside this release.
