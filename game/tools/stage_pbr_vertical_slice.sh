#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/assets/vendor/pbr"
CACHE="$ROOT/.asset-cache/pbr"

MAGE_PIN="973e08700a721330b281cf2f6ce50d5ae191763d"
MAGE_RAW="https://raw.githubusercontent.com/turican0/MagicBalls/${MAGE_PIN}/godot-code/entites/sources/wizards/pbr_shadowkin_mage_rigged.glb"

# dark_igorek — The Forgotten Knight. TexVerse metadata maps the original
# Sketchfab object to this exact 1K PBR GLB path. Pin the dataset revision so
# CI does not silently change the visual gate underneath us.
KNIGHT_ID="d14eb14d83bd4e7ba7cbe443d76a10fd"
TEXVERSE_REV="8b4bf4a6eb0c3b3ce5244a863621d79b4d3f344d"
KNIGHT_RAW="https://huggingface.co/datasets/YiboZhang2001/TexVerse-1K/resolve/${TEXVERSE_REV}/glbs/glbs_1k/000-041/${KNIGHT_ID}_1024.glb?download=true"

rm -rf "$TARGET" "$CACHE"
mkdir -p "$TARGET" "$CACHE"

fetch_model() {
  local label="$1"
  local url="$2"
  local output="$3"
  local min_bytes="$4"

  printf '\n=== STAGE %s ===\n' "$label"
  curl -fL --retry 4 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 180 \
    "$url" -o "$output"
  test -s "$output"

  local bytes
  bytes="$(wc -c < "$output" | tr -d ' ')"
  if (( bytes < min_bytes )); then
    echo "$label download is suspiciously small: ${bytes} bytes" >&2
    exit 1
  fi

  # A GLB starts with the ASCII magic bytes glTF. This catches HTML/login/error
  # bodies that occasionally arrive with HTTP 200 from third-party mirrors.
  local magic
  magic="$(head -c 4 "$output" || true)"
  if [[ "$magic" != "glTF" ]]; then
    echo "$label is not a GLB (magic='$magic')" >&2
    exit 1
  fi

  sha256sum "$output"
  echo "OK: $(basename "$output") (${bytes} bytes)"
}

# Ferocious Industries — PBR Shadowkin Mage (Rigged), CC BY.
fetch_model "PBR Shadowkin Mage" "$MAGE_RAW" "$TARGET/ShadowkinMage.glb" 500000

# dark_igorek — The Forgotten Knight, CC BY. High-poly by design: this is a
# two-character cinematic reference gate, not the 32-piece mobile runtime LOD.
fetch_model "PBR Forgotten Knight" "$KNIGHT_RAW" "$TARGET/ForgottenKnight.glb" 1000000

cat > "$TARGET/PROVENANCE.md" <<EOF
# High-fidelity vertical-slice assets

These models are staged only for the cinematic art-direction gate. Runtime
mobile pieces will receive dedicated LOD/retopology before production use.

## PBR Shadowkin Mage (Rigged)
- Creator: Ferocious Industries
- Original: https://sketchfab.com/3d-models/pbr-shadowkin-mage-rigged-7aab96637055455297d158584b1602cd
- License: Creative Commons Attribution (CC BY), as published by the creator on Sketchfab.
- Runtime staging mirror: https://github.com/turican0/MagicBalls
- Mirror pin: ${MAGE_PIN}
- Runtime file: ShadowkinMage.glb

## The Forgotten Knight
- Creator: dark_igorek
- Original: https://sketchfab.com/3d-models/the-forgotten-knight-${KNIGHT_ID}
- License: Creative Commons Attribution (CC BY), as published by the creator and recorded by TexVerse metadata.
- Dataset: https://huggingface.co/datasets/YiboZhang2001/TexVerse-1K
- Dataset revision: ${TEXVERSE_REV}
- TexVerse path: glbs/glbs_1k/000-041/${KNIGHT_ID}_1024.glb
- Runtime file: ForgottenKnight.glb
- Source mesh is intentionally high-poly and is NOT approved for 32-piece mobile runtime use without LOD/retopology.

These assets are used only as original dark-fantasy building blocks. No Harry Potter characters, house marks, costumes, symbols, names or franchise assets are included.
EOF

printf '\nPBR staged files:\n'
find "$TARGET" -type f -printf '%P %k KB\n' | sort
