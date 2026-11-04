#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
# Command Line Tools ships Testing as a framework, but SwiftPM does not add -F.
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
test_flags=()
if [[ -d "$frameworks/Testing.framework" ]]; then
    test_flags=(-Xswiftc -F -Xswiftc "$frameworks"
                -Xlinker -F -Xlinker "$frameworks"
                -Xlinker -rpath -Xlinker "$frameworks")
fi
swift test --disable-sandbox --disable-xctest \
    --cache-path "$PWD/.build/package-cache" \
    --config-path "$PWD/.build/package-config" \
    --security-path "$PWD/.build/package-security" "${test_flags[@]}" "$@"
