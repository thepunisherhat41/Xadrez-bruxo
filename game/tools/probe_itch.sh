#!/usr/bin/env bash
set -euo pipefail
URL="https://quaternius.itch.io/modular-character-outfits-fantasy/purchase"
TMP="$(mktemp)"
curl -fsSL -A 'Mozilla/5.0' "$URL" -o "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(errors='ignore')
needle = 'No thanks, just take me to the downloads'
pos = text.find(needle)
print('ITCH_PURCHASE_HTML_BYTES', len(text))
print('NO_THANKS_OFFSET', pos)
if pos >= 0:
    print(text[max(0,pos-1200):pos+1800])
print('CANDIDATE_LINKS')
for m in re.finditer(r'(?:href|action|data-[\w-]+)="([^"]+)"', text):
    value = m.group(1)
    low = value.lower()
    if any(key in low for key in ('download','purchase','skip','upload','claim')):
        print(value)
PY
