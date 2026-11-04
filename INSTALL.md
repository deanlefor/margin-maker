# Run your local build

Margin Maker 0.3.0 is finalized for personal use. The project provides source
code; a signed and notarized public application is not part of this release.

1. Build from source using the command in README.md.
2. Extract **Margin Maker.zip** outside iCloud or another synced folder.
3. Open **Margin Maker.app** from the extracted folder. Keep it separate from
   an existing installation, or copy it to Applications when you choose to replace
   your own installed version.
4. Open a PDF, choose orientation, position, and scale, then export a new copy.
   Add highlights and handwriting to that copy afterward.

The app is version **0.3.0**, build **4**, bundle identifier
`local.marginmaker.app`. It is ad-hoc signed for local execution, without
Developer ID signing or notarization. It installs no services and does not
change your default PDF application. A build made on Apple Silicon contains
an arm64 executable. Intel and macOS 13 remain unverified; local testing covers
Apple Silicon on macOS 27.0.1.

**Read before converting:** Certain PDFs using `/ActualText` lose replacement-text
information, which can affect copying, searching, and accessibility even when
the output looks correct. Not all PDF structures are preserved. Existing
annotations are not guaranteed to survive: add margins before annotating.
Original source documents are protected from replacement. Keep the originals.
See [COMPATIBILITY.md](COMPATIBILITY.md) for evidence and reproduction steps.
