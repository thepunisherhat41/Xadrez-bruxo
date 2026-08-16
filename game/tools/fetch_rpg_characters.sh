#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-/tmp/quaternius-rpg-characters}"
rm -rf "$OUT"
mkdir -p "$OUT"
python3 -m pip install -q gdown==5.2.0
set +e
gdown --folder "https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b" -O "$OUT" --remaining-ok
GDOWN_RC=$?
set -e
printf '\nGDOWN_RC=%s\n' "$GDOWN_RC"
printf 'Downloaded RPG files: %s\n' "$(find "$OUT" -type f | wc -l)"
printf '\nCharacter assets found:\n'
find "$OUT" -type f \( -iname '*.gltf' -o -iname '*.glb' -o -iname '*.fbx' \) -printf '%P\n' | sort | head -240
printf '\nLikely classes:\n'
find "$OUT" -type f -printf '%P\n' | grep -Ei 'wizard|mage|knight|monk|ranger|assassin|rogue|warrior' | head -240 || true
