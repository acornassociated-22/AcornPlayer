#!/usr/bin/env bash
# Build the Linux release bundle and package it as .deb plus a portable .tar.gz.
set -euo pipefail
source "$(dirname "$0")/_common.sh"

BUNDLE="$ROOT/build/linux/x64/release/bundle"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "==> flutter build linux --release"
  flutter build linux --release
fi

if [[ ! -x "$BUNDLE/$BINARY_NAME" ]]; then
  echo "Bundle not found at $BUNDLE" >&2
  exit 1
fi

# --- .deb ---------------------------------------------------------------
DEB_ROOT="$DIST/deb/${PKG_NAME}_${VERSION}_amd64"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN" "$DEB_ROOT/usr/lib/$PKG_NAME" "$DEB_ROOT/usr/bin" \
  "$DEB_ROOT/usr/share/applications" "$DEB_ROOT/usr/share/icons/hicolor"

cp -r "$BUNDLE"/. "$DEB_ROOT/usr/lib/$PKG_NAME/"

cat > "$DEB_ROOT/usr/bin/$PKG_NAME" <<EOF
#!/bin/sh
exec /usr/lib/$PKG_NAME/$BINARY_NAME "\$@"
EOF
chmod 755 "$DEB_ROOT/usr/bin/$PKG_NAME"

write_desktop_entry "$DEB_ROOT/usr/share/applications/$PKG_NAME.desktop" "$PKG_NAME %U"
render_icons "$DEB_ROOT/usr/share/icons/hicolor" 16 32 48 64 128 256 512

INSTALLED_KB="$(du -sk "$DEB_ROOT" | cut -f1)"
cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: sound
Priority: optional
Architecture: amd64
Maintainer: Acorn Associated <Info@acornassociated.org>
Installed-Size: $INSTALLED_KB
Depends: libc6, libgtk-3-0 | libgtk-3-0t64, libmpv2 | libmpv1, libasound2t64 | libasound2
Homepage: https://acornassociated.org/
Description: Neumorphic local music player
 Acorn Player is a soft-UI music player for your own files: folder scan,
 SQLite library, embedded cover art, waveform seeking and a vinyl platter
 that doubles as the progress ring. No account, no cloud, no tracking.
EOF

DEB_FILE="$RELEASES/${PKG_NAME}_${VERSION}_amd64.deb"
rm -f "$DEB_FILE"
dpkg-deb --root-owner-group --build "$DEB_ROOT" "$DEB_FILE" >/dev/null
echo "==> $DEB_FILE"

# --- portable .tar.gz ---------------------------------------------------
TAR_ROOT="$DIST/tar/${PKG_NAME}-${VERSION}-linux-x64"
rm -rf "$TAR_ROOT"
mkdir -p "$TAR_ROOT"
cp -r "$BUNDLE"/. "$TAR_ROOT/"
cp "$ICON_SOURCE" "$TAR_ROOT/$PKG_NAME.png"
write_desktop_entry "$TAR_ROOT/$PKG_NAME.desktop" "$PKG_NAME %U"

cat > "$TAR_ROOT/install.sh" <<EOF
#!/usr/bin/env bash
# Install Acorn Player for the current user (no root needed).
set -euo pipefail
HERE="\$(cd "\$(dirname "\$0")" && pwd)"
PREFIX="\$HOME/.local"
APP_DIR="\$PREFIX/share/$PKG_NAME"

mkdir -p "\$APP_DIR" "\$PREFIX/bin" "\$PREFIX/share/applications" "\$PREFIX/share/icons/hicolor/512x512/apps"
cp -r "\$HERE"/. "\$APP_DIR/"
ln -sf "\$APP_DIR/$BINARY_NAME" "\$PREFIX/bin/$PKG_NAME"
cp "\$HERE/$PKG_NAME.png" "\$PREFIX/share/icons/hicolor/512x512/apps/$PKG_NAME.png"
sed "s|^Exec=.*|Exec=\$PREFIX/bin/$PKG_NAME %U|" "\$HERE/$PKG_NAME.desktop" \\
  > "\$PREFIX/share/applications/$PKG_NAME.desktop"

echo "Installed. Run '$PKG_NAME' or launch Acorn Player from your app menu."
echo "Needs libmpv2 and GTK 3: sudo apt install libmpv2 libgtk-3-0"
EOF
chmod 755 "$TAR_ROOT/install.sh"

TAR_FILE="$RELEASES/${PKG_NAME}_${VERSION}_linux_x64.tar.gz"
rm -f "$TAR_FILE"
tar -czf "$TAR_FILE" -C "$(dirname "$TAR_ROOT")" "$(basename "$TAR_ROOT")"
echo "==> $TAR_FILE"
