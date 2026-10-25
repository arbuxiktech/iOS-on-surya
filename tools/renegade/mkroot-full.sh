#!/bin/bash
# Build the full iOS 18.7.8 root image: see tools/renegade/README.md. No sudo on macOS.
#   tools/renegade/fetch-root.sh        # (once) download + decrypt the three dmgs
#   tools/renegade/mkroot-full.sh [--board beryllium|surya] [mkroot-full.py options]
# -> research/ios18/ios18-root-full.simg (Beryllium) or ios18-root-full-surya.simg
#    (Surya; the raw image is consumed while the simg is written)
set -euo pipefail
cd "$(dirname "$0")/../.."
exec python3 -I tools/renegade/mkroot-full.py "$@"
