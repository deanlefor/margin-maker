# Remaining work for Margin Maker 0.3.0

The release-preparation branch is `codex/release-0.3.0`, based on main at
`6c811fd`. Main includes the reviewed source protection, Portrait/Landscape,
reliability, Finder drop and approved Concept C icon work. The original v0.2.0
baseline and existing builds are preserved.

The candidate has version 0.3.0/build 4. It is ready for acceptance testing of
its documented scope, **not unrestricted public distribution**.

1. **Decide the ActualText scope.** Read `COMPATIBILITY.md`. The known semantic
   loss is not fixed and is a significant release decision. Either explicitly
   accept the disclosed limitation or authorize separate work; do not silently
   claim all searchable/accessibility text is preserved.
2. **Test the exact release candidate.** Use the separately named QA app and
   representative readings. Check copy/search, both orientations, all-page and
   individual overrides, source protection/failure recovery, and PDF Expert's
   highlight/write/save/reopen interaction. The user already approved Finder
   dropping, the icon and earlier highlighting; those are not new-version results.
3. **Resolve compatibility claims.** Test macOS 13, Intel if promised, and clean
   installation on another Mac/account. Current archives contain arm64 binaries;
   no physical macOS 13 or Intel verification has occurred.
4. **Review and approve the branch.** The native suite passes 54 tests in debug
   and release; Python passes eight tests. Independent structural and text checks
   are recorded in `TESTING.md`. Leave the branch unmerged until approved.
5. **Authorize distribution separately.** Developer ID signing/notarization,
   enrollment/certificates, hosting, a final v0.3.0 tag and public release remain
   separate decisions. No paid service, push, publication or final tag was created.

See `RELEASE_CHECKLIST.md` for candidate paths and completed checks. No new
features or unrelated refactoring are planned for this release.
