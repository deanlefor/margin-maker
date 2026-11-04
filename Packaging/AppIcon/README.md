# Approved Concept C artwork

`MarginMakerIcon-ConceptC-transparent.png` is the unchanged 1254 × 1254 RGBA
master supplied in `Margin-Maker-Icon-Concept-C-Handoff.zip`, approved on
November 4, 2026. Its SHA-256 is:

```text
bdffb749f9b61757b52e0b4fc71a6ca1899263ac4774e6f7c0f708051da0a4e7
```

Keep the dark teal rounded square, landscape output canvas, smaller upright
document on the left, generous right margin, and blue stroke. The package's
opaque reference preview is intentionally not an app asset. The handoff states
that the artwork was generated with OpenAI's image tool and edited to remove
the outside background, without supplied third-party logos or artwork.

`scripts/build-icon.sh` downsamples directly from this master with macOS `sips`
and packages the standard 16, 32, 128, 256, and 512 point representations at
1× and 2× using `iconutil`. It preserves transparency and performs no cropping,
flattening, or design changes. Generated iconsets and `.icns` files belong in
temporary build directories, not in source control.

The app build embeds `AppIcon.icns` in `Contents/Resources`, identifies it with
`CFBundleIconFile`, and signs the complete bundle afterward. No image-generation
service or third-party library is needed to rebuild it.
