#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-/tmp/quaternius-current}"
rm -rf "$OUT"
mkdir -p "$OUT"

npx -y itchio-downloader@1.2.0 \
  --url "https://quaternius.itch.io/modular-character-outfits-fantasy" \
  --downloadDirectory "$OUT" \
  --noCookieCache

printf '\nDownloaded files:\n'
find "$OUT" -maxdepth 2 -type f -printf '%p %k KB\n' | sort
ZIP="$(find "$OUT" -type f -iname '*.zip' | head -1)"
if [[ -z "$ZIP" ]]; then
  echo "No ZIP returned by itch downloader" >&2
  exit 1
fi
printf '\nSelected ZIP: %s\n' "$ZIP"
printf '\nRelevant outfit entries:\n'
unzip -l "$ZIP" | grep -Ei '(^|/)(Male|Female)_(Knight|Wizard|Noble|Ranger|Peasant)|Knight|Wizard|Noble' | head -120 || true
