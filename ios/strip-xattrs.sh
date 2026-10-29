#!/bin/sh
# Called by Xcode after linking, before CodeSign. Xcode exports its build
# settings as environment variables; CODESIGNING_FOLDER_PATH is the .app bundle.
set -e
APP="${CODESIGNING_FOLDER_PATH:-${TARGET_BUILD_DIR}/${WRAPPER_NAME}}"
if [ -d "$APP" ]; then
    /usr/bin/xattr -cr "$APP"
    echo "Extended attributes removed from $APP"
else
    echo "warning: app bundle not found at '$APP'; skipping xattr cleanup"
fi
