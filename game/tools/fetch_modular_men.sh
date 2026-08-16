#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-/tmp/quaternius-modular-men}"
rm -rf "$OUT"
mkdir -p "$OUT"
python3 -m pip install -q gdown==5.2.0
gdown --folder "https://drive.google.com/drive/folders/1USAAquX2JJWuA2m6zol0KUkFe3UkZ8zX" -O "$OUT" --remaining-ok
printf '\nDownloaded modular-men files: %s\n' "$(find "$OUT" -type f | wc -l)"
printf '\nLikely character/GLTF assets:\n'
find "$OUT" -type f \( -iname '*.gltf' -o -iname '*.glb' -o -iname '*.fbx' \) -printf '%P\n' | grep -Ei 'knight|king|queen|medieval|wizard|mage|character|body|outfit|modular|soldier|adventurer' | head -200 || true
printf '\nTop-level tree:\n'
find "$OUT" -maxdepth 3 -type d -printf '%P/\n' | head -120
