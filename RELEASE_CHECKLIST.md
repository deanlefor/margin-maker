# 0.3.0 release-candidate handoff

## Completed on the release-preparation branch

- [x] Review and fast-forward the approved Concept C icon into main (`6c811fd`).
- [x] Preserve the `v0.2.0` tag and existing app/ZIP artifacts.
- [x] Create `codex/release-0.3.0`; leave it unmerged.
- [x] Reproduce both PDF issues, isolate framework behavior, and document options.
- [x] Apply the contained Quartz xref repair and six new regression tests.
- [x] Pass 54 native tests in debug and 54 in release; pass eight Python tests.
- [x] Validate 38 retained native PDFs plus six independent exports with qpdf.
- [x] Verify ordinary/OCR extraction, upright renders and both canvas orientations.
- [x] Retain source protection, cancellation, queueing, drop handling and icon tests.
- [x] Prepare version 0.3.0/build 4 metadata and distinct normal/QA packages.
- [x] Retain the MIT license and document building/installation/known limitations.
- [x] Review tracked files and bundle contents for artifacts, secrets and personal PDFs.

User-confirmed results: Finder drag-and-drop and Concept C icon approval, plus
previous PDF Expert highlighting. These are attributed to the user, not reported
as new independent physical testing by the agent.

## Required before unrestricted public distribution

- [ ] Decide the ActualText policy described in `COMPATIBILITY.md`. This is the
  significant unresolved release risk; native test success does not waive it.
- [ ] Final user acceptance of this exact 0.3.0 candidate on representative PDFs,
  including copy/search, PDF Expert highlight/write/save/reopen, and failed-export
  recovery. Earlier highlighting approval is not a complete new-version test.
- [ ] Test macOS 13 and Intel if those platforms will be advertised. Current ZIPs
  contain an arm64 executable; no universal or Intel binary has been produced.
- [ ] Test clean installation on another Mac/account and quarantine behavior.
- [ ] Separately authorize any Developer ID signing, notarization and distribution
  work. No enrollment, certificate change, paid service or notarization occurred.
- [ ] Review and approve the release-preparation branch, then explicitly authorize
  any merge, final tag, source hosting or public release. None is automatic.

## Candidate files

Local signed apps outside synced storage:

- `/private/tmp/margin-maker-030-rc-jpy34ud0/packages-final/standard/Margin Maker.app`
- `/private/tmp/margin-maker-030-rc-jpy34ud0/packages-final/qa/Margin Maker 0.3.0 RC QA.app`

Durable local archives in the ignored build directory:

- `build/rc-0.3.0/Margin Maker 0.3.0 RC.zip`
- `build/rc-0.3.0/Margin Maker 0.3.0 RC QA.zip`
- `build/rc-0.3.0/SHA256SUMS.txt`

ZIPs include the app, installation instructions, changelog, compatibility report
and license. They are metadata-free and ad-hoc signed; fresh extractions are
verified before handoff. Existing artifact files were hashed before work and
checked again afterward. Build/test logs and synthetic fixtures are under the
same temporary task directory; no personal PDFs were used.

The candidate is ready for final user acceptance testing of its documented
scope. **It is not approved for unrestricted public distribution.** ActualText
policy, compatibility checks, distribution signing and final approval remain open.
