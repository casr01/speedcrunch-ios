#!/bin/bash
# Double-click to check that the project builds for iPhone (unsigned).
cd "$(dirname "$0")"
scripts/setup-ios.sh --check 2>&1 | tee verification.log
echo
echo "Done. You can close this window."
