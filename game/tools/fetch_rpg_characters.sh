#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-/tmp/quaternius-rpg-characters}"
rm -rf "$OUT"
mkdir -p "$OUT"
python3 -m pip install -q gdown==6.1.0
FOLDER="https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b"
gdown "$FOLDER" --folder --json --quiet > "$OUT/manifest.json"
printf 'RPG manifest entries: '
jq 'length' "$OUT/manifest.json"
printf '\nLikely class assets:\n'
jq -r '.[] | select(.path | test("wizard|mage|knight|monk|ranger|assassin|rogue|warrior"; "i")) | [.path,.url] | @tsv' "$OUT/manifest.json" | head -240
printf '\nAll glTF/GLB assets:\n'
jq -r '.[] | select(.path | test("\\.(gltf|glb)$"; "i")) | [.path,.url] | @tsv' "$OUT/manifest.json" | head -240
