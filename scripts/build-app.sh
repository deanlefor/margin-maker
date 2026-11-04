#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    echo "Usage: $0 [release|debug] [output-directory]" >&2
    exit 2
fi

# Keep compiler caches inside the checkout for restricted local environments.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
package_flags=(--disable-sandbox --cache-path "$PWD/.build/package-cache"
               --config-path "$PWD/.build/package-config"
               --security-path "$PWD/.build/package-security")
swift build "${package_flags[@]}" -c "$configuration"
binary_dir="$(swift build "${package_flags[@]}" -c "$configuration" --show-bin-path)"
output_dir="${2:-$PWD/build}"
mkdir -p "$output_dir"
# Sign outside synced folders, where providers may reattach Finder metadata.
staging_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/margin-maker.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app="$staging_dir/Margin Maker.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MarginMaker" "$app/Contents/MacOS/MarginMaker"
cp Packaging/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
# Remove only metadata that codesign forbids; preserve iCloud provider attributes.
xattr -dr com.apple.FinderInfo "$app" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$app" 2>/dev/null || true
# Ad-hoc signing allows local execution. This is NOT Developer ID signing or notarization.
codesign --force --sign - "$app"
codesign --verify --strict "$app"
# A metadata-free archive remains intact when this checkout is in iCloud Drive.
ditto --norsrc --noextattr -c -k --keepParent "$app" "$output_dir/Margin Maker.zip"
ditto --norsrc --noextattr "$app" "$output_dir/Margin Maker.app"
echo "Built local app: $output_dir/Margin Maker.app"
echo "Local app archive: $output_dir/Margin Maker.zip"
