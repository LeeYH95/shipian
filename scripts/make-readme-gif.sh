#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Convert the approved film without changing its scene order or timing.
ffmpeg -v error -y -i docs/media/shipian-intro.mp4 \
  -filter_complex "fps=15,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff:reserve_transparent=0[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  -loop 0 docs/media/shipian-preview.gif

python3 - <<'PY'
from pathlib import Path
path = Path('docs/media/shipian-preview.gif')
size = path.stat().st_size
if size > 10_000_000:
    raise SystemExit('GIF exceeds the 10 MB preview budget; review before publishing.')
print(f'Built {path} ({size / 1024 / 1024:.1f} MiB)')
PY
