#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/assets/vendor/quaternius"
CACHE="$ROOT/.asset-cache/rpg-pack"
FOLDER="https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b"

rm -rf "$TARGET" "$CACHE"
mkdir -p "$TARGET" "$CACHE"
python3 -m pip install -q gdown==6.1.0

gdown "$FOLDER" --folder --json --quiet > "$CACHE/manifest.json"

jq -r '
  .[]
  | select(
      (.path | test("^glTF/(Cleric|Monk|Ranger|Rogue|Warrior|Wizard)\\.gltf$"))
      or (.path | test("^Textures/.*\\.png$"; "i"))
      or (.path | test("License\\.txt$"; "i"))
    )
  | [.url, .path] | @tsv
' "$CACHE/manifest.json" > "$CACHE/selected.tsv"

while IFS=$'\t' read -r url rel; do
  [[ -n "$url" && -n "$rel" ]] || continue
  mkdir -p "$TARGET/$(dirname "$rel")"
  gdown "$url" -O "$TARGET/$rel" --quiet
done < "$CACHE/selected.tsv"

for required in Cleric Monk Ranger Rogue Warrior Wizard; do
  test -s "$TARGET/glTF/$required.gltf"
done

cat > "$TARGET/PROVENANCE.md" <<'EOF'
# Quaternius RPG Character Pack

Official pack: https://quaternius.com/packs/rpgcharacters.html
Official public Drive folder: https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b
License: CC0 1.0

Selected runtime characters:
- Cleric
- Monk
- Ranger
- Rogue
- Warrior
- Wizard

Only the six glTF character files and their texture folder are staged into the build. They are downloaded from the creator's public Drive at build time and are not committed into this repository.
EOF

printf 'Staged RPG visual assets:\n'
find "$TARGET" -type f -printf '%P %k KB\n' | sort
