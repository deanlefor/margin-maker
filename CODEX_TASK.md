# Margin Maker development handoff

Read `AGENTS.md`, `README.md`, `COMPATIBILITY.md`, `RELEASE_CHECKLIST.md`, and
`TESTING.md` before continuing.

## Current state

Main is at `6c811fd`, after review and fast-forward merge of the approved Concept C
icon. It includes source-file identity protection, Portrait/Landscape canvases,
serialized/coalesced previews, queued imports, Finder dropping and the icon.
The original `v0.2.0` tag remains at `e707124`.

`codex/release-0.3.0` is the separate, unmerged release-preparation branch.
It adds only a contained Quartz xref normalization, six regression tests,
development-only compatibility probes, 0.3.0/build 4 metadata, packaging notes
and release documentation. Runtime app dependencies remain Apple frameworks only.
No controls, layout, or application behavior outside PDF finalization changed.

## Significant unresolved issue

The Core Graphics drawing path drops `/ActualText` replacements in both output
orientations. It is reproduced independently and **not fixed**. Do not call this
an unrestricted text-preserving release or silently remove the limitation from
user-facing documentation. No in-app detector/warning was added. The user must
explicitly decide whether to accept the disclosed restricted scope or authorize
separate detector/object-preserving-engine work. Do not begin an engine rewrite.

The other PDF issue, Quartz's unused offset-zero xref entries, is narrowly repaired
without changing content, fonts, file length or object offsets. Unknown formats
are left untouched. `COMPATIBILITY.md` contains reproduction steps and the decision.

## Validation and approval

- 54 native tests pass in debug and release; eight Python reference tests pass.
- 38 retained native PDFs and six independent exports pass qpdf without warnings.
- Ordinary multilingual and invisible OCR-layer text pass independent checks.
- The compatibility probe intentionally exits 2 for the known ActualText loss.
- The user verified Finder drag-and-drop, approved the icon, and previously
  confirmed PDF Expert highlighting. Do not relabel these as new agent GUI tests.
- macOS 13, Intel, clean installation on another Mac, and this exact candidate's
  full PDF Expert interaction remain unverified. Local packaged binaries are arm64.

Commands and installation instructions are in `README.md`. The standard and
separately named QA packages, checksums, remaining acceptance actions and local
app paths are recorded in `RELEASE_CHECKLIST.md`. All signing is local ad-hoc.

## Safeguards for the next session

Preserve installed apps, every existing app/ZIP artifact, `main`, and `v0.2.0`.
Do not merge this release branch, tag 0.3.0, push, publish, notarize, enroll in paid
services or change certificates without explicit approval. Packaging refuses
existing app/ZIP names; use fresh output directories and extract outside iCloud.
No personal PDFs are used by tests; fixtures, logs and candidate artifacts remain
ignored. Finish acceptance and compatibility decisions before considering any
new features. The project retains its existing MIT license.
