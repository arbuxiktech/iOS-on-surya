#!/bin/bash
# Build the native arm64 iOS 18 tools and EAGL/Mesa payload used by the Surya Renegade root.
#   GPU_EAGL_WORK=/scratch/surya-eagl tools/renegade/build-surya-userland.sh
# Outputs: research/surya-sweetnet/ios18/ and research/surya-gles/ (both ignored build artifacts).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${GPU_EAGL_WORK:?set GPU_EAGL_WORK to a scratch directory for Mesa's source and build files}"
SWEETNET_OUT="${SWEETNET_OUT:-$REPO/research/surya-sweetnet}"
BGL_OUT="${SURYA_BGL_OUT:-$REPO/research/surya-gles}"
cd "$REPO"

SWEETNET_OUT="$SWEETNET_OUT" IOS18_ARCH=arm64 IOS18_MIN_VERSION=18.0 \
	sh tools/sweetnet/build.sh
ARCH=arm64 IOS_MIN_VERSION=18.0 GPU_EAGL_WORK="$WORK" \
	gpu/eagl/mesa/build-mesa.sh
ARCH=arm64 IOS_MIN_VERSION=18.0 GPU_EAGL_WORK="$WORK" MESA_BLD="$WORK/build-hw" \
	gpu/eagl/make-payload.sh "$BGL_OUT"

printf 'Surya iOS 18 tools: %s\n' "$SWEETNET_OUT"
printf 'Surya EAGL/Mesa payload: %s\n' "$BGL_OUT"
printf 'Use RENEGADE_SWEETNET_SURYA=%s and RENEGADE_BGL_SURYA=%s with renegade root --board surya.\n' \
	"$SWEETNET_OUT" "$BGL_OUT"
