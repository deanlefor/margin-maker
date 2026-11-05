# Publish v0.4.0 only after final approval

The application is prepared with production identity as v0.4.0, build 5. Release
preparation stays on codex/margin-maker-v2. Existing v0.2.0/v0.3.0 tags, published
v0.3.0 assets, and download links remain unchanged. RELEASE_CHECKLIST.md is the
historical v0.3.0 release record; RELEASE_0.4.0.md records the new candidate.

## Required approval checks

1. Verify the candidate ZIP's size and SHA-256 against RELEASE_0.4.0.md and the
   proposed release notes. Review the draft PR and production identity/footer.
2. On the exact extracted package, open a disposable PDF in Margin Maker, export,
   then use PDF Expert to highlight, handwrite in a margin, save, close, and reopen.
   Confirm annotations/text and original-source preservation. This is a manual check.
3. Accept the disclosed ActualText/annotation, ad-hoc-signing, and unverified
   platform/installation limitations. This preparation does not establish macOS
   13, Intel, another-Mac installation, or full VoiceOver speech compatibility.
4. Explicitly approve this exact package and authorize merge/tag/publication.

## Steps after authorization

1. Mark the draft PR ready and merge it into main. Check that the approved
   application source and Packaging/Info.plist match the reviewed candidate.
2. Create a new annotated v0.4.0 tag at the approved main commit and push only
   that new tag. Do not move or replace v0.2.0 or v0.3.0.
3. Confirm the proposed GitHub release targets the approved commit/tag, contains
   the verified ZIP and checksum, and has the reviewed final notes. If a draft
   release exists, use that draft; do not create a duplicate or replace old assets.
4. Publish v0.4.0 only after final approval. Keep the exact v0.3.0 release/download
   URL working. Do not rebuild or replace the approved ZIP during publication.
5. Any public website or landing-page change requires separate authorization
   and work in its own repository. No website change is part of this release task.

No merge, tag creation, public release publication, installed-app replacement,
or website modification is automated by the build or test scripts.
