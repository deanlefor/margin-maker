# Source publication audit

Reviewed November 4, 2026 before finalizing v0.3.0. This is a local source audit;
no GitHub repository, push, visibility change, or public release was performed.

## Scope and findings

- Inspected every tracked path and all seven existing commits reachable from all
  branches and tags, including v0.2.0: **80 distinct historical file blobs**.
  `git fsck --full --no-reflogs` reported no errors or unreachable objects.
- Reviewed historical filenames, text, binary sizes, and credential/key patterns.
  No personal academic PDFs, copyrighted readings, tokens, private keys, Apple
  signing credentials/certificates, committed caches, apps, archives, or generated
  binaries were found. This combines pattern scanning and content review; it is
  not a guarantee that every possible secret format can be recognized.
- No private home-directory paths or personal document content were found in
  tracked files/history. Old temporary QA paths were replaced with portable
  reproduction instructions in current documentation. Historical temporary paths
  and a synthetic academic-style test filename remain in prior commits.
- Git history retains its existing author/committer attribution, including
  `IG Admin <web@le4.me>`. That ordinary Git metadata will be visible on publication;
  it was not rewritten. No other personal contact data was found in source files.
- The only tracked binary is the approved **1.78 MB PNG icon master**. Its provenance
  metadata contains OpenAI/Trufo public content-authenticity certificates, not
  private keys, Apple signing material, personal prompts, or account credentials.
  The approved image is unchanged.
- The complete MIT license is included and unchanged. The native package has no
  remote dependencies. The optional Python reference uses pypdf; development-only
  reportlab, qpdf, and Poppler are not bundled in the app.
- `.gitignore` excludes personal PDFs, credentials/signing files, build products,
  caches, local environments, editor metadata, and temporary outputs. History was
  examined separately; ignore rules were not treated as historical protection.

## Preservation and publication

Both completed branches were fast-forwarded into main. The ActualText branch
added documentation only. No detection prototype, engine changes beyond the
completed release work, history rewrite, forced merge, or tag replacement was
performed. Existing local app executables and ZIPs were recorded for checksum
comparison; final verification is in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

No sensitive-file or history blocker was identified. The accepted ActualText
limitation and unverified platforms are disclosed in [README.md](README.md).
Publication steps are in [NEXT_STEPS.md](NEXT_STEPS.md). Publish the Git source
and named tags, not a file copy of the checkout with its ignored local artifacts.
