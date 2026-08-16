#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/.asset-cache/ffxi-browser"
TARGET="$ROOT/assets/vendor/quaternius"
PIN="d65cd213cffb9c0ef17e3f70a6a46ea82ba47dfa"
REMOTE="https://github.com/lord3nd3r/ffxi-browser.git"

rm -rf "$CACHE" "$TARGET"
mkdir -p "$(dirname "$CACHE")" "$TARGET"

git init -q "$CACHE"
git -C "$CACHE" remote add origin "$REMOTE"
git -C "$CACHE" fetch -q --depth 1 origin "$PIN"
git -C "$CACHE" checkout -q FETCH_HEAD

cp -R "$CACHE/public/models/chars/." "$TARGET/"

cat > "$TARGET/PROVENANCE.md" <<EOF
# Third-party visual assets

Character bases/outfits and the Universal Animation Library are Quaternius assets distributed under CC0 1.0.

Official sources:
- https://quaternius.com/packs/universalbasecharacters.html
- https://quaternius.com/packs/modularcharacteroutfitsfantasy.html
- https://quaternius.com/packs/universalanimationlibrary.html

Build mirror used for deterministic CI staging:
- https://github.com/lord3nd3r/ffxi-browser
- pinned commit: $PIN

Only the character folder is staged into the build. The generated vendor folder is not hand-edited.
EOF

printf 'Staged visual assets: '
find "$TARGET" -type f | wc -l
