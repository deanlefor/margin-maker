#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 output.icns" >&2
    exit 2
fi

source_image="$PWD/Packaging/AppIcon/MarginMakerIcon-ConceptC-transparent.png"
icon_staging="$(mktemp -d "${TMPDIR:-/private/tmp}/margin-maker-icon.XXXXXX")"
trap 'rm -rf "$icon_staging"' EXIT
iconset="$icon_staging/AppIcon.iconset"
mkdir -p "$iconset"

# Render every representation directly from the approved transparent master.
# sips preserves alpha; do not flatten, crop, or redraw the approved artwork.
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_image" \
        --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$source_image" \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$1" "$iconset"
