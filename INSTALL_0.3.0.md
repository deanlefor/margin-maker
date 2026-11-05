# Install Margin Maker v0.3.0

[Download the Apple Silicon application ZIP](https://github.com/deanlefor/margin-maker/releases/download/v0.3.0/Margin.Maker.0.3.0.macOS.Apple.Silicon.zip)
from the [public v0.3.0 release](https://github.com/deanlefor/margin-maker/releases/tag/v0.3.0).
No build tools are required for this download.

The app is version **0.3.0**, build **4**, bundle identifier `local.marginmaker.app`.
The ZIP contains only **Apple Silicon (arm64)** code. Local testing covers Apple
Silicon on macOS 27.0.1; **macOS 13 and Intel compatibility remain unverified**.
Clean installation on another Mac also remains unverified.

**Read before converting:** Certain PDFs using `/ActualText` lose replacement-text
information, which can affect copying, searching, and accessibility even when
the output looks correct. Not all PDF structures are preserved. Existing
annotations are not guaranteed to survive: add margins before annotating.
Original source documents are protected from replacement. Keep the originals.
See [COMPATIBILITY.md](COMPATIBILITY.md) for evidence and reproduction steps.

## Download and launch

1. Download the application ZIP using the link above. In the release's **Assets**
   list, its label is **Margin Maker 0.3.0 macOS Apple Silicon.zip**; GitHub serves
   it as `Margin.Maker.0.3.0.macOS.Apple.Silicon.zip`. The source-code ZIP and tarball
   are for building from source.
2. Double-click the downloaded ZIP in Finder to extract it outside iCloud or
   another synced folder.
3. Open **Margin Maker.app** from the extracted folder. Keep it separate from
   older copies so you launch this version. You may copy it to Applications when
   you choose to replace your own installed version.
4. If macOS displays a security warning, read the guidance below before proceeding.
5. Click **Open PDF**, press Command-O, or drop a PDF from Finder onto the window.
   Choose Portrait or Landscape, one of nine positions, and a scale from 50% to 100%.
   Apply settings to all pages or customize individual pages, then export a new PDF.
   Add highlights and handwriting to that exported copy afterward.

The downloadable ZIP is the previously verified final archive, unchanged. Its
bundled documents retain historical personal-use/source-build wording; these
instructions describe the prebuilt public release. The app installs no services
and does not change your default PDF application.

## macOS security warnings

This build is **ad-hoc signed**, without Developer ID signing or **Apple
notarization**, so macOS may display security warnings. If you trust the download
and choose to proceed, follow [Apple's official guidance for opening apps from
unidentified developers](https://support.apple.com/en-us/102445):

1. First attempt to open **Margin Maker.app**.
2. Open **System Settings → Privacy & Security**, scroll down, and select
   **Open Anyway** for Margin Maker when offered.
3. Confirm **Open** when the warning prompt reappears.

These steps create an exception for this application. Do not disable macOS
security protections globally.

## Verify the download

The application ZIP is **2,179,751 bytes**. Its SHA-256 checksum is:

```text
43c50baec087bd47f04ad401ee3a9bf1edfda4f2d61d1b6ada3463d41fa14bbc
```

To check it in Terminal, run this command from the folder containing the download
and compare its output with the checksum above:

```bash
shasum -a 256 "Margin.Maker.0.3.0.macOS.Apple.Silicon.zip"
```

## Build from source instead

Follow [Build from source in README.md](README.md#build-from-source). Local builds
produce **Margin Maker.app** and **Margin Maker.zip**; extract that ZIP outside
synced storage and follow the launch instructions above. The build uses the
current Mac's architecture and does not establish compatibility with untested
Macs or macOS versions. Source code is available under the [MIT license](LICENSE).
