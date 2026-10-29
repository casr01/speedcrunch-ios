#!/bin/bash
# Double-click to regenerate the Xcode project and open it.
cd "$(dirname "$0")"
scripts/setup-ios.sh 2>&1 | tee preparation.log
echo
echo "Done. Xcode should be open now; you can close this window."
