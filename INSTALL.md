# Margin Maker 0.3.0 release candidate

This is a local acceptance-test build, not a public release. The supplied apps
are built for Apple Silicon and have version **0.3.0**, build **4**. The source
project targets macOS 13+, but this build was tested on macOS 27.0.1; macOS 13 and
Intel hardware have not been verified.

1. Extract the ZIP outside iCloud or another synced folder.
2. For acceptance testing, open **Margin Maker 0.3.0 RC QA.app**. Its distinct
   name and identifier let you keep it alongside your installed working app.
3. If using the normal **Margin Maker.app** package, keep that candidate in a
   separate folder during QA to preserve your current installation.
4. Open or drop one disposable PDF, choose orientation, position and scale, and
   export a new copy. Check the result in your PDF reader before using real readings.

The app works offline and does not install services, update itself, or change
your default PDF application. It is ad-hoc signed for local QA, not Developer ID
signed or notarized. Public signing/distribution remains a separate future step.

## Read before testing

**ActualText replacements are not preserved.** A PDF can look right while
copying, searching or accessibility tools return different text. This can affect
some ligatures, math, specially encoded text or accessible PDFs. Do not use this
candidate when those semantics must survive. Public distribution is on hold
pending a scope decision. Read `COMPATIBILITY.md` for the evidence and options.

Ordinary vector text and a conventional invisible OCR text layer pass the tested
fixtures. Existing annotations, links, forms, outlines and signatures are not
migrated: create margins before annotating. Password-locked inputs need an
unlocked copy. The original file is protected; keep the original for reference.

For final acceptance, check portrait/landscape placement, text search/copy,
individual-page overrides, Finder dropping, the icon, and PDF Expert's
highlight/write/save/reopen workflow on representative readings. Prior user
approval covers Finder dropping, the icon and earlier highlighting; this exact
candidate still needs final approval. The project uses the existing MIT license.
