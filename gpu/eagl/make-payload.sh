#!/bin/bash
# SPDX-License-Identifier: MIT
# Build the payload that the Renegade root tweak "bglrender" installs into /usr/local/lib/bergamota-gl/ of the iOS root:
#   bgl-launch                     launchd job target of backboardd (execs the real one, injects the shim only with bglrender=1|soft)
#   OpenGLES.framework/OpenGLES    injection build of the shim (patches the real EAGLContext/EAGLSharegroup at load)
#   libOSMesa.8.dylib              Mesa 25.0.7: freedreno (a6xx) + softpipe, GLES 1/2/3 (rpath @loader_path)
#   libdrm.2.dylib                 the libdrm stand-in over SweetAdreno630
# ARCH=arm64e is PAC-stripped and signed; ARCH=arm64 is signed as built. Output: research/bergamota-gl/ (git-ignored) + MANIFEST.
#   GPU_EAGL_WORK=<scratch with mesa/ and build-hw/> gpu/eagl/make-payload.sh [OUTDIR]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${GPU_EAGL_WORK:?set GPU_EAGL_WORK}"
OUT="${1:-$REPO/research/bergamota-gl}"
ARCH="${ARCH:-arm64e}"
IOS_MIN_VERSION="${IOS_MIN_VERSION:-18.0}"
MESA_BLD="${MESA_BLD:-$WORK/build-hw}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
TMP="$WORK/payload-build"
rm -rf "$TMP" "$OUT"; mkdir -p "$TMP" "$OUT/OpenGLES.framework"
ARCH="$ARCH" IOS_MIN_VERSION="$IOS_MIN_VERSION" EAGL_DEFS=-DEAGL_INJECT MESA_BLD="$MESA_BLD" "$HERE/build.sh" "$TMP/inj" >/dev/null
xcrun --sdk iphoneos clang -arch "$ARCH" -miphoneos-version-min="$IOS_MIN_VERSION" -isysroot "$SDK" -O2 -Wall -Wextra "$HERE/launch/bgl-launch.c" -o "$TMP/bgl-launch"
cp "$TMP/bgl-launch" "$OUT/bgl-launch"
cp "$TMP/inj/OpenGLES.framework/OpenGLES" "$OUT/OpenGLES.framework/OpenGLES"
cp "$TMP/inj/libOSMesa.8.dylib" "$TMP/inj/libdrm.2.dylib" "$OUT/"
for f in bgl-launch OpenGLES.framework/OpenGLES libOSMesa.8.dylib libdrm.2.dylib; do
  if [[ "$ARCH" == arm64e ]]; then
    python3 -I "$REPO/tools/renegade/pacstrip.py" --sign "$OUT/$f" >/dev/null
  else
    codesign -s - -f "$OUT/$f"
  fi
done
(cd "$OUT" && shasum -a 256 bgl-launch OpenGLES.framework/OpenGLES libOSMesa.8.dylib libdrm.2.dylib > MANIFEST.sha256 && cat MANIFEST.sha256 && ls -l bgl-launch OpenGLES.framework/OpenGLES libOSMesa.8.dylib libdrm.2.dylib)
