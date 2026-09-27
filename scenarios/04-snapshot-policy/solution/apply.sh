#!/usr/bin/env bash
# Еталон: політика оновлення для snapshot — daily (або always, якщо потрібно щомиті).
set -euo pipefail
WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
P="$WORKDIR/04/pom.xml"
python3 - "$P" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
text = text.replace("<updatePolicy>never</updatePolicy>", "<updatePolicy>daily</updatePolicy>")
p.write_text(text, encoding="utf-8")
print("   еталон: updatePolicy=daily")
PY
