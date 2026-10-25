#!/bin/bash
# Build the libdrm stand-in for ARCH (default arm64e); arm64e output is PAC-stripped and signed.
#   gpu/freedreno-sweet/build.sh [OUTDIR]     default: gpu/freedreno-sweet/out/libdrm.2.dylib
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/out}"
ARCH="${ARCH:-arm64e}"
IOS_MIN_VERSION="${IOS_MIN_VERSION:-18.0}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
mkdir -p "$OUT"
xcrun --sdk iphoneos clang -arch "$ARCH" -miphoneos-version-min="$IOS_MIN_VERSION" -isysroot "$SDK" -O2 -g -Wall -Wextra -fvisibility=hidden \
    -dynamiclib -install_name @rpath/libdrm.2.dylib -current_version 2.4.0 -compatibility_version 2.0.0 \
    "$HERE/sweet_drm.c" -o "$OUT/libdrm.2.$ARCH.dylib" -framework IOKit -framework CoreFoundation
if [[ "$ARCH" == arm64e ]]; then
    "$HERE/../../tools/renegade/renegade" strip --sign -o "$OUT/libdrm.2.dylib" "$OUT/libdrm.2.$ARCH.dylib"
else
    cp -f "$OUT/libdrm.2.$ARCH.dylib" "$OUT/libdrm.2.dylib"
    codesign -s - -f "$OUT/libdrm.2.dylib"
fi
ls -l "$OUT/libdrm.2.dylib"
