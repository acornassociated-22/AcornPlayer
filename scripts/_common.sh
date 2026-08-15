#!/usr/bin/env bash
# Shared paths and metadata for the packaging scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_ID="com.acorn.acorn_player"
APP_NAME="Acorn Player"
PKG_NAME="acorn-player"
BINARY_NAME="acorn_player"
ICON_SOURCE="$ROOT/promo/app_icon.png"
RELEASES="$ROOT/releases"
DIST="$ROOT/dist"

VERSION="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "$ROOT/pubspec.yaml" | head -1)"
if [[ -z "$VERSION" ]]; then
  echo "Could not read version from pubspec.yaml" >&2
  exit 1
fi

mkdir -p "$RELEASES"

# Render the app icon into a target directory at the given square sizes.
render_icons() {
  local out_dir="$1"
  shift
  python3 - "$ICON_SOURCE" "$out_dir" "$@" <<'PY'
import os, sys
from PIL import Image

src, out_dir, *sizes = sys.argv[1:]
icon = Image.open(src).convert("RGBA")
for raw in sizes:
    size = int(raw)
    target = os.path.join(out_dir, f"{size}x{size}", "apps")
    os.makedirs(target, exist_ok=True)
    icon.resize((size, size), Image.LANCZOS).save(os.path.join(target, "acorn-player.png"))
PY
}

# Write the shared freedesktop entry; $1 is the destination file, $2 the Exec value.
write_desktop_entry() {
  local dest="$1"
  local exec_line="$2"
  cat > "$dest" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
GenericName=Music Player
Comment=Play your local music library
Exec=$exec_line
Icon=$PKG_NAME
Terminal=false
Categories=AudioVideo;Audio;Player;
MimeType=audio/mpeg;audio/flac;audio/x-wav;audio/mp4;audio/ogg;audio/x-m4a;
StartupWMClass=$BINARY_NAME
EOF
}
