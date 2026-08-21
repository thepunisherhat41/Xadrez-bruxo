#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/assets/vendor/rpg"
CACHE="$ROOT/.asset-cache/rpg-pack"
FOLDER="https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b"

rm -rf "$TARGET" "$CACHE"
mkdir -p "$TARGET" "$CACHE"
python3 -m pip install -q gdown==6.1.0

gdown "$FOLDER" --folder --json --quiet > "$CACHE/manifest.json"

CACHE="$CACHE" TARGET="$TARGET" python3 - <<'PY'
from pathlib import Path
import json, os, posixpath, subprocess

cache = Path(os.environ['CACHE'])
target = Path(os.environ['TARGET'])
manifest = json.loads((cache / 'manifest.json').read_text())
by_path = {item['path']: item['url'] for item in manifest}

models = [
    'glTF/Cleric.gltf',
    'glTF/Monk.gltf',
    'glTF/Ranger.gltf',
    'glTF/Rogue.gltf',
    'glTF/Warrior.gltf',
    'glTF/Wizard.gltf',
]

def download(path: str):
    if path not in by_path:
        raise SystemExit(f'Missing manifest entry: {path}')
    out = target / path
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 0:
        return
    subprocess.run(['gdown', by_path[path], '-O', str(out), '--quiet'], check=True)
    if not out.exists() or out.stat().st_size == 0:
        raise SystemExit(f'Empty download: {path}')

for model in models:
    download(model)

# Pull only resources actually referenced by the chosen glTFs.
for model in models:
    doc = json.loads((target / model).read_text())
    base = posixpath.dirname(model)
    refs = []
    refs += [item.get('uri') for item in doc.get('buffers', [])]
    refs += [item.get('uri') for item in doc.get('images', [])]
    for uri in refs:
        if not uri or uri.startswith('data:'):
            continue
        resolved = posixpath.normpath(posixpath.join(base, uri))
        download(resolved)

(target / 'PROVENANCE.md').write_text('''# Quaternius RPG Character Pack\n\nSource: https://quaternius.itch.io/rpgcharacters\nLicense: CC0 1.0 Universal\n\nThe build stages only the six glTF character classes and the files referenced by those glTF documents. No Harry Potter assets, names, symbols, costumes or characters are included.\n''')

print('STAGED_RPG_ASSETS')
for path in sorted(p for p in target.rglob('*') if p.is_file()):
    print(path.relative_to(target), path.stat().st_size)
PY
