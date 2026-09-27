#!/usr/bin/env bash
# Еталон: mirror перехоплює лише central, внутрішні репозиторії не чіпає.
set -euo pipefail
WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
S="$WORKDIR/03/settings.xml"
python3 - "$S" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
text = text.replace("<mirrorOf>*</mirrorOf>", "<mirrorOf>central</mirrorOf>")
p.write_text(text, encoding="utf-8")
print("   еталон: mirrorOf звужено до central")
PY
