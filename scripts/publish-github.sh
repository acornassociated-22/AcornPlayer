#!/usr/bin/env bash
# Create the GitHub repo, push main, tag the version and publish the release with local artifacts.
# Prerequisites: gh auth login  (never put passwords in this script)
set -euo pipefail
source "$(dirname "$0")/_common.sh"

TAG="${RELEASE_TAG:-v$VERSION}"
REPO_NAME="${GITHUB_REPO_NAME:-AcornPlayer}"
DESCRIPTION="Neumorphic local music player for Linux, Windows, macOS, Android and iOS — Flutter"

# Resolve gh: env override, PATH or ~/.local/bin.
resolve_gh() {
  if [[ -n "${GH:-}" ]] && command -v "$GH" >/dev/null 2>&1; then
    command -v "$GH"
    return 0
  fi
  if [[ -x "$HOME/.local/bin/gh" ]]; then
    echo "$HOME/.local/bin/gh"
    return 0
  fi
  command -v gh 2>/dev/null || true
}

GH="$(resolve_gh || true)"
if [[ -z "$GH" ]] || ! "$GH" --version >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found — see https://cli.github.com/" >&2
  exit 1
fi

if ! "$GH" auth status >/dev/null 2>&1; then
  echo "Not logged in. Run: $GH auth login" >&2
  exit 1
fi

GH_USER="$("$GH" api user --jq .login)"
REPO="${GITHUB_REPO:-${GH_USER}/${REPO_NAME}}"
REPO_OWNER="${REPO%%/*}"
if [[ "$REPO_OWNER" != "$GH_USER" ]]; then
  echo "Logged in as '$GH_USER' but target owner is '$REPO_OWNER'." >&2
  exit 1
fi

echo "==> GitHub account: $GH_USER"
echo "==> Target repo: $REPO ($TAG)"

if ! "$GH" repo view "$REPO" >/dev/null 2>&1; then
  echo "==> Creating public repo $REPO"
  "$GH" repo create "$REPO_NAME" --public --description "$DESCRIPTION" --homepage "https://acornassociated.org/"
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "https://github.com/${REPO}.git"
else
  git remote add origin "https://github.com/${REPO}.git"
fi

"$GH" repo edit "$REPO" \
  --description "$DESCRIPTION" \
  --homepage "https://acornassociated.org/" \
  --add-topic flutter --add-topic music-player --add-topic neumorphism \
  --add-topic dart --add-topic linux --add-topic windows --add-topic macos \
  --add-topic android --add-topic ios --add-topic offline-first >/dev/null

echo "==> Pushing main"
git push -u origin main

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "$APP_NAME $VERSION"
fi
git push origin "$TAG"

ASSETS=()
shopt -s nullglob
for f in "$RELEASES"/${PKG_NAME}_"${VERSION}"*; do
  ASSETS+=("$f")
done
shopt -u nullglob

NOTES="$(cat <<EOF
## Acorn Player $VERSION

A soft-UI, local-first music player: folder scan, SQLite library, embedded cover art,
waveform seeking and a vinyl platter that doubles as the progress ring. No account, no cloud.

### Downloads

| Platform | File |
|:--|:--|
| Linux (x64) | \`${PKG_NAME}_${VERSION}_amd64.deb\` |
| Linux (portable) | \`${PKG_NAME}_${VERSION}_linux_x64.tar.gz\` |
| Android (universal) | \`${PKG_NAME}_${VERSION}.apk\` |
| Windows (x64) | \`${PKG_NAME}_${VERSION}_windows_x64_setup.exe\` · \`..._windows_x64.zip\` |
| macOS | \`${PKG_NAME}_${VERSION}_macos.dmg\` |
| iOS | \`${PKG_NAME}_${VERSION}_ios_unsigned.ipa\` |

Windows, macOS and iOS files are built by the release workflow and appear here once it finishes.
macOS and iOS builds are unsigned: on macOS use right-click → Open, on iOS sideload with your own identity.

### Install

\`\`\`bash
sudo apt install ./${PKG_NAME}_${VERSION}_amd64.deb   # Linux
\`\`\`

Requires \`libmpv2\` and GTK 3 on Linux. Android APK is signed with a debug key.
EOF
)"

if "$GH" release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "==> Release $TAG exists — uploading ${#ASSETS[@]} artifact(s)"
  ((${#ASSETS[@]} == 0)) || "$GH" release upload "$TAG" --repo "$REPO" --clobber "${ASSETS[@]}"
else
  echo "==> Creating release $TAG with ${#ASSETS[@]} artifact(s)"
  "$GH" release create "$TAG" --repo "$REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "$NOTES" \
    "${ASSETS[@]}"
fi

echo "==> Done: https://github.com/${REPO}/releases/tag/${TAG}"
