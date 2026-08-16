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

# The deterministic mirror keeps BaseColor maps but omits some technical maps
# referenced by the original glTF files. Create tiny neutral maps so Godot can
# import the scenes without broken texture references. They do not replace the
# visible BaseColor artwork.
TARGET="$TARGET" python3 - <<'PY'
from pathlib import Path
import os, struct, zlib

root = Path(os.environ["TARGET"])

def chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    crc = zlib.crc32(body) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + body + struct.pack(">I", crc)

def write_png(name: str, rgba: tuple[int, int, int, int]):
    path = root / name
    if path.exists():
        return
    width = height = 4
    raw = b"".join(b"\x00" + bytes(rgba) * width for _ in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)

normal = (128, 128, 255, 255)
rough = (220, 220, 220, 255)
orm = (255, 205, 0, 255)

for name in [
    "T_Hair_1_Normal_png.png",
    "T_Hair_2_Normal.png",
    "T_Eye_Normal_png.png",
    "T_Superhero_Male_Normal.png",
    "T_Superhero_Female_Normal.png",
    "T_Ranger_Normal.png",
    "T_Regular_Male_Normal.png",
    "T_Regular_Female_Normal.png",
    "T_Peasant_Normal.png",
]:
    write_png(name, normal)

for name in [
    "T_Superhero_Male_Roughness.png",
    "T_Superhero_Female_Roughness.png",
    "T_Regular_Male_Roughness.png",
    "T_Regular_Female_Roughness.png",
]:
    write_png(name, rough)

for name in ["T_Ranger_ORM.png", "T_Peasant_ORM.png"]:
    write_png(name, orm)
PY

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

The mirror carries the visible BaseColor textures and character geometry. Missing neutral normal/roughness/ORM technical maps are generated locally at build time solely to satisfy the original glTF references; no visible copyrighted artwork is synthesized or substituted.
EOF

printf 'Staged visual assets: '
find "$TARGET" -type f | wc -l
