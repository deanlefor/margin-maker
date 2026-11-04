#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    echo "Usage: $0 [release|debug] [output-directory]" >&2
    exit 2
fi

# Paired overrides produce a separately identifiable QA bundle without editing
# the regular application's metadata or replacing an earlier package.
app_name="${MARGIN_MAKER_APP_NAME:-Margin Maker}"
bundle_id="${MARGIN_MAKER_BUNDLE_ID:-local.marginmaker.app}"
if [[ -n "${MARGIN_MAKER_APP_NAME:-}" || -n "${MARGIN_MAKER_BUNDLE_ID:-}" ]]; then
    if [[ -z "${MARGIN_MAKER_APP_NAME:-}" || -z "${MARGIN_MAKER_BUNDLE_ID:-}" ]]; then
        echo "Set both MARGIN_MAKER_APP_NAME and MARGIN_MAKER_BUNDLE_ID for a QA build." >&2
        exit 2
    fi
fi
if [[ "$app_name" == */* || "$app_name" == *$'\n'* ||
      "$app_name" == . || "$app_name" == .. ||
      ! "$bundle_id" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+$ ]]; then
    echo "Use a simple application name and a valid bundle identifier." >&2
    exit 2
fi
output_dir="${2:-$PWD/build}"
app_output="$output_dir/$app_name.app"
zip_output="$output_dir/$app_name.zip"
if [[ -e "$app_output" || -L "$app_output" || -e "$zip_output" || -L "$zip_output" ]]; then
    echo "Refusing to replace an existing application or ZIP. Choose a fresh output directory." >&2
    exit 1
fi

# Keep compiler caches inside the checkout for restricted local environments.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
package_flags=(--disable-sandbox --cache-path "$PWD/.build/package-cache"
               --config-path "$PWD/.build/package-config"
               --security-path "$PWD/.build/package-security")
swift build "${package_flags[@]}" -c "$configuration"
binary_dir="$(swift build "${package_flags[@]}" -c "$configuration" --show-bin-path)"
mkdir -p "$output_dir"
# Sign outside synced folders, where providers may reattach Finder metadata.
staging_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/margin-maker.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app="$staging_dir/$app_name.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MarginMaker" "$app/Contents/MacOS/MarginMaker"
cp Packaging/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $app_name" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $app_name" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
bash scripts/build-icon.sh "$app/Contents/Resources/AppIcon.icns"
# Remove only metadata that codesign forbids; preserve iCloud provider attributes.
xattr -dr com.apple.FinderInfo "$app" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$app" 2>/dev/null || true
# Ad-hoc signing allows local execution. This is NOT Developer ID signing or notarization.
codesign --force --sign - "$app"
codesign --verify --strict "$app"
# A metadata-free archive remains intact when this checkout is in iCloud Drive.
ditto --norsrc --noextattr -c -k --keepParent "$app" "$zip_output"
ditto --norsrc --noextattr "$app" "$app_output"
echo "Built local app: $app_output"
echo "Local app archive: $zip_output"
