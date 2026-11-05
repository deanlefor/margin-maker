# Install Margin Maker v0.4.0

This package contains **Margin Maker 0.4.0, build 5**, using the production name
**Margin Maker.app**, identifier `local.marginmaker.app`, and Release channel.
The footer reads **v0.4.0 (5)**. Final publication approval is pending; the app is
not a development-identity build. No build tools are needed to run the packaged app.

The ZIP contains only **Apple Silicon (arm64)** code. Tested locally on macOS
27.0.1. The declared minimum is macOS 13, but macOS 13 and Intel compatibility
remain unverified; Intel code is not included. Installation on another Mac is
also unverified.

## Open the candidate safely

1. Verify the ZIP's SHA-256 against the approval record or release notes supplied
   alongside it. For a published download, use the checksum on its GitHub release.
2. Double-click the ZIP in Finder to extract it into a **fresh folder outside
   iCloud or other synced storage**. Do not extract over an existing application.
3. Open **Margin Maker.app** from that folder. This candidate has the same bundle
   identifier as the production v0.3.0 app. If an older production copy is running,
   quit it yourself first so macOS launches the intended extracted copy. Existing
   app files and release ZIPs must remain in their current locations during review.
4. Confirm **v0.4.0 (5)** in the footer before testing.
5. Open a disposable PDF. Defaults are Portrait, All pages, 75%, middle-center,
   and 0.00-inch horizontal/vertical offsets. Try offsets such as 0.25 or 0.50,
   check the ranges, and export a new PDF. Add annotations to the exported copy.

This app installs no services and does not change your default PDF application.
Do not replace an installed copy until the final package is approved.

## macOS security warnings

The app is **ad-hoc signed**, without Developer ID signing or Apple notarization.
macOS may display security warnings. If you trust the package and choose to
proceed, follow [Apple's guidance for opening apps from unidentified developers](https://support.apple.com/en-us/102445):
after attempting to open it, use **System Settings > Privacy & Security > Open
Anyway** for this application when offered, then confirm Open. This is an
application-specific exception; do not disable macOS protections globally.

## Verify the ZIP

The final byte count and SHA-256 are recorded outside the archive in its release
approval record, release notes, and SHA256SUMS.txt. Keeping the checksum outside
its own ZIP avoids changing the bytes being verified. From the download folder:

```bash
shasum -a 256 "Margin.Maker.0.4.0.macOS.Apple.Silicon.zip"
```

Compare the output with the supplied checksum before opening the app.

## PDF compatibility

Certain PDFs using **/ActualText** lose replacement-text semantics, affecting
copying, searching, and accessibility even if their appearance is correct.
Ordinary vector text and conventional invisible OCR layers pass the tested
fixtures; not all PDF structures are preserved. Keep your original PDFs.
Existing annotations are not guaranteed to survive conversion; prepare margins
before annotating. Links, forms, outlines, signatures, and accessible structure
are not migrated. See [COMPATIBILITY.md](COMPATIBILITY.md).

The final manual check is to export a disposable reading, open it in PDF Expert,
highlight text, handwrite in the margin, save, close, and reopen. Confirm the
annotations/text remain usable and the original source is unchanged.

## Existing v0.3.0 download

The [v0.3.0 release](https://github.com/deanlefor/margin-maker/releases/tag/v0.3.0)
and [original Apple Silicon ZIP](https://github.com/deanlefor/margin-maker/releases/download/v0.3.0/Margin.Maker.0.3.0.macOS.Apple.Silicon.zip)
remain available unchanged. Its archived installation instructions are preserved
in the source repository as INSTALL_0.3.0.md. Do not use the v0.3.0 checksum to
verify the new v0.4.0 ZIP.
