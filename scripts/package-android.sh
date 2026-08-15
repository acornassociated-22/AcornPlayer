#!/usr/bin/env bash
# Build the release APK (universal) and copy it into releases/.
set -euo pipefail
source "$(dirname "$0")/_common.sh"

echo "==> flutter build apk --release"
flutter build apk --release

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$APK" ]]; then
  echo "APK not found at $APK" >&2
  exit 1
fi

APK_FILE="$RELEASES/${PKG_NAME}_${VERSION}.apk"
cp "$APK" "$APK_FILE"
echo "==> $APK_FILE"
