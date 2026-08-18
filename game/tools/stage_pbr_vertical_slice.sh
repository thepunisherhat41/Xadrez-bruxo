#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/assets/vendor/pbr"
CACHE="$ROOT/.asset-cache/pbr"
MAGE_PIN="973e08700a721330b281cf2f6ce50d5ae191763d"
MAGE_RAW="https://raw.githubusercontent.com/turican0/MagicBalls/${MAGE_PIN}/godot-code/entites/sources/wizards/pbr_shadowkin_mage_rigged.glb"
KNIGHT_FOLDER="https://drive.google.com/drive/folders/1VwJEb5of_BHNTJVuVKCFsR5jYoFEBqyP"

rm -rf "$TARGET" "$CACHE"
mkdir -p "$TARGET" "$CACHE"

# Ferocious Industries — PBR Shadowkin Mage (Rigged), CC BY.
# A pinned public mirror is used solely for deterministic CI staging.
curl -fL --retry 3 --retry-delay 2 "$MAGE_RAW" -o "$TARGET/ShadowkinMage.glb"
test -s "$TARGET/ShadowkinMage.glb"

# soidev — Lowpoly PBR Knight Armour, CC BY. The creator publishes a public
# Drive folder with full-resolution textures and the rigged source. For now we
# enumerate it deterministically and keep the manifest as CI evidence so we can
# choose the lightest production-friendly rig/material combination.
python3 -m pip install -q gdown==6.1.0
gdown "$KNIGHT_FOLDER" --folder --json --quiet > "$CACHE/knight-manifest.json"

printf '\n=== KNIGHT PBR MANIFEST: likely runtime assets ===\n'
jq -r '.[] | select(.path | test("\\.(glb|gltf|fbx|blend|unitypackage|png|tga|jpg|jpeg)$"; "i")) | [.path,.url] | @tsv' "$CACHE/knight-manifest.json" | head -240

cat > "$TARGET/PROVENANCE.md" <<EOF
# High-fidelity vertical-slice assets

## PBR Shadowkin Mage (Rigged)
- Creator: Ferocious Industries
- Original: https://sketchfab.com/3d-models/pbr-shadowkin-mage-rigged-7aab96637055455297d158584b1602cd
- License: Creative Commons Attribution (CC BY), as published by the creator on Sketchfab.
- Runtime staging mirror: https://github.com/turican0/MagicBalls
- Mirror pin: ${MAGE_PIN}
- Runtime file: ShadowkinMage.glb

## Lowpoly PBR Knight Armour
- Creator: soidev
- Original: https://sketchfab.com/3d-models/lowpoly-pbr-knight-armour-7e8485a272784e6cb3b5bda68ff319fa
- License: Creative Commons Attribution (CC BY), as published by the creator on Sketchfab.
- Creator-provided full-resolution source: ${KNIGHT_FOLDER}
- Current step: manifest only; no knight source is promoted until the exact mobile-suitable rig/material set is selected.

These assets are used only as original dark-fantasy building blocks. No Harry Potter characters, house marks, costumes, symbols, names or franchise assets are included.
EOF

printf '\nPBR staged files:\n'
find "$TARGET" -type f -printf '%P %k KB\n' | sort
